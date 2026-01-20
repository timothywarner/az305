// ============================================================================
// User-Assigned Managed Identity with Role Assignment
// ============================================================================
// Purpose: Create user-assigned managed identity for Zero Trust authentication
// AZ-305 Exam Objectives:
//   - Design authentication and authorization solutions (Objective 1.1)
//   - Design a solution for managing identities and access (Objective 1.2)
// Prerequisites:
//   - Resource group must exist
//   - Appropriate permissions to create managed identities and role assignments
// ============================================================================

targetScope = 'resourceGroup'

// ============================================================================
// Parameters
// ============================================================================

@description('Name of the user-assigned managed identity.')
@minLength(3)
@maxLength(128)
param identityName string

@description('Azure region for the managed identity.')
param location string = resourceGroup().location

@description('Tags to apply to the managed identity.')
param tags object = {
  environment: 'production'
  purpose: 'application-identity'
  examObjective: 'AZ-305-IdentityManagement'
}

@description('Array of built-in role definition IDs to assign to the identity.')
param roleAssignments array = []

@description('Scope for role assignments. Defaults to current resource group.')
param roleAssignmentScope string = resourceGroup().id

// ============================================================================
// Variables
// ============================================================================

// Built-in role definition IDs (for reference)
var builtInRoles = {
  // Storage roles
  StorageBlobDataContributor: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
  StorageBlobDataReader: '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
  StorageQueueDataContributor: '974c5e8b-45b9-4653-ba55-5f855dd0fb88'
  StorageTableDataContributor: '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3'

  // Key Vault roles
  KeyVaultSecretsUser: '4633458b-17de-408a-b874-0445c86b69e6'
  KeyVaultSecretsOfficer: 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'
  KeyVaultCryptoUser: '12338af0-0e69-4776-bea7-57ae8d297424'
  KeyVaultCertificatesOfficer: 'a4417e6f-fecd-4de8-b567-7b0420556985'

  // Database roles
  SQLDBContributor: '9b7fa17d-e63e-47b0-bb0a-15c516ac86ec'
  CosmosDBAccountReader: 'fbdf93bf-df7d-467e-a4d2-9458aa1360c8'
  CosmosDBOperator: '230815da-be43-4aae-9cb4-875f7bd000aa'

  // Compute roles
  VirtualMachineContributor: '9980e02c-c2be-4d73-94e8-173b1dc7cf3c'
  ContainerRegistryPush: '8311e382-0749-4cb8-b61a-304f252e45ec'
  ContainerRegistryPull: '7f951dda-4ed3-4680-a7ca-43fe172d538d'
  AKSClusterUserRole: '4abbcc35-e782-43d8-92c5-2d3f1bd2253f'

  // Monitoring roles
  MonitoringReader: '43d0d8ad-25c7-4714-9337-8ba259a9fe05'
  MonitoringContributor: '749f88d5-cbae-40b8-bcfc-e573ddc772fa'
  LogAnalyticsContributor: '92aaf0da-9dab-42b6-94a3-d43ce8d16293'

  // General roles
  Contributor: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
  Reader: 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
  ManagedIdentityOperator: 'f1a07417-d97a-45cb-824c-7a7467783830'
}

var identityResourceName = 'id-${identityName}'

// ============================================================================
// Resources
// ============================================================================

@description('User-assigned managed identity')
resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityResourceName
  location: location
  tags: tags
}

@description('Role assignments for the managed identity')
resource identityRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for (role, i) in roleAssignments: {
  name: guid(roleAssignmentScope, userAssignedIdentity.id, role)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role)
    principalId: userAssignedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}]

// ============================================================================
// Example: Storage Blob Data Contributor Assignment
// ============================================================================

@description('Example: Assign Storage Blob Data Contributor role')
resource storageBlobContributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (length(roleAssignments) == 0) {
  name: guid(resourceGroup().id, userAssignedIdentity.id, builtInRoles.StorageBlobDataContributor)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', builtInRoles.StorageBlobDataContributor)
    principalId: userAssignedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    description: 'Allows the managed identity to read, write, and delete storage blobs'
  }
}

@description('Example: Assign Key Vault Secrets User role')
resource keyVaultSecretsUserAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (length(roleAssignments) == 0) {
  name: guid(resourceGroup().id, userAssignedIdentity.id, builtInRoles.KeyVaultSecretsUser)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', builtInRoles.KeyVaultSecretsUser)
    principalId: userAssignedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    description: 'Allows the managed identity to read Key Vault secrets'
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('Resource ID of the managed identity')
output identityId string = userAssignedIdentity.id

@description('Name of the managed identity')
output identityName string = userAssignedIdentity.name

@description('Principal ID (Object ID) of the managed identity')
output identityPrincipalId string = userAssignedIdentity.properties.principalId

@description('Client ID (Application ID) of the managed identity')
output identityClientId string = userAssignedIdentity.properties.clientId

@description('Tenant ID of the managed identity')
output identityTenantId string = userAssignedIdentity.properties.tenantId

@description('Full identity object for use in other resources')
output identityObject object = {
  type: 'UserAssigned'
  userAssignedIdentities: {
    '${userAssignedIdentity.id}': {}
  }
}

@description('Built-in role IDs for reference')
output builtInRoleIds object = builtInRoles
