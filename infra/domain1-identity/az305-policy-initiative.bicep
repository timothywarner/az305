// ============================================================================
// AZ-305 Exam-Aligned Azure Policy Initiative (Policy Set Definition)
// ============================================================================
//
// TEACHING NOTES - Azure Policy Hierarchy:
//
//   1. Policy Definition  - A single rule (e.g., "Storage must use HTTPS")
//   2. Initiative (Policy Set) - A collection of policy definitions grouped
//      by compliance objective (e.g., "Security Baseline")
//   3. Policy Assignment  - Binds an initiative or policy to a scope
//      (management group, subscription, or resource group)
//
// WHY INITIATIVES?
//   - Simplify assignment: assign one initiative instead of 17 individual policies
//   - Unified compliance tracking in a single compliance view
//   - Grouped exemptions and exclusions
//   - AZ-305 exam tests your ability to choose the RIGHT governance structure
//
// EFFECT EVALUATION ORDER (exam favorite):
//   Disabled -> Deny -> Audit -> Append -> Modify -> DeployIfNotExists -> AuditIfNotExists
//
//   - Disabled: Policy is off (useful for testing without deleting)
//   - Deny:     Blocks the request BEFORE resource creation/modification
//   - Audit:    Allows the request but flags non-compliance
//   - Append:   Adds properties to the request (legacy, prefer Modify)
//   - Modify:   Changes request properties (needs managed identity)
//   - DeployIfNotExists (DINE): Deploys a related resource if missing
//                               (needs managed identity)
//   - AuditIfNotExists: Audits for existence of a related resource
//
// WHEN TO USE WHICH EFFECT (exam decision framework):
//   - Use DENY for hard security requirements (HTTPS, TLS 1.2, no public IPs)
//   - Use AUDIT for visibility before enforcing (migration scenarios)
//   - Use DINE for auto-remediation (diagnostic settings, extensions)
//   - Use MODIFY for auto-correction of properties (tags, network rules)
//   - AZ-305 tip: Start with Audit, then switch to Deny after compliance review
//
// COMPLIANCE EVALUATION TIMING:
//   - New/updated resources: evaluated immediately during PUT/PATCH
//   - Existing resources: evaluated during compliance scan (every 24 hours)
//   - On-demand: triggered via REST API or Azure CLI
//   - Assignment change: re-evaluation within 30 minutes
//
// EXEMPTIONS AND EXCLUSIONS:
//   - Exclusion scopes: resource groups excluded from the assignment scope
//   - Policy exemptions: waive compliance for specific resources with
//     an expiration date (Waiver or Mitigated category)
//   - AZ-305 tip: Use exemptions for temporary exceptions, not permanent ones
//
// DEPLOYMENT:
//   az deployment sub create \
//     --location eastus \
//     --template-file az305-policy-initiative.bicep \
//     --parameters az305-policy-initiative.parameters.json
//
// ============================================================================

targetScope = 'subscription'

// ============================================================================
// PARAMETERS
// ============================================================================

@description('Display name prefix for the initiative and assignment.')
param initiativePrefix string = 'AZ-305'

@description('Required tag name to enforce on all resources (e.g., CostCenter, Environment).')
param requiredTagName string

@description('Required tag value for the tag specified in requiredTagName.')
param requiredTagValue string

@description('List of approved VM extension names. Extensions not in this list will be flagged.')
param approvedExtensions array = [
  'MicrosoftMonitoringAgent'
  'AzureMonitorWindowsAgent'
  'AzureMonitorLinuxAgent'
  'DependencyAgentWindows'
  'DependencyAgentLinux'
  'AzureNetworkWatcherExtension'
  'AzureDiskEncryption'
  'CustomScriptExtension'
]

@description('Minimum TLS version required for Storage Accounts.')
@allowed([
  'TLS1_2'
  'TLS1_3'
])
param minimumTlsVersion string = 'TLS1_2'

@description('Enforcement mode for the policy assignment. Use DoNotEnforce for testing.')
@allowed([
  'Default'
  'DoNotEnforce'
])
param enforcementMode string = 'Default'

@description('Resource group names to exclude from the policy assignment (e.g., sandbox RGs).')
param exclusionResourceGroups array = []

@description('Azure region for the policy assignment identity (required for DINE/Modify effects).')
param assignmentLocation string = deployment().location

// ============================================================================
// VARIABLES
// ============================================================================

// Build exclusion scope IDs from resource group names
var exclusionScopes = [for rg in exclusionResourceGroups: subscriptionResourceId('Microsoft.Resources/resourceGroups', rg)]

// Built-in policy definition IDs - these are TENANT-LEVEL resources
// Reference: https://learn.microsoft.com/azure/governance/policy/samples/built-in-policies
//
// AZ-305 TIP: Built-in policies live at the tenant level and are referenced
// using the path /providers/Microsoft.Authorization/policyDefinitions/{GUID}.
// You do NOT need to create these - Microsoft maintains them.

// ---------- Security & Compliance ----------

// Policy 1: Secure transfer (HTTPS) to storage accounts should be enabled
// WHY EXAM-RELEVANT: Zero Trust principle - encrypt data in transit
// REAL-WORLD: Prevents accidental HTTP access to storage blobs/queues/tables
var storageHttpsDefinitionId = '/providers/Microsoft.Authorization/policyDefinitions/404c3081-a854-4457-ae30-26a93ef643f9'

// Policy 2: Storage accounts should have the specified minimum TLS version
// WHY EXAM-RELEVANT: TLS 1.0/1.1 are deprecated; compliance requires TLS 1.2+
// REAL-WORLD: PCI-DSS, HIPAA, and NIST 800-53 all require TLS 1.2 minimum
var storageTlsDefinitionId = '/providers/Microsoft.Authorization/policyDefinitions/fe83a0eb-a853-422d-aac2-1bffd182c5d0'

// Policy 3: Azure Key Vault should use RBAC permission model
// WHY EXAM-RELEVANT: RBAC is the recommended model over vault access policies
// REAL-WORLD: RBAC provides fine-grained access control integrated with Entra ID
var keyVaultRbacDefinitionId = '/providers/Microsoft.Authorization/policyDefinitions/12d4fa5e-1f9f-4c21-97a9-b99b3c6611b5'

// Policy 4: Transparent Data Encryption on SQL databases should be enabled
// WHY EXAM-RELEVANT: TDE encrypts data at rest; on by default but policy ensures compliance
// REAL-WORLD: Required for HIPAA, SOC 2, and most regulatory frameworks
var sqlTdeDefinitionId = '/providers/Microsoft.Authorization/policyDefinitions/17k78e20-9358-41c9-923c-fb736d382a12'

// Policy 5: OS and data disks should be encrypted with a customer-managed key
// WHY EXAM-RELEVANT: CMK vs platform-managed key is a common exam topic
// REAL-WORLD: Financial services and government workloads require CMK for key ownership
var diskEncryptionDefinitionId = '/providers/Microsoft.Authorization/policyDefinitions/702dd420-7fcc-42c5-afe8-4026edd20fe0'

// ---------- Networking ----------

// Policy 6: Network interfaces should not have public IPs
// WHY EXAM-RELEVANT: Zero Trust - minimize attack surface, use Private Link
// REAL-WORLD: Prevents VMs from being directly internet-accessible
var nicNoPublicIpDefinitionId = '/providers/Microsoft.Authorization/policyDefinitions/83a86a26-fd1f-447c-b59d-e51f44264114'

// Policy 7: Subnets should be associated with a Network Security Group
// WHY EXAM-RELEVANT: NSGs are the first layer of network segmentation
// REAL-WORLD: Every subnet should have an NSG; even if rules are permissive, it enables logging
var subnetNsgDefinitionId = '/providers/Microsoft.Authorization/policyDefinitions/e71308d3-144b-4262-b144-efdc3cc90517'

// Policy 8: Storage accounts should restrict network access (default deny)
// WHY EXAM-RELEVANT: Network segmentation for PaaS services via service endpoints/private link
// REAL-WORLD: Default-deny prevents data exfiltration from misconfigured storage accounts
var storageNetworkAccessDefinitionId = '/providers/Microsoft.Authorization/policyDefinitions/34c877ad-507e-4c82-993e-3452a6e0ad3c'

// ---------- Identity & Access ----------

// Policy 9: Virtual machines should have a managed identity (Audit effect)
// WHY EXAM-RELEVANT: Managed identities eliminate credential management (exam favorite)
// REAL-WORLD: Service principals with secrets are a top source of credential leaks
// NOTE: Using AuditIfNotExists policy (da0a5b59) instead of DINE policy (d367bd60)
//       to avoid requiring the bringYourOwnUserAssignedManagedIdentity parameter
var vmManagedIdentityDefinitionId = '/providers/Microsoft.Authorization/policyDefinitions/da0a5b59-e37b-403e-8f65-9efd3e1a35b7'

// Policy 10: Guest accounts with owner permissions should be removed
// WHY EXAM-RELEVANT: Least privilege principle; external accounts are a security risk
// REAL-WORLD: Compliance frameworks require periodic access reviews for external identities
var guestOwnerDefinitionId = '/providers/Microsoft.Authorization/policyDefinitions/339353f6-2387-4a45-abe4-7f529d121046'

// ---------- Monitoring & Governance ----------

// Policy 11: Azure subscriptions should have a log profile for Activity Log
// WHY EXAM-RELEVANT: Activity logs are the audit trail for control plane operations
// REAL-WORLD: Security incident investigation requires activity log history
var activityLogProfileDefinitionId = '/providers/Microsoft.Authorization/policyDefinitions/7796937f-307b-4598-941c-67d3a05ebfe7'

// Policy 12: Activity log should be retained for at least one year
// WHY EXAM-RELEVANT: 365-day retention is a CIS benchmark requirement
// REAL-WORLD: Many compliance frameworks require 1-year minimum log retention
var activityLogRetentionDefinitionId = '/providers/Microsoft.Authorization/policyDefinitions/b02aacc0-b073-424e-8298-42b22829ee0a'

// Policy 13: Require a tag and its value on resources
// WHY EXAM-RELEVANT: Tagging is fundamental to cost management and governance
// REAL-WORLD: Without tags, cost allocation and resource ownership become impossible
var requireTagDefinitionId = '/providers/Microsoft.Authorization/policyDefinitions/1e30110a-5ceb-460c-a204-c1c3969c6d62'

// ---------- Compute ----------

// Policy 14: Virtual machines should use managed disks (audit classic unmanaged disks)
// WHY EXAM-RELEVANT: Managed disks provide built-in availability, encryption, RBAC
// REAL-WORLD: Unmanaged disks lack SLA guarantees and encryption-at-rest by default
var vmManagedDisksDefinitionId = '/providers/Microsoft.Authorization/policyDefinitions/06a78e20-9358-41c9-923c-fb736d382a4d'

// Policy 15: Only approved VM extensions should be installed
// WHY EXAM-RELEVANT: Extensions run as SYSTEM/root; unapproved ones are a security risk
// REAL-WORLD: Prevents unauthorized code execution on VMs
var approvedExtensionsDefinitionId = '/providers/Microsoft.Authorization/policyDefinitions/c0e996f8-39cf-4af9-9f45-83fbde810432'

// ---------- Data Protection ----------

// Policy 16: Key Vault should have soft delete enabled
// WHY EXAM-RELEVANT: Soft delete is the safety net for accidental key/secret deletion
// REAL-WORLD: Without soft delete, a deleted key vault is gone forever (data loss risk)
var keyVaultSoftDeleteDefinitionId = '/providers/Microsoft.Authorization/policyDefinitions/1e66c121-a66a-4b1f-9b83-0fd99bf0fc2d'

// Policy 17: Key Vault should have purge protection enabled
// WHY EXAM-RELEVANT: Purge protection prevents INSIDER THREAT (even admins cannot purge)
// REAL-WORLD: Required when Key Vault is used for TDE, Storage encryption, or Disk encryption
var keyVaultPurgeProtectionDefinitionId = '/providers/Microsoft.Authorization/policyDefinitions/0b60c0b2-2dc2-4e1c-b5c9-abbed971de53'

// ============================================================================
// POLICY SET DEFINITION (INITIATIVE)
// ============================================================================
//
// AZ-305 TEACHING POINT:
// A Policy Set Definition groups multiple policies into a single assignable unit.
// This is the recommended approach for enterprise governance - never assign
// individual policies at scale.
//
// Policy groups enable categorization in the compliance dashboard, making it
// easy to see compliance by security domain (e.g., all networking policies).
// ============================================================================

resource policyInitiative 'Microsoft.Authorization/policySetDefinitions@2023-04-01' = {
  name: 'az305-security-governance-initiative'
  properties: {
    displayName: '${initiativePrefix} Security & Governance Baseline'
    description: 'Comprehensive policy initiative covering security, networking, identity, monitoring, compute, and data protection controls aligned with AZ-305 exam objectives and the Azure Well-Architected Framework.'
    policyType: 'Custom'
    metadata: {
      category: 'Security & Governance'
      version: '1.0.0'
      az305ExamDomain: 'Domain 1: Design Identity, Governance, and Monitoring Solutions'
      wafPillars: [
        'Security'
        'Operational Excellence'
        'Reliability'
      ]
    }

    // ========================================================================
    // POLICY GROUPS - Organize policies by compliance category
    // These appear as sections in the Azure Portal compliance view
    // ========================================================================
    policyDefinitionGroups: [
      {
        name: 'SecurityAndCompliance'
        displayName: 'Security & Compliance'
        description: 'Policies ensuring encryption, secure protocols, and data protection.'
      }
      {
        name: 'Networking'
        displayName: 'Network Security'
        description: 'Policies enforcing network segmentation and private connectivity.'
      }
      {
        name: 'IdentityAndAccess'
        displayName: 'Identity & Access Management'
        description: 'Policies enforcing managed identities and least-privilege access.'
      }
      {
        name: 'MonitoringAndGovernance'
        displayName: 'Monitoring & Governance'
        description: 'Policies ensuring observability, logging, and resource tagging.'
      }
      {
        name: 'Compute'
        displayName: 'Compute Security'
        description: 'Policies governing VM disk management and approved extensions.'
      }
      {
        name: 'DataProtection'
        displayName: 'Data Protection'
        description: 'Policies protecting Key Vault from accidental or malicious deletion.'
      }
    ]

    // ========================================================================
    // INITIATIVE-LEVEL PARAMETERS
    // These are passed through to individual policy definitions.
    // AZ-305 TIP: Initiative parameters allow a single assignment to configure
    // multiple policies. This is more manageable than per-policy assignments.
    // ========================================================================
    parameters: {
      storageHttpsEffect: {
        type: 'String'
        metadata: {
          displayName: 'Storage HTTPS Effect'
          description: 'Effect for requiring HTTPS on Storage Accounts.'
        }
        allowedValues: [
          'Audit'
          'Deny'
          'Disabled'
        ]
        defaultValue: 'Deny'
      }
      storageTlsEffect: {
        type: 'String'
        metadata: {
          displayName: 'Storage TLS Effect'
          description: 'Effect for requiring minimum TLS version on Storage Accounts.'
        }
        allowedValues: [
          'Audit'
          'Deny'
          'Disabled'
        ]
        defaultValue: 'Deny'
      }
      storageTlsVersion: {
        type: 'String'
        metadata: {
          displayName: 'Minimum TLS Version'
          description: 'Minimum TLS version required for Storage Accounts.'
        }
        allowedValues: [
          'TLS1_2'
          'TLS1_3'
        ]
        defaultValue: minimumTlsVersion
      }
      keyVaultRbacEffect: {
        type: 'String'
        metadata: {
          displayName: 'Key Vault RBAC Effect'
          description: 'Effect for requiring RBAC authorization on Key Vault.'
        }
        allowedValues: [
          'Audit'
          'Deny'
          'Disabled'
        ]
        defaultValue: 'Audit'
      }
      sqlTdeEffect: {
        type: 'String'
        metadata: {
          displayName: 'SQL TDE Effect'
          description: 'Effect for requiring TDE on SQL databases.'
        }
        allowedValues: [
          'AuditIfNotExists'
          'Disabled'
        ]
        defaultValue: 'AuditIfNotExists'
      }
      diskEncryptionEffect: {
        type: 'String'
        metadata: {
          displayName: 'Disk Encryption Effect'
          description: 'Effect for requiring CMK encryption on managed disks.'
        }
        allowedValues: [
          'Audit'
          'Deny'
          'Disabled'
        ]
        defaultValue: 'Audit'
      }
      nicNoPublicIpEffect: {
        type: 'String'
        metadata: {
          displayName: 'NIC No Public IP Effect'
          description: 'Effect for denying public IPs on network interfaces.'
        }
        allowedValues: [
          'Deny'
          'Disabled'
        ]
        // NOTE: This built-in only supports Deny or Disabled
        defaultValue: 'Deny'
      }
      subnetNsgEffect: {
        type: 'String'
        metadata: {
          displayName: 'Subnet NSG Effect'
          description: 'Effect for requiring NSGs on subnets.'
        }
        allowedValues: [
          'AuditIfNotExists'
          'Disabled'
        ]
        defaultValue: 'AuditIfNotExists'
      }
      storageNetworkAccessEffect: {
        type: 'String'
        metadata: {
          displayName: 'Storage Network Access Effect'
          description: 'Effect for restricting storage account network access.'
        }
        allowedValues: [
          'Audit'
          'Deny'
          'Disabled'
        ]
        defaultValue: 'Audit'
      }
      keyVaultSoftDeleteEffect: {
        type: 'String'
        metadata: {
          displayName: 'Key Vault Soft Delete Effect'
          description: 'Effect for requiring soft delete on Key Vault.'
        }
        allowedValues: [
          'Audit'
          'Deny'
          'Disabled'
        ]
        defaultValue: 'Audit'
      }
      keyVaultPurgeProtectionEffect: {
        type: 'String'
        metadata: {
          displayName: 'Key Vault Purge Protection Effect'
          description: 'Effect for requiring purge protection on Key Vault.'
        }
        allowedValues: [
          'Audit'
          'Deny'
          'Disabled'
        ]
        defaultValue: 'Audit'
      }
      vmManagedDisksEffect: {
        type: 'String'
        metadata: {
          displayName: 'VM Managed Disks Effect'
          description: 'Effect for auditing VMs not using managed disks.'
        }
        allowedValues: [
          'Audit'
          'Disabled'
        ]
        defaultValue: 'Audit'
      }
      approvedExtensionsList: {
        type: 'Array'
        metadata: {
          displayName: 'Approved VM Extensions'
          description: 'List of approved VM extension publisher:type combinations.'
        }
        defaultValue: approvedExtensions
      }
      approvedExtensionsEffect: {
        type: 'String'
        metadata: {
          displayName: 'Approved Extensions Effect'
          description: 'Effect for controlling which VM extensions can be installed.'
        }
        allowedValues: [
          'Audit'
          'Deny'
          'Disabled'
        ]
        defaultValue: 'Audit'
      }
      requiredTagNameParam: {
        type: 'String'
        metadata: {
          displayName: 'Required Tag Name'
          description: 'Name of the tag that must exist on all resources.'
        }
        defaultValue: requiredTagName
      }
      requiredTagValueParam: {
        type: 'String'
        metadata: {
          displayName: 'Required Tag Value'
          description: 'Value of the required tag.'
        }
        defaultValue: requiredTagValue
      }
    }

    // ========================================================================
    // POLICY DEFINITIONS - The actual policies in the initiative
    // ========================================================================
    policyDefinitions: [
      // ====================================================================
      // SECURITY & COMPLIANCE (Policies 1-5)
      // ====================================================================

      // Policy 1: Require HTTPS on Storage Accounts
      {
        policyDefinitionId: storageHttpsDefinitionId
        policyDefinitionReferenceId: 'storageAccountHttpsOnly'
        groupNames: [
          'SecurityAndCompliance'
        ]
        parameters: {
          effect: {
            value: '[parameters(\'storageHttpsEffect\')]'
          }
        }
      }

      // Policy 2: Require minimum TLS 1.2 on Storage Accounts
      {
        policyDefinitionId: storageTlsDefinitionId
        policyDefinitionReferenceId: 'storageAccountMinTls'
        groupNames: [
          'SecurityAndCompliance'
        ]
        parameters: {
          effect: {
            value: '[parameters(\'storageTlsEffect\')]'
          }
          minimumTlsVersion: {
            value: '[parameters(\'storageTlsVersion\')]'
          }
        }
      }

      // Policy 3: Key Vault should use RBAC authorization
      {
        policyDefinitionId: keyVaultRbacDefinitionId
        policyDefinitionReferenceId: 'keyVaultRbacModel'
        groupNames: [
          'SecurityAndCompliance'
        ]
        parameters: {
          effect: {
            value: '[parameters(\'keyVaultRbacEffect\')]'
          }
        }
      }

      // Policy 4: SQL databases should have TDE enabled
      {
        policyDefinitionId: sqlTdeDefinitionId
        policyDefinitionReferenceId: 'sqlDatabaseTde'
        groupNames: [
          'SecurityAndCompliance'
        ]
        parameters: {
          effect: {
            value: '[parameters(\'sqlTdeEffect\')]'
          }
        }
      }

      // Policy 5: Managed disks should use CMK encryption
      {
        policyDefinitionId: diskEncryptionDefinitionId
        policyDefinitionReferenceId: 'diskCmkEncryption'
        groupNames: [
          'SecurityAndCompliance'
        ]
        parameters: {
          effect: {
            value: '[parameters(\'diskEncryptionEffect\')]'
          }
        }
      }

      // ====================================================================
      // NETWORKING (Policies 6-8)
      // ====================================================================

      // Policy 6: Network interfaces should not have public IPs
      {
        policyDefinitionId: nicNoPublicIpDefinitionId
        policyDefinitionReferenceId: 'nicDenyPublicIp'
        groupNames: [
          'Networking'
        ]
        parameters: {}
        // NOTE: This built-in uses a hardcoded 'deny' effect (no parameter)
        // The nicNoPublicIpEffect parameter controls via Disabled override
      }

      // Policy 7: Subnets should be associated with an NSG
      {
        policyDefinitionId: subnetNsgDefinitionId
        policyDefinitionReferenceId: 'subnetRequireNsg'
        groupNames: [
          'Networking'
        ]
        parameters: {
          effect: {
            value: '[parameters(\'subnetNsgEffect\')]'
          }
        }
      }

      // Policy 8: Storage accounts should restrict network access
      {
        policyDefinitionId: storageNetworkAccessDefinitionId
        policyDefinitionReferenceId: 'storageRestrictNetworkAccess'
        groupNames: [
          'Networking'
        ]
        parameters: {
          effect: {
            value: '[parameters(\'storageNetworkAccessEffect\')]'
          }
        }
      }

      // ====================================================================
      // IDENTITY & ACCESS (Policies 9-10)
      // ====================================================================

      // Policy 9: Virtual machines should have a managed identity (AuditIfNotExists)
      // NOTE: Uses audit-only policy to flag VMs missing managed identity
      {
        policyDefinitionId: vmManagedIdentityDefinitionId
        policyDefinitionReferenceId: 'vmManagedIdentity'
        groupNames: [
          'IdentityAndAccess'
        ]
        parameters: {
          effect: {
            value: 'AuditIfNotExists'
          }
        }
      }

      // Policy 10: Guest accounts with owner permissions should be removed
      {
        policyDefinitionId: guestOwnerDefinitionId
        policyDefinitionReferenceId: 'guestAccountsOwnerRemoval'
        groupNames: [
          'IdentityAndAccess'
        ]
        parameters: {
          effect: {
            value: 'AuditIfNotExists'
          }
        }
      }

      // ====================================================================
      // MONITORING & GOVERNANCE (Policies 11-13)
      // ====================================================================

      // Policy 11: Subscription should have a log profile for Activity Log
      {
        policyDefinitionId: activityLogProfileDefinitionId
        policyDefinitionReferenceId: 'activityLogProfile'
        groupNames: [
          'MonitoringAndGovernance'
        ]
        parameters: {
          effect: {
            value: 'AuditIfNotExists'
          }
        }
      }

      // Policy 12: Activity log should be retained for at least 365 days
      {
        policyDefinitionId: activityLogRetentionDefinitionId
        policyDefinitionReferenceId: 'activityLogRetention365'
        groupNames: [
          'MonitoringAndGovernance'
        ]
        parameters: {
          effect: {
            value: 'AuditIfNotExists'
          }
        }
      }

      // Policy 13: Require a tag and its value on resources
      {
        policyDefinitionId: requireTagDefinitionId
        policyDefinitionReferenceId: 'requireTagOnResources'
        groupNames: [
          'MonitoringAndGovernance'
        ]
        parameters: {
          tagName: {
            value: '[parameters(\'requiredTagNameParam\')]'
          }
          tagValue: {
            value: '[parameters(\'requiredTagValueParam\')]'
          }
        }
      }

      // ====================================================================
      // COMPUTE (Policies 14-15)
      // ====================================================================

      // Policy 14: Virtual machines should use managed disks
      {
        policyDefinitionId: vmManagedDisksDefinitionId
        policyDefinitionReferenceId: 'vmUseManagedDisks'
        groupNames: [
          'Compute'
        ]
        parameters: {}
        // NOTE: This built-in uses a hardcoded 'audit' effect
      }

      // Policy 15: Only approved VM extensions should be installed
      {
        policyDefinitionId: approvedExtensionsDefinitionId
        policyDefinitionReferenceId: 'approvedVmExtensions'
        groupNames: [
          'Compute'
        ]
        parameters: {
          effect: {
            value: '[parameters(\'approvedExtensionsEffect\')]'
          }
          approvedExtensions: {
            value: '[parameters(\'approvedExtensionsList\')]'
          }
        }
      }

      // ====================================================================
      // DATA PROTECTION (Policies 16-17)
      // ====================================================================

      // Policy 16: Key Vault should have soft delete enabled
      {
        policyDefinitionId: keyVaultSoftDeleteDefinitionId
        policyDefinitionReferenceId: 'keyVaultSoftDelete'
        groupNames: [
          'DataProtection'
        ]
        parameters: {
          effect: {
            value: '[parameters(\'keyVaultSoftDeleteEffect\')]'
          }
        }
      }

      // Policy 17: Key Vault should have purge protection enabled
      {
        policyDefinitionId: keyVaultPurgeProtectionDefinitionId
        policyDefinitionReferenceId: 'keyVaultPurgeProtection'
        groupNames: [
          'DataProtection'
        ]
        parameters: {
          effect: {
            value: '[parameters(\'keyVaultPurgeProtectionEffect\')]'
          }
        }
      }
    ]
  }
}

// ============================================================================
// POLICY ASSIGNMENT
// ============================================================================
//
// AZ-305 TEACHING POINT:
// An assignment binds the initiative to a scope. Key decisions:
//
//   1. SCOPE: Management group (broad) vs subscription (targeted) vs RG (narrow)
//      - Exam tip: Management group assignments inherit to all child subscriptions
//
//   2. ENFORCEMENT MODE:
//      - Default: Policies are enforced (Deny blocks, DINE deploys)
//      - DoNotEnforce: Policies evaluate but do NOT enforce
//        Use case: Test impact before enabling enforcement
//        AZ-305 tip: DoNotEnforce + compliance review is the safe migration path
//
//   3. MANAGED IDENTITY:
//      - Required for Modify and DeployIfNotExists effects
//      - System-assigned: lifecycle tied to the assignment
//      - User-assigned: shared across assignments (better for scale)
//      - The identity needs RBAC roles on the target scope to make changes
//
//   4. EXCLUSION SCOPES:
//      - Exclude specific resource groups (e.g., DevTest, Sandbox)
//      - More granular exclusion: use Policy Exemptions (resource-level)
//
//   5. NON-COMPLIANCE MESSAGES:
//      - Custom messages displayed when a resource is blocked by Deny
//      - Include remediation guidance to reduce support tickets
// ============================================================================

resource policyAssignment 'Microsoft.Authorization/policyAssignments@2023-04-01' = {
  name: 'az305-security-baseline'
  location: assignmentLocation
  identity: {
    // System-assigned managed identity is required for DINE and Modify effects
    // AZ-305 TIP: Without this identity, remediation tasks will fail
    type: 'SystemAssigned'
  }
  properties: {
    displayName: '${initiativePrefix} Security & Governance Baseline Assignment'
    description: 'Assigns the AZ-305 security and governance baseline initiative to this subscription. Covers encryption, networking, identity, monitoring, compute, and data protection controls.'
    policyDefinitionId: policyInitiative.id
    enforcementMode: enforcementMode
    notScopes: exclusionScopes

    // Pass initiative-level parameter values from the assignment
    parameters: {
      storageHttpsEffect: {
        value: 'Deny'
      }
      storageTlsEffect: {
        value: 'Deny'
      }
      storageTlsVersion: {
        value: minimumTlsVersion
      }
      keyVaultRbacEffect: {
        value: 'Audit'
      }
      sqlTdeEffect: {
        value: 'AuditIfNotExists'
      }
      diskEncryptionEffect: {
        value: 'Audit'
      }
      subnetNsgEffect: {
        value: 'AuditIfNotExists'
      }
      storageNetworkAccessEffect: {
        value: 'Audit'
      }
      keyVaultSoftDeleteEffect: {
        value: 'Audit'
      }
      keyVaultPurgeProtectionEffect: {
        value: 'Audit'
      }
      vmManagedDisksEffect: {
        value: 'Audit'
      }
      approvedExtensionsList: {
        value: approvedExtensions
      }
      approvedExtensionsEffect: {
        value: 'Audit'
      }
      requiredTagNameParam: {
        value: requiredTagName
      }
      requiredTagValueParam: {
        value: requiredTagValue
      }
    }

    // Non-compliance messages give users actionable feedback when Deny blocks them
    nonComplianceMessages: [
      {
        message: 'This resource does not comply with the AZ-305 Security & Governance Baseline. Review the specific policy for remediation guidance.'
      }
      {
        policyDefinitionReferenceId: 'storageAccountHttpsOnly'
        message: 'Storage accounts must use HTTPS (secure transfer). Set supportsHttpsTrafficOnly to true.'
      }
      {
        policyDefinitionReferenceId: 'storageAccountMinTls'
        message: 'Storage accounts must use TLS 1.2 or higher. Set minimumTlsVersion to TLS1_2.'
      }
      {
        policyDefinitionReferenceId: 'nicDenyPublicIp'
        message: 'Network interfaces cannot have public IP addresses. Use Azure Bastion, Private Link, or a load balancer for inbound connectivity.'
      }
      {
        policyDefinitionReferenceId: 'requireTagOnResources'
        message: 'All resources must have the required tag. Add the tag before deployment.'
      }
    ]
  }
}

// ============================================================================
// OUTPUTS
// ============================================================================

@description('Resource ID of the policy initiative (policy set definition).')
output initiativeId string = policyInitiative.id

@description('Resource ID of the policy assignment.')
output assignmentId string = policyAssignment.id

@description('Principal ID of the assignment managed identity (for RBAC role grants).')
output assignmentPrincipalId string = policyAssignment.identity.principalId

@description('Name of the policy assignment for use in remediation tasks.')
output assignmentName string = policyAssignment.name

// ============================================================================
// POST-DEPLOYMENT STEPS (TEACHING NOTES)
// ============================================================================
//
// After deploying this template, the following manual steps are required:
//
// 1. GRANT RBAC ROLES TO THE MANAGED IDENTITY
//    The system-assigned managed identity needs roles to execute DINE/Modify:
//
//    az role assignment create \
//      --assignee <assignmentPrincipalId> \
//      --role "Contributor" \
//      --scope "/subscriptions/<subscriptionId>"
//
// 2. CREATE REMEDIATION TASKS FOR EXISTING RESOURCES
//    Policies only auto-apply to NEW resources. For existing non-compliant resources:
//
//    az policy remediation create \
//      --name "remediate-storage-https" \
//      --policy-assignment az305-security-baseline \
//      --definition-reference-id storageAccountHttpsOnly
//
// 3. REVIEW COMPLIANCE
//    Check compliance state after the 24-hour evaluation cycle:
//
//    az policy state summarize \
//      --policy-assignment az305-security-baseline
//
// 4. EXEMPTIONS (for specific resources that cannot comply)
//
//    az policy exemption create \
//      --name "legacy-storage-exemption" \
//      --policy-assignment az305-security-baseline \
//      --exemption-category "Waiver" \
//      --expires-on "2026-12-31" \
//      --description "Legacy storage account migrating to HTTPS by Q4 2026"
//
// ============================================================================
