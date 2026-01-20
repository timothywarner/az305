// ============================================================================
// Azure Storage Account with Lifecycle Management
// ============================================================================
// Purpose: Deploy storage account with tiered storage and lifecycle policies
// AZ-305 Exam Objectives:
//   - Design data storage solutions (Objective 2.1)
//   - Design a solution for backup and disaster recovery (Objective 3.1)
//   - Design a solution for managing secrets, keys, and certificates (Objective 2.4)
// Prerequisites:
//   - Resource group must exist
//   - Virtual network for private endpoint (optional)
// ============================================================================

targetScope = 'resourceGroup'

// ============================================================================
// Parameters
// ============================================================================

@description('Name prefix for the storage account.')
@minLength(3)
@maxLength(11)
param storageAccountNamePrefix string

@description('Azure region for the storage account.')
param location string = resourceGroup().location

@description('Storage account SKU.')
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RAGRS'
  'Standard_ZRS'
  'Premium_LRS'
  'Premium_ZRS'
  'Standard_GZRS'
  'Standard_RAGZRS'
])
param storageSku string = 'Standard_RAGZRS'

@description('Storage account kind.')
@allowed([
  'StorageV2'
  'BlobStorage'
  'BlockBlobStorage'
  'FileStorage'
])
param storageKind string = 'StorageV2'

@description('Storage account access tier.')
@allowed([
  'Hot'
  'Cool'
])
param accessTier string = 'Hot'

@description('Enable hierarchical namespace (Data Lake Gen2).')
param enableHierarchicalNamespace bool = false

@description('Enable blob versioning.')
param enableBlobVersioning bool = true

@description('Enable blob soft delete.')
param enableBlobSoftDelete bool = true

@description('Blob soft delete retention days.')
@minValue(1)
@maxValue(365)
param blobSoftDeleteRetentionDays int = 30

@description('Enable container soft delete.')
param enableContainerSoftDelete bool = true

@description('Container soft delete retention days.')
@minValue(1)
@maxValue(365)
param containerSoftDeleteRetentionDays int = 30

@description('Enable point-in-time restore.')
param enablePointInTimeRestore bool = true

@description('Point-in-time restore retention days.')
@minValue(1)
@maxValue(365)
param pointInTimeRestoreDays int = 7

@description('Enable change feed.')
param enableChangeFeed bool = true

@description('Days before moving blobs to cool tier.')
param daysToCoolTier int = 30

@description('Days before moving blobs to archive tier.')
param daysToArchiveTier int = 90

@description('Days before deleting blobs.')
param daysToDeleteBlob int = 365

@description('Container names to create.')
param containerNames array = [
  'data'
  'backups'
  'archives'
  'logs'
]

@description('Tags to apply to resources.')
param tags object = {
  environment: 'production'
  purpose: 'storage'
  examObjective: 'AZ-305-DataStorage'
}

// ============================================================================
// Variables
// ============================================================================

var storageAccountName = 'st${storageAccountNamePrefix}${uniqueString(resourceGroup().id)}'

// ============================================================================
// Resources - Storage Account
// ============================================================================

@description('Storage account with security best practices')
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: storageSku
  }
  kind: storageKind
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    accessTier: accessTier
    allowBlobPublicAccess: false
    allowCrossTenantReplication: false
    allowSharedKeyAccess: true // Set to false for AAD-only auth
    defaultToOAuthAuthentication: true
    dnsEndpointType: 'Standard'
    encryption: {
      keySource: 'Microsoft.Storage'
      requireInfrastructureEncryption: true
      services: {
        blob: {
          enabled: true
          keyType: 'Account'
        }
        file: {
          enabled: true
          keyType: 'Account'
        }
        queue: {
          enabled: true
          keyType: 'Account'
        }
        table: {
          enabled: true
          keyType: 'Account'
        }
      }
    }
    isHnsEnabled: enableHierarchicalNamespace
    isLocalUserEnabled: false
    isSftpEnabled: false
    largeFileSharesState: 'Disabled'
    minimumTlsVersion: 'TLS1_2'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow' // Set to 'Deny' for Private Link only
      ipRules: []
      virtualNetworkRules: []
    }
    publicNetworkAccess: 'Enabled' // Set to 'Disabled' for Private Link only
    supportsHttpsTrafficOnly: true
  }
}

// ============================================================================
// Resources - Blob Services Configuration
// ============================================================================

@description('Blob service configuration')
resource blobServices 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    automaticSnapshotPolicyEnabled: false
    changeFeed: {
      enabled: enableChangeFeed
      retentionInDays: pointInTimeRestoreDays + 1
    }
    containerDeleteRetentionPolicy: {
      enabled: enableContainerSoftDelete
      days: containerSoftDeleteRetentionDays
    }
    cors: {
      corsRules: []
    }
    deleteRetentionPolicy: {
      enabled: enableBlobSoftDelete
      days: blobSoftDeleteRetentionDays
      allowPermanentDelete: false
    }
    isVersioningEnabled: enableBlobVersioning
    restorePolicy: enablePointInTimeRestore ? {
      enabled: true
      days: pointInTimeRestoreDays
    } : null
  }
}

// ============================================================================
// Resources - Containers
// ============================================================================

@description('Blob containers')
resource containers 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = [for containerName in containerNames: {
  parent: blobServices
  name: containerName
  properties: {
    defaultEncryptionScope: '$account-encryption-key'
    denyEncryptionScopeOverride: false
    publicAccess: 'None'
  }
}]

// ============================================================================
// Resources - Lifecycle Management Policy
// ============================================================================

@description('Lifecycle management policy for automatic tiering')
resource lifecyclePolicy 'Microsoft.Storage/storageAccounts/managementPolicies@2023-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    policy: {
      rules: [
        {
          name: 'tierToCoolRule'
          enabled: true
          type: 'Lifecycle'
          definition: {
            filters: {
              blobTypes: [
                'blockBlob'
              ]
              prefixMatch: [
                'data/'
                'logs/'
              ]
            }
            actions: {
              baseBlob: {
                tierToCool: {
                  daysAfterModificationGreaterThan: daysToCoolTier
                }
                tierToArchive: {
                  daysAfterModificationGreaterThan: daysToArchiveTier
                }
                delete: {
                  daysAfterModificationGreaterThan: daysToDeleteBlob
                }
              }
              snapshot: {
                tierToCool: {
                  daysAfterCreationGreaterThan: daysToCoolTier
                }
                delete: {
                  daysAfterCreationGreaterThan: daysToDeleteBlob
                }
              }
              version: {
                tierToCool: {
                  daysAfterCreationGreaterThan: daysToCoolTier
                }
                delete: {
                  daysAfterCreationGreaterThan: daysToDeleteBlob
                }
              }
            }
          }
        }
        {
          name: 'archiveBackupsRule'
          enabled: true
          type: 'Lifecycle'
          definition: {
            filters: {
              blobTypes: [
                'blockBlob'
              ]
              prefixMatch: [
                'backups/'
              ]
            }
            actions: {
              baseBlob: {
                tierToArchive: {
                  daysAfterModificationGreaterThan: 7
                }
                delete: {
                  daysAfterModificationGreaterThan: 730 // 2 years
                }
              }
            }
          }
        }
        {
          name: 'deleteOldVersionsRule'
          enabled: true
          type: 'Lifecycle'
          definition: {
            filters: {
              blobTypes: [
                'blockBlob'
              ]
            }
            actions: {
              version: {
                delete: {
                  daysAfterCreationGreaterThan: 90
                }
              }
            }
          }
        }
      ]
    }
  }
}

// ============================================================================
// Resources - Diagnostic Settings (requires Log Analytics workspace)
// ============================================================================

// Uncomment and configure with your Log Analytics workspace ID
// @description('Diagnostic settings for storage account')
// resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
//   name: 'storage-diagnostics'
//   scope: blobServices
//   properties: {
//     workspaceId: logAnalyticsWorkspaceId
//     logs: [
//       {
//         category: 'StorageRead'
//         enabled: true
//       }
//       {
//         category: 'StorageWrite'
//         enabled: true
//       }
//       {
//         category: 'StorageDelete'
//         enabled: true
//       }
//     ]
//     metrics: [
//       {
//         category: 'Transaction'
//         enabled: true
//       }
//     ]
//   }
// }

// ============================================================================
// Outputs
// ============================================================================

@description('Storage account name')
output storageAccountName string = storageAccount.name

@description('Storage account ID')
output storageAccountId string = storageAccount.id

@description('Storage account primary blob endpoint')
output primaryBlobEndpoint string = storageAccount.properties.primaryEndpoints.blob

@description('Storage account primary file endpoint')
output primaryFileEndpoint string = storageAccount.properties.primaryEndpoints.file

@description('Storage account primary queue endpoint')
output primaryQueueEndpoint string = storageAccount.properties.primaryEndpoints.queue

@description('Storage account primary table endpoint')
output primaryTableEndpoint string = storageAccount.properties.primaryEndpoints.table

@description('Storage account primary DFS endpoint (Data Lake)')
output primaryDfsEndpoint string = storageAccount.properties.primaryEndpoints.dfs

@description('System-assigned managed identity principal ID')
output identityPrincipalId string = storageAccount.identity.principalId

@description('Container names created')
output containerNames array = [for (name, i) in containerNames: containers[i].name]

@description('Connection string template (use managed identity in production)')
output connectionStringTemplate string = 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey={your-key}'

@description('Blob service resource ID')
output blobServiceId string = blobServices.id
