#!/usr/bin/env bash
# ============================================================================
# TITLE:    AZ-305 Domain 1: Monitoring, Logging & Diagnostics
# DOMAIN:   Domain 1 - Design Identity, Governance, and Monitoring (25-30%)
# DESCRIPTION:
#   Teaching examples covering Log Analytics, diagnostic settings, Application
#   Insights, Azure Monitor alerts, action groups, Event Hub log routing, and
#   workbook concepts. Code-review examples for AZ-305 classroom use.
# AUTHOR:   Tim Warner
# DATE:     January 2026
# NOTES:    Not intended for direct execution -- these are teaching examples
#           illustrating correct syntax and architectural decision-making.
# ============================================================================

set -euo pipefail

# Common variables for the demo environment
SUBSCRIPTION_ID="00000000-0000-0000-0000-000000000000"
RESOURCE_GROUP="az305-rg"
LOCATION="eastus"
PREFIX="az305"

# ============================================================================
# SECTION 1: Log Analytics Workspace Creation and Configuration
# ============================================================================

# EXAM TIP: Log Analytics is the CENTRAL data platform for Azure Monitor.
# All diagnostic logs, metrics, Application Insights data, and Microsoft Sentinel
# data flow into Log Analytics workspaces. The exam tests workspace DESIGN:
# single workspace vs. multiple, retention periods, and access control models.

# WHEN TO USE: A single workspace per environment for most organizations.
# Multiple workspaces when you need: data sovereignty (different regions),
# access isolation (separate teams), or cost separation (different billing).
# Avoid workspace sprawl -- it complicates cross-resource queries.

az monitor log-analytics workspace create \
    --resource-group "$RESOURCE_GROUP" \
    --workspace-name "${PREFIX}-law" \
    --location "$LOCATION" \
    --sku "PerGB2018" \
    --retention-time 90 \
    --ingestion-access "Enabled" \
    --query-access "Enabled"

# Capture workspace ID for later use in diagnostic settings
LAW_ID=$(az monitor log-analytics workspace show \
    --resource-group "$RESOURCE_GROUP" \
    --workspace-name "${PREFIX}-law" \
    --query id --output tsv)

# EXAM TIP: Retention can be set from 30-730 days (workspace-level default)
# or per-table up to 2,556 days (7 years) for compliance. Data beyond the
# retention period can be archived at lower cost using archive tier.
# Interactive retention = hot queries; Archive = restore-then-query.

# Configure workspace data cap to prevent cost overruns
az monitor log-analytics workspace update \
    --resource-group "$RESOURCE_GROUP" \
    --workspace-name "${PREFIX}-law" \
    --set "workspaceCapping.dailyQuotaGb=5"

# ============================================================================
# SECTION 2: Diagnostic Settings for Multiple Resource Types
# ============================================================================

# EXAM TIP: Diagnostic settings route platform logs and metrics to destinations.
# Every Azure resource has different log categories. The exam expects you to know:
# 1. What logs are available for key services (audit, request, metrics)
# 2. Where to send them (Log Analytics, Storage, Event Hub)
# 3. When to use each destination (analytics vs. archive vs. SIEM)

# WHEN TO USE each destination:
#   Log Analytics   -> Real-time queries, alerts, dashboards, Sentinel (primary choice)
#   Storage Account -> Long-term archive, compliance retention, cost-effective cold storage
#   Event Hub       -> SIEM integration (Splunk, QRadar), custom stream processing

# --- VM Diagnostic Settings (via Azure Monitor Agent) ---
# NOTE: Legacy Log Analytics Agent (MMA) is deprecated. Always use Azure Monitor Agent (AMA).
# EXAM TIP: AMA uses Data Collection Rules (DCR) instead of workspace configuration.

az monitor data-collection rule create \
    --resource-group "$RESOURCE_GROUP" \
    --name "${PREFIX}-dcr-vm-perf" \
    --location "$LOCATION" \
    --data-flows '[{
        "streams": ["Microsoft-Perf", "Microsoft-Event"],
        "destinations": ["logAnalyticsWorkspace"]
    }]' \
    --destinations "{\"logAnalytics\": [{
        \"workspaceResourceId\": \"${LAW_ID}\",
        \"name\": \"logAnalyticsWorkspace\"
    }]}" \
    --description "Collect VM performance counters and Windows events"

# --- Azure SQL Database Diagnostic Settings ---
SQL_SERVER_ID="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Sql/servers/${PREFIX}-sql/databases/${PREFIX}-sqldb"

az monitor diagnostic-settings create \
    --name "send-to-log-analytics" \
    --resource "$SQL_SERVER_ID" \
    --workspace "$LAW_ID" \
    --logs '[
        {"category": "SQLInsights", "enabled": true},
        {"category": "AutomaticTuning", "enabled": true},
        {"category": "QueryStoreRuntimeStatistics", "enabled": true},
        {"category": "Errors", "enabled": true},
        {"category": "DatabaseWaitStatistics", "enabled": true},
        {"category": "Deadlocks", "enabled": true}
    ]' \
    --metrics '[{"category": "Basic", "enabled": true}]'

# --- Key Vault Diagnostic Settings ---
# EXAM TIP: Key Vault audit logging is CRITICAL for security monitoring.
# Always enable AuditEvent logs to track who accessed which secrets/keys/certs.
KEYVAULT_ID="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.KeyVault/vaults/${PREFIX}-kv"

az monitor diagnostic-settings create \
    --name "send-to-log-analytics" \
    --resource "$KEYVAULT_ID" \
    --workspace "$LAW_ID" \
    --logs '[
        {"category": "AuditEvent", "enabled": true},
        {"category": "AllMetrics", "enabled": true}
    ]'

# --- NSG Flow Logs (via Network Watcher, not standard diagnostic settings) ---
# EXAM TIP: NSG flow logs are configured through Network Watcher, NOT through
# standard diagnostic settings. This is a common exam distractor.
az network watcher flow-log create \
    --resource-group "$RESOURCE_GROUP" \
    --name "${PREFIX}-nsg-flowlog" \
    --nsg "${PREFIX}-nsg" \
    --storage-account "${PREFIX}flowlogstorage" \
    --workspace "$LAW_ID" \
    --enabled true \
    --retention 90 \
    --traffic-analytics true \
    --interval 10  # Traffic Analytics processing interval in minutes

# ============================================================================
# SECTION 3: Application Insights (Workspace-Based)
# ============================================================================

# EXAM TIP: Application Insights is the APM (Application Performance Monitoring)
# solution in Azure Monitor. ALWAYS choose workspace-based (not classic).
# Classic Application Insights is deprecated. Workspace-based stores data in
# Log Analytics, enabling cross-resource queries and longer retention.

# WHEN TO USE: Application Insights for any web application, API, or microservice.
# It provides: request tracking, dependency mapping, exception logging,
# custom metrics, availability tests, and distributed tracing.

az monitor app-insights component create \
    --app "${PREFIX}-appinsights" \
    --location "$LOCATION" \
    --resource-group "$RESOURCE_GROUP" \
    --kind "web" \
    --application-type "web" \
    --workspace "$LAW_ID" \
    --retention-time 90

# Get the instrumentation key and connection string for application configuration
APPINSIGHTS_KEY=$(az monitor app-insights component show \
    --app "${PREFIX}-appinsights" \
    --resource-group "$RESOURCE_GROUP" \
    --query instrumentationKey --output tsv)

APPINSIGHTS_CONNSTR=$(az monitor app-insights component show \
    --app "${PREFIX}-appinsights" \
    --resource-group "$RESOURCE_GROUP" \
    --query connectionString --output tsv)

# EXAM TIP: Use CONNECTION STRING (not instrumentation key alone) for new apps.
# Connection strings support regional endpoints and are the modern approach.
# Store the connection string in Key Vault or App Configuration, never in code.

# Create an availability test (URL ping test)
# EXAM TIP: Availability tests verify your app is reachable from multiple global
# locations. Standard tests run every 5 minutes from up to 16 locations.
az monitor app-insights web-test create \
    --resource-group "$RESOURCE_GROUP" \
    --name "${PREFIX}-availability-test" \
    --defined-web-test-name "Homepage Health Check" \
    --location "$LOCATION" \
    --kind "standard" \
    --locations '[{"Id": "us-va-ash-azr"}, {"Id": "emea-gb-db3-azr"}, {"Id": "apac-jp-kaw-edge"}]' \
    --web-test-kind "standard" \
    --request-url "https://${PREFIX}-webapp.azurewebsites.net/health" \
    --expected-status-code 200 \
    --frequency 300 \
    --timeout 30 \
    --ssl-check true

# ============================================================================
# SECTION 4: Azure Monitor Alert Rules
# ============================================================================

# EXAM TIP: Azure Monitor supports three alert types:
# 1. METRIC alerts  -> Numeric thresholds (CPU > 80%, response time > 2s)
# 2. LOG alerts     -> KQL query results (error count, custom conditions)
# 3. ACTIVITY LOG alerts -> Control plane events (VM deleted, role assigned)
# The exam tests WHEN to use each type. Metric alerts evaluate every 1-5 min.
# Log alerts can evaluate on custom schedules (5 min to 24 hours).

# WHEN TO USE each alert type:
#   Metric alerts    -> Real-time performance thresholds (fastest evaluation)
#   Log alerts       -> Complex conditions requiring KQL queries
#   Activity log     -> Security/governance events (resource changes, role assignments)

# --- Metric Alert: VM CPU exceeds 80% ---
VM_ID="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Compute/virtualMachines/${PREFIX}-vm"

az monitor metrics alert create \
    --name "high-cpu-alert" \
    --resource-group "$RESOURCE_GROUP" \
    --scopes "$VM_ID" \
    --condition "avg Percentage CPU > 80" \
    --window-size "5m" \
    --evaluation-frequency "1m" \
    --severity 2 \
    --description "Alert when VM CPU exceeds 80% averaged over 5 minutes" \
    --action "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Insights/actionGroups/${PREFIX}-ag-ops"

# --- Log Alert: Application error spike ---
# Uses KQL (Kusto Query Language) to detect error patterns
az monitor scheduled-query create \
    --name "app-error-spike" \
    --resource-group "$RESOURCE_GROUP" \
    --scopes "$LAW_ID" \
    --condition "count 'Heartbeat | where TimeGenerated > ago(5m)' > 50" \
    --condition-query "AppExceptions | where TimeGenerated > ago(15m) | summarize ErrorCount = count() by AppName" \
    --evaluation-frequency "5m" \
    --window-size "15m" \
    --severity 1 \
    --description "Alert when application exceptions spike above normal baseline" \
    --action "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Insights/actionGroups/${PREFIX}-ag-ops"

# --- Activity Log Alert: Resource deletion detection ---
# EXAM TIP: Activity log alerts detect control plane operations. Use these for
# governance (someone deleted a resource, changed an NSG, or modified RBAC).
az monitor activity-log alert create \
    --name "resource-deletion-alert" \
    --resource-group "$RESOURCE_GROUP" \
    --condition "category=Administrative and operationName=Microsoft.Resources/subscriptions/resourceGroups/delete/action and level=Critical" \
    --scope "/subscriptions/${SUBSCRIPTION_ID}" \
    --action-group "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Insights/actionGroups/${PREFIX}-ag-security" \
    --description "Alert when any resource group is deleted"

# ============================================================================
# SECTION 5: Action Groups with Multiple Notification Channels
# ============================================================================

# EXAM TIP: Action groups define WHO gets notified and HOW. A single action group
# can include email, SMS, voice, push, webhook, ITSM, Logic App, Azure Function,
# and Automation Runbook actions. Reuse action groups across multiple alert rules.

# WHEN TO USE each notification type:
#   Email      -> Primary notification for all alert severities
#   SMS/Voice  -> Critical alerts only (P1/Sev1) -- has per-message cost
#   Webhook    -> Integration with PagerDuty, ServiceNow, Slack, Teams
#   Runbook    -> Auto-remediation (restart VM, scale out, etc.)

# Operations team action group
az monitor action-group create \
    --name "${PREFIX}-ag-ops" \
    --resource-group "$RESOURCE_GROUP" \
    --short-name "OpsTeam" \
    --action email ops-email "ops-team@contoso.com" \
    --action sms ops-sms "1" "5551234567" \
    --action webhook ops-pagerduty "https://events.pagerduty.com/integration/REDACTED/enqueue"

# Security team action group (separate escalation path)
az monitor action-group create \
    --name "${PREFIX}-ag-security" \
    --resource-group "$RESOURCE_GROUP" \
    --short-name "SecTeam" \
    --action email sec-email "security-team@contoso.com" \
    --action webhook sec-sentinel "https://sentinel-webhook.contoso.com/alerts"

# EXAM TIP: Action groups have RATE LIMITS to prevent notification storms:
#   Email: max 100 emails/hour, SMS: max 1 per 5 minutes, Voice: max 1 per 5 min.
# Design your alert rules to avoid cascading triggers.

# ============================================================================
# SECTION 6: Log Routing to Event Hub for SIEM Integration
# ============================================================================

# EXAM TIP: Event Hubs serve as the bridge between Azure Monitor and external
# SIEM solutions (Splunk, IBM QRadar, Elastic). The exam tests the pattern:
#   Azure Resource -> Diagnostic Settings -> Event Hub -> SIEM Consumer
# This is DIFFERENT from Microsoft Sentinel, which consumes logs natively
# in Log Analytics. Use Event Hub when the SIEM is external/third-party.

# WHEN TO USE Event Hub routing:
#   - External SIEM (Splunk, QRadar) that cannot query Log Analytics directly
#   - Real-time stream processing with Azure Stream Analytics or custom consumers
#   - Multi-cloud logging aggregation
# WHEN TO USE Microsoft Sentinel instead:
#   - Cloud-native SIEM needs (built on Log Analytics)
#   - You want built-in threat detection, SOAR playbooks, and hunting queries

# Create Event Hub namespace for log streaming
az eventhubs namespace create \
    --name "${PREFIX}-eh-namespace" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --sku "Standard" \
    --capacity 2 \
    --enable-auto-inflate true \
    --maximum-throughput-units 10

# Create a dedicated Event Hub for security logs
az eventhubs eventhub create \
    --name "security-logs" \
    --namespace-name "${PREFIX}-eh-namespace" \
    --resource-group "$RESOURCE_GROUP" \
    --partition-count 4 \
    --message-retention 7

EVENT_HUB_RULE_ID=$(az eventhubs namespace authorization-rule show \
    --resource-group "$RESOURCE_GROUP" \
    --namespace-name "${PREFIX}-eh-namespace" \
    --name "RootManageSharedAccessKey" \
    --query id --output tsv)

# Route Activity Log to Event Hub for SIEM consumption
az monitor diagnostic-settings create \
    --name "activity-to-eventhub" \
    --resource "/subscriptions/${SUBSCRIPTION_ID}" \
    --event-hub "security-logs" \
    --event-hub-rule "$EVENT_HUB_RULE_ID" \
    --logs '[
        {"category": "Administrative", "enabled": true},
        {"category": "Security", "enabled": true},
        {"category": "Policy", "enabled": true}
    ]'

# ============================================================================
# SECTION 7: Workbook Concepts
# ============================================================================

# EXAM TIP: Azure Workbooks provide interactive, customizable dashboards built
# on Log Analytics data. They replace the deprecated View Designer.
# Workbooks support: KQL queries, metrics, parameters, visualizations, and
# conditional visibility. They can be shared via Azure portal galleries.

# WHEN TO USE Workbooks vs. Dashboards vs. Power BI:
#   Workbooks  -> Interactive analysis with parameters, drill-down, rich visuals
#   Dashboards -> Quick overview tiles pinned from various Azure blades
#   Power BI   -> Executive reporting, cross-platform data, scheduled refresh

# Workbooks are defined as JSON templates -- typically created in the portal
# and exported. Here we show the conceptual structure:
#
# Key workbook concepts for the exam:
# 1. PARAMETERS: Dynamic filters (time range, resource group, subscription)
# 2. STEPS: Query blocks that render as grids, charts, or text
# 3. LINKS: Cross-workbook navigation and drill-through
# 4. GROUPS: Conditional visibility based on parameter values
# 5. TEMPLATES: Reusable workbook definitions shared via gallery

# Example: Create a workbook template via ARM/Bicep (conceptual)
# az deployment group create \
#     --resource-group "$RESOURCE_GROUP" \
#     --template-file workbook-template.bicep \
#     --parameters workbookName="${PREFIX}-ops-workbook" \
#                  workspaceId="$LAW_ID"

echo "Monitoring and logging configuration complete."
echo "Log Analytics Workspace: ${PREFIX}-law"
echo "Application Insights: ${PREFIX}-appinsights"
echo "Event Hub Namespace: ${PREFIX}-eh-namespace"
