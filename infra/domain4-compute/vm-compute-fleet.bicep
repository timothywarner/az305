// ============================================================================
// VM Compute Fleet - Multi-Pattern Teaching Template
// ============================================================================
// Purpose: Deploy multiple VM patterns for AZ-305 learners to explore
// AZ-305 Exam Objectives:
//   - Design a compute solution (Objective 4.1)
//   - Recommend a solution for compute infrastructure (Objective 4.1)
//   - Recommend a solution for containers (comparison context)
// Teaching Points:
//   - Windows vs Linux VM deployment patterns
//   - Availability Zones for high availability
//   - Spot VMs for cost optimization
//   - VM Scale Sets for horizontal scaling
//   - Managed identities (Zero Trust)
//   - NSG rules and network segmentation
//   - Boot diagnostics for troubleshooting
//   - Managed disk SKU selection (Premium vs Standard)
// Prerequisites:
//   - Resource group must exist
//   - Contributor role on the resource group
//   - Sufficient quota for Standard_B2as_v2 and Standard_B2as_v2
// Estimated Cost: ~$15-20/day (delete resources after demo)
// ============================================================================

targetScope = 'resourceGroup'

// ============================================================================
// Parameters
// ============================================================================

@description('Base name prefix for all resources. Uses contoso convention.')
@minLength(1)
@maxLength(15)
param namePrefix string

@description('Azure region. All resources deploy to the same region.')
param location string = resourceGroup().location

// --- VM Admin Credentials ---
// AZ-305 Teaching Point: @secure() prevents parameter values from appearing
// in deployment logs, ARM template outputs, or the Azure Portal deployment
// history. For production workloads, use Azure Key Vault references instead.

@description('Administrator username for all VMs.')
@minLength(1)
@maxLength(20)
param adminUsername string

@description('Administrator password for all VMs. Minimum 12 characters with complexity requirements.')
@secure()
@minLength(12)
param adminPassword string

// --- Network Security ---
// AZ-305 Teaching Point: Zero Trust principle - never allow management ports
// from the entire internet. Restrict to known source IPs. In production,
// use Azure Bastion instead of direct RDP/SSH access.

@description('Source IP address or CIDR range allowed for RDP/SSH access. Use your public IP (e.g., 203.0.113.50/32). Use * only for quick demos.')
param allowedSourceIP string

// --- Networking ---

@description('Virtual network address space.')
param vnetAddressPrefix string = '10.10.0.0/16'

@description('Web tier subnet address prefix (Windows VM).')
param webSubnetPrefix string = '10.10.1.0/24'

@description('App tier subnet address prefix (Linux VM).')
param appSubnetPrefix string = '10.10.2.0/24'

@description('Spot tier subnet address prefix (Spot VM).')
param spotSubnetPrefix string = '10.10.3.0/24'

@description('Scale set subnet address prefix (VMSS).')
param vmssSubnetPrefix string = '10.10.4.0/24'

// --- Tags ---

@description('Tags applied to every resource for governance and cost tracking.')
param tags object = {
  environment: 'demo'
  purpose: 'az305-compute-fleet'
  examObjective: 'AZ-305-Domain4-Compute'
  owner: 'contoso-training'
  deleteAfter: 'demo-complete'
}

// ============================================================================
// Variables
// ============================================================================

// AZ-305 Teaching Point: Consistent naming conventions are critical for
// governance at scale. Microsoft recommends the pattern:
// <resource-type>-<workload>-<environment>-<region>
// See: https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming

var vnetName = 'vnet-${namePrefix}-compute-fleet'
var nsgWindowsName = 'nsg-${namePrefix}-web'
var nsgLinuxName = 'nsg-${namePrefix}-app'
var nsgSpotName = 'nsg-${namePrefix}-spot'
var nsgVmssName = 'nsg-${namePrefix}-vmss'

var windowsVmName = 'vm-${namePrefix}-web'
var linuxVmName = 'vm-${namePrefix}-app'
var spotVmName = 'vm-${namePrefix}-spot'
var vmssName = 'vmss-${namePrefix}-scale'

var windowsNicName = 'nic-${windowsVmName}'
var linuxNicName = 'nic-${linuxVmName}'
var spotNicName = 'nic-${spotVmName}'

// ============================================================================
// Resources - Virtual Network
// ============================================================================
// AZ-305 Teaching Point: Network segmentation is a Zero Trust fundamental.
// Each workload tier gets its own subnet with its own NSG. This limits
// lateral movement if one tier is compromised.

@description('Shared virtual network with tiered subnets for compute fleet')
resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: 'snet-web'
        properties: {
          addressPrefix: webSubnetPrefix
          networkSecurityGroup: {
            id: nsgWindows.id
          }
        }
      }
      {
        name: 'snet-app'
        properties: {
          addressPrefix: appSubnetPrefix
          networkSecurityGroup: {
            id: nsgLinux.id
          }
        }
      }
      {
        name: 'snet-spot'
        properties: {
          addressPrefix: spotSubnetPrefix
          networkSecurityGroup: {
            id: nsgSpot.id
          }
        }
      }
      {
        name: 'snet-vmss'
        properties: {
          addressPrefix: vmssSubnetPrefix
          networkSecurityGroup: {
            id: nsgVmss.id
          }
        }
      }
    ]
  }
}

// ============================================================================
// Resources - Network Security Groups
// ============================================================================
// AZ-305 Teaching Point: NSGs are stateful firewalls at the subnet and NIC
// level. The exam tests your understanding of NSG rule evaluation order
// (lowest priority number wins) and the difference between subnet-level
// and NIC-level NSGs. Always use explicit deny-all rules as a safety net.

@description('NSG for Windows web tier - allows RDP from restricted source only')
resource nsgWindows 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: nsgWindowsName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        // AZ-305 Teaching Point: In production, use Azure Bastion instead of
        // opening RDP directly. This rule is for demo purposes only.
        name: 'AllowRDP'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: allowedSourceIP
          destinationAddressPrefix: '*'
          description: 'Allow RDP from admin source IP only (use Bastion in production)'
        }
      }
      {
        name: 'AllowHTTPS'
        properties: {
          priority: 200
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          description: 'Allow HTTPS inbound for web serving'
        }
      }
      {
        // AZ-305 Teaching Point: Explicit deny-all is a defense-in-depth
        // measure. Azure has implicit deny at 65500 priority, but an explicit
        // rule at 4096 makes the intent clear and logs denied traffic.
        name: 'DenyAllInbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          description: 'Explicit deny-all for defense in depth'
        }
      }
    ]
  }
}

@description('NSG for Linux app tier - allows SSH from restricted source only')
resource nsgLinux 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: nsgLinuxName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowSSH'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: allowedSourceIP
          destinationAddressPrefix: '*'
          description: 'Allow SSH from admin source IP only (use Bastion in production)'
        }
      }
      {
        name: 'AllowAppPort'
        properties: {
          priority: 200
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '8080'
          sourceAddressPrefix: webSubnetPrefix
          destinationAddressPrefix: '*'
          description: 'Allow app traffic from web tier only (micro-segmentation)'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          description: 'Explicit deny-all for defense in depth'
        }
      }
    ]
  }
}

@description('NSG for Spot VM tier - SSH from restricted source only')
resource nsgSpot 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: nsgSpotName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowSSH'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: allowedSourceIP
          destinationAddressPrefix: '*'
          description: 'Allow SSH from admin source IP only'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          description: 'Explicit deny-all for defense in depth'
        }
      }
    ]
  }
}

@description('NSG for VMSS tier - allows HTTP from anywhere for load testing')
resource nsgVmss 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: nsgVmssName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowHTTP'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          description: 'Allow HTTP for scale testing demos'
        }
      }
      {
        name: 'AllowSSH'
        properties: {
          priority: 200
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: allowedSourceIP
          destinationAddressPrefix: '*'
          description: 'Allow SSH from admin source IP only'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          description: 'Explicit deny-all for defense in depth'
        }
      }
    ]
  }
}

// ============================================================================
// Resources - Network Interfaces
// ============================================================================

@description('NIC for the Windows web VM')
resource windowsNic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: windowsNicName
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: vnet.properties.subnets[0].id
          }
        }
      }
    ]
    // AZ-305 Teaching Point: No public IP assigned. In production, use
    // Azure Bastion or a jump box for management access. Direct public
    // IPs on VMs violate Zero Trust principles.
  }
}

@description('NIC for the Linux app VM')
resource linuxNic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: linuxNicName
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: vnet.properties.subnets[1].id
          }
        }
      }
    ]
  }
}

@description('NIC for the Spot VM')
resource spotNic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: spotNicName
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: vnet.properties.subnets[2].id
          }
        }
      }
    ]
  }
}

// ============================================================================
// Resource 1 - Windows VM (Web Server)
// ============================================================================
// AZ-305 Teaching Point: Windows Server VMs are common for IIS-based web
// apps, .NET Framework workloads, and Active Directory. The exam tests
// when to use VMs vs App Service vs Container Apps.
//
// Key decisions for the exam:
// - Availability Zone 1: Protects against datacenter-level failures
// - Premium SSD: Required for production SLA (99.9% single-instance)
// - Managed identity: Eliminates stored credentials for Azure service access
// - Boot diagnostics: Essential for troubleshooting boot failures

@description('Windows Server 2022 VM simulating a web server in Availability Zone 1')
resource windowsVm 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: windowsVmName
  location: location
  tags: union(tags, {
    role: 'web-server'
    os: 'windows'
    tier: 'frontend'
  })
  // AZ-305 Teaching Point: Availability Zones provide 99.99% SLA when
  // you deploy 2+ VMs across zones. A single VM in a zone still gets
  // 99.9% SLA with Premium SSDs. The exam frequently tests zone placement.
  // Note: Zone pinning removed for subscription capacity compatibility.
  // In production, use zones: ['1'] for explicit zone placement.
  identity: {
    // AZ-305 Teaching Point: System-assigned managed identity is the
    // simplest Zero Trust pattern. The identity lifecycle is tied to the
    // VM - when the VM is deleted, the identity is automatically cleaned up.
    // Use user-assigned identity when multiple resources share an identity.
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      // AZ-305 Teaching Point: Standard_B2as_v2 is a general-purpose VM.
      // The "s" means Premium Storage capable. The "v5" is the latest
      // generation with better price/performance. The exam tests SKU
      // selection: B-series (burstable), D-series (general), E-series
      // (memory), F-series (compute), L-series (storage), N-series (GPU).
      vmSize: 'Standard_B2as_v2'
    }
    osProfile: {
      computerName: take(windowsVmName, 15)
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: true
        // AZ-305 Teaching Point: Patch orchestration mode 'AutomaticByPlatform'
        // integrates with Azure Update Manager for controlled patching
        // with maintenance windows. Critical for Operational Excellence.
        patchSettings: {
          patchMode: 'AutomaticByPlatform'
          assessmentMode: 'AutomaticByPlatform'
          automaticByPlatformSettings: {
            rebootSetting: 'IfRequired'
          }
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter-azure-edition'
        version: 'latest'
      }
      osDisk: {
        name: 'osdisk-${windowsVmName}'
        createOption: 'FromImage'
        // AZ-305 Teaching Point: Premium SSD (Premium_LRS) is REQUIRED
        // for the 99.9% single-instance SLA. Standard SSD (StandardSSD_LRS)
        // does NOT qualify. This is a common exam question.
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
        caching: 'ReadWrite'
        deleteOption: 'Delete'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: windowsNic.id
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        // AZ-305 Teaching Point: When enabled is true and storageUri is
        // omitted, Azure uses a managed storage account. This is the
        // recommended approach - no need to manage a separate storage
        // account for diagnostics.
        enabled: true
      }
    }
    // AZ-305 Teaching Point: securityProfile with securityType 'TrustedLaunch'
    // enables Secure Boot and vTPM. This is a security baseline for new VMs.
    securityProfile: {
      securityType: 'TrustedLaunch'
      uefiSettings: {
        secureBootEnabled: true
        vTpmEnabled: true
      }
    }
  }
}

// ============================================================================
// Resource 2 - Linux VM (App Server)
// ============================================================================
// AZ-305 Teaching Point: Linux VMs cost less than Windows (no OS license).
// Ubuntu is the most popular Linux distribution on Azure. The exam tests
// understanding of Linux vs Windows trade-offs for cost optimization.
//
// Key differences from the Windows VM:
// - Availability Zone 2: Different zone for cross-zone HA pattern
// - Standard SSD: Demonstrates cost optimization for non-SLA workloads
// - SSH key auth: More secure than password for Linux

@description('Ubuntu 22.04 LTS VM simulating an app server in Availability Zone 2')
resource linuxVm 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: linuxVmName
  location: location
  tags: union(tags, {
    role: 'app-server'
    os: 'linux'
    tier: 'backend'
  })
  // AZ-305 Teaching Point: Placing VMs in different zones demonstrates
  // cross-zone deployment. If Zone 1 fails, Zone 2 continues serving
  // app-tier traffic. Zone pinning removed for capacity compatibility.
  // In production, use zones: ['2'] for explicit zone placement.
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B2as_v2'
    }
    osProfile: {
      computerName: take(linuxVmName, 64)
      adminUsername: adminUsername
      adminPassword: adminPassword
      // AZ-305 Teaching Point: disablePasswordAuthentication = false here
      // for demo simplicity. In production, set to true and use SSH keys
      // exclusively. Password auth is a security risk for Linux VMs.
      linuxConfiguration: {
        disablePasswordAuthentication: false
        provisionVMAgent: true
        patchSettings: {
          patchMode: 'AutomaticByPlatform'
          assessmentMode: 'AutomaticByPlatform'
          automaticByPlatformSettings: {
            rebootSetting: 'IfRequired'
          }
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        name: 'osdisk-${linuxVmName}'
        createOption: 'FromImage'
        // AZ-305 Teaching Point: StandardSSD_LRS is cheaper than
        // Premium_LRS but does NOT qualify for the 99.9% single-instance
        // SLA. Use this for dev/test or non-critical workloads.
        // Cost comparison: Premium ~$7.68/mo vs Standard SSD ~$3.84/mo
        // for 64 GB disk.
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
        caching: 'ReadWrite'
        deleteOption: 'Delete'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: linuxNic.id
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
    securityProfile: {
      securityType: 'TrustedLaunch'
      uefiSettings: {
        secureBootEnabled: true
        vTpmEnabled: true
      }
    }
  }
}

// ============================================================================
// Resource 3 - Spot VM (Cost Optimization)
// ============================================================================
// AZ-305 Teaching Point: Spot VMs use unused Azure capacity at up to 90%
// discount. Azure can evict them with 30 seconds notice when capacity is
// needed. The exam tests when Spot VMs are appropriate:
//   GOOD FOR: Batch processing, CI/CD agents, dev/test, stateless workers
//   BAD FOR:  Production web servers, databases, stateful workloads
//
// Eviction policies:
// - Deallocate: VM stops, disks preserved, can restart when capacity returns
// - Delete: VM and disks are deleted (cheapest, use for truly ephemeral work)

@description('Spot VM demonstrating cost optimization with eviction policy')
resource spotVm 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: spotVmName
  location: location
  tags: union(tags, {
    role: 'batch-worker'
    os: 'linux'
    tier: 'spot-compute'
    costOptimization: 'spot-instance'
  })
  // AZ-305 Teaching Point: Spot VMs do NOT support Availability Zones
  // in the same way as regular VMs. You cannot guarantee zone placement
  // because Azure places them wherever spare capacity exists.
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      // AZ-305 Teaching Point: Larger SKUs are often a better value for
      // Spot VMs because the discount percentage is the same but you get
      // more compute per eviction/restart cycle.
      vmSize: 'Standard_B2as_v2'
    }
    // AZ-305 Teaching Point: priority = 'Spot' is the key property.
    // billingProfile.maxPrice = -1 means you accept the current spot price
    // (up to pay-as-you-go price). You can set a specific max price to
    // control costs, but you risk more frequent evictions.
    priority: 'Spot'
    evictionPolicy: 'Deallocate'
    billingProfile: {
      maxPrice: -1
    }
    osProfile: {
      computerName: take(spotVmName, 64)
      adminUsername: adminUsername
      adminPassword: adminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
        provisionVMAgent: true
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        name: 'osdisk-${spotVmName}'
        createOption: 'FromImage'
        // AZ-305 Teaching Point: Use Standard SSD or even Standard HDD
        // for Spot VMs to minimize cost. Premium SSD is wasted money on
        // a VM that can be evicted at any time.
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
        caching: 'ReadWrite'
        // AZ-305 Teaching Point: deleteOption = 'Delete' on a Spot VM
        // means when the VM is deleted, the disk goes with it. For Spot
        // workloads with Deallocate eviction, the disk persists across
        // evictions but is cleaned up on explicit VM deletion.
        deleteOption: 'Delete'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: spotNic.id
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
    securityProfile: {
      securityType: 'TrustedLaunch'
      uefiSettings: {
        secureBootEnabled: true
        vTpmEnabled: true
      }
    }
  }
}

// ============================================================================
// Resource 4 - VM Scale Set (Auto-Scaling)
// ============================================================================
// AZ-305 Teaching Point: VMSS provides identical VMs that scale horizontally.
// The exam tests VMSS vs other scaling options:
//   - VMSS: Best for stateless, identical workloads needing rapid scale
//   - App Service: Better for web apps (managed platform, less control)
//   - AKS/Container Apps: Better for microservices and containers
//   - Azure Functions: Best for event-driven, short-duration compute
//
// Orchestration modes:
// - Flexible: Recommended for new deployments, supports mixed VM sizes
// - Uniform: Legacy mode, all VMs must be identical

@description('VM Scale Set with autoscaling and zone redundancy')
resource vmss 'Microsoft.Compute/virtualMachineScaleSets@2024-03-01' = {
  name: vmssName
  location: location
  tags: union(tags, {
    role: 'scalable-workload'
    os: 'linux'
    tier: 'vmss-compute'
    autoScale: 'enabled'
  })
  // AZ-305 Teaching Point: Zone-redundant VMSS distributes instances
  // across all specified zones automatically. Azure balances the instance
  // count across zones. This provides 99.99% SLA.
  // Note: Zone pinning removed for subscription capacity compatibility.
  // In production, use zones: ['1', '2', '3'] for zone redundancy.
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'Standard_B2as_v2'
    tier: 'Standard'
    // AZ-305 Teaching Point: This capacity is the INITIAL instance count.
    // The autoscale rules (defined below) control the actual running count
    // between min and max based on CPU utilization.
    capacity: 2
  }
  properties: {
    // AZ-305 Teaching Point: Flexible orchestration mode is recommended
    // for new VMSS deployments. It supports mixing VM sizes, manual
    // instance addition, and availability zone spreading.
    orchestrationMode: 'Flexible'
    platformFaultDomainCount: 1
    virtualMachineProfile: {
      osProfile: {
        computerNamePrefix: take(namePrefix, 9)
        adminUsername: adminUsername
        adminPassword: adminPassword
        linuxConfiguration: {
          disablePasswordAuthentication: false
          provisionVMAgent: true
        }
      }
      storageProfile: {
        imageReference: {
          publisher: 'Canonical'
          offer: '0001-com-ubuntu-server-jammy'
          sku: '22_04-lts-gen2'
          version: 'latest'
        }
        osDisk: {
          createOption: 'FromImage'
          managedDisk: {
            storageAccountType: 'StandardSSD_LRS'
          }
          caching: 'ReadWrite'
        }
      }
      networkProfile: {
        networkApiVersion: '2020-11-01'
        networkInterfaceConfigurations: [
          {
            name: 'nic-${vmssName}'
            properties: {
              primary: true
              ipConfigurations: [
                {
                  name: 'ipconfig1'
                  properties: {
                    primary: true
                    subnet: {
                      id: vnet.properties.subnets[3].id
                    }
                  }
                }
              ]
            }
          }
        ]
      }
      diagnosticsProfile: {
        bootDiagnostics: {
          enabled: true
        }
      }
      securityProfile: {
        securityType: 'TrustedLaunch'
        uefiSettings: {
          secureBootEnabled: true
          vTpmEnabled: true
        }
      }
    }
  }
}

// ============================================================================
// Resources - Autoscale Settings for VMSS
// ============================================================================
// AZ-305 Teaching Point: Autoscale rules define WHEN to scale and BY HOW
// MUCH. The exam tests metric-based vs schedule-based scaling:
//   - Metric-based: React to CPU, memory, queue depth, custom metrics
//   - Schedule-based: Predictable load patterns (business hours, weekends)
//   - Combined: Both rules apply; the higher instance count wins
//
// Scale-out vs scale-in:
//   - Scale-out (add instances): Use shorter cooldown, lower threshold
//   - Scale-in (remove instances): Use longer cooldown, higher threshold
//   This asymmetry prevents "flapping" (rapid scale-out then scale-in).

@description('Autoscale settings for the VM Scale Set with CPU-based rules')
resource autoscaleSettings 'Microsoft.Insights/autoscalesettings@2022-10-01' = {
  name: 'autoscale-${vmssName}'
  location: location
  tags: tags
  properties: {
    enabled: true
    targetResourceUri: vmss.id
    profiles: [
      {
        name: 'CPU-based autoscaling'
        capacity: {
          // AZ-305 Teaching Point: minimum = guaranteed always running.
          // default = starting count when no metric data available.
          // maximum = cost ceiling. Set max carefully to control spend.
          minimum: '2'
          maximum: '5'
          default: '2'
        }
        rules: [
          {
            // Scale OUT rule: Add 1 instance when average CPU > 70%
            // for 5 minutes. 5-minute cooldown prevents rapid scaling.
            metricTrigger: {
              metricName: 'Percentage CPU'
              metricResourceUri: vmss.id
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT5M'
              timeAggregation: 'Average'
              operator: 'GreaterThan'
              threshold: 70
            }
            scaleAction: {
              direction: 'Increase'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT5M'
            }
          }
          {
            // Scale IN rule: Remove 1 instance when average CPU < 30%
            // for 10 minutes. Longer window and cooldown prevent flapping.
            // AZ-305 Teaching Point: The scale-in threshold (30%) is NOT
            // the inverse of scale-out (70%). This gap prevents oscillation.
            // If they were 70/70, the system would constantly scale out
            // then immediately scale in.
            metricTrigger: {
              metricName: 'Percentage CPU'
              metricResourceUri: vmss.id
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT10M'
              timeAggregation: 'Average'
              operator: 'LessThan'
              threshold: 30
            }
            scaleAction: {
              direction: 'Decrease'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT10M'
            }
          }
        ]
      }
    ]
  }
}

// ============================================================================
// Outputs
// ============================================================================
// AZ-305 Teaching Point: Outputs let you chain Bicep deployments together
// and verify what was deployed. In production, use deployment stacks or
// pipeline variables to pass outputs between deployment stages.

@description('Virtual network resource ID')
output vnetId string = vnet.id

@description('Virtual network name')
output vnetName string = vnet.name

@description('Windows VM resource ID')
output windowsVmId string = windowsVm.id

@description('Windows VM name')
output windowsVmName string = windowsVm.name

@description('Windows VM managed identity principal ID (use for RBAC assignments)')
output windowsVmPrincipalId string = windowsVm.identity.principalId

@description('Linux VM resource ID')
output linuxVmId string = linuxVm.id

@description('Linux VM name')
output linuxVmName string = linuxVm.name

@description('Linux VM managed identity principal ID (use for RBAC assignments)')
output linuxVmPrincipalId string = linuxVm.identity.principalId

@description('Spot VM resource ID')
output spotVmId string = spotVm.id

@description('Spot VM name')
output spotVmName string = spotVm.name

@description('Spot VM managed identity principal ID')
output spotVmPrincipalId string = spotVm.identity.principalId

@description('VM Scale Set resource ID')
output vmssId string = vmss.id

@description('VM Scale Set name')
output vmssName string = vmss.name

@description('VM Scale Set managed identity principal ID')
output vmssPrincipalId string = vmss.identity.principalId

@description('Web tier subnet ID')
output webSubnetId string = vnet.properties.subnets[0].id

@description('App tier subnet ID')
output appSubnetId string = vnet.properties.subnets[1].id

@description('Spot tier subnet ID')
output spotSubnetId string = vnet.properties.subnets[2].id

@description('VMSS subnet ID')
output vmssSubnetId string = vnet.properties.subnets[3].id
