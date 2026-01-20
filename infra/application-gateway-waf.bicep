// ============================================================================
// Azure Application Gateway with WAF v2
// ============================================================================
// Purpose: Deploy Application Gateway with WAF v2 for web application security
// AZ-305 Exam Objectives:
//   - Design a solution for network connectivity (Objective 4.2)
//   - Design authentication and authorization solutions (Objective 1.1)
// Prerequisites:
//   - Resource group must exist
//   - Virtual network with dedicated subnet for App Gateway
//   - SSL certificate (can use Key Vault reference)
// ============================================================================

targetScope = 'resourceGroup'

// ============================================================================
// Parameters
// ============================================================================

@description('Name of the Application Gateway.')
@minLength(1)
@maxLength(80)
param appGatewayName string

@description('Azure region for the Application Gateway.')
param location string = resourceGroup().location

@description('Virtual network resource ID.')
param vnetId string

@description('Subnet name for Application Gateway.')
param appGatewaySubnetName string = 'AppGateway'

@description('Application Gateway SKU tier.')
@allowed([
  'Standard_v2'
  'WAF_v2'
])
param skuTier string = 'WAF_v2'

@description('Minimum capacity for autoscaling.')
@minValue(1)
@maxValue(125)
param minCapacity int = 2

@description('Maximum capacity for autoscaling.')
@minValue(1)
@maxValue(125)
param maxCapacity int = 10

@description('Enable WAF.')
param enableWaf bool = true

@description('WAF mode.')
@allowed([
  'Detection'
  'Prevention'
])
param wafMode string = 'Prevention'

@description('WAF rule set type.')
@allowed([
  'OWASP'
  'Microsoft_BotManagerRuleSet'
])
param wafRuleSetType string = 'OWASP'

@description('WAF rule set version.')
param wafRuleSetVersion string = '3.2'

@description('Backend pool FQDN or IP addresses.')
param backendAddresses array = []

@description('Backend HTTP settings port.')
param backendPort int = 443

@description('Backend HTTP settings protocol.')
@allowed([
  'Http'
  'Https'
])
param backendProtocol string = 'Https'

@description('Enable HTTP to HTTPS redirect.')
param enableHttpToHttpsRedirect bool = true

@description('Key Vault resource ID for SSL certificate.')
param keyVaultId string = ''

@description('SSL certificate secret name in Key Vault.')
param sslCertificateSecretName string = ''

@description('Log Analytics workspace ID for diagnostics.')
param logAnalyticsWorkspaceId string = ''

@description('Tags to apply to resources.')
param tags object = {
  environment: 'production'
  purpose: 'application-gateway'
  examObjective: 'AZ-305-Networking'
}

// ============================================================================
// Variables
// ============================================================================

var gatewayName = 'agw-${appGatewayName}-${uniqueString(resourceGroup().id)}'
var publicIpName = 'pip-${gatewayName}'
var gatewayIpConfigName = 'appGatewayIpConfig'
var frontendIpConfigName = 'appGatewayFrontendIp'
var frontendHttpPortName = 'frontendHttpPort'
var frontendHttpsPortName = 'frontendHttpsPort'
var backendPoolName = 'defaultBackendPool'
var backendHttpSettingsName = 'defaultBackendHttpSettings'
var httpListenerName = 'httpListener'
var httpsListenerName = 'httpsListener'
var httpToHttpsRedirectName = 'httpToHttpsRedirect'
var httpsRoutingRuleName = 'httpsRoutingRule'
var httpRoutingRuleName = 'httpRoutingRule'
var healthProbeName = 'defaultHealthProbe'

// ============================================================================
// Resources - Public IP
// ============================================================================

@description('Public IP for Application Gateway')
resource publicIp 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: publicIpName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  zones: ['1', '2', '3']
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    dnsSettings: {
      domainNameLabel: toLower(gatewayName)
    }
  }
}

// ============================================================================
// Resources - User-Assigned Managed Identity (for Key Vault access)
// ============================================================================

@description('User-assigned managed identity for Key Vault access')
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = if (!empty(keyVaultId)) {
  name: 'id-${gatewayName}'
  location: location
  tags: tags
}

// ============================================================================
// Resources - Application Gateway
// ============================================================================

@description('Application Gateway with WAF v2')
resource applicationGateway 'Microsoft.Network/applicationGateways@2023-09-01' = {
  name: gatewayName
  location: location
  tags: tags
  zones: ['1', '2', '3']
  identity: !empty(keyVaultId) ? {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  } : null
  properties: {
    sku: {
      name: skuTier
      tier: skuTier
    }
    autoscaleConfiguration: {
      minCapacity: minCapacity
      maxCapacity: maxCapacity
    }
    enableHttp2: true
    gatewayIPConfigurations: [
      {
        name: gatewayIpConfigName
        properties: {
          subnet: {
            id: '${vnetId}/subnets/${appGatewaySubnetName}'
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: frontendIpConfigName
        properties: {
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: frontendHttpPortName
        properties: {
          port: 80
        }
      }
      {
        name: frontendHttpsPortName
        properties: {
          port: 443
        }
      }
    ]
    backendAddressPools: [
      {
        name: backendPoolName
        properties: {
          backendAddresses: [for address in backendAddresses: {
            fqdn: contains(address, '.') ? address : null
            ipAddress: !contains(address, '.') ? address : null
          }]
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: backendHttpSettingsName
        properties: {
          port: backendPort
          protocol: backendProtocol
          cookieBasedAffinity: 'Disabled'
          requestTimeout: 30
          pickHostNameFromBackendAddress: true
          probe: {
            id: resourceId('Microsoft.Network/applicationGateways/probes', gatewayName, healthProbeName)
          }
        }
      }
    ]
    httpListeners: concat([
      {
        name: httpListenerName
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', gatewayName, frontendIpConfigName)
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', gatewayName, frontendHttpPortName)
          }
          protocol: 'Http'
          requireServerNameIndication: false
        }
      }
    ], !empty(keyVaultId) ? [
      {
        name: httpsListenerName
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', gatewayName, frontendIpConfigName)
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', gatewayName, frontendHttpsPortName)
          }
          protocol: 'Https'
          requireServerNameIndication: false
          sslCertificate: {
            id: resourceId('Microsoft.Network/applicationGateways/sslCertificates', gatewayName, 'defaultSslCert')
          }
        }
      }
    ] : [])
    sslCertificates: !empty(keyVaultId) ? [
      {
        name: 'defaultSslCert'
        properties: {
          keyVaultSecretId: '${keyVaultId}/secrets/${sslCertificateSecretName}'
        }
      }
    ] : []
    requestRoutingRules: concat([
      {
        name: httpRoutingRuleName
        properties: {
          priority: enableHttpToHttpsRedirect && !empty(keyVaultId) ? 200 : 100
          ruleType: enableHttpToHttpsRedirect && !empty(keyVaultId) ? 'Basic' : 'Basic'
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', gatewayName, httpListenerName)
          }
          redirectConfiguration: enableHttpToHttpsRedirect && !empty(keyVaultId) ? {
            id: resourceId('Microsoft.Network/applicationGateways/redirectConfigurations', gatewayName, httpToHttpsRedirectName)
          } : null
          backendAddressPool: !enableHttpToHttpsRedirect || empty(keyVaultId) ? {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', gatewayName, backendPoolName)
          } : null
          backendHttpSettings: !enableHttpToHttpsRedirect || empty(keyVaultId) ? {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', gatewayName, backendHttpSettingsName)
          } : null
        }
      }
    ], !empty(keyVaultId) ? [
      {
        name: httpsRoutingRuleName
        properties: {
          priority: 100
          ruleType: 'Basic'
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', gatewayName, httpsListenerName)
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', gatewayName, backendPoolName)
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', gatewayName, backendHttpSettingsName)
          }
        }
      }
    ] : [])
    redirectConfigurations: enableHttpToHttpsRedirect && !empty(keyVaultId) ? [
      {
        name: httpToHttpsRedirectName
        properties: {
          redirectType: 'Permanent'
          targetListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', gatewayName, httpsListenerName)
          }
          includePath: true
          includeQueryString: true
        }
      }
    ] : []
    probes: [
      {
        name: healthProbeName
        properties: {
          protocol: backendProtocol
          path: '/health'
          interval: 30
          timeout: 30
          unhealthyThreshold: 3
          pickHostNameFromBackendHttpSettings: true
          minServers: 0
          match: {
            statusCodes: [
              '200-399'
            ]
          }
        }
      }
    ]
    webApplicationFirewallConfiguration: enableWaf ? {
      enabled: true
      firewallMode: wafMode
      ruleSetType: wafRuleSetType
      ruleSetVersion: wafRuleSetVersion
      disabledRuleGroups: []
      requestBodyCheck: true
      maxRequestBodySizeInKb: 128
      fileUploadLimitInMb: 100
    } : null
    sslPolicy: {
      policyType: 'Predefined'
      policyName: 'AppGwSslPolicy20220101S'
    }
  }
}

// ============================================================================
// Resources - Diagnostic Settings
// ============================================================================

@description('Application Gateway diagnostic settings')
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  name: 'appgw-diagnostics'
  scope: applicationGateway
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

@description('Application Gateway name')
output appGatewayName string = applicationGateway.name

@description('Application Gateway resource ID')
output appGatewayId string = applicationGateway.id

@description('Application Gateway public IP address')
output publicIpAddress string = publicIp.properties.ipAddress

@description('Application Gateway FQDN')
output fqdn string = publicIp.properties.dnsSettings.fqdn

@description('Application Gateway private IP address')
output privateIpAddress string = applicationGateway.properties.frontendIPConfigurations[0].properties.privateIPAddress

@description('Backend pool ID')
output backendPoolId string = resourceId('Microsoft.Network/applicationGateways/backendAddressPools', gatewayName, backendPoolName)

@description('WAF enabled')
output wafEnabled bool = enableWaf

@description('WAF mode')
output wafMode string = wafMode

@description('Managed identity principal ID')
output managedIdentityPrincipalId string = !empty(keyVaultId) ? managedIdentity.properties.principalId : ''
