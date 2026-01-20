#!/bin/bash
#===============================================================================
# SCRIPT: configure-diagnostic-settings.sh
# SYNOPSIS: Configure diagnostic settings for Azure resources
# DESCRIPTION:
#   This script configures diagnostic settings to send logs and metrics to:
#   - Log Analytics Workspace (for analysis and alerting)
#   - Storage Account (for long-term retention and compliance)
#   - Event Hub (for streaming to external SIEM)
#
#   Demonstrates configuration for common resource types:
#   - Azure Key Vault
#   - Azure SQL Database
#   - Azure App Service
#   - Network Security Groups (flow logs)
#
# AZ-305 EXAM OBJECTIVES:
#   - Design a solution for logging and monitoring: Diagnostic settings
#   - Design data storage: Log retention strategies
#   - Cost optimization: Choosing appropriate log destinations
#   - Operational excellence: Observability patterns
#
# PREREQUISITES:
#   - Azure CLI 2.50+ installed and authenticated
#   - Microsoft.Insights resource provider registered
#   - Existing resources to configure (or script will create samples)
#
# EXAMPLES:
#   # Configure diagnostics for all resources in a resource group
#   ./configure-diagnostic-settings.sh
#
#   # Configure with custom retention days
#   RETENTION_DAYS=365 ./configure-diagnostic-settings.sh
#
# REFERENCES:
#   - https://learn.microsoft.com/azure/azure-monitor/essentials/diagnostic-settings
#   - https://learn.microsoft.com/azure/azure-monitor/essentials/resource-logs
#===============================================================================

set -euo pipefail

#-------------------------------------------------------------------------------
# CONFIGURATION
#-------------------------------------------------------------------------------
LOCATION="${LOCATION:-eastus}"
PREFIX="${PREFIX:-az305}"
RESOURCE_GROUP="${RESOURCE_GROUP:-${PREFIX}-diagnostics-rg}"
RETENTION_DAYS="${RETENTION_DAYS:-90}"

# Log Analytics Workspace
LAW_NAME="${PREFIX}-law"
LAW_SKU="${LAW_SKU:-PerGB2018}"
LAW_RETENTION_DAYS="${LAW_RETENTION_DAYS:-30}"

# Storage Account for logs archive
DIAG_STORAGE_NAME="${PREFIX}diaglogs$(openssl rand -hex 4)"

# Event Hub for streaming (optional)
EVENTHUB_NAMESPACE="${PREFIX}-eventhub-ns"
EVENTHUB_NAME="diagnostic-logs"

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

#-------------------------------------------------------------------------------
# SETUP LOG DESTINATIONS
#-------------------------------------------------------------------------------
setup_log_destinations() {
    log_info "Setting up log destinations..."

    # Create resource group
    az group create \
        --name "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --tags "Environment=Development" "Purpose=AZ305-Diagnostics" \
        --output none

    # Create Log Analytics Workspace
    # WHY: Central location for log analysis, alerts, and Azure Monitor integration
    log_info "Creating Log Analytics Workspace..."
    az monitor log-analytics workspace create \
        --workspace-name "$LAW_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --sku "$LAW_SKU" \
        --retention-time "$LAW_RETENTION_DAYS" \
        --tags "Purpose=Diagnostics" \
        --output none

    # Get workspace ID for later use
    LAW_ID=$(az monitor log-analytics workspace show \
        --workspace-name "$LAW_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query id \
        --output tsv)

    log_success "Log Analytics Workspace created: $LAW_NAME"

    # Create Storage Account for log archival
    # WHY: Cost-effective long-term storage for compliance requirements
    log_info "Creating Storage Account for log archival..."
    az storage account create \
        --name "$DIAG_STORAGE_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --sku "Standard_LRS" \
        --kind "StorageV2" \
        --https-only true \
        --min-tls-version "TLS1_2" \
        --allow-blob-public-access false \
        --tags "Purpose=DiagnosticLogs" \
        --output none

    DIAG_STORAGE_ID=$(az storage account show \
        --name "$DIAG_STORAGE_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query id \
        --output tsv)

    log_success "Storage Account created: $DIAG_STORAGE_NAME"

    # Create Event Hub Namespace for streaming (optional but demonstrates the pattern)
    # WHY: Stream logs to external SIEM systems like Splunk, QRadar, etc.
    log_info "Creating Event Hub Namespace..."
    az eventhubs namespace create \
        --name "$EVENTHUB_NAMESPACE" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --sku "Standard" \
        --tags "Purpose=DiagnosticStreaming" \
        --output none

    az eventhubs eventhub create \
        --name "$EVENTHUB_NAME" \
        --namespace-name "$EVENTHUB_NAMESPACE" \
        --resource-group "$RESOURCE_GROUP" \
        --message-retention 1 \
        --partition-count 2 \
        --output none

    # Get Event Hub authorization rule ID
    EVENTHUB_AUTH_RULE_ID=$(az eventhubs namespace authorization-rule show \
        --name "RootManageSharedAccessKey" \
        --namespace-name "$EVENTHUB_NAMESPACE" \
        --resource-group "$RESOURCE_GROUP" \
        --query id \
        --output tsv)

    log_success "Event Hub created: $EVENTHUB_NAME"
}

#-------------------------------------------------------------------------------
# CREATE SAMPLE RESOURCES
#-------------------------------------------------------------------------------
create_sample_resources() {
    log_info "Creating sample resources for diagnostic configuration..."

    # Create Key Vault
    KV_NAME="${PREFIX}-diag-kv-$(openssl rand -hex 4)"
    az keyvault create \
        --name "$KV_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --enable-rbac-authorization true \
        --output none

    KV_ID=$(az keyvault show \
        --name "$KV_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query id \
        --output tsv)

    log_success "Key Vault created: $KV_NAME"

    # Create App Service Plan and Web App
    APP_PLAN_NAME="${PREFIX}-diag-plan"
    WEB_APP_NAME="${PREFIX}-diag-app-$(openssl rand -hex 4)"

    az appservice plan create \
        --name "$APP_PLAN_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --sku "S1" \
        --output none

    az webapp create \
        --name "$WEB_APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --plan "$APP_PLAN_NAME" \
        --output none

    WEB_APP_ID=$(az webapp show \
        --name "$WEB_APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query id \
        --output tsv)

    log_success "Web App created: $WEB_APP_NAME"
}

#-------------------------------------------------------------------------------
# CONFIGURE DIAGNOSTIC SETTINGS FOR KEY VAULT
#-------------------------------------------------------------------------------
configure_keyvault_diagnostics() {
    log_info "Configuring diagnostic settings for Key Vault..."

    # WHY: Key Vault audit logs are critical for security monitoring
    # AuditEvent logs capture all API operations on secrets, keys, and certificates
    az monitor diagnostic-settings create \
        --name "kv-diagnostics" \
        --resource "$KV_ID" \
        --workspace "$LAW_ID" \
        --storage-account "$DIAG_STORAGE_ID" \
        --event-hub-rule "$EVENTHUB_AUTH_RULE_ID" \
        --event-hub "$EVENTHUB_NAME" \
        --logs '[
            {
                "category": "AuditEvent",
                "enabled": true,
                "retentionPolicy": {
                    "enabled": true,
                    "days": '"$RETENTION_DAYS"'
                }
            },
            {
                "category": "AzurePolicyEvaluationDetails",
                "enabled": true,
                "retentionPolicy": {
                    "enabled": true,
                    "days": '"$RETENTION_DAYS"'
                }
            }
        ]' \
        --metrics '[
            {
                "category": "AllMetrics",
                "enabled": true,
                "retentionPolicy": {
                    "enabled": true,
                    "days": '"$RETENTION_DAYS"'
                }
            }
        ]' \
        --output none

    log_success "Key Vault diagnostic settings configured"
}

#-------------------------------------------------------------------------------
# CONFIGURE DIAGNOSTIC SETTINGS FOR WEB APP
#-------------------------------------------------------------------------------
configure_webapp_diagnostics() {
    log_info "Configuring diagnostic settings for Web App..."

    # WHY: App Service logs help troubleshoot application issues and track performance
    # Multiple log categories cover different aspects of the application
    az monitor diagnostic-settings create \
        --name "webapp-diagnostics" \
        --resource "$WEB_APP_ID" \
        --workspace "$LAW_ID" \
        --storage-account "$DIAG_STORAGE_ID" \
        --logs '[
            {
                "category": "AppServiceHTTPLogs",
                "enabled": true,
                "retentionPolicy": {
                    "enabled": true,
                    "days": '"$RETENTION_DAYS"'
                }
            },
            {
                "category": "AppServiceConsoleLogs",
                "enabled": true,
                "retentionPolicy": {
                    "enabled": true,
                    "days": '"$RETENTION_DAYS"'
                }
            },
            {
                "category": "AppServiceAppLogs",
                "enabled": true,
                "retentionPolicy": {
                    "enabled": true,
                    "days": '"$RETENTION_DAYS"'
                }
            },
            {
                "category": "AppServiceAuditLogs",
                "enabled": true,
                "retentionPolicy": {
                    "enabled": true,
                    "days": '"$RETENTION_DAYS"'
                }
            },
            {
                "category": "AppServiceIPSecAuditLogs",
                "enabled": true,
                "retentionPolicy": {
                    "enabled": true,
                    "days": '"$RETENTION_DAYS"'
                }
            },
            {
                "category": "AppServicePlatformLogs",
                "enabled": true,
                "retentionPolicy": {
                    "enabled": true,
                    "days": '"$RETENTION_DAYS"'
                }
            }
        ]' \
        --metrics '[
            {
                "category": "AllMetrics",
                "enabled": true,
                "retentionPolicy": {
                    "enabled": true,
                    "days": '"$RETENTION_DAYS"'
                }
            }
        ]' \
        --output none

    log_success "Web App diagnostic settings configured"
}

#-------------------------------------------------------------------------------
# CONFIGURE ACTIVITY LOG EXPORT
#-------------------------------------------------------------------------------
configure_activity_log() {
    log_info "Configuring Activity Log export to Log Analytics..."

    # WHY: Activity Log contains subscription-level events (control plane operations)
    # Critical for auditing who did what at the management plane level
    # Get subscription ID
    SUBSCRIPTION_ID=$(az account show --query id --output tsv)

    # Check if diagnostic setting already exists
    existing=$(az monitor diagnostic-settings list \
        --resource "/subscriptions/$SUBSCRIPTION_ID" \
        --query "[?name=='activity-log-diagnostics']" \
        --output tsv 2>/dev/null || echo "")

    if [ -z "$existing" ]; then
        az monitor diagnostic-settings create \
            --name "activity-log-diagnostics" \
            --resource "/subscriptions/$SUBSCRIPTION_ID" \
            --workspace "$LAW_ID" \
            --logs '[
                {
                    "category": "Administrative",
                    "enabled": true
                },
                {
                    "category": "Security",
                    "enabled": true
                },
                {
                    "category": "ServiceHealth",
                    "enabled": true
                },
                {
                    "category": "Alert",
                    "enabled": true
                },
                {
                    "category": "Recommendation",
                    "enabled": true
                },
                {
                    "category": "Policy",
                    "enabled": true
                },
                {
                    "category": "Autoscale",
                    "enabled": true
                },
                {
                    "category": "ResourceHealth",
                    "enabled": true
                }
            ]' \
            --output none

        log_success "Activity Log export configured"
    else
        log_info "Activity Log diagnostic setting already exists"
    fi
}

#-------------------------------------------------------------------------------
# CREATE ALERT RULES
#-------------------------------------------------------------------------------
create_sample_alerts() {
    log_info "Creating sample alert rules..."

    # Alert for Key Vault access
    # WHY: Alerts enable proactive monitoring and incident response
    az monitor metrics alert create \
        --name "kv-high-latency-alert" \
        --resource-group "$RESOURCE_GROUP" \
        --scopes "$KV_ID" \
        --condition "avg ServiceApiLatency > 1000" \
        --window-size 5m \
        --evaluation-frequency 1m \
        --severity 2 \
        --description "Alert when Key Vault API latency exceeds 1 second" \
        --output none

    log_success "Sample alert rules created"
}

#-------------------------------------------------------------------------------
# DISPLAY SUMMARY
#-------------------------------------------------------------------------------
display_summary() {
    echo ""
    echo "==============================================================================="
    echo "                  DIAGNOSTIC SETTINGS DEPLOYMENT SUMMARY"
    echo "==============================================================================="
    echo ""
    echo "Resource Group: $RESOURCE_GROUP"
    echo "Location: $LOCATION"
    echo ""
    echo "LOG DESTINATIONS:"
    echo "-------------------------------------------------------------------------------"
    echo "1. Log Analytics Workspace: $LAW_NAME"
    echo "   - Retention: $LAW_RETENTION_DAYS days"
    echo "   - SKU: $LAW_SKU"
    echo ""
    echo "2. Storage Account: $DIAG_STORAGE_NAME"
    echo "   - Purpose: Long-term log archival"
    echo "   - Retention: $RETENTION_DAYS days"
    echo ""
    echo "3. Event Hub: $EVENTHUB_NAMESPACE/$EVENTHUB_NAME"
    echo "   - Purpose: Stream to external SIEM"
    echo ""
    echo "CONFIGURED RESOURCES:"
    echo "-------------------------------------------------------------------------------"
    echo "1. Key Vault: $KV_NAME"
    echo "   - Logs: AuditEvent, AzurePolicyEvaluationDetails"
    echo "   - Metrics: AllMetrics"
    echo ""
    echo "2. Web App: $WEB_APP_NAME"
    echo "   - Logs: HTTP, Console, App, Audit, IPSec, Platform"
    echo "   - Metrics: AllMetrics"
    echo ""
    echo "3. Activity Log (Subscription-level)"
    echo "   - Categories: Administrative, Security, ServiceHealth, etc."
    echo ""
    echo "DIAGNOSTIC SETTINGS LIST:"
    echo ""
    echo "Key Vault Diagnostics:"
    az monitor diagnostic-settings list --resource "$KV_ID" \
        --query "[].{Name:name, Workspace:workspaceId!=null, Storage:storageAccountId!=null, EventHub:eventHubAuthorizationRuleId!=null}" \
        --output table
    echo ""
    echo "Web App Diagnostics:"
    az monitor diagnostic-settings list --resource "$WEB_APP_ID" \
        --query "[].{Name:name, Workspace:workspaceId!=null, Storage:storageAccountId!=null}" \
        --output table
    echo ""
    echo "==============================================================================="
    echo "SAMPLE KQL QUERIES FOR LOG ANALYTICS:"
    echo ""
    echo "// Key Vault operations"
    echo "AzureDiagnostics"
    echo "| where ResourceProvider == 'MICROSOFT.KEYVAULT'"
    echo "| where Category == 'AuditEvent'"
    echo "| project TimeGenerated, OperationName, ResultType, CallerIPAddress"
    echo "| order by TimeGenerated desc"
    echo ""
    echo "// App Service HTTP requests"
    echo "AppServiceHTTPLogs"
    echo "| where ScStatus >= 400"
    echo "| summarize count() by ScStatus, CsMethod"
    echo ""
    echo "// Activity Log - Resource changes"
    echo "AzureActivity"
    echo "| where CategoryValue == 'Administrative'"
    echo "| where OperationNameValue contains 'write' or OperationNameValue contains 'delete'"
    echo "| project TimeGenerated, Caller, OperationNameValue, ResourceGroup"
    echo "==============================================================================="
}

#-------------------------------------------------------------------------------
# MAIN
#-------------------------------------------------------------------------------
main() {
    log_info "Starting diagnostic settings configuration..."

    setup_log_destinations
    create_sample_resources
    configure_keyvault_diagnostics
    configure_webapp_diagnostics
    configure_activity_log
    create_sample_alerts
    display_summary

    log_success "Diagnostic settings configuration completed successfully!"
}

main "$@"
