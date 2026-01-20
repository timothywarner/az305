// ============================================================================
// Azure API Management with Backend Services
// ============================================================================
// Purpose: Deploy API Management with backend configuration and policies
// AZ-305 Exam Objectives:
//   - Design an application architecture (Objective 4.3)
//   - Design authentication and authorization solutions (Objective 1.1)
//   - Design a solution for network connectivity (Objective 4.2)
// Prerequisites:
//   - Resource group must exist
//   - Virtual network for internal APIM (optional)
//   - Application Insights for monitoring (optional)
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

@description('Deploy sample API.')
param deploySampleApi bool = false

@description('Backend API URL for sample API.')
param sampleApiBackendUrl string = 'https://httpbin.org'

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

@description('Sample API')
resource sampleApi 'Microsoft.ApiManagement/service/apis@2023-05-01-preview' = if (deploySampleApi) {
  parent: apiManagement
  name: 'sample-api'
  properties: {
    displayName: 'Sample API'
    description: 'Sample API for testing'
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
    description: 'Returns GET data'
    responses: [
      {
        statusCode: 200
        description: 'Success'
      }
    ]
  }
}

// ============================================================================
// Resources - Global Policy
// ============================================================================

@description('Global API policy')
resource globalPolicy 'Microsoft.ApiManagement/service/policies@2023-05-01-preview' = {
  parent: apiManagement
  name: 'policy'
  properties: {
    value: '''
      <policies>
        <inbound>
          <cors allow-credentials="false">
            <allowed-origins>
              <origin>*</origin>
            </allowed-origins>
            <allowed-methods>
              <method>GET</method>
              <method>POST</method>
              <method>PUT</method>
              <method>DELETE</method>
              <method>OPTIONS</method>
            </allowed-methods>
            <allowed-headers>
              <header>*</header>
            </allowed-headers>
          </cors>
          <rate-limit calls="100" renewal-period="60" />
          <quota calls="10000" renewal-period="86400" />
        </inbound>
        <backend>
          <forward-request timeout="30" />
        </backend>
        <outbound>
          <set-header name="X-Powered-By" exists-action="delete" />
          <set-header name="X-AspNet-Version" exists-action="delete" />
        </outbound>
        <on-error>
          <base />
        </on-error>
      </policies>
    '''
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
