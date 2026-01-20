#!/bin/bash
#===============================================================================
# SCRIPT: deploy-hub-spoke.sh
# SYNOPSIS: Deploy a hub-spoke network topology with VNet peering
# DESCRIPTION:
#   This script creates a hub-spoke network architecture consisting of:
#   - A hub virtual network with subnets for Azure Firewall, Bastion, and Gateway
#   - Two spoke virtual networks for workloads
#   - Bidirectional VNet peering between hub and each spoke
#   - Network Security Groups for basic traffic control
#
# AZ-305 EXAM OBJECTIVES:
#   - Design infrastructure solutions: Design a network topology
#   - Hub-spoke is a core Azure architecture pattern for network segmentation
#   - Understand VNet peering properties: AllowForwardedTraffic, AllowGatewayTransit
#   - Service chaining through the hub for spoke-to-spoke communication
#
# PREREQUISITES:
#   - Azure CLI 2.50+ installed and authenticated
#   - Subscription with Network Contributor or higher permissions
#   - Resource group should not exist (will be created)
#
# EXAMPLES:
#   # Deploy with defaults to East US
#   ./deploy-hub-spoke.sh
#
#   # Deploy to specific region with custom prefix
#   LOCATION="westus2" PREFIX="prod" ./deploy-hub-spoke.sh
#
# REFERENCES:
#   - https://learn.microsoft.com/azure/architecture/networking/architecture/hub-spoke
#   - https://learn.microsoft.com/azure/virtual-network/virtual-network-peering-overview
#===============================================================================

set -euo pipefail

#-------------------------------------------------------------------------------
# CONFIGURATION - Override these with environment variables
#-------------------------------------------------------------------------------
LOCATION="${LOCATION:-eastus}"
PREFIX="${PREFIX:-az305}"
RESOURCE_GROUP="${RESOURCE_GROUP:-${PREFIX}-hub-spoke-rg}"

# Hub VNet configuration
HUB_VNET_NAME="${PREFIX}-hub-vnet"
HUB_VNET_PREFIX="10.0.0.0/16"
HUB_FIREWALL_SUBNET_PREFIX="10.0.1.0/26"        # AzureFirewallSubnet - minimum /26
HUB_BASTION_SUBNET_PREFIX="10.0.2.0/26"         # AzureBastionSubnet - minimum /26
HUB_GATEWAY_SUBNET_PREFIX="10.0.3.0/27"         # GatewaySubnet - minimum /27
HUB_MANAGEMENT_SUBNET_PREFIX="10.0.4.0/24"      # Management subnet for shared services

# Spoke VNets configuration
SPOKE1_VNET_NAME="${PREFIX}-spoke1-vnet"
SPOKE1_VNET_PREFIX="10.1.0.0/16"
SPOKE1_WORKLOAD_SUBNET_PREFIX="10.1.1.0/24"

SPOKE2_VNET_NAME="${PREFIX}-spoke2-vnet"
SPOKE2_VNET_PREFIX="10.2.0.0/16"
SPOKE2_WORKLOAD_SUBNET_PREFIX="10.2.1.0/24"

#-------------------------------------------------------------------------------
# HELPER FUNCTIONS
#-------------------------------------------------------------------------------
log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

log_success() {
    echo "[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

check_resource_exists() {
    local resource_type=$1
    local resource_name=$2
    local rg=$3

    case $resource_type in
        "vnet")
            az network vnet show --name "$resource_name" --resource-group "$rg" &>/dev/null
            ;;
        "nsg")
            az network nsg show --name "$resource_name" --resource-group "$rg" &>/dev/null
            ;;
        *)
            return 1
            ;;
    esac
}

#-------------------------------------------------------------------------------
# MAIN DEPLOYMENT
#-------------------------------------------------------------------------------
main() {
    log_info "Starting hub-spoke network deployment..."
    log_info "Location: $LOCATION | Resource Group: $RESOURCE_GROUP"

    # Step 1: Create Resource Group (idempotent)
    log_info "Creating resource group..."
    az group create \
        --name "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --tags "Environment=Development" "Purpose=AZ305-Training" "Pattern=Hub-Spoke" \
        --output none
    log_success "Resource group created or already exists"

    # Step 2: Create Hub VNet with subnets
    # WHY: The hub is the central point for shared services, connectivity, and security controls
    log_info "Creating hub virtual network..."
    if ! check_resource_exists "vnet" "$HUB_VNET_NAME" "$RESOURCE_GROUP"; then
        az network vnet create \
            --name "$HUB_VNET_NAME" \
            --resource-group "$RESOURCE_GROUP" \
            --location "$LOCATION" \
            --address-prefixes "$HUB_VNET_PREFIX" \
            --tags "Role=Hub" "Environment=Development" \
            --output none

        # Create specialized subnets - names are Azure-mandated for certain services
        # WHY: AzureFirewallSubnet must be named exactly this for Azure Firewall deployment
        az network vnet subnet create \
            --name "AzureFirewallSubnet" \
            --resource-group "$RESOURCE_GROUP" \
            --vnet-name "$HUB_VNET_NAME" \
            --address-prefix "$HUB_FIREWALL_SUBNET_PREFIX" \
            --output none

        # WHY: AzureBastionSubnet must be named exactly this for Azure Bastion deployment
        az network vnet subnet create \
            --name "AzureBastionSubnet" \
            --resource-group "$RESOURCE_GROUP" \
            --vnet-name "$HUB_VNET_NAME" \
            --address-prefix "$HUB_BASTION_SUBNET_PREFIX" \
            --output none

        # WHY: GatewaySubnet is required for VPN/ExpressRoute gateways
        az network vnet subnet create \
            --name "GatewaySubnet" \
            --resource-group "$RESOURCE_GROUP" \
            --vnet-name "$HUB_VNET_NAME" \
            --address-prefix "$HUB_GATEWAY_SUBNET_PREFIX" \
            --output none

        # Management subnet for shared services (DNS, AD DS, etc.)
        az network vnet subnet create \
            --name "ManagementSubnet" \
            --resource-group "$RESOURCE_GROUP" \
            --vnet-name "$HUB_VNET_NAME" \
            --address-prefix "$HUB_MANAGEMENT_SUBNET_PREFIX" \
            --output none

        log_success "Hub VNet created with all subnets"
    else
        log_info "Hub VNet already exists, skipping creation"
    fi

    # Step 3: Create Spoke 1 VNet
    # WHY: Spokes contain workloads and are isolated from each other by default
    log_info "Creating spoke 1 virtual network..."
    if ! check_resource_exists "vnet" "$SPOKE1_VNET_NAME" "$RESOURCE_GROUP"; then
        az network vnet create \
            --name "$SPOKE1_VNET_NAME" \
            --resource-group "$RESOURCE_GROUP" \
            --location "$LOCATION" \
            --address-prefixes "$SPOKE1_VNET_PREFIX" \
            --subnet-name "WorkloadSubnet" \
            --subnet-prefixes "$SPOKE1_WORKLOAD_SUBNET_PREFIX" \
            --tags "Role=Spoke" "Environment=Development" "SpokeNumber=1" \
            --output none
        log_success "Spoke 1 VNet created"
    else
        log_info "Spoke 1 VNet already exists, skipping creation"
    fi

    # Step 4: Create Spoke 2 VNet
    log_info "Creating spoke 2 virtual network..."
    if ! check_resource_exists "vnet" "$SPOKE2_VNET_NAME" "$RESOURCE_GROUP"; then
        az network vnet create \
            --name "$SPOKE2_VNET_NAME" \
            --resource-group "$RESOURCE_GROUP" \
            --location "$LOCATION" \
            --address-prefixes "$SPOKE2_VNET_PREFIX" \
            --subnet-name "WorkloadSubnet" \
            --subnet-prefixes "$SPOKE2_WORKLOAD_SUBNET_PREFIX" \
            --tags "Role=Spoke" "Environment=Development" "SpokeNumber=2" \
            --output none
        log_success "Spoke 2 VNet created"
    else
        log_info "Spoke 2 VNet already exists, skipping creation"
    fi

    # Step 5: Create Hub-to-Spoke1 Peering
    # WHY: VNet peering is non-transitive - must create bidirectional peerings
    # AllowForwardedTraffic: Allows traffic forwarded from the peered VNet (for NVA/firewall scenarios)
    # AllowGatewayTransit: Allows spoke to use hub's VPN/ExpressRoute gateway
    log_info "Creating VNet peering: Hub to Spoke1..."
    az network vnet peering create \
        --name "hub-to-spoke1" \
        --resource-group "$RESOURCE_GROUP" \
        --vnet-name "$HUB_VNET_NAME" \
        --remote-vnet "$SPOKE1_VNET_NAME" \
        --allow-vnet-access \
        --allow-forwarded-traffic \
        --allow-gateway-transit \
        --output none 2>/dev/null || log_info "Peering hub-to-spoke1 already exists"

    log_info "Creating VNet peering: Spoke1 to Hub..."
    az network vnet peering create \
        --name "spoke1-to-hub" \
        --resource-group "$RESOURCE_GROUP" \
        --vnet-name "$SPOKE1_VNET_NAME" \
        --remote-vnet "$HUB_VNET_NAME" \
        --allow-vnet-access \
        --allow-forwarded-traffic \
        --output none 2>/dev/null || log_info "Peering spoke1-to-hub already exists"

    # Step 6: Create Hub-to-Spoke2 Peering
    log_info "Creating VNet peering: Hub to Spoke2..."
    az network vnet peering create \
        --name "hub-to-spoke2" \
        --resource-group "$RESOURCE_GROUP" \
        --vnet-name "$HUB_VNET_NAME" \
        --remote-vnet "$SPOKE2_VNET_NAME" \
        --allow-vnet-access \
        --allow-forwarded-traffic \
        --allow-gateway-transit \
        --output none 2>/dev/null || log_info "Peering hub-to-spoke2 already exists"

    log_info "Creating VNet peering: Spoke2 to Hub..."
    az network vnet peering create \
        --name "spoke2-to-hub" \
        --resource-group "$RESOURCE_GROUP" \
        --vnet-name "$SPOKE2_VNET_NAME" \
        --remote-vnet "$HUB_VNET_NAME" \
        --allow-vnet-access \
        --allow-forwarded-traffic \
        --output none 2>/dev/null || log_info "Peering spoke2-to-hub already exists"

    log_success "All VNet peerings created"

    # Step 7: Create Network Security Groups for spokes
    # WHY: NSGs provide stateful packet filtering for defense-in-depth
    log_info "Creating Network Security Groups..."

    for spoke_num in 1 2; do
        nsg_name="${PREFIX}-spoke${spoke_num}-nsg"
        vnet_name="${PREFIX}-spoke${spoke_num}-vnet"

        if ! check_resource_exists "nsg" "$nsg_name" "$RESOURCE_GROUP"; then
            az network nsg create \
                --name "$nsg_name" \
                --resource-group "$RESOURCE_GROUP" \
                --location "$LOCATION" \
                --tags "Role=Spoke" "SpokeNumber=$spoke_num" \
                --output none

            # Allow inbound from hub management subnet (for admin access)
            az network nsg rule create \
                --name "AllowHubManagement" \
                --nsg-name "$nsg_name" \
                --resource-group "$RESOURCE_GROUP" \
                --priority 100 \
                --direction Inbound \
                --access Allow \
                --protocol "*" \
                --source-address-prefixes "$HUB_MANAGEMENT_SUBNET_PREFIX" \
                --destination-address-prefixes "*" \
                --destination-port-ranges "*" \
                --description "Allow traffic from hub management subnet" \
                --output none

            # Deny all other VNet-to-VNet traffic (spoke isolation)
            # WHY: Spokes should communicate through the hub firewall for inspection
            az network nsg rule create \
                --name "DenyVNetInbound" \
                --nsg-name "$nsg_name" \
                --resource-group "$RESOURCE_GROUP" \
                --priority 4000 \
                --direction Inbound \
                --access Deny \
                --protocol "*" \
                --source-address-prefixes "VirtualNetwork" \
                --destination-address-prefixes "*" \
                --destination-port-ranges "*" \
                --description "Deny other VNet traffic - force through firewall" \
                --output none

            # Associate NSG with workload subnet
            az network vnet subnet update \
                --name "WorkloadSubnet" \
                --resource-group "$RESOURCE_GROUP" \
                --vnet-name "$vnet_name" \
                --network-security-group "$nsg_name" \
                --output none

            log_success "NSG $nsg_name created and associated"
        else
            log_info "NSG $nsg_name already exists"
        fi
    done

    # Step 8: Display deployment summary
    echo ""
    echo "==============================================================================="
    echo "                      HUB-SPOKE DEPLOYMENT SUMMARY"
    echo "==============================================================================="
    echo ""
    echo "Resource Group: $RESOURCE_GROUP"
    echo "Location: $LOCATION"
    echo ""
    echo "Hub VNet:"
    echo "  Name: $HUB_VNET_NAME"
    echo "  Address Space: $HUB_VNET_PREFIX"
    echo "  Subnets:"
    echo "    - AzureFirewallSubnet: $HUB_FIREWALL_SUBNET_PREFIX"
    echo "    - AzureBastionSubnet: $HUB_BASTION_SUBNET_PREFIX"
    echo "    - GatewaySubnet: $HUB_GATEWAY_SUBNET_PREFIX"
    echo "    - ManagementSubnet: $HUB_MANAGEMENT_SUBNET_PREFIX"
    echo ""
    echo "Spoke 1 VNet:"
    echo "  Name: $SPOKE1_VNET_NAME"
    echo "  Address Space: $SPOKE1_VNET_PREFIX"
    echo ""
    echo "Spoke 2 VNet:"
    echo "  Name: $SPOKE2_VNET_NAME"
    echo "  Address Space: $SPOKE2_VNET_PREFIX"
    echo ""
    echo "Peering Status:"
    az network vnet peering list \
        --resource-group "$RESOURCE_GROUP" \
        --vnet-name "$HUB_VNET_NAME" \
        --query "[].{Name:name, PeeringState:peeringState, AllowForwardedTraffic:allowForwardedTraffic}" \
        --output table
    echo ""
    echo "==============================================================================="
    echo "NEXT STEPS:"
    echo "  1. Deploy Azure Firewall to AzureFirewallSubnet for traffic inspection"
    echo "  2. Create User Defined Routes (UDRs) to force spoke traffic through firewall"
    echo "  3. Deploy Azure Bastion for secure VM access"
    echo "  4. Optionally deploy VPN/ExpressRoute Gateway for hybrid connectivity"
    echo "==============================================================================="

    log_success "Hub-spoke network deployment completed successfully!"
}

# Execute main function
main "$@"
