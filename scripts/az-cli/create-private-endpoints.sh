#!/bin/bash
#===============================================================================
# SCRIPT: create-private-endpoints.sh
# SYNOPSIS: Create private endpoints for Azure PaaS services
# DESCRIPTION:
#   This script demonstrates creating private endpoints for common PaaS services:
#   - Azure Storage Account (blob, file, queue, table)
#   - Azure SQL Database
#   - Azure Key Vault
#   - Azure Container Registry
#
#   Private endpoints provide:
#   - Private IP address from your VNet for the PaaS service
#   - Traffic stays on Microsoft backbone network
#   - Data exfiltration protection
#   - Elimination of public endpoint exposure
#
# AZ-305 EXAM OBJECTIVES:
#   - Design data storage solutions: Private access to storage
#   - Design infrastructure solutions: Network integration with PaaS
#   - Zero Trust architecture: Eliminate public endpoints
#   - Compare Private Endpoints vs Service Endpoints
#
# PREREQUISITES:
#   - Azure CLI 2.50+ installed and authenticated
#   - Existing VNet with a subnet for private endpoints
#   - Subscription with Network Contributor and service-specific permissions
#
# EXAMPLES:
#   # Create private endpoints for all supported services
#   ./create-private-endpoints.sh
#
#   # Create for specific service
#   SERVICE_TYPE="storage" ./create-private-endpoints.sh
#
# REFERENCES:
#   - https://learn.microsoft.com/azure/private-link/private-endpoint-overview
#   - https://learn.microsoft.com/azure/private-link/availability
#===============================================================================

set -euo pipefail

#-------------------------------------------------------------------------------
# CONFIGURATION
#-------------------------------------------------------------------------------
LOCATION="${LOCATION:-eastus}"
PREFIX="${PREFIX:-az305}"
RESOURCE_GROUP="${RESOURCE_GROUP:-${PREFIX}-privatelink-rg}"
VNET_NAME="${VNET_NAME:-${PREFIX}-vnet}"
VNET_PREFIX="${VNET_PREFIX:-10.10.0.0/16}"
PE_SUBNET_NAME="${PE_SUBNET_NAME:-private-endpoints}"
PE_SUBNET_PREFIX="${PE_SUBNET_PREFIX:-10.10.1.0/24}"
WORKLOAD_SUBNET_NAME="${WORKLOAD_SUBNET_NAME:-workload}"
WORKLOAD_SUBNET_PREFIX="${WORKLOAD_SUBNET_PREFIX:-10.10.2.0/24}"

# Service configurations
STORAGE_ACCOUNT_NAME="${PREFIX}stor$(openssl rand -hex 4)"
SQL_SERVER_NAME="${PREFIX}-sqlserver-$(openssl rand -hex 4)"
SQL_ADMIN_USER="${SQL_ADMIN_USER:-sqladmin}"
KEY_VAULT_NAME="${PREFIX}-kv-$(openssl rand -hex 4)"
ACR_NAME="${PREFIX}acr$(openssl rand -hex 4)"

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

# Generate a random password that meets SQL Server requirements
generate_sql_password() {
    # Must contain uppercase, lowercase, number, and special char
    echo "P@ss$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9')!"
}

#-------------------------------------------------------------------------------
# INFRASTRUCTURE SETUP
#-------------------------------------------------------------------------------
setup_infrastructure() {
    log_info "Setting up base infrastructure..."

    # Create resource group
    az group create \
        --name "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --tags "Environment=Development" "Purpose=AZ305-PrivateEndpoints" \
        --output none

    # Create VNet with subnets
    log_info "Creating virtual network..."
    az network vnet create \
        --name "$VNET_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --address-prefixes "$VNET_PREFIX" \
        --output none

    # WHY: Private endpoints require a dedicated subnet
    # The subnet must have privateEndpointNetworkPolicies disabled
    log_info "Creating private endpoint subnet..."
    az network vnet subnet create \
        --name "$PE_SUBNET_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --vnet-name "$VNET_NAME" \
        --address-prefixes "$PE_SUBNET_PREFIX" \
        --output none

    # Disable network policies on PE subnet
    # WHY: NSGs and UDRs don't apply to private endpoint traffic by default
    # This is required for private endpoints to function properly
    az network vnet subnet update \
        --name "$PE_SUBNET_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --vnet-name "$VNET_NAME" \
        --disable-private-endpoint-network-policies true \
        --output none

    # Create workload subnet
    az network vnet subnet create \
        --name "$WORKLOAD_SUBNET_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --vnet-name "$VNET_NAME" \
        --address-prefixes "$WORKLOAD_SUBNET_PREFIX" \
        --output none

    log_success "Base infrastructure created"
}

#-------------------------------------------------------------------------------
# PRIVATE DNS ZONES
#-------------------------------------------------------------------------------
create_private_dns_zones() {
    log_info "Creating Private DNS Zones..."

    # WHY: Private DNS zones are required to resolve the private endpoint
    # to its private IP address instead of the public IP
    # Each PaaS service has a specific DNS zone name
    declare -A dns_zones=(
        ["blob"]="privatelink.blob.core.windows.net"
        ["file"]="privatelink.file.core.windows.net"
        ["queue"]="privatelink.queue.core.windows.net"
        ["table"]="privatelink.table.core.windows.net"
        ["sql"]="privatelink.database.windows.net"
        ["vault"]="privatelink.vaultcore.azure.net"
        ["acr"]="privatelink.azurecr.io"
    )

    for zone_type in "${!dns_zones[@]}"; do
        zone_name="${dns_zones[$zone_type]}"
        log_info "Creating DNS zone: $zone_name"

        # Create the private DNS zone
        az network private-dns zone create \
            --name "$zone_name" \
            --resource-group "$RESOURCE_GROUP" \
            --output none 2>/dev/null || log_info "DNS zone $zone_name already exists"

        # Link the DNS zone to the VNet
        # WHY: VNet link enables DNS resolution from VMs in the VNet
        az network private-dns link vnet create \
            --name "${zone_type}-link" \
            --resource-group "$RESOURCE_GROUP" \
            --zone-name "$zone_name" \
            --virtual-network "$VNET_NAME" \
            --registration-enabled false \
            --output none 2>/dev/null || log_info "DNS link for $zone_name already exists"
    done

    log_success "Private DNS zones created and linked"
}

#-------------------------------------------------------------------------------
# STORAGE ACCOUNT WITH PRIVATE ENDPOINTS
#-------------------------------------------------------------------------------
create_storage_private_endpoints() {
    log_info "Creating Storage Account with private endpoints..."

    # Create storage account
    az storage account create \
        --name "$STORAGE_ACCOUNT_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --sku "Standard_LRS" \
        --kind "StorageV2" \
        --https-only true \
        --min-tls-version "TLS1_2" \
        --allow-blob-public-access false \
        --tags "Environment=Development" "PrivateEndpoint=true" \
        --output none

    # Get storage account resource ID
    storage_id=$(az storage account show \
        --name "$STORAGE_ACCOUNT_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query id \
        --output tsv)

    # Create private endpoints for each storage service type
    # WHY: Each storage service (blob, file, queue, table) requires its own private endpoint
    declare -A storage_subresources=(
        ["blob"]="blob"
        ["file"]="file"
    )

    for service_type in "${!storage_subresources[@]}"; do
        pe_name="${STORAGE_ACCOUNT_NAME}-${service_type}-pe"
        log_info "Creating private endpoint: $pe_name"

        az network private-endpoint create \
            --name "$pe_name" \
            --resource-group "$RESOURCE_GROUP" \
            --location "$LOCATION" \
            --vnet-name "$VNET_NAME" \
            --subnet "$PE_SUBNET_NAME" \
            --private-connection-resource-id "$storage_id" \
            --group-id "${storage_subresources[$service_type]}" \
            --connection-name "${STORAGE_ACCOUNT_NAME}-${service_type}-connection" \
            --output none

        # Create DNS zone group for automatic DNS registration
        # WHY: DNS zone groups automatically create A records in the private DNS zone
        az network private-endpoint dns-zone-group create \
            --name "default" \
            --resource-group "$RESOURCE_GROUP" \
            --endpoint-name "$pe_name" \
            --private-dns-zone "privatelink.${service_type}.core.windows.net" \
            --zone-name "${service_type}-zone" \
            --output none

        log_success "Private endpoint $pe_name created"
    done

    # Disable public network access after private endpoints are configured
    # WHY: This ensures traffic can only flow through the private endpoint
    az storage account update \
        --name "$STORAGE_ACCOUNT_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --public-network-access Disabled \
        --output none

    log_success "Storage account private endpoints configured"
}

#-------------------------------------------------------------------------------
# SQL DATABASE WITH PRIVATE ENDPOINT
#-------------------------------------------------------------------------------
create_sql_private_endpoint() {
    log_info "Creating Azure SQL Database with private endpoint..."

    # Generate password
    sql_password=$(generate_sql_password)

    # Create SQL Server
    az sql server create \
        --name "$SQL_SERVER_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --admin-user "$SQL_ADMIN_USER" \
        --admin-password "$sql_password" \
        --minimal-tls-version "1.2" \
        --output none

    # Create sample database
    az sql db create \
        --name "sampledb" \
        --resource-group "$RESOURCE_GROUP" \
        --server "$SQL_SERVER_NAME" \
        --edition "Basic" \
        --capacity 5 \
        --output none

    # Get SQL Server resource ID
    sql_id=$(az sql server show \
        --name "$SQL_SERVER_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query id \
        --output tsv)

    # Create private endpoint
    # WHY: sqlServer is the group-id for Azure SQL Database private endpoints
    pe_name="${SQL_SERVER_NAME}-pe"
    az network private-endpoint create \
        --name "$pe_name" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --vnet-name "$VNET_NAME" \
        --subnet "$PE_SUBNET_NAME" \
        --private-connection-resource-id "$sql_id" \
        --group-id "sqlServer" \
        --connection-name "${SQL_SERVER_NAME}-connection" \
        --output none

    # Create DNS zone group
    az network private-endpoint dns-zone-group create \
        --name "default" \
        --resource-group "$RESOURCE_GROUP" \
        --endpoint-name "$pe_name" \
        --private-dns-zone "privatelink.database.windows.net" \
        --zone-name "sql-zone" \
        --output none

    # Disable public network access
    # WHY: Ensures SQL Server is only accessible via private endpoint
    az sql server update \
        --name "$SQL_SERVER_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --enable-public-network false \
        --output none

    log_success "SQL Server private endpoint configured"
    log_info "SQL Admin User: $SQL_ADMIN_USER"
    log_info "SQL Admin Password: $sql_password (save this securely!)"
}

#-------------------------------------------------------------------------------
# KEY VAULT WITH PRIVATE ENDPOINT
#-------------------------------------------------------------------------------
create_keyvault_private_endpoint() {
    log_info "Creating Azure Key Vault with private endpoint..."

    # Create Key Vault
    # WHY: enable-rbac-authorization is recommended for modern access control
    az keyvault create \
        --name "$KEY_VAULT_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --enable-rbac-authorization true \
        --sku "standard" \
        --output none

    # Get Key Vault resource ID
    kv_id=$(az keyvault show \
        --name "$KEY_VAULT_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query id \
        --output tsv)

    # Create private endpoint
    # WHY: vault is the group-id for Key Vault private endpoints
    pe_name="${KEY_VAULT_NAME}-pe"
    az network private-endpoint create \
        --name "$pe_name" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --vnet-name "$VNET_NAME" \
        --subnet "$PE_SUBNET_NAME" \
        --private-connection-resource-id "$kv_id" \
        --group-id "vault" \
        --connection-name "${KEY_VAULT_NAME}-connection" \
        --output none

    # Create DNS zone group
    az network private-endpoint dns-zone-group create \
        --name "default" \
        --resource-group "$RESOURCE_GROUP" \
        --endpoint-name "$pe_name" \
        --private-dns-zone "privatelink.vaultcore.azure.net" \
        --zone-name "vault-zone" \
        --output none

    # Update network settings to deny public access
    az keyvault update \
        --name "$KEY_VAULT_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --public-network-access Disabled \
        --output none

    log_success "Key Vault private endpoint configured"
}

#-------------------------------------------------------------------------------
# CONTAINER REGISTRY WITH PRIVATE ENDPOINT
#-------------------------------------------------------------------------------
create_acr_private_endpoint() {
    log_info "Creating Azure Container Registry with private endpoint..."

    # Create ACR - Premium SKU required for private endpoints
    # WHY: Private endpoint feature requires Premium tier
    az acr create \
        --name "$ACR_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --sku "Premium" \
        --admin-enabled false \
        --output none

    # Get ACR resource ID
    acr_id=$(az acr show \
        --name "$ACR_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query id \
        --output tsv)

    # Create private endpoint
    # WHY: registry is the group-id for ACR private endpoints
    pe_name="${ACR_NAME}-pe"
    az network private-endpoint create \
        --name "$pe_name" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --vnet-name "$VNET_NAME" \
        --subnet "$PE_SUBNET_NAME" \
        --private-connection-resource-id "$acr_id" \
        --group-id "registry" \
        --connection-name "${ACR_NAME}-connection" \
        --output none

    # Create DNS zone group
    az network private-endpoint dns-zone-group create \
        --name "default" \
        --resource-group "$RESOURCE_GROUP" \
        --endpoint-name "$pe_name" \
        --private-dns-zone "privatelink.azurecr.io" \
        --zone-name "acr-zone" \
        --output none

    # Disable public network access
    az acr update \
        --name "$ACR_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --public-network-enabled false \
        --output none

    log_success "Container Registry private endpoint configured"
}

#-------------------------------------------------------------------------------
# DISPLAY SUMMARY
#-------------------------------------------------------------------------------
display_summary() {
    echo ""
    echo "==============================================================================="
    echo "                    PRIVATE ENDPOINTS DEPLOYMENT SUMMARY"
    echo "==============================================================================="
    echo ""
    echo "Resource Group: $RESOURCE_GROUP"
    echo "Location: $LOCATION"
    echo "VNet: $VNET_NAME ($VNET_PREFIX)"
    echo "Private Endpoint Subnet: $PE_SUBNET_NAME ($PE_SUBNET_PREFIX)"
    echo ""
    echo "Resources Created:"
    echo "-------------------------------------------------------------------------------"
    echo ""
    echo "1. Storage Account: $STORAGE_ACCOUNT_NAME"
    echo "   Private Endpoints: blob, file"
    echo "   Public Access: Disabled"
    echo ""
    echo "2. SQL Server: $SQL_SERVER_NAME"
    echo "   Database: sampledb"
    echo "   Private Endpoint: sqlServer"
    echo "   Public Access: Disabled"
    echo ""
    echo "3. Key Vault: $KEY_VAULT_NAME"
    echo "   Private Endpoint: vault"
    echo "   Public Access: Disabled"
    echo ""
    echo "4. Container Registry: $ACR_NAME"
    echo "   Private Endpoint: registry"
    echo "   Public Access: Disabled"
    echo ""
    echo "Private Endpoints:"
    az network private-endpoint list \
        --resource-group "$RESOURCE_GROUP" \
        --query "[].{Name:name, PrivateIP:customDnsConfigs[0].ipAddresses[0], Status:privateLinkServiceConnections[0].privateLinkServiceConnectionState.status}" \
        --output table
    echo ""
    echo "Private DNS Zones:"
    az network private-dns zone list \
        --resource-group "$RESOURCE_GROUP" \
        --query "[].{Zone:name, Records:numberOfRecordSets}" \
        --output table
    echo ""
    echo "==============================================================================="
    echo "VERIFICATION STEPS:"
    echo "  1. Deploy a VM in the workload subnet"
    echo "  2. Use nslookup to verify DNS resolution to private IPs"
    echo "  3. Test connectivity to services using private endpoints"
    echo ""
    echo "EXAMPLE VERIFICATION (from VM in VNet):"
    echo "  nslookup ${STORAGE_ACCOUNT_NAME}.blob.core.windows.net"
    echo "  nslookup ${SQL_SERVER_NAME}.database.windows.net"
    echo "  nslookup ${KEY_VAULT_NAME}.vault.azure.net"
    echo "  nslookup ${ACR_NAME}.azurecr.io"
    echo "==============================================================================="
}

#-------------------------------------------------------------------------------
# MAIN
#-------------------------------------------------------------------------------
main() {
    log_info "Starting private endpoints deployment..."

    setup_infrastructure
    create_private_dns_zones
    create_storage_private_endpoints
    create_sql_private_endpoint
    create_keyvault_private_endpoint
    create_acr_private_endpoint
    display_summary

    log_success "Private endpoints deployment completed successfully!"
}

main "$@"
