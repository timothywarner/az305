// ============================================================================
// Azure Key Vault with Private Link and RBAC
// ============================================================================
// Purpose: Deploy Key Vault with Private Endpoint and Azure RBAC authorization
// AZ-305 Exam Objectives:
//   - Design a solution for managing secrets, keys, and certificates (Objective 2.4)
//   - Design authentication and authorization solutions (Objective 1.1)
//   - Design a solution for network connectivity (Objective 4.2)
// Prerequisites:
//   - Resource group must exist
//   - Virtual network with subnet for private endpoint
//   - Private DNS zone for Key Vault (privatelink.vaultcore.azure.net)
// ============================================================================

targetScope = 'resourceGroup'

// ============================================================================
// Parameters
// ============================================================================

@description('Name of the Key Vault.')
@minLength(3)
@maxLength(24)
param keyVaultName string

@description('Azure region for the Key Vault.')
param location string = resourceGroup().location

@description('Key Vault SKU.')
@allowed([
  'standard'
  'premium'
])
param skuName string = 'standard'

@description('Enable Azure RBAC authorization (recommended).')
param enableRbacAuthorization bool = true

@description('Enable soft delete.')
param enableSoftDelete bool = true

@description('Soft delete retention in days.')
@minValue(7)
@maxValue(90)
param softDeleteRetentionInDays int = 90

@description('Enable purge protection.')
param enablePurgeProtection bool = true

@description('Enable public network access.')
param enablePublicNetworkAccess bool = false

@description('Virtual network resource ID for private endpoint.')
param vnetId string = ''

@description('Subnet name for private endpoint.')
param privateEndpointSubnetName string = 'PrivateEndpoints'

@description('Private DNS zone resource ID for Key Vault.')
param privateDnsZoneId string = ''

@description('Enable deployment of private endpoint.')
param deployPrivateEndpoint bool = true

@description('Principal IDs to grant Key Vault Administrator role.')
param keyVaultAdminPrincipalIds array = []

@description('Principal IDs to grant Key Vault Secrets User role.')
param keyVaultSecretsUserPrincipalIds array = []

@description('Principal IDs to grant Key Vault Crypto User role.')
param keyVaultCryptoUserPrincipalIds array = []

@description('Enable diagnostic logging.')
param enableDiagnostics bool = false

@description('Log Analytics workspace ID for diagnostics.')
param logAnalyticsWorkspaceId string = ''

@description('Tags to apply to resources.')
param tags object = {
  environment: 'production'
  purpose: 'secrets-management'
  examObjective: 'AZ-305-SecretsManagement'
}

// ============================================================================
// Variables
// ============================================================================

var vaultName = 'kv-${keyVaultName}-${uniqueString(resourceGroup().id)}'
var privateEndpointName = 'pe-${vaultName}'
var privateEndpointNicName = 'nic-${privateEndpointName}'

// Built-in role definition IDs
var keyVaultAdminRoleId = '00482a5a-887f-4fb3-b363-3b7fe8e74483'
var keyVaultSecretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'
var keyVaultCryptoUserRoleId = '12338af0-0e69-4776-bea7-57ae8d297424'
var keyVaultSecretsOfficerRoleId = 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'
var keyVaultCertificatesOfficerRoleId = 'a4417e6f-fecd-4de8-b567-7b0420556985'
var keyVaultCryptoOfficerRoleId = '14b46e9e-c2b7-41b4-b07b-48a6ebf60603'

// ============================================================================
// Resources - Key Vault
// ============================================================================

@description('Azure Key Vault with RBAC authorization')
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: vaultName
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: skuName
    }
    tenantId: tenant().tenantId
    enableRbacAuthorization: enableRbacAuthorization
    enableSoftDelete: enableSoftDelete
    softDeleteRetentionInDays: softDeleteRetentionInDays
    enablePurgeProtection: enablePurgeProtection ? true : null
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    publicNetworkAccess: enablePublicNetworkAccess ? 'Enabled' : 'Disabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: enablePublicNetworkAccess ? 'Allow' : 'Deny'
      ipRules: []
      virtualNetworkRules: []
    }
  }
}

// ============================================================================
// Resources - Private Endpoint
// ============================================================================

@description('Private endpoint for Key Vault')
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = if (deployPrivateEndpoint && !empty(vnetId)) {
  name: privateEndpointName
  location: location
  tags: tags
  properties: {
    customNetworkInterfaceName: privateEndpointNicName
    privateLinkServiceConnections: [
      {
        name: privateEndpointName
        properties: {
          privateLinkServiceId: keyVault.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
    subnet: {
      id: '${vnetId}/subnets/${privateEndpointSubnetName}'
    }
  }
}

@description('Private DNS zone group for Key Vault')
resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-09-01' = if (deployPrivateEndpoint && !empty(privateDnsZoneId)) {
  parent: privateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-vaultcore-azure-net'
        properties: {
          privateDnsZoneId: privateDnsZoneId
        }
      }
    ]
  }
}

// ============================================================================
// Resources - RBAC Role Assignments
// ============================================================================

@description('Key Vault Administrator role assignments')
resource keyVaultAdminAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for principalId in keyVaultAdminPrincipalIds: {
  name: guid(keyVault.id, principalId, keyVaultAdminRoleId)
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultAdminRoleId)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}]

@description('Key Vault Secrets User role assignments')
resource keyVaultSecretsUserAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for principalId in keyVaultSecretsUserPrincipalIds: {
  name: guid(keyVault.id, principalId, keyVaultSecretsUserRoleId)
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsUserRoleId)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}]

@description('Key Vault Crypto User role assignments')
resource keyVaultCryptoUserAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for principalId in keyVaultCryptoUserPrincipalIds: {
  name: guid(keyVault.id, principalId, keyVaultCryptoUserRoleId)
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultCryptoUserRoleId)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}]

// ============================================================================
// Resources - Diagnostic Settings
// ============================================================================

@description('Diagnostic settings for Key Vault')
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics && !empty(logAnalyticsWorkspaceId)) {
  name: 'keyvault-diagnostics'
  scope: keyVault
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'audit'
        enabled: true
      }
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

@description('Key Vault name')
output keyVaultName string = keyVault.name

@description('Key Vault resource ID')
output keyVaultId string = keyVault.id

@description('Key Vault URI')
output keyVaultUri string = keyVault.properties.vaultUri

@description('Key Vault tenant ID')
output tenantId string = keyVault.properties.tenantId

@description('Private endpoint ID')
output privateEndpointId string = deployPrivateEndpoint && !empty(vnetId) ? privateEndpoint.id : ''

@description('Private endpoint IP address')
output privateEndpointIp string = deployPrivateEndpoint && !empty(vnetId) ? privateEndpoint.properties.customDnsConfigs[0].ipAddresses[0] : ''

@description('Key Vault Administrator role definition ID')
output keyVaultAdminRoleDefinitionId string = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultAdminRoleId)

@description('Key Vault Secrets User role definition ID')
output keyVaultSecretsUserRoleDefinitionId string = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsUserRoleId)

@description('Key Vault Secrets Officer role definition ID')
output keyVaultSecretsOfficerRoleDefinitionId string = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsOfficerRoleId)

@description('Key Vault Crypto User role definition ID')
output keyVaultCryptoUserRoleDefinitionId string = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultCryptoUserRoleId)

@description('Key Vault Crypto Officer role definition ID')
output keyVaultCryptoOfficerRoleDefinitionId string = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultCryptoOfficerRoleId)

@description('Key Vault Certificates Officer role definition ID')
output keyVaultCertificatesOfficerRoleDefinitionId string = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultCertificatesOfficerRoleId)

@description('Secret reference format for App Service/Function')
output secretReferenceFormat string = '@Microsoft.KeyVault(VaultName=${keyVault.name};SecretName={secret-name})'
