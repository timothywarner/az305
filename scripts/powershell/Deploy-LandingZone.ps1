<#
.SYNOPSIS
    Deploy a basic Azure Landing Zone foundation with networking and governance.

.DESCRIPTION
    This script creates a foundational landing zone structure including:
    - Resource groups for different workload types
    - Hub virtual network with standard subnets
    - Network security groups with baseline rules
    - Azure Bastion for secure VM access
    - Log Analytics workspace for centralized logging
    - Basic tagging and naming conventions

    This is a simplified landing zone for learning purposes. Production
    landing zones should use the Cloud Adoption Framework Enterprise-Scale
    reference implementation.

.PARAMETER SubscriptionId
    The Azure subscription ID where resources will be deployed.

.PARAMETER Location
    The Azure region for resource deployment. Default: eastus

.PARAMETER EnvironmentName
    Environment name (dev, test, prod). Used in resource naming.

.PARAMETER Prefix
    Naming prefix for all resources. Default: az305

.EXAMPLE
    # Deploy with default settings
    .\Deploy-LandingZone.ps1 -SubscriptionId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

.EXAMPLE
    # Deploy to specific environment
    .\Deploy-LandingZone.ps1 -SubscriptionId "xxx" -EnvironmentName "prod" -Location "westus2"

.NOTES
    AZ-305 EXAM OBJECTIVES:
    - Design identity, governance, and monitoring solutions
    - Implement landing zone architecture patterns
    - Configure network topology for enterprise workloads
    - Design for operational excellence and governance

.LINK
    https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/
    https://learn.microsoft.com/azure/architecture/landing-zones/
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $false)]
    [string]$Location = "eastus",

    [Parameter(Mandatory = $false)]
    [ValidateSet("dev", "test", "prod")]
    [string]$EnvironmentName = "dev",

    [Parameter(Mandatory = $false)]
    [string]$Prefix = "az305"
)

#Requires -Modules Az.Accounts, Az.Resources, Az.Network, Az.OperationalInsights

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

#-------------------------------------------------------------------------------
# HELPER FUNCTIONS
#-------------------------------------------------------------------------------
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "INFO" { "White" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR" { "Red" }
    }
    Write-Host "[$Level] $timestamp - $Message" -ForegroundColor $color
}

function Get-ResourceName {
    param([string]$ResourceType, [string]$Suffix = "")
    # WHY: Consistent naming convention helps with resource organization
    # and enables pattern-based policies and queries
    $name = "$Prefix-$EnvironmentName-$ResourceType"
    if ($Suffix) { $name += "-$Suffix" }
    return $name.ToLower()
}

#-------------------------------------------------------------------------------
# CONNECT TO AZURE
#-------------------------------------------------------------------------------
function Connect-ToAzure {
    Write-Log "Connecting to Azure subscription: $SubscriptionId"

    # Check if already connected
    $context = Get-AzContext -ErrorAction SilentlyContinue
    if (-not $context -or $context.Subscription.Id -ne $SubscriptionId) {
        Connect-AzAccount -SubscriptionId $SubscriptionId
    }

    Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
    Write-Log "Connected to subscription: $((Get-AzContext).Subscription.Name)" -Level "SUCCESS"
}

#-------------------------------------------------------------------------------
# CREATE RESOURCE GROUPS
#-------------------------------------------------------------------------------
function New-LandingZoneResourceGroups {
    Write-Log "Creating resource groups..."

    # WHY: Separate resource groups for different functions enable:
    # - RBAC at the resource group level
    # - Cost tracking per workload/function
    # - Lifecycle management (delete entire group)

    $resourceGroups = @(
        @{ Name = Get-ResourceName -ResourceType "network-rg"; Purpose = "Networking" },
        @{ Name = Get-ResourceName -ResourceType "shared-rg"; Purpose = "SharedServices" },
        @{ Name = Get-ResourceName -ResourceType "workload-rg"; Purpose = "Workloads" },
        @{ Name = Get-ResourceName -ResourceType "security-rg"; Purpose = "Security" }
    )

    $tags = @{
        Environment = $EnvironmentName
        ManagedBy   = "PowerShell"
        Purpose     = "AZ305-LandingZone"
        CreatedDate = (Get-Date -Format "yyyy-MM-dd")
    }

    foreach ($rg in $resourceGroups) {
        $existingRg = Get-AzResourceGroup -Name $rg.Name -ErrorAction SilentlyContinue
        if (-not $existingRg) {
            New-AzResourceGroup -Name $rg.Name -Location $Location -Tag ($tags + @{ Function = $rg.Purpose }) | Out-Null
            Write-Log "Created resource group: $($rg.Name)" -Level "SUCCESS"
        }
        else {
            Write-Log "Resource group already exists: $($rg.Name)"
        }
    }

    return $resourceGroups
}

#-------------------------------------------------------------------------------
# CREATE LOG ANALYTICS WORKSPACE
#-------------------------------------------------------------------------------
function New-LogAnalyticsWorkspace {
    param([string]$ResourceGroupName)

    Write-Log "Creating Log Analytics workspace..."

    # WHY: Centralized logging is essential for:
    # - Security monitoring and threat detection
    # - Performance analysis and troubleshooting
    # - Compliance and audit requirements
    # - Cost analysis through resource logs

    $workspaceName = Get-ResourceName -ResourceType "law"

    $workspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName $ResourceGroupName -Name $workspaceName -ErrorAction SilentlyContinue
    if (-not $workspace) {
        $workspace = New-AzOperationalInsightsWorkspace `
            -ResourceGroupName $ResourceGroupName `
            -Name $workspaceName `
            -Location $Location `
            -Sku "PerGB2018" `
            -RetentionInDays 30

        Write-Log "Created Log Analytics workspace: $workspaceName" -Level "SUCCESS"
    }
    else {
        Write-Log "Log Analytics workspace already exists: $workspaceName"
    }

    return $workspace
}

#-------------------------------------------------------------------------------
# CREATE HUB VIRTUAL NETWORK
#-------------------------------------------------------------------------------
function New-HubVirtualNetwork {
    param([string]$ResourceGroupName)

    Write-Log "Creating hub virtual network..."

    $vnetName = Get-ResourceName -ResourceType "hub-vnet"
    $vnetAddressSpace = "10.0.0.0/16"

    # WHY: Hub VNet serves as central point for:
    # - Shared services (DNS, AD, jump boxes)
    # - Connectivity (VPN Gateway, ExpressRoute)
    # - Security appliances (Azure Firewall, NVAs)

    $existingVnet = Get-AzVirtualNetwork -Name $vnetName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue

    if (-not $existingVnet) {
        # Define subnets
        # WHY: Subnet segregation enables network-level security controls
        $subnets = @(
            @{
                Name          = "AzureBastionSubnet"  # Required name for Bastion
                AddressPrefix = "10.0.0.0/26"        # /26 minimum for Bastion
            },
            @{
                Name          = "GatewaySubnet"       # Required name for VPN/ExpressRoute Gateway
                AddressPrefix = "10.0.1.0/27"
            },
            @{
                Name          = "AzureFirewallSubnet" # Required name for Azure Firewall
                AddressPrefix = "10.0.2.0/26"
            },
            @{
                Name          = "SharedServicesSubnet"
                AddressPrefix = "10.0.10.0/24"
            },
            @{
                Name          = "ManagementSubnet"
                AddressPrefix = "10.0.11.0/24"
            }
        )

        $subnetConfigs = @()
        foreach ($subnet in $subnets) {
            $subnetConfigs += New-AzVirtualNetworkSubnetConfig -Name $subnet.Name -AddressPrefix $subnet.AddressPrefix
        }

        $vnet = New-AzVirtualNetwork `
            -Name $vnetName `
            -ResourceGroupName $ResourceGroupName `
            -Location $Location `
            -AddressPrefix $vnetAddressSpace `
            -Subnet $subnetConfigs `
            -Tag @{
            Environment = $EnvironmentName
            Purpose     = "Hub-Network"
        }

        Write-Log "Created hub virtual network: $vnetName" -Level "SUCCESS"
    }
    else {
        $vnet = $existingVnet
        Write-Log "Hub virtual network already exists: $vnetName"
    }

    return $vnet
}

#-------------------------------------------------------------------------------
# CREATE NETWORK SECURITY GROUPS
#-------------------------------------------------------------------------------
function New-NetworkSecurityGroups {
    param([string]$ResourceGroupName)

    Write-Log "Creating Network Security Groups..."

    # WHY: NSGs provide stateful packet filtering for defense-in-depth
    # Default deny-all inbound with explicit allow rules follows zero-trust principles

    $nsgConfigs = @(
        @{
            Name   = Get-ResourceName -ResourceType "shared-nsg"
            Subnet = "SharedServicesSubnet"
            Rules  = @(
                @{
                    Name                     = "Allow-HTTPS-Inbound"
                    Priority                 = 100
                    Direction                = "Inbound"
                    Access                   = "Allow"
                    Protocol                 = "Tcp"
                    SourcePortRange          = "*"
                    DestinationPortRange     = "443"
                    SourceAddressPrefix      = "VirtualNetwork"
                    DestinationAddressPrefix = "*"
                },
                @{
                    Name                     = "Deny-All-Inbound"
                    Priority                 = 4096
                    Direction                = "Inbound"
                    Access                   = "Deny"
                    Protocol                 = "*"
                    SourcePortRange          = "*"
                    DestinationPortRange     = "*"
                    SourceAddressPrefix      = "*"
                    DestinationAddressPrefix = "*"
                }
            )
        },
        @{
            Name   = Get-ResourceName -ResourceType "mgmt-nsg"
            Subnet = "ManagementSubnet"
            Rules  = @(
                @{
                    Name                     = "Allow-Bastion-SSH-RDP"
                    Priority                 = 100
                    Direction                = "Inbound"
                    Access                   = "Allow"
                    Protocol                 = "Tcp"
                    SourcePortRange          = "*"
                    DestinationPortRange     = "22,3389"
                    SourceAddressPrefix      = "10.0.0.0/26"  # Bastion subnet
                    DestinationAddressPrefix = "*"
                }
            )
        }
    )

    foreach ($nsgConfig in $nsgConfigs) {
        $existingNsg = Get-AzNetworkSecurityGroup -Name $nsgConfig.Name -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue

        if (-not $existingNsg) {
            $rules = @()
            foreach ($rule in $nsgConfig.Rules) {
                $rules += New-AzNetworkSecurityRuleConfig @rule
            }

            $nsg = New-AzNetworkSecurityGroup `
                -Name $nsgConfig.Name `
                -ResourceGroupName $ResourceGroupName `
                -Location $Location `
                -SecurityRules $rules `
                -Tag @{
                Environment = $EnvironmentName
                Purpose     = "NetworkSecurity"
            }

            Write-Log "Created NSG: $($nsgConfig.Name)" -Level "SUCCESS"
        }
        else {
            Write-Log "NSG already exists: $($nsgConfig.Name)"
        }
    }
}

#-------------------------------------------------------------------------------
# CREATE AZURE BASTION
#-------------------------------------------------------------------------------
function New-AzureBastionHost {
    param(
        [string]$ResourceGroupName,
        [Microsoft.Azure.Commands.Network.Models.PSVirtualNetwork]$VirtualNetwork
    )

    Write-Log "Creating Azure Bastion (this may take several minutes)..."

    # WHY: Azure Bastion provides secure RDP/SSH access without exposing VMs to public internet
    # - No need for public IPs on VMs
    # - No need for NSG rules allowing RDP/SSH from internet
    # - Audit logging of all sessions

    $bastionName = Get-ResourceName -ResourceType "bastion"
    $pipName = Get-ResourceName -ResourceType "bastion-pip"

    $existingBastion = Get-AzBastion -ResourceGroupName $ResourceGroupName -Name $bastionName -ErrorAction SilentlyContinue

    if (-not $existingBastion) {
        # Create Public IP for Bastion
        $pip = New-AzPublicIpAddress `
            -ResourceGroupName $ResourceGroupName `
            -Name $pipName `
            -Location $Location `
            -AllocationMethod Static `
            -Sku Standard `
            -Tag @{
            Environment = $EnvironmentName
            Purpose     = "AzureBastion"
        }

        Write-Log "Created Bastion public IP: $pipName" -Level "SUCCESS"

        # Create Bastion
        $bastion = New-AzBastion `
            -ResourceGroupName $ResourceGroupName `
            -Name $bastionName `
            -PublicIpAddress $pip `
            -VirtualNetwork $VirtualNetwork `
            -Sku "Basic"

        Write-Log "Created Azure Bastion: $bastionName" -Level "SUCCESS"
    }
    else {
        Write-Log "Azure Bastion already exists: $bastionName"
    }
}

#-------------------------------------------------------------------------------
# DISPLAY SUMMARY
#-------------------------------------------------------------------------------
function Show-DeploymentSummary {
    param(
        [array]$ResourceGroups,
        [object]$Workspace,
        [object]$VirtualNetwork
    )

    Write-Host ""
    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host "                    LANDING ZONE DEPLOYMENT SUMMARY" -ForegroundColor Cyan
    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Subscription: $((Get-AzContext).Subscription.Name)"
    Write-Host "Location: $Location"
    Write-Host "Environment: $EnvironmentName"
    Write-Host ""
    Write-Host "RESOURCE GROUPS:" -ForegroundColor Yellow
    Write-Host "-------------------------------------------------------------------------------"
    foreach ($rg in $ResourceGroups) {
        Write-Host "  $($rg.Name) - $($rg.Purpose)"
    }
    Write-Host ""
    Write-Host "LOG ANALYTICS WORKSPACE:" -ForegroundColor Yellow
    Write-Host "-------------------------------------------------------------------------------"
    Write-Host "  Name: $($Workspace.Name)"
    Write-Host "  Workspace ID: $($Workspace.CustomerId)"
    Write-Host ""
    Write-Host "HUB VIRTUAL NETWORK:" -ForegroundColor Yellow
    Write-Host "-------------------------------------------------------------------------------"
    Write-Host "  Name: $($VirtualNetwork.Name)"
    Write-Host "  Address Space: $($VirtualNetwork.AddressSpace.AddressPrefixes -join ', ')"
    Write-Host "  Subnets:"
    foreach ($subnet in $VirtualNetwork.Subnets) {
        Write-Host "    - $($subnet.Name): $($subnet.AddressPrefix)"
    }
    Write-Host ""
    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host "LANDING ZONE CONCEPTS (AZ-305 Exam Context):" -ForegroundColor Cyan
    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "LANDING ZONE TYPES:"
    Write-Host "  Platform Landing Zone: Centralized services (identity, connectivity, management)"
    Write-Host "  Application Landing Zone: Workload-specific resources"
    Write-Host ""
    Write-Host "KEY COMPONENTS:"
    Write-Host "  - Resource organization (Management Groups, Subscriptions, RGs)"
    Write-Host "  - Network topology (Hub-Spoke, Virtual WAN)"
    Write-Host "  - Identity and access management (Microsoft Entra ID, RBAC)"
    Write-Host "  - Governance (Policies, Deployment Stacks)"
    Write-Host "  - Operations (Monitoring, Backup, Security)"
    Write-Host ""
    Write-Host "ENTERPRISE-SCALE REFERENCE:"
    Write-Host "  For production, use Azure Landing Zone accelerators:"
    Write-Host "  https://aka.ms/alz"
    Write-Host "===============================================================================" -ForegroundColor Cyan
}

#-------------------------------------------------------------------------------
# MAIN
#-------------------------------------------------------------------------------
function Main {
    Write-Log "Starting Landing Zone deployment..."
    Write-Log "Environment: $EnvironmentName | Location: $Location | Prefix: $Prefix"

    try {
        # Connect to Azure
        Connect-ToAzure

        # Create resource groups
        $resourceGroups = New-LandingZoneResourceGroups
        $networkRgName = ($resourceGroups | Where-Object { $_.Purpose -eq "Networking" }).Name
        $sharedRgName = ($resourceGroups | Where-Object { $_.Purpose -eq "SharedServices" }).Name

        # Create Log Analytics workspace
        $workspace = New-LogAnalyticsWorkspace -ResourceGroupName $sharedRgName

        # Create hub virtual network
        $vnet = New-HubVirtualNetwork -ResourceGroupName $networkRgName

        # Create NSGs
        New-NetworkSecurityGroups -ResourceGroupName $networkRgName

        # Create Azure Bastion (optional - can be expensive)
        # Uncomment the following line if you want to deploy Bastion
        # New-AzureBastionHost -ResourceGroupName $networkRgName -VirtualNetwork $vnet

        # Display summary
        Show-DeploymentSummary -ResourceGroups $resourceGroups -Workspace $workspace -VirtualNetwork $vnet

        Write-Log "Landing Zone deployment completed successfully!" -Level "SUCCESS"
    }
    catch {
        Write-Log "Deployment failed: $_" -Level "ERROR"
        throw
    }
}

# Execute main function
Main
