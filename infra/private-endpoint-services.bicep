// ============================================================================
// Private Endpoints for Azure PaaS Services
// ============================================================================
// Purpose: Deploy private endpoints with Private DNS integration
// AZ-305 Exam Objectives:
//   - Design a solution for network connectivity (Objective 4.2)
//   - Design a solution for managing secrets, keys, and certificates (Objective 2.4)
// Prerequisites:
//   - Virtual network with subnet for private endpoints
//   - Private DNS zones for target services
//   - Target PaaS services must exist
// ============================================================================

targetScope = 'resourceGroup'

// ============================================================================
// Parameters
// ============================================================================

@description('Name prefix for private endpoint resources.')
@minLength(1)
@maxLength(20)
param namePrefix string

@description('Azure region for the resources.')
param location string = resourceGroup().location

@description('Virtual network resource ID.')
param vnetId string

@description('Subnet name for private endpoints.')
param privateEndpointSubnetName string = 'PrivateEndpoints'

@description('Deploy private endpoint for Storage Blob.')
param deployStorageBlobEndpoint bool = false

@description('Storage account resource ID for blob endpoint.')
param storageAccountId string = ''

@description('Deploy private endpoint for Key Vault.')
param deployKeyVaultEndpoint bool = false

@description('Key Vault resource ID.')
param keyVaultId string = ''

@description('Deploy private endpoint for SQL Database.')
param deploySqlEndpoint bool = false

@description('SQL Server resource ID.')
param sqlServerId string = ''

@description('Deploy private endpoint for Cosmos DB.')
param deployCosmosDbEndpoint bool = false

@description('Cosmos DB account resource ID.')
param cosmosDbAccountId string = ''

@description('Deploy private endpoint for Container Registry.')
param deployAcrEndpoint bool = false

@description('Container Registry resource ID.')
param acrId string = ''

@description('Create Private DNS zones.')
param createPrivateDnsZones bool = true

@description('Link DNS zones to virtual network.')
param linkDnsZonesToVnet bool = true

@description('Tags to apply to resources.')
param tags object = {
  environment: 'production'
  purpose: 'private-endpoints'
  examObjective: 'AZ-305-Networking'
}

// ============================================================================
// Variables
// ============================================================================

var privateEndpointSubnetId = '${vnetId}/subnets/${privateEndpointSubnetName}'

// DNS zone names for Azure services
var privateDnsZones = {
  blob: 'privatelink.blob.${environment().suffixes.storage}'
  keyVault: 'privatelink.vaultcore.azure.net'
  sql: 'privatelink${environment().suffixes.sqlServerHostname}'
  cosmosDb: 'privatelink.documents.azure.com'
  acr: 'privatelink.azurecr.io'
}

// ============================================================================
// Resources - Private DNS Zones
// ============================================================================

@description('Private DNS zone for Storage Blob')
resource blobDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (createPrivateDnsZones && deployStorageBlobEndpoint) {
  name: privateDnsZones.blob
  location: 'global'
  tags: tags
}

@description('Private DNS zone for Key Vault')
resource keyVaultDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (createPrivateDnsZones && deployKeyVaultEndpoint) {
  name: privateDnsZones.keyVault
  location: 'global'
  tags: tags
}

@description('Private DNS zone for SQL Database')
resource sqlDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (createPrivateDnsZones && deploySqlEndpoint) {
  name: privateDnsZones.sql
  location: 'global'
  tags: tags
}

@description('Private DNS zone for Cosmos DB')
resource cosmosDbDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (createPrivateDnsZones && deployCosmosDbEndpoint) {
  name: privateDnsZones.cosmosDb
  location: 'global'
  tags: tags
}

@description('Private DNS zone for Container Registry')
resource acrDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (createPrivateDnsZones && deployAcrEndpoint) {
  name: privateDnsZones.acr
  location: 'global'
  tags: tags
}

// ============================================================================
// Resources - Private DNS Zone VNet Links
// ============================================================================

@description('Blob DNS zone VNet link')
resource blobDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (createPrivateDnsZones && linkDnsZonesToVnet && deployStorageBlobEndpoint) {
  parent: blobDnsZone
  name: '${namePrefix}-blob-link'
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

@description('Key Vault DNS zone VNet link')
resource keyVaultDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (createPrivateDnsZones && linkDnsZonesToVnet && deployKeyVaultEndpoint) {
  parent: keyVaultDnsZone
  name: '${namePrefix}-keyvault-link'
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

@description('SQL DNS zone VNet link')
resource sqlDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (createPrivateDnsZones && linkDnsZonesToVnet && deploySqlEndpoint) {
  parent: sqlDnsZone
  name: '${namePrefix}-sql-link'
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

@description('Cosmos DB DNS zone VNet link')
resource cosmosDbDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (createPrivateDnsZones && linkDnsZonesToVnet && deployCosmosDbEndpoint) {
  parent: cosmosDbDnsZone
  name: '${namePrefix}-cosmosdb-link'
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

@description('ACR DNS zone VNet link')
resource acrDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (createPrivateDnsZones && linkDnsZonesToVnet && deployAcrEndpoint) {
  parent: acrDnsZone
  name: '${namePrefix}-acr-link'
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

// ============================================================================
// Resources - Private Endpoints
// ============================================================================

@description('Storage Blob private endpoint')
resource storageBlobEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = if (deployStorageBlobEndpoint && !empty(storageAccountId)) {
  name: 'pe-${namePrefix}-blob'
  location: location
  tags: tags
  properties: {
    customNetworkInterfaceName: 'nic-pe-${namePrefix}-blob'
    privateLinkServiceConnections: [
      {
        name: 'pe-${namePrefix}-blob'
        properties: {
          privateLinkServiceId: storageAccountId
          groupIds: [
            'blob'
          ]
        }
      }
    ]
    subnet: {
      id: privateEndpointSubnetId
    }
  }
}

@description('Storage Blob DNS zone group')
resource storageBlobDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-09-01' = if (deployStorageBlobEndpoint && createPrivateDnsZones) {
  parent: storageBlobEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'blob-config'
        properties: {
          privateDnsZoneId: blobDnsZone.id
        }
      }
    ]
  }
}

@description('Key Vault private endpoint')
resource keyVaultEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = if (deployKeyVaultEndpoint && !empty(keyVaultId)) {
  name: 'pe-${namePrefix}-keyvault'
  location: location
  tags: tags
  properties: {
    customNetworkInterfaceName: 'nic-pe-${namePrefix}-keyvault'
    privateLinkServiceConnections: [
      {
        name: 'pe-${namePrefix}-keyvault'
        properties: {
          privateLinkServiceId: keyVaultId
          groupIds: [
            'vault'
          ]
        }
      }
    ]
    subnet: {
      id: privateEndpointSubnetId
    }
  }
}

@description('Key Vault DNS zone group')
resource keyVaultDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-09-01' = if (deployKeyVaultEndpoint && createPrivateDnsZones) {
  parent: keyVaultEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'keyvault-config'
        properties: {
          privateDnsZoneId: keyVaultDnsZone.id
        }
      }
    ]
  }
}

@description('SQL Server private endpoint')
resource sqlEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = if (deploySqlEndpoint && !empty(sqlServerId)) {
  name: 'pe-${namePrefix}-sql'
  location: location
  tags: tags
  properties: {
    customNetworkInterfaceName: 'nic-pe-${namePrefix}-sql'
    privateLinkServiceConnections: [
      {
        name: 'pe-${namePrefix}-sql'
        properties: {
          privateLinkServiceId: sqlServerId
          groupIds: [
            'sqlServer'
          ]
        }
      }
    ]
    subnet: {
      id: privateEndpointSubnetId
    }
  }
}

@description('SQL DNS zone group')
resource sqlDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-09-01' = if (deploySqlEndpoint && createPrivateDnsZones) {
  parent: sqlEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'sql-config'
        properties: {
          privateDnsZoneId: sqlDnsZone.id
        }
      }
    ]
  }
}

@description('Cosmos DB private endpoint')
resource cosmosDbEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = if (deployCosmosDbEndpoint && !empty(cosmosDbAccountId)) {
  name: 'pe-${namePrefix}-cosmosdb'
  location: location
  tags: tags
  properties: {
    customNetworkInterfaceName: 'nic-pe-${namePrefix}-cosmosdb'
    privateLinkServiceConnections: [
      {
        name: 'pe-${namePrefix}-cosmosdb'
        properties: {
          privateLinkServiceId: cosmosDbAccountId
          groupIds: [
            'Sql'
          ]
        }
      }
    ]
    subnet: {
      id: privateEndpointSubnetId
    }
  }
}

@description('Cosmos DB DNS zone group')
resource cosmosDbDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-09-01' = if (deployCosmosDbEndpoint && createPrivateDnsZones) {
  parent: cosmosDbEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'cosmosdb-config'
        properties: {
          privateDnsZoneId: cosmosDbDnsZone.id
        }
      }
    ]
  }
}

@description('Container Registry private endpoint')
resource acrEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = if (deployAcrEndpoint && !empty(acrId)) {
  name: 'pe-${namePrefix}-acr'
  location: location
  tags: tags
  properties: {
    customNetworkInterfaceName: 'nic-pe-${namePrefix}-acr'
    privateLinkServiceConnections: [
      {
        name: 'pe-${namePrefix}-acr'
        properties: {
          privateLinkServiceId: acrId
          groupIds: [
            'registry'
          ]
        }
      }
    ]
    subnet: {
      id: privateEndpointSubnetId
    }
  }
}

@description('ACR DNS zone group')
resource acrDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-09-01' = if (deployAcrEndpoint && createPrivateDnsZones) {
  parent: acrEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'acr-config'
        properties: {
          privateDnsZoneId: acrDnsZone.id
        }
      }
    ]
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('Storage Blob private endpoint ID')
output storageBlobEndpointId string = deployStorageBlobEndpoint ? storageBlobEndpoint.id : ''

@description('Storage Blob private IP')
output storageBlobPrivateIp string = deployStorageBlobEndpoint ? storageBlobEndpoint.properties.customDnsConfigs[0].ipAddresses[0] : ''

@description('Key Vault private endpoint ID')
output keyVaultEndpointId string = deployKeyVaultEndpoint ? keyVaultEndpoint.id : ''

@description('Key Vault private IP')
output keyVaultPrivateIp string = deployKeyVaultEndpoint ? keyVaultEndpoint.properties.customDnsConfigs[0].ipAddresses[0] : ''

@description('SQL Server private endpoint ID')
output sqlEndpointId string = deploySqlEndpoint ? sqlEndpoint.id : ''

@description('SQL Server private IP')
output sqlPrivateIp string = deploySqlEndpoint ? sqlEndpoint.properties.customDnsConfigs[0].ipAddresses[0] : ''

@description('Cosmos DB private endpoint ID')
output cosmosDbEndpointId string = deployCosmosDbEndpoint ? cosmosDbEndpoint.id : ''

@description('Cosmos DB private IP')
output cosmosDbPrivateIp string = deployCosmosDbEndpoint ? cosmosDbEndpoint.properties.customDnsConfigs[0].ipAddresses[0] : ''

@description('Container Registry private endpoint ID')
output acrEndpointId string = deployAcrEndpoint ? acrEndpoint.id : ''

@description('Container Registry private IP')
output acrPrivateIp string = deployAcrEndpoint ? acrEndpoint.properties.customDnsConfigs[0].ipAddresses[0] : ''

@description('Private DNS zone IDs')
output privateDnsZoneIds object = {
  blob: createPrivateDnsZones && deployStorageBlobEndpoint ? blobDnsZone.id : ''
  keyVault: createPrivateDnsZones && deployKeyVaultEndpoint ? keyVaultDnsZone.id : ''
  sql: createPrivateDnsZones && deploySqlEndpoint ? sqlDnsZone.id : ''
  cosmosDb: createPrivateDnsZones && deployCosmosDbEndpoint ? cosmosDbDnsZone.id : ''
  acr: createPrivateDnsZones && deployAcrEndpoint ? acrDnsZone.id : ''
}
