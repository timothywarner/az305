@description('The location for all resources')
param location string = resourceGroup().location

@description('The name of the storage account')
param storageAccountName string

@description('The name of the Log Analytics workspace')
param logAnalyticsWorkspaceName string

@description('The SKU name for the storage account')
param storageAccountSku string = 'Standard_LRS'

@description('Enable blob encryption at rest')
param enableBlobEncryption bool = true

@description('Enable file encryption at rest')
param enableFileEncryption bool = true

@description('Enable table encryption at rest')
param enableTableEncryption bool = true

@description('Enable queue encryption at rest')
param enableQueueEncryption bool = true

// Log Analytics Workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// Storage Account
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: storageAccountSku
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    supportsHttpsTrafficOnly: true
    encryption: {
      services: {
        blob: {
          enabled: enableBlobEncryption
        }
        file: {
          enabled: enableFileEncryption
        }
        table: {
          enabled: enableTableEncryption
        }
        queue: {
          enabled: enableQueueEncryption
        }
      }
      keySource: 'Microsoft.Storage'
    }
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }
  }
}

// Diagnostic Settings for Storage Account
resource storageDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${storageAccount.name}-diagnostics'
  scope: storageAccount
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        category: 'StorageRead'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 30
        }
      }
      {
        category: 'StorageWrite'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 30
        }
      }
      {
        category: 'StorageDelete'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 30
        }
      }
      {
        category: 'Transaction'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 30
        }
      }
      {
        category: 'Capacity'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 30
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 30
        }
      }
    ]
  }
}

// Outputs
output storageAccountId string = storageAccount.id
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id 
