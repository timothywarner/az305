// ============================================================================
// Azure API Management with Backend Services and Comprehensive Policies
// ============================================================================
// Purpose: Deploy API Management with backend configuration and exam-relevant
//          policies covering rate limiting, JWT validation, caching, CORS,
//          IP filtering, mock responses, and header transformations.
//
// AZ-305 Exam Objectives:
//   - Design an application architecture (Objective 4.3)
//   - Design authentication and authorization solutions (Objective 1.1)
//   - Design a solution for network connectivity (Objective 4.2)
//   - Recommend a solution for API integration (Objective 4.3)
//
// Teaching Notes:
//   APIM policies execute in four pipeline stages: inbound, backend, outbound,
//   on-error. The AZ-305 exam tests your ability to SELECT the right policy
//   for a given business requirement -- not memorize XML syntax.
//
//   Key exam scenarios this template demonstrates:
//   1. Throttling (rate-limit-by-key) vs Quotas (quota-by-key) -- when to use each
//   2. JWT validation with Microsoft Entra ID -- Zero Trust pattern
//   3. Response caching -- Performance Efficiency pillar
//   4. IP filtering -- Network security layer in defense-in-depth
//   5. CORS -- SPA frontend calling backend APIs
//   6. Mock responses -- Health endpoints without backend dependency
//   7. Header transforms -- Security hardening and distributed tracing
//
// Prerequisites:
//   - Resource group must exist
//   - Virtual network for internal APIM (optional)
//   - Application Insights for monitoring (optional)
//   - Microsoft Entra ID tenant for JWT validation (optional)
// ============================================================================

targetScope = 'resourceGroup'

// ============================================================================
// Parameters
// ============================================================================

@description('Name of the API Management service.')
@minLength(1)
@maxLength(50)
param apimName string

@description('Azure region for the service.')
param location string = resourceGroup().location

@description('Publisher email address.')
param publisherEmail string

@description('Publisher organization name.')
param publisherName string

@description('API Management SKU.')
@allowed([
  'Consumption'
  'Developer'
  'Basic'
  'Standard'
  'Premium'
])
param sku string = 'Developer'

@description('Number of scale units (only for non-Consumption SKUs).')
@minValue(1)
@maxValue(12)
param skuCount int = 1

@description('Enable virtual network integration.')
@allowed([
  'None'
  'External'
  'Internal'
])
param virtualNetworkType string = 'None'

@description('Virtual network resource ID (required for VNet integration).')
param vnetId string = ''

@description('Subnet name for APIM (required for VNet integration).')
param apimSubnetName string = 'ApiManagement'

@description('Enable availability zones (Premium SKU only).')
param enableAvailabilityZones bool = false

@description('Application Insights resource ID.')
param applicationInsightsId string = ''

@description('Application Insights instrumentation key.')
@secure()
param applicationInsightsKey string = ''

@description('Enable system-assigned managed identity.')
param enableManagedIdentity bool = true

@description('Deploy sample API with comprehensive policies.')
param deploySampleApi bool = false

@description('Backend API URL for sample API.')
param sampleApiBackendUrl string = 'https://httpbin.org'

// ---------------------------------------------------------------------------
// Policy Parameters
// ---------------------------------------------------------------------------
// AZ-305 Teaching Point: Parameterizing policy values allows environment-
// specific configurations (dev vs prod). This aligns with the Operational
// Excellence pillar -- externalize configuration from code.
// ---------------------------------------------------------------------------

@description('Microsoft Entra ID tenant ID for JWT validation.')
param entraIdTenantId string = ''

@description('Microsoft Entra ID application (client) ID representing the API audience.')
param entraIdAudienceAppId string = ''

@description('Allowed IP address ranges for IP filtering. Each entry needs "from" and "to" properties defining the range start and end.')
param allowedIpRanges array = [
  {
    from: '10.0.0.0'
    to: '10.255.255.255'
  }
  {
    from: '172.16.0.0'
    to: '172.31.255.255'
  }
  {
    from: '192.168.0.0'
    to: '192.168.255.255'
  }
]

@description('Allowed CORS origins for cross-origin requests from SPA frontends.')
param allowedCorsOrigins array = [
  'https://portal.contoso.com'
  'https://app.contoso.com'
]

@description('Rate limit: max calls per renewal period per subscription key.')
param rateLimitCalls int = 50

@description('Rate limit: renewal period in seconds.')
param rateLimitPeriodSeconds int = 60

@description('Rate limit for anonymous (IP-based) access: max calls per renewal period.')
param rateLimitAnonymousCalls int = 20

@description('Rate limit for anonymous (IP-based) access: renewal period in seconds.')
param rateLimitAnonymousPeriodSeconds int = 60

@description('Daily quota: max calls per subscription per day.')
param quotaDailyCalls int = 1000

@description('Daily quota: max bandwidth in KB per subscription per day.')
param quotaDailyBandwidthKB int = 51200

@description('Cache duration in seconds for GET responses.')
param cacheDurationSeconds int = 300

@description('Tags to apply to resources.')
param tags object = {
  environment: 'production'
  purpose: 'api-management'
  examObjective: 'AZ-305-Application'
}

// ============================================================================
// Variables
// ============================================================================

var apimServiceName = 'apim-${apimName}-${uniqueString(resourceGroup().id)}'
var zones = enableAvailabilityZones && sku == 'Premium' ? ['1', '2', '3'] : []

// Build the Microsoft Entra ID OpenID configuration URL.
// AZ-305 Teaching Point: Microsoft Entra ID (formerly Azure AD) exposes a
// well-known OpenID Connect metadata endpoint. APIM uses this to download
// signing keys automatically -- no manual key rotation needed.
var entraIdOpenIdConfigUrl = !empty(entraIdTenantId)
  ? 'https://login.microsoftonline.com/${entraIdTenantId}/v2.0/.well-known/openid-configuration'
  : ''

// Build comma-separated allowed origins for the CORS policy XML.
var corsOriginsXml = join(map(allowedCorsOrigins, origin => '<origin>${origin}</origin>'), '\n              ')

// Build IP filter allow-list entries for the ip-filter policy XML.
// APIM ip-filter uses <address> for single IPs and <address-range from="x" to="y" /> for ranges.
var ipFilterXml = join(map(allowedIpRanges, range => '<address-range from="${range.from}" to="${range.to}" />'), '\n      ')

// ============================================================================
// Resources - API Management Service
// ============================================================================

@description('API Management service')
resource apiManagement 'Microsoft.ApiManagement/service@2023-05-01-preview' = {
  name: apimServiceName
  location: location
  tags: tags
  sku: {
    name: sku
    capacity: sku == 'Consumption' ? 0 : skuCount
  }
  identity: enableManagedIdentity ? {
    type: 'SystemAssigned'
  } : null
  zones: zones
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
    virtualNetworkType: virtualNetworkType
    virtualNetworkConfiguration: virtualNetworkType != 'None' && !empty(vnetId) ? {
      subnetResourceId: '${vnetId}/subnets/${apimSubnetName}'
    } : null
    customProperties: {
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls10': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls11': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Ssl30': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls10': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls11': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Ssl30': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TripleDes168': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Protocols.Server.Http2': 'True'
    }
    apiVersionConstraint: {
      minApiVersion: '2021-08-01'
    }
  }
}

// ============================================================================
// Resources - Application Insights Logger
// ============================================================================

@description('Application Insights logger')
resource apimLogger 'Microsoft.ApiManagement/service/loggers@2023-05-01-preview' = if (!empty(applicationInsightsId)) {
  parent: apiManagement
  name: 'applicationinsights'
  properties: {
    loggerType: 'applicationInsights'
    resourceId: applicationInsightsId
    credentials: {
      instrumentationKey: applicationInsightsKey
    }
  }
}

// ============================================================================
// Resources - Diagnostic Settings
// ============================================================================

@description('API diagnostic settings for Application Insights')
resource apiDiagnostics 'Microsoft.ApiManagement/service/diagnostics@2023-05-01-preview' = if (!empty(applicationInsightsId)) {
  parent: apiManagement
  name: 'applicationinsights'
  properties: {
    alwaysLog: 'allErrors'
    loggerId: apimLogger.id
    sampling: {
      percentage: 100
      samplingType: 'fixed'
    }
    frontend: {
      request: {
        headers: []
        body: {
          bytes: 0
        }
      }
      response: {
        headers: []
        body: {
          bytes: 0
        }
      }
    }
    backend: {
      request: {
        headers: []
        body: {
          bytes: 0
        }
      }
      response: {
        headers: []
        body: {
          bytes: 0
        }
      }
    }
    logClientIp: true
    httpCorrelationProtocol: 'W3C'
    verbosity: 'information'
  }
}

// ============================================================================
// Resources - Named Values (Configuration)
// ============================================================================

@description('Named value for backend URL')
resource backendUrlNamedValue 'Microsoft.ApiManagement/service/namedValues@2023-05-01-preview' = if (deploySampleApi) {
  parent: apiManagement
  name: 'backend-url'
  properties: {
    displayName: 'backend-url'
    value: sampleApiBackendUrl
    secret: false
  }
}

// ============================================================================
// Resources - Backend Service
// ============================================================================

@description('Backend service configuration')
resource backend 'Microsoft.ApiManagement/service/backends@2023-05-01-preview' = if (deploySampleApi) {
  parent: apiManagement
  name: 'httpbin-backend'
  properties: {
    url: sampleApiBackendUrl
    protocol: 'http'
    title: 'HTTPBin Backend'
    description: 'Sample backend service for testing'
    tls: {
      validateCertificateChain: true
      validateCertificateName: true
    }
    circuitBreaker: {
      rules: [
        {
          name: 'default-circuit-breaker'
          failureCondition: {
            count: 5
            interval: 'PT1M'
            statusCodeRanges: [
              {
                min: 500
                max: 599
              }
            ]
          }
          tripDuration: 'PT1M'
        }
      ]
    }
  }
}

// ============================================================================
// Resources - Sample API
// ============================================================================

@description('Sample API with comprehensive policy demonstrations')
resource sampleApi 'Microsoft.ApiManagement/service/apis@2023-05-01-preview' = if (deploySampleApi) {
  parent: apiManagement
  name: 'sample-api'
  properties: {
    displayName: 'Sample API'
    description: 'Sample API demonstrating APIM policies for AZ-305 exam preparation'
    subscriptionRequired: true
    serviceUrl: sampleApiBackendUrl
    path: 'sample'
    protocols: [
      'https'
    ]
    apiVersion: 'v1'
    apiVersionSetId: null
    isCurrent: true
  }
}

@description('Sample API GET operation')
resource sampleApiGetOperation 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = if (deploySampleApi) {
  parent: sampleApi
  name: 'get-data'
  properties: {
    displayName: 'Get Data'
    method: 'GET'
    urlTemplate: '/get'
    description: 'Returns GET data -- demonstrates caching and JWT validation'
    responses: [
      {
        statusCode: 200
        description: 'Success'
      }
    ]
  }
}

// ============================================================================
// Resources - Health Check Endpoint (Mock Response)
// ============================================================================
// AZ-305 Teaching Point: Health endpoints are critical for load balancers
// (Azure Front Door, Application Gateway) to determine backend availability.
// A mock-response policy returns a response directly from APIM without
// hitting the backend -- zero latency, zero backend dependency. This is the
// recommended pattern for health probes.
// ============================================================================

@description('Health check operation returning mock 200 response')
resource healthOperation 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = if (deploySampleApi) {
  parent: sampleApi
  name: 'health-check'
  properties: {
    displayName: 'Health Check'
    method: 'GET'
    urlTemplate: '/health'
    description: 'Health probe endpoint -- returns mock 200 without calling backend'
    responses: [
      {
        statusCode: 200
        description: 'Service is healthy'
        representations: [
          {
            contentType: 'application/json'
            examples: {
              default: {
                value: '{"status":"healthy","service":"apim","timestamp":"2026-01-30T00:00:00Z"}'
              }
            }
          }
        ]
      }
    ]
  }
}

// ============================================================================
// Resources - Health Check Operation Policy (Mock Response)
// ============================================================================
// AZ-305 Teaching Point: Operation-level policies override API-level policies.
// The mock-response policy short-circuits the pipeline -- no backend call.
// This is commonly tested in exam scenarios asking about health probes for
// Application Gateway or Azure Front Door integration with APIM.
// ============================================================================

@description('Mock response policy for health endpoint')
resource healthOperationPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2023-05-01-preview' = if (deploySampleApi) {
  parent: healthOperation
  name: 'policy'
  properties: {
    value: '<policies>\n  <inbound>\n    <base />\n    <!-- ================================================================= -->\n    <!-- POLICY 7: Mock Response                                           -->\n    <!-- ================================================================= -->\n    <!-- AZ-305 Exam Relevance: mock-response returns a canned response    -->\n    <!-- without forwarding to the backend. Use cases:                      -->\n    <!--   1. Health probes for load balancers                             -->\n    <!--   2. API prototyping before backend is ready                      -->\n    <!--   3. Circuit breaker fallback responses                           -->\n    <!--                                                                   -->\n    <!-- status-code and content-type define the response shape.           -->\n    <!-- The response body can be defined inline or reference the          -->\n    <!-- operation response schema.                                        -->\n    <!-- ================================================================= -->\n    <mock-response status-code="200" content-type="application/json" />\n  </inbound>\n  <backend>\n    <!-- mock-response short-circuits here -- backend is never called -->\n    <base />\n  </backend>\n  <outbound>\n    <base />\n    <!-- Override the mock body with a dynamic timestamp -->\n    <set-body>@{\n      return new JObject(\n        new JProperty("status", "healthy"),\n        new JProperty("service", "apim"),\n        new JProperty("timestamp", DateTime.UtcNow.ToString("o"))\n      ).ToString();\n    }</set-body>\n  </outbound>\n  <on-error>\n    <base />\n  </on-error>\n</policies>'
    format: 'xml'
  }
}

// ============================================================================
// Resources - API-Level Policy (JWT, Caching, IP Filtering)
// ============================================================================
// AZ-305 Teaching Point: API-level policies apply to ALL operations within
// a single API. This is the right scope for authentication (JWT validation),
// caching, and IP filtering that should protect every endpoint in this API
// but NOT necessarily every API in the APIM instance.
//
// Policy inheritance: Global -> Product -> API -> Operation
// The <base /> element controls where parent policies are injected.
// Placing <base /> FIRST means parent policies run before API-level policies.
// ============================================================================

@description('API-level policy with JWT validation, caching, and IP filtering')
resource sampleApiPolicy 'Microsoft.ApiManagement/service/apis/policies@2023-05-01-preview' = if (deploySampleApi) {
  parent: sampleApi
  name: 'policy'
  properties: {
    value: '<policies>\n  <inbound>\n    <!-- Inherit global policies first (CORS, rate limiting, correlation ID) -->\n    <base />\n\n    <!-- ================================================================= -->\n    <!-- POLICY 3 (API-level): IP Filtering (ip-filter)                    -->\n    <!-- ================================================================= -->\n    <!-- AZ-305 Exam Relevance: IP filtering is a network security layer   -->\n    <!-- in the defense-in-depth model. The exam tests whether you know    -->\n    <!-- the difference between:                                           -->\n    <!--   - NSG rules (layer 4, subnet/NIC level)                        -->\n    <!--   - APIM ip-filter (layer 7, per-API granularity)                -->\n    <!--   - Azure Firewall (centralized, cross-service)                  -->\n    <!--                                                                   -->\n    <!-- action="allow" = allow-list (deny all except listed)              -->\n    <!-- action="forbid" = deny-list (allow all except listed)             -->\n    <!--                                                                   -->\n    <!-- Real-World: Use allow-list for internal APIs that should only be  -->\n    <!-- called from your VNet or known partner IPs. Combine with Private  -->\n    <!-- Endpoints for strongest network isolation.                        -->\n    <!-- ================================================================= -->\n    <ip-filter action="allow">\n      ${ipFilterXml}\n    </ip-filter>\n\n    <!-- ================================================================= -->\n    <!-- POLICY 4 (API-level): JWT Validation (validate-jwt)               -->\n    <!-- ================================================================= -->\n    <!-- AZ-305 Exam Relevance: This is the MOST TESTED APIM policy on    -->\n    <!-- AZ-305. The exam presents scenarios where you must secure an API  -->\n    <!-- with Microsoft Entra ID and asks which policy to use.             -->\n    <!--                                                                   -->\n    <!-- Key concepts the exam tests:                                      -->\n    <!--   - header-name="Authorization" extracts the Bearer token         -->\n    <!--   - openid-config auto-discovers signing keys (no manual rotation)-->\n    <!--   - required-claims enforces audience (aud) and custom claims     -->\n    <!--   - failed-validation-httpcode returns 401 (not 403)              -->\n    <!--   - clock-skew accounts for time drift between token issuer and   -->\n    <!--     APIM (300 seconds = 5 minutes is standard)                    -->\n    <!--                                                                   -->\n    <!-- Real-World: Always validate JWT at the gateway level (APIM)      -->\n    <!-- AND at the backend. This is the Zero Trust principle: never trust -->\n    <!-- never trust, always verify -- even internal traffic.              -->\n    <!-- ================================================================= -->\n    ${!empty(entraIdTenantId) ? '<validate-jwt header-name="Authorization" failed-validation-httpcode="401" failed-validation-error-message="Unauthorized. Access token is missing or invalid." require-expiration-time="true" require-signed-tokens="true" clock-skew="300">\n      <openid-config url="${entraIdOpenIdConfigUrl}" />\n      <audiences>\n        <audience>${entraIdAudienceAppId}</audience>\n      </audiences>\n      <issuers>\n        <issuer>https://login.microsoftonline.com/${entraIdTenantId}/v2.0</issuer>\n        <issuer>https://sts.windows.net/${entraIdTenantId}/</issuer>\n      </issuers>\n      <required-claims>\n        <claim name="aud" match="any">\n          <value>${entraIdAudienceAppId}</value>\n        </claim>\n      </required-claims>\n    </validate-jwt>' : '<!-- JWT validation disabled: entraIdTenantId parameter not set -->'}\n\n    <!-- ================================================================= -->\n    <!-- POLICY 5 (API-level): Response Caching - Lookup Phase             -->\n    <!-- ================================================================= -->\n    <!-- AZ-305 Exam Relevance: Caching is a Performance Efficiency        -->\n    <!-- pillar concern. The exam tests when to use:                        -->\n    <!--   - APIM internal cache (built-in, limited by SKU memory)        -->\n    <!--   - Azure Cache for Redis (external, shared across instances)     -->\n    <!--                                                                   -->\n    <!-- cache-lookup runs in inbound; cache-store runs in outbound.       -->\n    <!-- They work as a pair. If a cache hit occurs, the pipeline          -->\n    <!-- short-circuits and returns the cached response immediately --     -->\n    <!-- no backend call.                                                  -->\n    <!--                                                                   -->\n    <!-- vary-by-query-string="*" means different query params = different -->\n    <!-- cache entries. vary-by-header on Authorization means each user    -->\n    <!-- gets their own cached response (important for personalized data). -->\n    <!-- ================================================================= -->\n    <cache-lookup vary-by-developer="false" vary-by-developer-groups="false" downstream-caching-type="none">\n      <vary-by-query-string>*</vary-by-query-string>\n      <vary-by-header>Authorization</vary-by-header>\n      <vary-by-header>Accept</vary-by-header>\n    </cache-lookup>\n  </inbound>\n\n  <backend>\n    <base />\n  </backend>\n\n  <outbound>\n    <base />\n\n    <!-- ================================================================= -->\n    <!-- POLICY 5 (API-level): Response Caching - Store Phase              -->\n    <!-- ================================================================= -->\n    <!-- AZ-305 Exam Relevance: cache-store duration controls how long     -->\n    <!-- responses are cached. Balance between freshness (low duration)    -->\n    <!-- and performance (high duration). 300 seconds (5 minutes) is a    -->\n    <!-- common default for read-heavy APIs.                               -->\n    <!--                                                                   -->\n    <!-- Real-World: Only cache GET requests. Never cache POST/PUT/DELETE -->\n    <!-- as these are state-changing operations.                           -->\n    <!-- ================================================================= -->\n    <cache-store duration="${cacheDurationSeconds}" />\n  </outbound>\n\n  <on-error>\n    <base />\n  </on-error>\n</policies>'
    format: 'xml'
  }
}

// ============================================================================
// Resources - Global Policy (All APIs)
// ============================================================================
// AZ-305 Teaching Point: Global policies apply to EVERY API in the APIM
// instance. Use global scope for cross-cutting concerns like security
// headers, correlation IDs, and basic rate limiting. API-level and
// operation-level policies inherit from global via the <base /> element.
//
// Policy execution order: Global -> Product -> API -> Operation
// Each scope can override or extend parent policies.
// ============================================================================

@description('Global API policy with rate limiting, security headers, CORS, and correlation ID')
resource globalPolicy 'Microsoft.ApiManagement/service/policies@2023-05-01-preview' = {
  parent: apiManagement
  name: 'policy'
  properties: {
    // -----------------------------------------------------------------------
    // IMPORTANT: We use string interpolation to inject parameter values into
    // the policy XML. This keeps policies configurable per environment.
    // -----------------------------------------------------------------------
    value: '<policies>\n  <inbound>\n    <!-- ================================================================= -->\n    <!-- POLICY 1: CORS (Cross-Origin Resource Sharing)                    -->\n    <!-- ================================================================= -->\n    <!-- AZ-305 Exam Relevance: When designing SPA + API architectures,    -->\n    <!-- you MUST configure CORS at the API gateway level. The exam tests  -->\n    <!-- whether you understand that CORS is enforced by browsers, not     -->\n    <!-- servers -- APIM sends the correct headers so browsers allow the   -->\n    <!-- cross-origin request.                                             -->\n    <!--                                                                   -->\n    <!-- Real-World: Never use origin="*" in production. Always specify    -->\n    <!-- exact origins to prevent unauthorized sites from calling your API. -->\n    <!-- preflight-result-max-age caches OPTIONS responses in the browser  -->\n    <!-- reducing round-trips for subsequent requests.                     -->\n    <!-- ================================================================= -->\n    <cors allow-credentials="true">\n      <allowed-origins>\n        ${corsOriginsXml}\n      </allowed-origins>\n      <allowed-methods preflight-result-max-age="600">\n        <method>GET</method>\n        <method>POST</method>\n        <method>PUT</method>\n        <method>DELETE</method>\n        <method>PATCH</method>\n        <method>OPTIONS</method>\n      </allowed-methods>\n      <allowed-headers>\n        <header>Authorization</header>\n        <header>Content-Type</header>\n        <header>Accept</header>\n        <header>X-Correlation-ID</header>\n      </allowed-headers>\n      <expose-headers>\n        <header>X-Correlation-ID</header>\n        <header>X-RateLimit-Remaining</header>\n      </expose-headers>\n    </cors>\n\n    <!-- ================================================================= -->\n    <!-- POLICY 2: Correlation ID (set-header with expression)             -->\n    <!-- ================================================================= -->\n    <!-- AZ-305 Exam Relevance: Distributed tracing is a key              -->\n    <!-- Operational Excellence concern. The exam may ask how to correlate -->\n    <!-- requests across microservices -- a correlation ID header is the   -->\n    <!-- standard pattern.                                                 -->\n    <!--                                                                   -->\n    <!-- Real-World: If the caller already sends X-Correlation-ID, we     -->\n    <!-- preserve it (skip). Otherwise, we generate a new GUID. This      -->\n    <!-- enables end-to-end tracing in Application Insights.              -->\n    <!-- ================================================================= -->\n    <set-header name="X-Correlation-ID" exists-action="skip">\n      <value>@{ return Guid.NewGuid().ToString("D"); }</value>\n    </set-header>\n\n    <!-- ================================================================= -->\n    <!-- POLICY 3: Rate Limiting by Subscription Key (rate-limit-by-key)   -->\n    <!-- ================================================================= -->\n    <!-- AZ-305 Exam Relevance: Throttling protects backends from bursts.  -->\n    <!-- rate-limit-by-key uses PER-GATEWAY counters (not global). For     -->\n    <!-- multi-region APIM, each region enforces its own counter.          -->\n    <!-- Use quota-by-key for GLOBAL limits across regions.                -->\n    <!--                                                                   -->\n    <!-- Key distinction the exam tests:                                   -->\n    <!--   rate-limit = short-term burst protection (per minute)           -->\n    <!--   quota      = long-term usage cap (per day/month)                -->\n    <!--                                                                   -->\n    <!-- retry-after-header-name surfaces a custom header so callers know -->\n    <!-- exactly when to retry -- better than guessing.                    -->\n    <!-- ================================================================= -->\n    <rate-limit-by-key calls="${rateLimitCalls}" renewal-period="${rateLimitPeriodSeconds}" counter-key="@(context.Subscription.Id)" retry-after-header-name="X-RateLimit-RetryAfter" remaining-calls-header-name="X-RateLimit-Remaining" />\n\n    <!-- ================================================================= -->\n    <!-- POLICY 4: Rate Limiting for Anonymous Access by IP                -->\n    <!-- ================================================================= -->\n    <!-- AZ-305 Exam Relevance: APIs that allow anonymous access (no       -->\n    <!-- subscription key) still need protection. IP-based rate limiting   -->\n    <!-- is the standard pattern. The exam may present a scenario where    -->\n    <!-- unauthenticated endpoints are being abused.                       -->\n    <!--                                                                   -->\n    <!-- Real-World: Be aware that multiple users behind a NAT share one  -->\n    <!-- public IP. Set limits accordingly -- not too aggressive.           -->\n    <!-- ================================================================= -->\n    <rate-limit-by-key calls="${rateLimitAnonymousCalls}" renewal-period="${rateLimitAnonymousPeriodSeconds}" counter-key="@(context.Request.IpAddress)" retry-after-header-name="X-RateLimit-RetryAfter-IP" />\n\n    <!-- ================================================================= -->\n    <!-- POLICY 5: Daily Quota by Subscription Key (quota-by-key)          -->\n    <!-- ================================================================= -->\n    <!-- AZ-305 Exam Relevance: Quotas are GLOBAL across all APIM          -->\n    <!-- gateways (unlike rate-limit which is per-gateway). Use quotas     -->\n    <!-- for billing tiers and long-term usage caps.                        -->\n    <!--                                                                   -->\n    <!-- bandwidth attribute limits data transfer in KB -- important for   -->\n    <!-- Cost Optimization when backend egress is expensive.               -->\n    <!-- ================================================================= -->\n    <quota-by-key calls="${quotaDailyCalls}" bandwidth="${quotaDailyBandwidthKB}" renewal-period="86400" counter-key="@(context.Subscription.Id)" />\n  </inbound>\n\n  <backend>\n    <!-- Forward to backend with a 30-second timeout -->\n    <forward-request timeout="30" />\n  </backend>\n\n  <outbound>\n    <!-- ================================================================= -->\n    <!-- POLICY 8: Security Header Removal (set-header delete)             -->\n    <!-- ================================================================= -->\n    <!-- AZ-305 Exam Relevance: Defense-in-depth requires removing headers -->\n    <!-- that reveal backend technology. OWASP API Security Top 10 lists   -->\n    <!-- information disclosure as a common vulnerability.                  -->\n    <!--                                                                   -->\n    <!-- Real-World: Attackers use Server, X-Powered-By, and X-AspNet-    -->\n    <!-- Version headers to fingerprint your stack and find known CVEs.    -->\n    <!-- ================================================================= -->\n    <set-header name="X-Powered-By" exists-action="delete" />\n    <set-header name="X-AspNet-Version" exists-action="delete" />\n    <set-header name="Server" exists-action="delete" />\n    <set-header name="X-StackTrace" exists-action="delete" />\n  </outbound>\n\n  <on-error>\n    <base />\n    <!-- ================================================================= -->\n    <!-- AZ-305 Teaching Point: The on-error section catches policy         -->\n    <!-- execution failures. In production, log the error to Application   -->\n    <!-- Insights and return a sanitized error response -- never leak      -->\n    <!-- stack traces or internal details to callers.                       -->\n    <!-- ================================================================= -->\n  </on-error>\n</policies>'
    format: 'xml'
  }
}

// ============================================================================
// Resources - Products
// ============================================================================

@description('Starter product')
resource starterProduct 'Microsoft.ApiManagement/service/products@2023-05-01-preview' = {
  parent: apiManagement
  name: 'starter'
  properties: {
    displayName: 'Starter'
    description: 'Starter product for API consumers with rate limits'
    subscriptionRequired: true
    approvalRequired: false
    state: 'published'
    terms: 'Terms of service for the Starter product'
  }
}

@description('Unlimited product')
resource unlimitedProduct 'Microsoft.ApiManagement/service/products@2023-05-01-preview' = {
  parent: apiManagement
  name: 'unlimited'
  properties: {
    displayName: 'Unlimited'
    description: 'Unlimited product for trusted API consumers'
    subscriptionRequired: true
    approvalRequired: true
    state: 'published'
    terms: 'Terms of service for the Unlimited product'
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('API Management service name')
output apimName string = apiManagement.name

@description('API Management service ID')
output apimId string = apiManagement.id

@description('API Management gateway URL')
output gatewayUrl string = apiManagement.properties.gatewayUrl

@description('API Management developer portal URL')
output developerPortalUrl string = apiManagement.properties.developerPortalUrl

@description('API Management management API URL')
output managementApiUrl string = apiManagement.properties.managementApiUrl

@description('API Management SCM URL')
output scmUrl string = apiManagement.properties.scmUrl

@description('API Management public IP addresses')
output publicIpAddresses array = apiManagement.properties.publicIPAddresses

@description('API Management private IP addresses')
output privateIpAddresses array = apiManagement.properties.privateIPAddresses

@description('System-assigned managed identity principal ID')
output identityPrincipalId string = enableManagedIdentity ? apiManagement.identity.principalId : ''

@description('API Management SKU')
output sku string = sku

@description('Virtual network type')
output vnetType string = virtualNetworkType
