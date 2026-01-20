// ============================================================================
// Azure Front Door Premium with WAF
// ============================================================================
// Purpose: Deploy Azure Front Door Premium with WAF for global load balancing
// AZ-305 Exam Objectives:
//   - Design a solution for network connectivity (Objective 4.2)
//   - Design high availability solutions (Objective 3.2)
//   - Design an application architecture (Objective 4.3)
// Prerequisites:
//   - Resource group must exist
//   - Backend origins must be accessible
// ============================================================================

targetScope = 'resourceGroup'

// ============================================================================
// Parameters
// ============================================================================

@description('Name of the Front Door profile.')
@minLength(1)
@maxLength(64)
param frontDoorName string

@description('Front Door SKU.')
@allowed([
  'Standard_AzureFrontDoor'
  'Premium_AzureFrontDoor'
])
param skuName string = 'Premium_AzureFrontDoor'

@description('Enable WAF policy.')
param enableWaf bool = true

@description('WAF mode.')
@allowed([
  'Detection'
  'Prevention'
])
param wafMode string = 'Prevention'

@description('Origin group name.')
param originGroupName string = 'default-origin-group'

@description('Primary origin hostname.')
param primaryOriginHostname string

@description('Secondary origin hostname (for HA).')
param secondaryOriginHostname string = ''

@description('Origin HTTP port.')
param originHttpPort int = 80

@description('Origin HTTPS port.')
param originHttpsPort int = 443

@description('Enable Private Link to origin.')
param enablePrivateLink bool = false

@description('Private Link resource ID.')
param privateLinkResourceId string = ''

@description('Private Link location.')
param privateLinkLocation string = ''

@description('Custom domain name (optional).')
param customDomainName string = ''

@description('Enable caching.')
param enableCaching bool = true

@description('Cache duration in seconds.')
param cacheDurationSeconds int = 86400

@description('Endpoint name.')
param endpointName string = 'default-endpoint'

@description('Route name.')
param routeName string = 'default-route'

@description('Log Analytics workspace ID for diagnostics.')
param logAnalyticsWorkspaceId string = ''

@description('Tags to apply to resources.')
param tags object = {
  environment: 'production'
  purpose: 'front-door'
  examObjective: 'AZ-305-Networking'
}

// ============================================================================
// Variables
// ============================================================================

var profileName = 'afd-${frontDoorName}-${uniqueString(resourceGroup().id)}'
var wafPolicyName = 'wafpolicy${replace(frontDoorName, '-', '')}'
var hasSecondaryOrigin = !empty(secondaryOriginHostname)

// ============================================================================
// Resources - Front Door Profile
// ============================================================================

@description('Azure Front Door profile')
resource frontDoorProfile 'Microsoft.Cdn/profiles@2023-05-01' = {
  name: profileName
  location: 'global'
  tags: tags
  sku: {
    name: skuName
  }
  properties: {
    originResponseTimeoutSeconds: 60
  }
}

// ============================================================================
// Resources - WAF Policy
// ============================================================================

@description('WAF policy for Front Door')
resource wafPolicy 'Microsoft.Network/FrontDoorWebApplicationFirewallPolicies@2022-05-01' = if (enableWaf) {
  name: wafPolicyName
  location: 'global'
  tags: tags
  sku: {
    name: skuName
  }
  properties: {
    policySettings: {
      enabledState: 'Enabled'
      mode: wafMode
      requestBodyCheck: 'Enabled'
    }
    customRules: {
      rules: [
        {
          name: 'BlockHighRiskCountries'
          priority: 100
          enabledState: 'Disabled' // Enable and customize as needed
          ruleType: 'MatchRule'
          action: 'Block'
          matchConditions: [
            {
              matchVariable: 'RemoteAddr'
              operator: 'GeoMatch'
              matchValue: []
              negateCondition: false
            }
          ]
        }
        {
          name: 'RateLimitRule'
          priority: 200
          enabledState: 'Enabled'
          ruleType: 'RateLimitRule'
          action: 'Block'
          rateLimitThreshold: 1000
          rateLimitDurationInMinutes: 1
          matchConditions: [
            {
              matchVariable: 'RequestUri'
              operator: 'Contains'
              matchValue: ['/api/']
              transforms: ['Lowercase']
              negateCondition: false
            }
          ]
        }
      ]
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'Microsoft_DefaultRuleSet'
          ruleSetVersion: '2.1'
          ruleSetAction: 'Block'
          ruleGroupOverrides: []
        }
        {
          ruleSetType: 'Microsoft_BotManagerRuleSet'
          ruleSetVersion: '1.0'
          ruleSetAction: 'Block'
          ruleGroupOverrides: []
        }
      ]
    }
  }
}

// ============================================================================
// Resources - Endpoint
// ============================================================================

@description('Front Door endpoint')
resource frontDoorEndpoint 'Microsoft.Cdn/profiles/afdEndpoints@2023-05-01' = {
  parent: frontDoorProfile
  name: endpointName
  location: 'global'
  tags: tags
  properties: {
    enabledState: 'Enabled'
  }
}

// ============================================================================
// Resources - Origin Group
// ============================================================================

@description('Origin group')
resource frontDoorOriginGroup 'Microsoft.Cdn/profiles/originGroups@2023-05-01' = {
  parent: frontDoorProfile
  name: originGroupName
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
      additionalLatencyInMilliseconds: 50
    }
    healthProbeSettings: {
      probePath: '/health'
      probeRequestType: 'HEAD'
      probeProtocol: 'Https'
      probeIntervalInSeconds: 30
    }
    sessionAffinityState: 'Disabled'
  }
}

// ============================================================================
// Resources - Origins
// ============================================================================

@description('Primary origin')
resource primaryOrigin 'Microsoft.Cdn/profiles/originGroups/origins@2023-05-01' = {
  parent: frontDoorOriginGroup
  name: 'primary-origin'
  properties: {
    hostName: primaryOriginHostname
    httpPort: originHttpPort
    httpsPort: originHttpsPort
    originHostHeader: primaryOriginHostname
    priority: 1
    weight: 1000
    enabledState: 'Enabled'
    enforceCertificateNameCheck: true
    sharedPrivateLinkResource: enablePrivateLink && !empty(privateLinkResourceId) ? {
      privateLink: {
        id: privateLinkResourceId
      }
      privateLinkLocation: privateLinkLocation
      requestMessage: 'Please approve this private link connection'
      groupId: 'sites' // Adjust based on resource type
    } : null
  }
}

@description('Secondary origin')
resource secondaryOrigin 'Microsoft.Cdn/profiles/originGroups/origins@2023-05-01' = if (hasSecondaryOrigin) {
  parent: frontDoorOriginGroup
  name: 'secondary-origin'
  properties: {
    hostName: secondaryOriginHostname
    httpPort: originHttpPort
    httpsPort: originHttpsPort
    originHostHeader: secondaryOriginHostname
    priority: 2
    weight: 1000
    enabledState: 'Enabled'
    enforceCertificateNameCheck: true
  }
}

// ============================================================================
// Resources - Route
// ============================================================================

@description('Front Door route')
resource frontDoorRoute 'Microsoft.Cdn/profiles/afdEndpoints/routes@2023-05-01' = {
  parent: frontDoorEndpoint
  name: routeName
  properties: {
    originGroup: {
      id: frontDoorOriginGroup.id
    }
    originPath: '/'
    ruleSets: []
    supportedProtocols: [
      'Http'
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    forwardingProtocol: 'HttpsOnly'
    linkToDefaultDomain: 'Enabled'
    httpsRedirect: 'Enabled'
    enabledState: 'Enabled'
    cacheConfiguration: enableCaching ? {
      queryStringCachingBehavior: 'IgnoreQueryString'
      compressionSettings: {
        isCompressionEnabled: true
        contentTypesToCompress: [
          'text/html'
          'text/css'
          'text/javascript'
          'application/javascript'
          'application/json'
          'application/xml'
        ]
      }
      cacheBehavior: 'OverrideAlways'
      cacheDuration: 'PT${cacheDurationSeconds}S'
    } : null
  }
  dependsOn: [
    primaryOrigin
    secondaryOrigin
  ]
}

// ============================================================================
// Resources - Security Policy (WAF Association)
// ============================================================================

@description('Security policy associating WAF with endpoint')
resource securityPolicy 'Microsoft.Cdn/profiles/securityPolicies@2023-05-01' = if (enableWaf) {
  parent: frontDoorProfile
  name: 'security-policy-${endpointName}'
  properties: {
    parameters: {
      type: 'WebApplicationFirewall'
      wafPolicy: {
        id: wafPolicy.id
      }
      associations: [
        {
          domains: [
            {
              id: frontDoorEndpoint.id
            }
          ]
          patternsToMatch: [
            '/*'
          ]
        }
      ]
    }
  }
}

// ============================================================================
// Resources - Custom Domain (Optional)
// ============================================================================

@description('Custom domain')
resource customDomain 'Microsoft.Cdn/profiles/customDomains@2023-05-01' = if (!empty(customDomainName)) {
  parent: frontDoorProfile
  name: replace(customDomainName, '.', '-')
  properties: {
    hostName: customDomainName
    tlsSettings: {
      certificateType: 'ManagedCertificate'
      minimumTlsVersion: 'TLS12'
    }
  }
}

// ============================================================================
// Resources - Diagnostic Settings
// ============================================================================

@description('Front Door diagnostic settings')
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  name: 'frontdoor-diagnostics'
  scope: frontDoorProfile
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('Front Door profile name')
output profileName string = frontDoorProfile.name

@description('Front Door profile ID')
output profileId string = frontDoorProfile.id

@description('Front Door endpoint hostname')
output endpointHostName string = frontDoorEndpoint.properties.hostName

@description('Front Door endpoint URL')
output endpointUrl string = 'https://${frontDoorEndpoint.properties.hostName}'

@description('Front Door endpoint ID')
output endpointId string = frontDoorEndpoint.id

@description('WAF policy ID')
output wafPolicyId string = enableWaf ? wafPolicy.id : ''

@description('WAF policy name')
output wafPolicyName string = enableWaf ? wafPolicy.name : ''

@description('Origin group ID')
output originGroupId string = frontDoorOriginGroup.id

@description('Custom domain validation info')
output customDomainValidation object = !empty(customDomainName) ? {
  domainName: customDomain.name
  validationProperties: customDomain.properties.validationProperties
} : {}

@description('CNAME record for custom domain')
output cnameRecord string = !empty(customDomainName) ? frontDoorEndpoint.properties.hostName : ''

@description('Front Door SKU')
output sku string = skuName
