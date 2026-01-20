#!/bin/bash
#===============================================================================
# SCRIPT: deploy-apim.sh
# SYNOPSIS: Deploy Azure API Management with sample API
# DESCRIPTION:
#   This script creates an Azure API Management instance with:
#   - Developer tier APIM instance (for demo purposes)
#   - Sample API imported from OpenAPI specification
#   - API policies (rate limiting, transformation)
#   - Products and subscriptions
#   - Application Insights integration
#
# AZ-305 EXAM OBJECTIVES:
#   - Design application architecture: API gateway patterns
#   - Implement API versioning and revision strategies
#   - Configure rate limiting and throttling
#   - Secure APIs with policies and authentication
#   - Monitor API usage with Application Insights
#
# PREREQUISITES:
#   - Azure CLI 2.50+ installed and authenticated
#   - Subscription with API Management Contributor permissions
#   - APIM deployment takes 30-45 minutes for Developer tier
#
# EXAMPLES:
#   # Deploy with default settings (Developer tier)
#   ./deploy-apim.sh
#
#   # Deploy with specific SKU
#   APIM_SKU="Consumption" ./deploy-apim.sh
#
# REFERENCES:
#   - https://learn.microsoft.com/azure/api-management/import-and-publish
#   - https://learn.microsoft.com/azure/api-management/api-management-policies
#===============================================================================

set -euo pipefail

#-------------------------------------------------------------------------------
# CONFIGURATION
#-------------------------------------------------------------------------------
LOCATION="${LOCATION:-eastus}"
PREFIX="${PREFIX:-az305}"
RESOURCE_GROUP="${RESOURCE_GROUP:-${PREFIX}-apim-rg}"
APIM_NAME="${APIM_NAME:-${PREFIX}-apim-$(openssl rand -hex 4)}"

# APIM SKU: Developer, Basic, Standard, Premium, Consumption
# Developer is cheapest for learning (takes ~30 min to deploy)
# Consumption is serverless and deploys faster
APIM_SKU="${APIM_SKU:-Developer}"

# Publisher info (required)
PUBLISHER_EMAIL="${PUBLISHER_EMAIL:-admin@contoso.com}"
PUBLISHER_NAME="${PUBLISHER_NAME:-Contoso API Team}"

# Application Insights for monitoring
APP_INSIGHTS_NAME="${PREFIX}-apim-ai"

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
        --location "$LOCATION" \
        --tags "Environment=Development" "Purpose=AZ305-APIM" \
        --output none

    log_success "Resource group created: $RESOURCE_GROUP"
}

#-------------------------------------------------------------------------------
# CREATE APPLICATION INSIGHTS
#-------------------------------------------------------------------------------
create_application_insights() {
    log_info "Creating Application Insights..."

    # WHY: Application Insights provides:
    # - Request metrics and logging
    # - Dependency tracking
    # - Custom metrics and events
    # - Integration with Azure Monitor

    az monitor app-insights component create \
        --app "$APP_INSIGHTS_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --application-type web \
        --output none

    APP_INSIGHTS_KEY=$(az monitor app-insights component show \
        --app "$APP_INSIGHTS_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query instrumentationKey \
        --output tsv)

    APP_INSIGHTS_ID=$(az monitor app-insights component show \
        --app "$APP_INSIGHTS_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query id \
        --output tsv)

    log_success "Application Insights created: $APP_INSIGHTS_NAME"
}

#-------------------------------------------------------------------------------
# CREATE API MANAGEMENT INSTANCE
#-------------------------------------------------------------------------------
create_apim_instance() {
    log_info "Creating API Management instance (this may take 30-45 minutes for Developer tier)..."

    # WHY: APIM provides:
    # - Unified API gateway for backend services
    # - Policy engine for transformation, security, throttling
    # - Developer portal for API documentation
    # - Analytics and monitoring

    if [ "$APIM_SKU" == "Consumption" ]; then
        # Consumption tier deploys faster
        az apim create \
            --name "$APIM_NAME" \
            --resource-group "$RESOURCE_GROUP" \
            --location "$LOCATION" \
            --publisher-email "$PUBLISHER_EMAIL" \
            --publisher-name "$PUBLISHER_NAME" \
            --sku-name "$APIM_SKU" \
            --output none
    else
        # Developer/Basic/Standard/Premium tiers
        az apim create \
            --name "$APIM_NAME" \
            --resource-group "$RESOURCE_GROUP" \
            --location "$LOCATION" \
            --publisher-email "$PUBLISHER_EMAIL" \
            --publisher-name "$PUBLISHER_NAME" \
            --sku-name "$APIM_SKU" \
            --sku-capacity 1 \
            --output none
    fi

    # Wait for APIM to be ready
    log_info "Waiting for APIM provisioning to complete..."
    while true; do
        state=$(az apim show \
            --name "$APIM_NAME" \
            --resource-group "$RESOURCE_GROUP" \
            --query "provisioningState" \
            --output tsv 2>/dev/null || echo "Creating")

        if [ "$state" == "Succeeded" ]; then
            break
        fi
        log_info "Current state: $state. Waiting..."
        sleep 60
    done

    log_success "API Management instance created: $APIM_NAME"
}

#-------------------------------------------------------------------------------
# CONFIGURE APIM LOGGER (Application Insights)
#-------------------------------------------------------------------------------
configure_logger() {
    log_info "Configuring Application Insights logger..."

    # WHY: Logger enables request/response logging to Application Insights
    # This provides visibility into API usage and performance

    az apim logger create \
        --name "appinsights-logger" \
        --resource-group "$RESOURCE_GROUP" \
        --service-name "$APIM_NAME" \
        --logger-type applicationInsights \
        --credentials "instrumentationKey=$APP_INSIGHTS_KEY" \
        --description "Application Insights logger for API diagnostics" \
        --output none 2>/dev/null || log_info "Logger may already exist"

    log_success "Application Insights logger configured"
}

#-------------------------------------------------------------------------------
# IMPORT SAMPLE API
#-------------------------------------------------------------------------------
import_sample_api() {
    log_info "Importing sample API from OpenAPI specification..."

    # WHY: Importing from OpenAPI spec automatically creates:
    # - API operations
    # - Request/response schemas
    # - Documentation

    # Using Petstore API as a sample (publicly available OpenAPI spec)
    PETSTORE_URL="https://petstore3.swagger.io/api/v3/openapi.json"

    az apim api import \
        --api-id "petstore-api" \
        --resource-group "$RESOURCE_GROUP" \
        --service-name "$APIM_NAME" \
        --path "petstore" \
        --display-name "Petstore API" \
        --specification-format OpenApi \
        --specification-url "$PETSTORE_URL" \
        --subscription-required true \
        --output none 2>/dev/null || log_info "API may already exist"

    log_success "Petstore API imported"
}

#-------------------------------------------------------------------------------
# CREATE CUSTOM API
#-------------------------------------------------------------------------------
create_custom_api() {
    log_info "Creating custom Echo API..."

    # WHY: Custom API demonstrates manual API creation and policy configuration

    # Create API
    az apim api create \
        --api-id "echo-api" \
        --resource-group "$RESOURCE_GROUP" \
        --service-name "$APIM_NAME" \
        --display-name "Echo API" \
        --path "echo" \
        --protocols https \
        --service-url "https://httpbin.org" \
        --subscription-required true \
        --output none 2>/dev/null || log_info "Echo API may already exist"

    # Create operation
    az apim api operation create \
        --api-id "echo-api" \
        --resource-group "$RESOURCE_GROUP" \
        --service-name "$APIM_NAME" \
        --operation-id "get-echo" \
        --display-name "Get Echo" \
        --method GET \
        --url-template "/get" \
        --description "Returns request headers and parameters" \
        --output none 2>/dev/null || log_info "Operation may already exist"

    log_success "Custom Echo API created"
}

#-------------------------------------------------------------------------------
# CREATE PRODUCTS
#-------------------------------------------------------------------------------
create_products() {
    log_info "Creating API products..."

    # WHY: Products bundle APIs together for subscription management
    # Different products can have different access levels and rate limits

    # Create Starter product (with rate limiting)
    az apim product create \
        --product-id "starter" \
        --resource-group "$RESOURCE_GROUP" \
        --service-name "$APIM_NAME" \
        --product-name "Starter" \
        --description "Free tier with limited requests" \
        --state published \
        --subscription-required true \
        --approval-required false \
        --subscriptions-limit 1 \
        --output none 2>/dev/null || log_info "Starter product may already exist"

    # Create Unlimited product
    az apim product create \
        --product-id "unlimited" \
        --resource-group "$RESOURCE_GROUP" \
        --service-name "$APIM_NAME" \
        --product-name "Unlimited" \
        --description "Unlimited access for premium subscribers" \
        --state published \
        --subscription-required true \
        --approval-required true \
        --output none 2>/dev/null || log_info "Unlimited product may already exist"

    # Add APIs to products
    az apim product api add \
        --product-id "starter" \
        --api-id "echo-api" \
        --resource-group "$RESOURCE_GROUP" \
        --service-name "$APIM_NAME" \
        --output none 2>/dev/null || true

    az apim product api add \
        --product-id "unlimited" \
        --api-id "echo-api" \
        --resource-group "$RESOURCE_GROUP" \
        --service-name "$APIM_NAME" \
        --output none 2>/dev/null || true

    log_success "Products created"
}

#-------------------------------------------------------------------------------
# CONFIGURE API POLICIES
#-------------------------------------------------------------------------------
configure_policies() {
    log_info "Configuring API policies..."

    # WHY: Policies enable:
    # - Rate limiting and throttling
    # - Request/response transformation
    # - Authentication and authorization
    # - Caching
    # - CORS

    # Create policy for Echo API with rate limiting
    # Rate limit: 5 calls per 60 seconds for demonstration
    cat > /tmp/echo-api-policy.xml << 'EOF'
<policies>
    <inbound>
        <base />
        <!-- Rate limiting - 5 calls per minute per subscription -->
        <rate-limit-by-key
            calls="5"
            renewal-period="60"
            counter-key="@(context.Subscription?.Key ?? "anonymous")"
            increment-condition="@(context.Response.StatusCode >= 200 && context.Response.StatusCode < 400)" />
        <!-- Add correlation ID for tracing -->
        <set-header name="X-Correlation-ID" exists-action="skip">
            <value>@(context.RequestId.ToString())</value>
        </set-header>
        <!-- Log to Application Insights -->
        <trace source="Echo API" severity="information">
            <message>@($"Incoming request to {context.Request.Url.Path}")</message>
        </trace>
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
        <!-- Remove backend headers -->
        <set-header name="X-Powered-By" exists-action="delete" />
        <!-- Add APIM headers -->
        <set-header name="X-Request-ID" exists-action="override">
            <value>@(context.RequestId.ToString())</value>
        </set-header>
    </outbound>
    <on-error>
        <base />
        <!-- Log errors -->
        <trace source="Echo API" severity="error">
            <message>@($"Error: {context.LastError?.Message}")</message>
        </trace>
    </on-error>
</policies>
EOF

    az apim api policy create \
        --api-id "echo-api" \
        --resource-group "$RESOURCE_GROUP" \
        --service-name "$APIM_NAME" \
        --xml-content @/tmp/echo-api-policy.xml \
        --output none 2>/dev/null || log_info "Policy may already exist"

    log_success "API policies configured"
}

#-------------------------------------------------------------------------------
# CREATE SUBSCRIPTION
#-------------------------------------------------------------------------------
create_subscription() {
    log_info "Creating test subscription..."

    # WHY: Subscriptions provide API keys for authentication
    # Different subscriptions can have different products/access levels

    az apim subscription create \
        --resource-group "$RESOURCE_GROUP" \
        --service-name "$APIM_NAME" \
        --subscription-id "test-subscription" \
        --display-name "Test Subscription" \
        --scope "/products/starter" \
        --state active \
        --output none 2>/dev/null || log_info "Subscription may already exist"

    # Get subscription key
    SUBSCRIPTION_KEY=$(az apim subscription show \
        --resource-group "$RESOURCE_GROUP" \
        --service-name "$APIM_NAME" \
        --subscription-id "test-subscription" \
        --query "primaryKey" \
        --output tsv 2>/dev/null || echo "")

    log_success "Test subscription created"
}

#-------------------------------------------------------------------------------
# DISPLAY SUMMARY
#-------------------------------------------------------------------------------
display_summary() {
    echo ""
    echo "==============================================================================="
    echo "                    API MANAGEMENT DEPLOYMENT SUMMARY"
    echo "==============================================================================="
    echo ""
    echo "Resource Group: $RESOURCE_GROUP"
    echo "Location: $LOCATION"
    echo ""
    echo "API MANAGEMENT INSTANCE:"
    echo "-------------------------------------------------------------------------------"
    echo "Name: $APIM_NAME"
    echo "SKU: $APIM_SKU"
    echo "Publisher: $PUBLISHER_NAME ($PUBLISHER_EMAIL)"
    echo ""

    # Get APIM endpoints
    APIM_GATEWAY=$(az apim show \
        --name "$APIM_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query "gatewayUrl" \
        --output tsv 2>/dev/null || echo "")

    APIM_PORTAL=$(az apim show \
        --name "$APIM_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query "developerPortalUrl" \
        --output tsv 2>/dev/null || echo "")

    APIM_MGMT=$(az apim show \
        --name "$APIM_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query "managementApiUrl" \
        --output tsv 2>/dev/null || echo "")

    echo "ENDPOINTS:"
    echo "-------------------------------------------------------------------------------"
    echo "Gateway URL: $APIM_GATEWAY"
    echo "Developer Portal: $APIM_PORTAL"
    echo "Management API: $APIM_MGMT"
    echo ""

    echo "APIS:"
    echo "-------------------------------------------------------------------------------"
    az apim api list \
        --resource-group "$RESOURCE_GROUP" \
        --service-name "$APIM_NAME" \
        --query "[].{Name:displayName, Path:path, Protocols:protocols}" \
        --output table 2>/dev/null || echo "(APIs not yet available)"
    echo ""

    echo "PRODUCTS:"
    echo "-------------------------------------------------------------------------------"
    az apim product list \
        --resource-group "$RESOURCE_GROUP" \
        --service-name "$APIM_NAME" \
        --query "[].{Name:displayName, State:state, ApprovalRequired:approvalRequired}" \
        --output table 2>/dev/null || echo "(Products not yet available)"
    echo ""

    echo "TEST SUBSCRIPTION:"
    echo "-------------------------------------------------------------------------------"
    if [ -n "$SUBSCRIPTION_KEY" ]; then
        echo "Subscription Key: $SUBSCRIPTION_KEY"
    else
        echo "Subscription key not available"
    fi
    echo ""

    echo "==============================================================================="
    echo "TEST THE API:"
    echo "==============================================================================="
    echo ""
    echo "# Test Echo API (replace <subscription-key> with actual key)"
    if [ -n "$APIM_GATEWAY" ] && [ -n "$SUBSCRIPTION_KEY" ]; then
        echo "curl -X GET \"${APIM_GATEWAY}/echo/get\" \\"
        echo "  -H \"Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY\""
    fi
    echo ""
    echo "==============================================================================="
    echo "API MANAGEMENT KEY CONCEPTS (AZ-305 Exam Context):"
    echo "==============================================================================="
    echo ""
    echo "TIERS (SKUs):"
    echo "  Consumption: Serverless, pay-per-call, no SLA"
    echo "  Developer: For dev/test, single region"
    echo "  Basic: Production-ready, 2 scale units"
    echo "  Standard: Multi-region, higher limits"
    echo "  Premium: VNet integration, multi-region"
    echo ""
    echo "KEY POLICIES:"
    echo "  rate-limit-by-key: Limit calls per time period"
    echo "  quota-by-key: Monthly/yearly call quotas"
    echo "  validate-jwt: JWT token validation"
    echo "  cache-lookup/store: Response caching"
    echo "  rewrite-uri: URL transformation"
    echo "  set-backend-service: Route to different backends"
    echo ""
    echo "VERSIONING STRATEGIES:"
    echo "  Path-based: /v1/api, /v2/api"
    echo "  Query string: /api?version=1"
    echo "  Header: Api-Version: 1"
    echo ""
    echo "==============================================================================="
}

#-------------------------------------------------------------------------------
# MAIN
#-------------------------------------------------------------------------------
main() {
    log_info "Starting API Management deployment..."
    log_warning "Note: Developer tier deployment takes 30-45 minutes"
    log_warning "For faster deployment, use: APIM_SKU=Consumption $0"

    create_resource_group
    create_application_insights
    create_apim_instance
    configure_logger
    import_sample_api
    create_custom_api
    create_products
    configure_policies
    create_subscription
    display_summary

    log_success "API Management deployment completed successfully!"
}

main "$@"
