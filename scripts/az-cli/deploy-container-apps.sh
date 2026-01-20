#!/bin/bash
#===============================================================================
# SCRIPT: deploy-container-apps.sh
# SYNOPSIS: Deploy Azure Container Apps environment with sample application
# DESCRIPTION:
#   This script creates a complete Azure Container Apps deployment including:
#   - Container Apps Environment with Log Analytics integration
#   - Sample containerized application with scaling rules
#   - Managed identity configuration
#   - Ingress configuration for external access
#   - Dapr integration (optional)
#
# AZ-305 EXAM OBJECTIVES:
#   - Design application architecture: Container orchestration options
#   - Compare Container Apps vs AKS vs App Service
#   - Understand serverless container hosting
#   - Configure auto-scaling based on HTTP requests or custom metrics
#   - Implement microservices patterns with Dapr
#
# PREREQUISITES:
#   - Azure CLI 2.50+ with containerapp extension
#   - Azure subscription with Microsoft.App provider registered
#
# EXAMPLES:
#   # Deploy with default configuration
#   ./deploy-container-apps.sh
#
#   # Deploy with Dapr enabled
#   ENABLE_DAPR=true ./deploy-container-apps.sh
#
# REFERENCES:
#   - https://learn.microsoft.com/azure/container-apps/overview
#   - https://learn.microsoft.com/azure/container-apps/scale-app
#===============================================================================

set -euo pipefail

#-------------------------------------------------------------------------------
# CONFIGURATION
#-------------------------------------------------------------------------------
LOCATION="${LOCATION:-eastus}"
PREFIX="${PREFIX:-az305}"
RESOURCE_GROUP="${RESOURCE_GROUP:-${PREFIX}-containerapps-rg}"
ENVIRONMENT_NAME="${ENVIRONMENT_NAME:-${PREFIX}-cae}"
APP_NAME="${APP_NAME:-${PREFIX}-app}"
ENABLE_DAPR="${ENABLE_DAPR:-false}"

# Container image (using a public sample image)
CONTAINER_IMAGE="${CONTAINER_IMAGE:-mcr.microsoft.com/azuredocs/containerapps-helloworld:latest}"

# Scaling configuration
MIN_REPLICAS="${MIN_REPLICAS:-0}"
MAX_REPLICAS="${MAX_REPLICAS:-10}"

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
# INSTALL/UPDATE CONTAINER APPS EXTENSION
#-------------------------------------------------------------------------------
setup_cli_extension() {
    log_info "Ensuring Container Apps CLI extension is installed..."

    # Add or update the containerapp extension
    az extension add --name containerapp --upgrade --yes --output none 2>/dev/null || true

    # Register the Microsoft.App namespace if not already registered
    log_info "Checking Microsoft.App provider registration..."
    registration_state=$(az provider show --namespace Microsoft.App --query "registrationState" --output tsv 2>/dev/null || echo "NotRegistered")

    if [ "$registration_state" != "Registered" ]; then
        log_info "Registering Microsoft.App provider..."
        az provider register --namespace Microsoft.App --output none
        # Wait for registration
        while [ "$(az provider show --namespace Microsoft.App --query "registrationState" --output tsv)" != "Registered" ]; do
            log_info "Waiting for provider registration..."
            sleep 10
        done
    fi

    # Also register Microsoft.OperationalInsights for Log Analytics
    az provider register --namespace Microsoft.OperationalInsights --output none 2>/dev/null || true

    log_success "CLI extension and providers ready"
}

#-------------------------------------------------------------------------------
# CREATE RESOURCE GROUP
#-------------------------------------------------------------------------------
create_resource_group() {
    log_info "Creating resource group..."

    az group create \
        --name "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --tags "Environment=Development" "Purpose=AZ305-ContainerApps" \
        --output none

    log_success "Resource group created: $RESOURCE_GROUP"
}

#-------------------------------------------------------------------------------
# CREATE LOG ANALYTICS WORKSPACE
#-------------------------------------------------------------------------------
create_log_analytics() {
    log_info "Creating Log Analytics Workspace..."

    LAW_NAME="${PREFIX}-cae-law"

    az monitor log-analytics workspace create \
        --workspace-name "$LAW_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --output none

    # Get workspace credentials for Container Apps environment
    LAW_CLIENT_ID=$(az monitor log-analytics workspace show \
        --workspace-name "$LAW_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query customerId \
        --output tsv)

    LAW_CLIENT_SECRET=$(az monitor log-analytics workspace get-shared-keys \
        --workspace-name "$LAW_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query primarySharedKey \
        --output tsv)

    log_success "Log Analytics Workspace created: $LAW_NAME"
}

#-------------------------------------------------------------------------------
# CREATE CONTAINER APPS ENVIRONMENT
#-------------------------------------------------------------------------------
create_container_apps_environment() {
    log_info "Creating Container Apps Environment..."

    # WHY: Container Apps Environment provides a secure boundary
    # - All apps in the same environment share the same virtual network
    # - Apps can communicate with each other using internal DNS
    # - Log Analytics integration provides centralized logging

    az containerapp env create \
        --name "$ENVIRONMENT_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --logs-workspace-id "$LAW_CLIENT_ID" \
        --logs-workspace-key "$LAW_CLIENT_SECRET" \
        --output none

    log_success "Container Apps Environment created: $ENVIRONMENT_NAME"
}

#-------------------------------------------------------------------------------
# CREATE CONTAINER APP
#-------------------------------------------------------------------------------
create_container_app() {
    log_info "Creating Container App..."

    # WHY: Container Apps provide serverless container hosting
    # - Automatic scaling based on HTTP traffic, CPU, memory, or custom metrics
    # - Built-in support for Dapr for microservices patterns
    # - Zero to N scaling (scale to zero when no traffic)

    # Build the create command
    create_cmd="az containerapp create \
        --name $APP_NAME \
        --resource-group $RESOURCE_GROUP \
        --environment $ENVIRONMENT_NAME \
        --image $CONTAINER_IMAGE \
        --target-port 80 \
        --ingress external \
        --min-replicas $MIN_REPLICAS \
        --max-replicas $MAX_REPLICAS \
        --cpu 0.25 \
        --memory 0.5Gi \
        --tags Environment=Development Purpose=AZ305"

    # Add Dapr configuration if enabled
    # WHY: Dapr provides service invocation, state management, pub/sub, and more
    if [ "$ENABLE_DAPR" == "true" ]; then
        log_info "Enabling Dapr integration..."
        create_cmd="$create_cmd \
            --enable-dapr \
            --dapr-app-id $APP_NAME \
            --dapr-app-port 80 \
            --dapr-app-protocol http"
    fi

    # Execute the command
    eval "$create_cmd --output none"

    log_success "Container App created: $APP_NAME"
}

#-------------------------------------------------------------------------------
# CONFIGURE SCALING RULES
#-------------------------------------------------------------------------------
configure_scaling() {
    log_info "Configuring advanced scaling rules..."

    # WHY: Container Apps support multiple scaling triggers
    # - HTTP: Scale based on concurrent requests
    # - CPU/Memory: Scale based on resource utilization
    # - Custom: Azure Queue, Kafka, etc.

    # Update with HTTP scaling rule
    # This scales based on concurrent HTTP requests per replica
    az containerapp update \
        --name "$APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --min-replicas "$MIN_REPLICAS" \
        --max-replicas "$MAX_REPLICAS" \
        --scale-rule-name "http-scaling" \
        --scale-rule-type "http" \
        --scale-rule-http-concurrency 100 \
        --output none

    log_success "Scaling rules configured"
}

#-------------------------------------------------------------------------------
# CREATE USER-ASSIGNED MANAGED IDENTITY
#-------------------------------------------------------------------------------
create_managed_identity() {
    log_info "Creating and assigning managed identity..."

    IDENTITY_NAME="${APP_NAME}-identity"

    # Create user-assigned managed identity
    # WHY: Managed identities eliminate the need to manage credentials
    # - No secrets to rotate
    # - Secure access to Azure resources like Key Vault, Storage
    az identity create \
        --name "$IDENTITY_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --output none

    # Get identity details
    IDENTITY_ID=$(az identity show \
        --name "$IDENTITY_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query id \
        --output tsv)

    IDENTITY_CLIENT_ID=$(az identity show \
        --name "$IDENTITY_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query clientId \
        --output tsv)

    # Assign identity to container app
    az containerapp identity assign \
        --name "$APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --user-assigned "$IDENTITY_ID" \
        --output none

    log_success "Managed identity assigned: $IDENTITY_NAME"
}

#-------------------------------------------------------------------------------
# CREATE SECOND APP FOR MICROSERVICES DEMO
#-------------------------------------------------------------------------------
create_backend_app() {
    log_info "Creating backend Container App for microservices demo..."

    BACKEND_APP_NAME="${APP_NAME}-backend"

    az containerapp create \
        --name "$BACKEND_APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --environment "$ENVIRONMENT_NAME" \
        --image "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest" \
        --target-port 80 \
        --ingress internal \
        --min-replicas 1 \
        --max-replicas 5 \
        --cpu 0.25 \
        --memory 0.5Gi \
        --output none

    # WHY: Internal ingress makes the app only accessible within the environment
    # This is the pattern for backend services in microservices architecture

    log_success "Backend Container App created: $BACKEND_APP_NAME"
}

#-------------------------------------------------------------------------------
# DISPLAY SUMMARY
#-------------------------------------------------------------------------------
display_summary() {
    echo ""
    echo "==============================================================================="
    echo "                   CONTAINER APPS DEPLOYMENT SUMMARY"
    echo "==============================================================================="
    echo ""
    echo "Resource Group: $RESOURCE_GROUP"
    echo "Location: $LOCATION"
    echo ""
    echo "CONTAINER APPS ENVIRONMENT:"
    echo "-------------------------------------------------------------------------------"
    echo "Name: $ENVIRONMENT_NAME"
    echo "Log Analytics: $LAW_NAME"
    echo ""

    # Get environment details
    env_details=$(az containerapp env show \
        --name "$ENVIRONMENT_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query "{StaticIP:properties.staticIp, DefaultDomain:properties.defaultDomain}" \
        --output json)

    echo "Environment Details:"
    echo "$env_details" | jq -r 'to_entries[] | "  \(.key): \(.value)"'
    echo ""

    echo "CONTAINER APPS:"
    echo "-------------------------------------------------------------------------------"

    # List all apps
    az containerapp list \
        --resource-group "$RESOURCE_GROUP" \
        --query "[].{Name:name, Image:properties.template.containers[0].image, Ingress:properties.configuration.ingress.external, FQDN:properties.configuration.ingress.fqdn, Replicas:properties.template.scale.minReplicas}" \
        --output table
    echo ""

    # Get frontend app URL
    APP_FQDN=$(az containerapp show \
        --name "$APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query "properties.configuration.ingress.fqdn" \
        --output tsv 2>/dev/null || echo "")

    if [ -n "$APP_FQDN" ]; then
        echo "APPLICATION URL: https://$APP_FQDN"
        echo ""
    fi

    echo "SCALING CONFIGURATION:"
    echo "-------------------------------------------------------------------------------"
    az containerapp show \
        --name "$APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query "properties.template.scale" \
        --output yaml
    echo ""

    if [ "$ENABLE_DAPR" == "true" ]; then
        echo "DAPR CONFIGURATION:"
        echo "-------------------------------------------------------------------------------"
        az containerapp show \
            --name "$APP_NAME" \
            --resource-group "$RESOURCE_GROUP" \
            --query "properties.configuration.dapr" \
            --output yaml
        echo ""
    fi

    echo "==============================================================================="
    echo "CONTAINER APPS VS OTHER OPTIONS (AZ-305 Exam Context):"
    echo "==============================================================================="
    echo ""
    echo "AZURE CONTAINER APPS:"
    echo "  - Serverless, fully managed"
    echo "  - Scale to zero (cost optimization)"
    echo "  - Built-in Dapr, KEDA support"
    echo "  - Best for: Microservices, APIs, event-driven apps"
    echo ""
    echo "AZURE KUBERNETES SERVICE (AKS):"
    echo "  - Full Kubernetes control"
    echo "  - Complex networking and storage options"
    echo "  - Best for: Complex workloads needing K8s features"
    echo ""
    echo "AZURE APP SERVICE:"
    echo "  - Traditional PaaS"
    echo "  - Deployment slots, custom domains"
    echo "  - Best for: Web apps with specific runtime needs"
    echo ""
    echo "==============================================================================="
    echo "USEFUL COMMANDS:"
    echo "==============================================================================="
    echo ""
    echo "# View application logs"
    echo "az containerapp logs show --name $APP_NAME --resource-group $RESOURCE_GROUP --follow"
    echo ""
    echo "# View revisions"
    echo "az containerapp revision list --name $APP_NAME --resource-group $RESOURCE_GROUP"
    echo ""
    echo "# Update container image"
    echo "az containerapp update --name $APP_NAME --resource-group $RESOURCE_GROUP --image <new-image>"
    echo ""
    echo "# Scale manually"
    echo "az containerapp update --name $APP_NAME --resource-group $RESOURCE_GROUP --min-replicas 2 --max-replicas 20"
    echo "==============================================================================="
}

#-------------------------------------------------------------------------------
# MAIN
#-------------------------------------------------------------------------------
main() {
    log_info "Starting Container Apps deployment..."

    setup_cli_extension
    create_resource_group
    create_log_analytics
    create_container_apps_environment
    create_container_app
    configure_scaling
    create_managed_identity
    create_backend_app
    display_summary

    log_success "Container Apps deployment completed successfully!"
}

main "$@"
