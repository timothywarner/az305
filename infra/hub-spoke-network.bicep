// ============================================================================
// Hub-Spoke Network Topology with Azure Firewall
// ============================================================================
// Purpose: Deploy hub-spoke network architecture with Azure Firewall
// AZ-305 Exam Objectives:
//   - Design a solution for network connectivity (Objective 4.2)
//   - Design authentication and authorization solutions (Objective 1.1)
// Prerequisites:
//   - Resource group must exist
//   - Log Analytics workspace for firewall diagnostics (optional)
// ============================================================================

targetScope = 'resourceGroup'

// ============================================================================
// Parameters
// ============================================================================

@description('Name prefix for network resources.')
@minLength(1)
@maxLength(20)
param networkNamePrefix string

@description('Azure region for the networks.')
param location string = resourceGroup().location

@description('Hub virtual network address space.')
param hubVnetAddressPrefix string = '10.0.0.0/16'

@description('Hub firewall subnet address prefix (must be /26 or larger).')
param firewallSubnetPrefix string = '10.0.0.0/26'

@description('Hub management subnet address prefix.')
param hubManagementSubnetPrefix string = '10.0.1.0/24'

@description('Hub bastion subnet address prefix (must be /26 or larger).')
param bastionSubnetPrefix string = '10.0.2.0/26'

@description('Hub gateway subnet address prefix.')
param gatewaySubnetPrefix string = '10.0.3.0/27'

@description('Spoke 1 virtual network address space.')
param spoke1VnetAddressPrefix string = '10.1.0.0/16'

@description('Spoke 1 workload subnet address prefix.')
param spoke1WorkloadSubnetPrefix string = '10.1.0.0/24'

@description('Spoke 2 virtual network address space.')
param spoke2VnetAddressPrefix string = '10.2.0.0/16'

@description('Spoke 2 workload subnet address prefix.')
param spoke2WorkloadSubnetPrefix string = '10.2.0.0/24'

@description('Deploy Azure Firewall.')
param deployFirewall bool = true

@description('Azure Firewall SKU.')
@allowed([
  'Standard'
  'Premium'
])
param firewallSku string = 'Standard'

@description('Deploy Azure Bastion.')
param deployBastion bool = true

@description('Azure Bastion SKU.')
@allowed([
  'Basic'
  'Standard'
])
param bastionSku string = 'Standard'

@description('Log Analytics workspace ID for diagnostics.')
param logAnalyticsWorkspaceId string = ''

@description('Tags to apply to resources.')
param tags object = {
  environment: 'production'
  purpose: 'networking'
  examObjective: 'AZ-305-Networking'
}

// ============================================================================
// Variables
// ============================================================================

var hubVnetName = 'vnet-${networkNamePrefix}-hub'
var spoke1VnetName = 'vnet-${networkNamePrefix}-spoke1'
var spoke2VnetName = 'vnet-${networkNamePrefix}-spoke2'
var firewallName = 'afw-${networkNamePrefix}'
var firewallPolicyName = 'afwp-${networkNamePrefix}'
var firewallPublicIpName = 'pip-${firewallName}'
var bastionName = 'bas-${networkNamePrefix}'
var bastionPublicIpName = 'pip-${bastionName}'

// ============================================================================
// Resources - Hub Virtual Network
// ============================================================================

@description('Hub virtual network')
resource hubVnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: hubVnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        hubVnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: firewallSubnetPrefix
        }
      }
      {
        name: 'AzureFirewallManagementSubnet'
        properties: {
          addressPrefix: hubManagementSubnetPrefix
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: bastionSubnetPrefix
        }
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: gatewaySubnetPrefix
        }
      }
    ]
    enableDdosProtection: false
  }
}

// ============================================================================
// Resources - Spoke Virtual Networks
// ============================================================================

@description('Spoke 1 virtual network')
resource spoke1Vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: spoke1VnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        spoke1VnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: 'snet-workload'
        properties: {
          addressPrefix: spoke1WorkloadSubnetPrefix
          routeTable: deployFirewall ? {
            id: spoke1RouteTable.id
          } : null
          networkSecurityGroup: {
            id: workloadNsg.id
          }
        }
      }
    ]
    enableDdosProtection: false
  }
  dependsOn: [
    spoke1RouteTable
    workloadNsg
  ]
}

@description('Spoke 2 virtual network')
resource spoke2Vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: spoke2VnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        spoke2VnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: 'snet-workload'
        properties: {
          addressPrefix: spoke2WorkloadSubnetPrefix
          routeTable: deployFirewall ? {
            id: spoke2RouteTable.id
          } : null
          networkSecurityGroup: {
            id: workloadNsg.id
          }
        }
      }
    ]
    enableDdosProtection: false
  }
  dependsOn: [
    spoke2RouteTable
    workloadNsg
  ]
}

// ============================================================================
// Resources - Network Security Groups
// ============================================================================

@description('Workload NSG')
resource workloadNsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: 'nsg-${networkNamePrefix}-workload'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowHttpsInbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowHttpInbound'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
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
        }
      }
    ]
  }
}

// ============================================================================
// Resources - Route Tables
// ============================================================================

@description('Spoke 1 route table')
resource spoke1RouteTable 'Microsoft.Network/routeTables@2023-09-01' = if (deployFirewall) {
  name: 'rt-${networkNamePrefix}-spoke1'
  location: location
  tags: tags
  properties: {
    disableBgpRoutePropagation: true
    routes: [
      {
        name: 'default-to-firewall'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: deployFirewall ? firewall.properties.ipConfigurations[0].properties.privateIPAddress : ''
        }
      }
      {
        name: 'spoke2-to-firewall'
        properties: {
          addressPrefix: spoke2VnetAddressPrefix
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: deployFirewall ? firewall.properties.ipConfigurations[0].properties.privateIPAddress : ''
        }
      }
    ]
  }
  dependsOn: [
    firewall
  ]
}

@description('Spoke 2 route table')
resource spoke2RouteTable 'Microsoft.Network/routeTables@2023-09-01' = if (deployFirewall) {
  name: 'rt-${networkNamePrefix}-spoke2'
  location: location
  tags: tags
  properties: {
    disableBgpRoutePropagation: true
    routes: [
      {
        name: 'default-to-firewall'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: deployFirewall ? firewall.properties.ipConfigurations[0].properties.privateIPAddress : ''
        }
      }
      {
        name: 'spoke1-to-firewall'
        properties: {
          addressPrefix: spoke1VnetAddressPrefix
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: deployFirewall ? firewall.properties.ipConfigurations[0].properties.privateIPAddress : ''
        }
      }
    ]
  }
  dependsOn: [
    firewall
  ]
}

// ============================================================================
// Resources - VNet Peerings
// ============================================================================

@description('Hub to Spoke 1 peering')
resource hubToSpoke1Peering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-09-01' = {
  parent: hubVnet
  name: 'peer-hub-to-spoke1'
  properties: {
    remoteVirtualNetwork: {
      id: spoke1Vnet.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: true
    useRemoteGateways: false
  }
}

@description('Spoke 1 to Hub peering')
resource spoke1ToHubPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-09-01' = {
  parent: spoke1Vnet
  name: 'peer-spoke1-to-hub'
  properties: {
    remoteVirtualNetwork: {
      id: hubVnet.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
  }
}

@description('Hub to Spoke 2 peering')
resource hubToSpoke2Peering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-09-01' = {
  parent: hubVnet
  name: 'peer-hub-to-spoke2'
  properties: {
    remoteVirtualNetwork: {
      id: spoke2Vnet.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: true
    useRemoteGateways: false
  }
}

@description('Spoke 2 to Hub peering')
resource spoke2ToHubPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-09-01' = {
  parent: spoke2Vnet
  name: 'peer-spoke2-to-hub'
  properties: {
    remoteVirtualNetwork: {
      id: hubVnet.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
  }
}

// ============================================================================
// Resources - Azure Firewall
// ============================================================================

@description('Azure Firewall public IP')
resource firewallPublicIp 'Microsoft.Network/publicIPAddresses@2023-09-01' = if (deployFirewall) {
  name: firewallPublicIpName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  zones: ['1', '2', '3']
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

@description('Azure Firewall policy')
resource firewallPolicy 'Microsoft.Network/firewallPolicies@2023-09-01' = if (deployFirewall) {
  name: firewallPolicyName
  location: location
  tags: tags
  properties: {
    sku: {
      tier: firewallSku
    }
    threatIntelMode: 'Alert'
    threatIntelWhitelist: {
      fqdns: []
      ipAddresses: []
    }
    dnsSettings: {
      enableProxy: true
    }
  }
}

@description('Azure Firewall policy rule collection group')
resource firewallPolicyRuleGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2023-09-01' = if (deployFirewall) {
  parent: firewallPolicy
  name: 'DefaultRuleCollectionGroup'
  properties: {
    priority: 200
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'AllowSpokeCommunication'
        priority: 100
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'AllowSpoke1ToSpoke2'
            ipProtocols: ['Any']
            sourceAddresses: [spoke1VnetAddressPrefix]
            destinationAddresses: [spoke2VnetAddressPrefix]
            destinationPorts: ['*']
          }
          {
            ruleType: 'NetworkRule'
            name: 'AllowSpoke2ToSpoke1'
            ipProtocols: ['Any']
            sourceAddresses: [spoke2VnetAddressPrefix]
            destinationAddresses: [spoke1VnetAddressPrefix]
            destinationPorts: ['*']
          }
        ]
      }
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'AllowOutboundHTTPS'
        priority: 200
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'ApplicationRule'
            name: 'AllowMicrosoftUpdates'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            sourceAddresses: ['*']
            targetFqdns: [
              '*.microsoft.com'
              '*.windowsupdate.com'
              '*.azure.com'
            ]
          }
        ]
      }
    ]
  }
}

@description('Azure Firewall')
resource firewall 'Microsoft.Network/azureFirewalls@2023-09-01' = if (deployFirewall) {
  name: firewallName
  location: location
  tags: tags
  zones: ['1', '2', '3']
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: firewallSku
    }
    firewallPolicy: {
      id: firewallPolicy.id
    }
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: '${hubVnet.id}/subnets/AzureFirewallSubnet'
          }
          publicIPAddress: {
            id: firewallPublicIp.id
          }
        }
      }
    ]
  }
  dependsOn: [
    firewallPolicy
    firewallPolicyRuleGroup
  ]
}

// ============================================================================
// Resources - Azure Bastion
// ============================================================================

@description('Azure Bastion public IP')
resource bastionPublicIp 'Microsoft.Network/publicIPAddresses@2023-09-01' = if (deployBastion) {
  name: bastionPublicIpName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  zones: ['1', '2', '3']
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

@description('Azure Bastion')
resource bastion 'Microsoft.Network/bastionHosts@2023-09-01' = if (deployBastion) {
  name: bastionName
  location: location
  tags: tags
  sku: {
    name: bastionSku
  }
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: '${hubVnet.id}/subnets/AzureBastionSubnet'
          }
          publicIPAddress: {
            id: bastionPublicIp.id
          }
        }
      }
    ]
    enableTunneling: bastionSku == 'Standard'
    enableFileCopy: bastionSku == 'Standard'
    enableIpConnect: bastionSku == 'Standard'
    enableShareableLink: bastionSku == 'Standard'
  }
}

// ============================================================================
// Resources - Diagnostic Settings
// ============================================================================

@description('Firewall diagnostic settings')
resource firewallDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (deployFirewall && !empty(logAnalyticsWorkspaceId)) {
  name: 'firewall-diagnostics'
  scope: firewall
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('Hub VNet ID')
output hubVnetId string = hubVnet.id

@description('Hub VNet name')
output hubVnetName string = hubVnet.name

@description('Spoke 1 VNet ID')
output spoke1VnetId string = spoke1Vnet.id

@description('Spoke 1 VNet name')
output spoke1VnetName string = spoke1Vnet.name

@description('Spoke 2 VNet ID')
output spoke2VnetId string = spoke2Vnet.id

@description('Spoke 2 VNet name')
output spoke2VnetName string = spoke2Vnet.name

@description('Firewall private IP')
output firewallPrivateIp string = deployFirewall ? firewall.properties.ipConfigurations[0].properties.privateIPAddress : ''

@description('Firewall public IP')
output firewallPublicIp string = deployFirewall ? firewallPublicIp.properties.ipAddress : ''

@description('Firewall name')
output firewallName string = deployFirewall ? firewall.name : ''

@description('Bastion name')
output bastionName string = deployBastion ? bastion.name : ''

@description('Spoke 1 workload subnet ID')
output spoke1WorkloadSubnetId string = '${spoke1Vnet.id}/subnets/snet-workload'

@description('Spoke 2 workload subnet ID')
output spoke2WorkloadSubnetId string = '${spoke2Vnet.id}/subnets/snet-workload'

@description('Gateway subnet ID')
output gatewaySubnetId string = '${hubVnet.id}/subnets/GatewaySubnet'
