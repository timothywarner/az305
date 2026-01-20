// ============================================================================
// Azure Policy Initiative for Tagging Compliance
// ============================================================================
// Purpose: Enforce organizational tagging standards through Azure Policy
// AZ-305 Exam Objectives:
//   - Design governance (Objective 1.4)
//   - Design a solution for managing identities and access (Objective 1.2)
// Prerequisites:
//   - Microsoft.Authorization/policyDefinitions/write permission
//   - Subscription or management group scope deployment
// ============================================================================

targetScope = 'subscription'

// ============================================================================
// Parameters
// ============================================================================

@description('Name of the policy initiative (policy set definition).')
param initiativeName string = 'tag-governance-initiative'

@description('Display name for the policy initiative.')
param initiativeDisplayName string = 'Tag Governance Initiative'

@description('Description of the policy initiative.')
param initiativeDescription string = 'Ensures resources have required tags for cost management and operations.'

@description('Category for the policy initiative.')
param policyCategory string = 'Tags'

@description('Required tags that must be present on resources.')
param requiredTags array = [
  'Environment'
  'CostCenter'
  'Owner'
  'Application'
]

@description('Default value for the Environment tag.')
@allowed([
  'Production'
  'Development'
  'Staging'
  'Test'
])
param defaultEnvironment string = 'Development'

// ============================================================================
// Resources - Custom Policy Definitions
// ============================================================================

@description('Policy to require a specific tag on resources')
resource requireTagPolicy 'Microsoft.Authorization/policyDefinitions@2021-06-01' = [for tag in requiredTags: {
  name: 'require-tag-${toLower(tag)}'
  properties: {
    displayName: 'Require ${tag} tag on resources'
    description: 'Enforces the presence of the ${tag} tag on all resources.'
    policyType: 'Custom'
    mode: 'Indexed'
    metadata: {
      category: policyCategory
      version: '1.0.0'
    }
    parameters: {
      tagName: {
        type: 'String'
        metadata: {
          displayName: 'Tag Name'
          description: 'Name of the tag to require'
        }
        defaultValue: tag
      }
    }
    policyRule: {
      if: {
        field: '[concat(\'tags[\', parameters(\'tagName\'), \']\')]'
        exists: 'false'
      }
      then: {
        effect: 'deny'
      }
    }
  }
}]

@description('Policy to inherit tag from resource group if missing')
resource inheritTagPolicy 'Microsoft.Authorization/policyDefinitions@2021-06-01' = [for tag in requiredTags: {
  name: 'inherit-tag-${toLower(tag)}'
  properties: {
    displayName: 'Inherit ${tag} tag from resource group if missing'
    description: 'Adds the ${tag} tag from the resource group when any resource missing this tag is created or updated.'
    policyType: 'Custom'
    mode: 'Indexed'
    metadata: {
      category: policyCategory
      version: '1.0.0'
    }
    parameters: {
      tagName: {
        type: 'String'
        metadata: {
          displayName: 'Tag Name'
          description: 'Name of the tag to inherit'
        }
        defaultValue: tag
      }
    }
    policyRule: {
      if: {
        allOf: [
          {
            field: '[concat(\'tags[\', parameters(\'tagName\'), \']\')]'
            exists: 'false'
          }
          {
            value: '[resourceGroup().tags[parameters(\'tagName\')]]'
            notEquals: ''
          }
        ]
      }
      then: {
        effect: 'modify'
        details: {
          roleDefinitionIds: [
            '/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'
          ]
          operations: [
            {
              operation: 'add'
              field: '[concat(\'tags[\', parameters(\'tagName\'), \']\')]'
              value: '[resourceGroup().tags[parameters(\'tagName\')]]'
            }
          ]
        }
      }
    }
  }
}]

@description('Policy to audit resources without required tags')
resource auditMissingTagPolicy 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: 'audit-missing-required-tags'
  properties: {
    displayName: 'Audit resources missing required tags'
    description: 'Audits resources that do not have all required tags.'
    policyType: 'Custom'
    mode: 'Indexed'
    metadata: {
      category: policyCategory
      version: '1.0.0'
    }
    parameters: {}
    policyRule: {
      if: {
        anyOf: [for tag in requiredTags: {
          field: 'tags[\'${tag}\']'
          exists: 'false'
        }]
      }
      then: {
        effect: 'audit'
      }
    }
  }
}

// ============================================================================
// Resources - Policy Initiative (Policy Set Definition)
// ============================================================================

@description('Policy Initiative combining all tagging policies')
resource tagGovernanceInitiative 'Microsoft.Authorization/policySetDefinitions@2021-06-01' = {
  name: initiativeName
  properties: {
    displayName: initiativeDisplayName
    description: initiativeDescription
    policyType: 'Custom'
    metadata: {
      category: policyCategory
      version: '1.0.0'
    }
    parameters: {
      defaultEnvironment: {
        type: 'String'
        metadata: {
          displayName: 'Default Environment'
          description: 'Default value for Environment tag'
        }
        defaultValue: defaultEnvironment
        allowedValues: [
          'Production'
          'Development'
          'Staging'
          'Test'
        ]
      }
    }
    policyDefinitions: concat(
      [for (tag, i) in requiredTags: {
        policyDefinitionId: requireTagPolicy[i].id
        policyDefinitionReferenceId: 'require-tag-${toLower(tag)}'
        parameters: {
          tagName: {
            value: tag
          }
        }
      }],
      [for (tag, i) in requiredTags: {
        policyDefinitionId: inheritTagPolicy[i].id
        policyDefinitionReferenceId: 'inherit-tag-${toLower(tag)}'
        parameters: {
          tagName: {
            value: tag
          }
        }
      }],
      [
        {
          policyDefinitionId: auditMissingTagPolicy.id
          policyDefinitionReferenceId: 'audit-missing-tags'
          parameters: {}
        }
      ]
    )
  }
}

// ============================================================================
// Resources - Policy Assignment (Optional - Uncomment to assign)
// ============================================================================

// @description('Assign the policy initiative to the subscription')
// resource initiativeAssignment 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
//   name: '${initiativeName}-assignment'
//   location: 'eastus' // Required for managed identity
//   identity: {
//     type: 'SystemAssigned'
//   }
//   properties: {
//     displayName: '${initiativeDisplayName} Assignment'
//     description: 'Assigns the tag governance initiative to enforce tagging standards.'
//     policyDefinitionId: tagGovernanceInitiative.id
//     enforcementMode: 'Default'
//     parameters: {
//       defaultEnvironment: {
//         value: defaultEnvironment
//       }
//     }
//     nonComplianceMessages: [
//       {
//         message: 'This resource does not comply with organizational tagging requirements. Please ensure all required tags are present.'
//       }
//     ]
//   }
// }

// ============================================================================
// Outputs
// ============================================================================

@description('Resource ID of the policy initiative')
output initiativeId string = tagGovernanceInitiative.id

@description('Name of the policy initiative')
output initiativeName string = tagGovernanceInitiative.name

@description('Policy definition IDs for require-tag policies')
output requireTagPolicyIds array = [for (tag, i) in requiredTags: requireTagPolicy[i].id]

@description('Policy definition IDs for inherit-tag policies')
output inheritTagPolicyIds array = [for (tag, i) in requiredTags: inheritTagPolicy[i].id]
