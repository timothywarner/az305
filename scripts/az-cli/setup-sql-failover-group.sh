#!/bin/bash
#===============================================================================
# SCRIPT: setup-sql-failover-group.sh
# SYNOPSIS: Configure Azure SQL Database auto-failover group
# DESCRIPTION:
#   This script creates a geo-replicated Azure SQL Database with auto-failover:
#   - Primary and secondary SQL servers in different regions
#   - Failover group with automatic failover policy
#   - Read-write and read-only listener endpoints
#   - Demonstrates planned and unplanned failover
#
# AZ-305 EXAM OBJECTIVES:
#   - Design data storage solutions: High availability patterns
#   - Understand auto-failover groups vs active geo-replication
#   - Configure read-scale-out for read-heavy workloads
#   - Design for RPO/RTO requirements
#   - Implement regional disaster recovery
#
# PREREQUISITES:
#   - Azure CLI 2.50+ installed and authenticated
#   - Subscription with SQL Server Contributor permissions
#   - Different regions available for primary and secondary
#
# EXAMPLES:
#   # Create failover group with default settings
#   ./setup-sql-failover-group.sh
#
#   # Create with specific grace period
#   GRACE_PERIOD_MINUTES=60 ./setup-sql-failover-group.sh
#
# REFERENCES:
#   - https://learn.microsoft.com/azure/azure-sql/database/failover-group-configure-sql-db
#   - https://learn.microsoft.com/azure/azure-sql/database/auto-failover-group-overview
#===============================================================================

set -euo pipefail

#-------------------------------------------------------------------------------
# CONFIGURATION
#-------------------------------------------------------------------------------
PRIMARY_LOCATION="${PRIMARY_LOCATION:-eastus}"
SECONDARY_LOCATION="${SECONDARY_LOCATION:-westus}"
PREFIX="${PREFIX:-az305}"
RESOURCE_GROUP="${RESOURCE_GROUP:-${PREFIX}-sqlfog-rg}"

# SQL Server configuration
PRIMARY_SERVER_NAME="${PREFIX}-sqlprimary-$(openssl rand -hex 4)"
SECONDARY_SERVER_NAME="${PREFIX}-sqlsecondary-$(openssl rand -hex 4)"
DATABASE_NAME="${DATABASE_NAME:-sampledb}"
FAILOVER_GROUP_NAME="${PREFIX}-fog"

# Admin credentials
SQL_ADMIN_USER="${SQL_ADMIN_USER:-sqladmin}"
# Generate a strong password
SQL_ADMIN_PASSWORD="P@ss$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9')!"

# Failover policy
FAILOVER_POLICY="${FAILOVER_POLICY:-Automatic}"
GRACE_PERIOD_MINUTES="${GRACE_PERIOD_MINUTES:-60}"

# Database SKU
DB_EDITION="${DB_EDITION:-GeneralPurpose}"
DB_CAPACITY="${DB_CAPACITY:-2}"
DB_FAMILY="${DB_FAMILY:-Gen5}"

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

log_warning() {
    echo "[WARNING] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

#-------------------------------------------------------------------------------
# CREATE RESOURCE GROUP
#-------------------------------------------------------------------------------
create_resource_group() {
    log_info "Creating resource group..."

    az group create \
        --name "$RESOURCE_GROUP" \
        --location "$PRIMARY_LOCATION" \
        --tags "Environment=Development" "Purpose=AZ305-SQLFailover" \
        --output none

    log_success "Resource group created: $RESOURCE_GROUP"
}

#-------------------------------------------------------------------------------
# CREATE PRIMARY SQL SERVER
#-------------------------------------------------------------------------------
create_primary_server() {
    log_info "Creating primary SQL Server in $PRIMARY_LOCATION..."

    # WHY: The primary server hosts the read-write replica
    # All write operations go to the primary

    az sql server create \
        --name "$PRIMARY_SERVER_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$PRIMARY_LOCATION" \
        --admin-user "$SQL_ADMIN_USER" \
        --admin-password "$SQL_ADMIN_PASSWORD" \
        --minimal-tls-version "1.2" \
        --output none

    # Configure firewall to allow Azure services
    # WHY: Required for failover group replication and Azure service access
    az sql server firewall-rule create \
        --name "AllowAzureServices" \
        --resource-group "$RESOURCE_GROUP" \
        --server "$PRIMARY_SERVER_NAME" \
        --start-ip-address "0.0.0.0" \
        --end-ip-address "0.0.0.0" \
        --output none

    # Allow current client IP for testing (optional)
    CLIENT_IP=$(curl -s https://api.ipify.org 2>/dev/null || echo "")
    if [ -n "$CLIENT_IP" ]; then
        az sql server firewall-rule create \
            --name "ClientIP" \
            --resource-group "$RESOURCE_GROUP" \
            --server "$PRIMARY_SERVER_NAME" \
            --start-ip-address "$CLIENT_IP" \
            --end-ip-address "$CLIENT_IP" \
            --output none
        log_info "Added firewall rule for client IP: $CLIENT_IP"
    fi

    log_success "Primary SQL Server created: $PRIMARY_SERVER_NAME"
}

#-------------------------------------------------------------------------------
# CREATE SECONDARY SQL SERVER
#-------------------------------------------------------------------------------
create_secondary_server() {
    log_info "Creating secondary SQL Server in $SECONDARY_LOCATION..."

    # WHY: Secondary server hosts the geo-replicated read-only replica
    # Provides disaster recovery and read scale-out capabilities

    az sql server create \
        --name "$SECONDARY_SERVER_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$SECONDARY_LOCATION" \
        --admin-user "$SQL_ADMIN_USER" \
        --admin-password "$SQL_ADMIN_PASSWORD" \
        --minimal-tls-version "1.2" \
        --output none

    # Configure firewall rules (same as primary)
    az sql server firewall-rule create \
        --name "AllowAzureServices" \
        --resource-group "$RESOURCE_GROUP" \
        --server "$SECONDARY_SERVER_NAME" \
        --start-ip-address "0.0.0.0" \
        --end-ip-address "0.0.0.0" \
        --output none

    if [ -n "$CLIENT_IP" ]; then
        az sql server firewall-rule create \
            --name "ClientIP" \
            --resource-group "$RESOURCE_GROUP" \
            --server "$SECONDARY_SERVER_NAME" \
            --start-ip-address "$CLIENT_IP" \
            --end-ip-address "$CLIENT_IP" \
            --output none
    fi

    log_success "Secondary SQL Server created: $SECONDARY_SERVER_NAME"
}

#-------------------------------------------------------------------------------
# CREATE DATABASE
#-------------------------------------------------------------------------------
create_database() {
    log_info "Creating database on primary server..."

    # WHY: Database is created on primary server first
    # Failover group will automatically replicate to secondary

    az sql db create \
        --name "$DATABASE_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --server "$PRIMARY_SERVER_NAME" \
        --edition "$DB_EDITION" \
        --capacity "$DB_CAPACITY" \
        --family "$DB_FAMILY" \
        --zone-redundant false \
        --backup-storage-redundancy Geo \
        --output none

    log_success "Database created: $DATABASE_NAME"
}

#-------------------------------------------------------------------------------
# CREATE FAILOVER GROUP
#-------------------------------------------------------------------------------
create_failover_group() {
    log_info "Creating failover group..."

    # WHY: Failover groups provide:
    # - Automatic failover based on health monitoring
    # - Listener endpoints that automatically redirect traffic
    # - Read-only endpoint for read scale-out
    # - Grace period to prevent flapping during temporary outages

    az sql failover-group create \
        --name "$FAILOVER_GROUP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --server "$PRIMARY_SERVER_NAME" \
        --partner-server "$SECONDARY_SERVER_NAME" \
        --failover-policy "$FAILOVER_POLICY" \
        --grace-period "$GRACE_PERIOD_MINUTES" \
        --add-db "$DATABASE_NAME" \
        --output none

    log_success "Failover group created: $FAILOVER_GROUP_NAME"
}

#-------------------------------------------------------------------------------
# DISPLAY SUMMARY
#-------------------------------------------------------------------------------
display_summary() {
    echo ""
    echo "==============================================================================="
    echo "                   SQL FAILOVER GROUP DEPLOYMENT SUMMARY"
    echo "==============================================================================="
    echo ""
    echo "Resource Group: $RESOURCE_GROUP"
    echo ""
    echo "SQL SERVERS:"
    echo "-------------------------------------------------------------------------------"
    echo "Primary Server: $PRIMARY_SERVER_NAME"
    echo "  Location: $PRIMARY_LOCATION"
    echo "  FQDN: ${PRIMARY_SERVER_NAME}.database.windows.net"
    echo ""
    echo "Secondary Server: $SECONDARY_SERVER_NAME"
    echo "  Location: $SECONDARY_LOCATION"
    echo "  FQDN: ${SECONDARY_SERVER_NAME}.database.windows.net"
    echo ""
    echo "DATABASE:"
    echo "-------------------------------------------------------------------------------"
    echo "Name: $DATABASE_NAME"
    echo "Edition: $DB_EDITION"
    echo "Compute: $DB_FAMILY, $DB_CAPACITY vCores"
    echo ""
    echo "FAILOVER GROUP:"
    echo "-------------------------------------------------------------------------------"
    echo "Name: $FAILOVER_GROUP_NAME"
    echo "Failover Policy: $FAILOVER_POLICY"
    echo "Grace Period: $GRACE_PERIOD_MINUTES minutes"
    echo ""

    # Get failover group status
    az sql failover-group show \
        --name "$FAILOVER_GROUP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --server "$PRIMARY_SERVER_NAME" \
        --query "{Name:name, ReplicationRole:replicationRole, ReplicationState:replicationState, FailoverPolicy:readWriteEndpoint.failoverPolicy}" \
        --output table
    echo ""

    echo "CONNECTION ENDPOINTS (USE THESE IN APPLICATIONS):"
    echo "-------------------------------------------------------------------------------"
    echo ""
    echo "Read-Write Listener (Primary):"
    echo "  ${FAILOVER_GROUP_NAME}.database.windows.net"
    echo "  -> Routes to current primary automatically"
    echo ""
    echo "Read-Only Listener (Secondary):"
    echo "  ${FAILOVER_GROUP_NAME}.secondary.database.windows.net"
    echo "  -> Routes to readable secondary for read scale-out"
    echo ""
    echo "CREDENTIALS:"
    echo "-------------------------------------------------------------------------------"
    echo "Admin User: $SQL_ADMIN_USER"
    echo "Admin Password: $SQL_ADMIN_PASSWORD"
    echo ""
    log_warning "Save these credentials securely! They cannot be retrieved later."
    echo ""
    echo "==============================================================================="
    echo "FAILOVER GROUP KEY CONCEPTS (AZ-305 Exam Context):"
    echo "==============================================================================="
    echo ""
    echo "AUTO-FAILOVER GROUP vs ACTIVE GEO-REPLICATION:"
    echo "  Auto-Failover Groups:"
    echo "    - Listener endpoints (automatic redirection)"
    echo "    - Automatic or manual failover"
    echo "    - Can include multiple databases"
    echo "    - Best for: Application-transparent failover"
    echo ""
    echo "  Active Geo-Replication:"
    echo "    - Up to 4 secondaries in any region"
    echo "    - Manual failover only"
    echo "    - Connection string must be updated"
    echo "    - Best for: Complex geo-distribution scenarios"
    echo ""
    echo "RPO/RTO CHARACTERISTICS:"
    echo "  RPO: Near-zero (async replication, typically < 5 seconds)"
    echo "  RTO: < 30 seconds (automatic), depends on app for manual"
    echo ""
    echo "GRACE PERIOD:"
    echo "  - Prevents failover for transient outages"
    echo "  - Set based on your tolerance for downtime vs data loss risk"
    echo "  - Current setting: $GRACE_PERIOD_MINUTES minutes"
    echo ""
    echo "==============================================================================="
    echo "FAILOVER COMMANDS:"
    echo "==============================================================================="
    echo ""
    echo "# Planned failover (no data loss) - Run from secondary region"
    echo "az sql failover-group set-primary \\"
    echo "    --name $FAILOVER_GROUP_NAME \\"
    echo "    --resource-group $RESOURCE_GROUP \\"
    echo "    --server $SECONDARY_SERVER_NAME"
    echo ""
    echo "# Forced failover (potential data loss) - For disaster scenarios"
    echo "az sql failover-group set-primary \\"
    echo "    --name $FAILOVER_GROUP_NAME \\"
    echo "    --resource-group $RESOURCE_GROUP \\"
    echo "    --server $SECONDARY_SERVER_NAME \\"
    echo "    --allow-data-loss"
    echo ""
    echo "# Check failover group status"
    echo "az sql failover-group show \\"
    echo "    --name $FAILOVER_GROUP_NAME \\"
    echo "    --resource-group $RESOURCE_GROUP \\"
    echo "    --server $PRIMARY_SERVER_NAME"
    echo ""
    echo "==============================================================================="
    echo "SAMPLE CONNECTION STRING:"
    echo "==============================================================================="
    echo ""
    echo "Server=${FAILOVER_GROUP_NAME}.database.windows.net;"
    echo "Database=${DATABASE_NAME};"
    echo "User ID=${SQL_ADMIN_USER};"
    echo "Password=<your-password>;"
    echo "Encrypt=True;"
    echo "TrustServerCertificate=False;"
    echo "ApplicationIntent=ReadWrite;"
    echo ""
    echo "For read-only connections (scale-out reads to secondary):"
    echo "ApplicationIntent=ReadOnly"
    echo "==============================================================================="
}

#-------------------------------------------------------------------------------
# TEST FAILOVER (Optional)
#-------------------------------------------------------------------------------
test_failover() {
    log_info "Testing planned failover..."

    # Perform planned failover to secondary
    az sql failover-group set-primary \
        --name "$FAILOVER_GROUP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --server "$SECONDARY_SERVER_NAME" \
        --output none

    log_success "Failover to secondary completed"

    # Wait a moment
    sleep 10

    # Check new roles
    log_info "Current roles after failover:"
    az sql failover-group show \
        --name "$FAILOVER_GROUP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --server "$SECONDARY_SERVER_NAME" \
        --query "{Name:name, NewPrimary:partnerServers[0].location, ReplicationState:replicationState}" \
        --output table

    # Fail back to original primary
    log_info "Failing back to original primary..."
    az sql failover-group set-primary \
        --name "$FAILOVER_GROUP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --server "$PRIMARY_SERVER_NAME" \
        --output none

    log_success "Failback completed"
}

#-------------------------------------------------------------------------------
# MAIN
#-------------------------------------------------------------------------------
main() {
    log_info "Starting SQL Failover Group deployment..."

    # Parse arguments
    DO_TEST_FAILOVER=false
    while [[ $# -gt 0 ]]; do
        case $1 in
            --test-failover)
                DO_TEST_FAILOVER=true
                shift
                ;;
            *)
                shift
                ;;
        esac
    done

    create_resource_group
    create_primary_server
    create_secondary_server
    create_database
    create_failover_group

    if [ "$DO_TEST_FAILOVER" = true ]; then
        test_failover
    fi

    display_summary

    log_success "SQL Failover Group deployment completed successfully!"
}

main "$@"
