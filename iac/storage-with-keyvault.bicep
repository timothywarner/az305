@description('The location for all resources')
param location string = resourceGroup().location

@description('The name of the storage account')
param storageAccountName string

@description('The name of the key vault')
param keyVaultName string

@description('The object ID of the user or service principal that will have access to the key vault')
param keyVaultAccessPolicyObjectId string

@description('The tenant ID of the subscription')
param tenantId string = subscription().tenantId

@description('The expiration date for the storage account keys')
param keyExpirationDate string = dateTimeAdd(utcNow(), 'P45D')

// Storage Account
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    networkAcls: {
      defaultAction: 'Deny'
    }
  }
}

// Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    enabledForDeployment: true
    enabledForTemplateDeployment: true
    enabledForDiskEncryption: true
    tenantId: tenantId
    accessPolicies: [
      {
        tenantId: tenantId
        objectId: keyVaultAccessPolicyObjectId
        permissions: {
          secrets: [
            'get'
            'list'
            'set'
          ]
          keys: [
            'get'
            'list'
            'create'
            'delete'
            'update'
            'import'
            'backup'
            'restore'
            'recover'
            'purge'
          ]
        }
      }
    ]
    sku: {
      name: 'standard'
      family: 'A'
    }
  }
}

// Store Storage Account Keys in Key Vault
resource storageAccountKey1 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: '${keyVault.name}/storageAccountKey1'
  properties: {
    value: listKeys('${storageAccount.id}', storageAccount.apiVersion).keys[0].value
    attributes: {
      enabled: true
      expires: keyExpirationDate
    }
  }
  dependsOn: [
    storageAccount
    keyVault
  ]
}

resource storageAccountKey2 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: '${keyVault.name}/storageAccountKey2'
  properties: {
    value: listKeys('${storageAccount.id}', storageAccount.apiVersion).keys[1].value
    attributes: {
      enabled: true
      expires: keyExpirationDate
    }
  }
  dependsOn: [
    storageAccount
    keyVault
  ]
}

// Output the Key Vault URI
output keyVaultUri string = keyVault.properties.vaultUri 
