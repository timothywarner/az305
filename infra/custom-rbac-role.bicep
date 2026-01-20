// ============================================================================
// Custom RBAC Role Definition
// ============================================================================
// Purpose: Create custom RBAC role for granular access control
// AZ-305 Exam Objectives:
//   - Design authentication and authorization solutions (Objective 1.1)
//   - Design a solution for managing identities and access (Objective 1.2)
// Prerequisites:
//   - Microsoft.Authorization/roleDefinitions/write permission
//   - Subscription-level or management group-level deployment
// ============================================================================

targetScope = 'subscription'

// ============================================================================
// Parameters
// ============================================================================

@description('Name of the custom RBAC role.')
param roleName string = 'Custom VM Operator'

@description('Description of the custom role.')
param roleDescription string = 'Can start, stop, and restart virtual machines but cannot create or delete them.'

@description('Actions that the role can perform.')
param actions array = [
  'Microsoft.Compute/virtualMachines/start/action'
  'Microsoft.Compute/virtualMachines/powerOff/action'
  'Microsoft.Compute/virtualMachines/restart/action'
  'Microsoft.Compute/virtualMachines/read'
  'Microsoft.Compute/virtualMachines/instanceView/read'
  'Microsoft.Network/networkInterfaces/read'
  'Microsoft.Network/publicIPAddresses/read'
  'Microsoft.Resources/subscriptions/resourceGroups/read'
]

@description('Actions that the role cannot perform.')
param notActions array = []

@description('Data actions that the role can perform.')
param dataActions array = []

@description('Data actions that the role cannot perform.')
param notDataActions array = []

@description('Scopes where the role can be assigned. Uses current subscription by default.')
param assignableScopes array = [
  subscription().id
]

// ============================================================================
// Variables
// ============================================================================

// Generate a deterministic GUID for the role definition based on name
var roleDefName = guid(subscription().id, roleName)

// ============================================================================
// Resources
// ============================================================================

@description('Custom RBAC Role Definition')
resource customRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: roleDefName
  properties: {
    roleName: roleName
    description: roleDescription
    type: 'CustomRole'
    permissions: [
      {
        actions: actions
        notActions: notActions
        dataActions: dataActions
        notDataActions: notDataActions
      }
    ]
    assignableScopes: assignableScopes
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('Resource ID of the custom role definition')
output roleDefinitionId string = customRoleDefinition.id

@description('Name (GUID) of the custom role definition')
output roleDefinitionName string = customRoleDefinition.name

@description('Display name of the custom role')
output roleDisplayName string = customRoleDefinition.properties.roleName
