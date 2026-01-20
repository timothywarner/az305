// ============================================================================
// Azure Cosmos DB with Multi-Region Writes
// ============================================================================
// Purpose: Deploy globally distributed Cosmos DB with multi-region writes
// AZ-305 Exam Objectives:
//   - Design data storage solutions (Objective 2.1)
//   - Design high availability solutions (Objective 3.2)
//   - Design a solution for backup and disaster recovery (Objective 3.1)
// Prerequisites:
//   - Resource group must exist
//   - Consider cost implications of multi-region writes
// ============================================================================

targetScope = 'resourceGroup'

// ============================================================================
// Parameters
// ============================================================================

@description('Name of the Cosmos DB account.')
@minLength(3)
@maxLength(44)
param cosmosAccountName string

@description('Primary region for Cosmos DB.')
param primaryLocation string = resourceGroup().location

@description('Additional regions for multi-region writes.')
param additionalLocations array = [
  'westus2'
  'northeurope'
]

@description('Enable multi-region writes.')
param enableMultiRegionWrites bool = true

@description('Default consistency level.')
@allowed([
  'Eventual'
  'ConsistentPrefix'
  'Session'
  'BoundedStaleness'
  'Strong'
])
param defaultConsistencyLevel string = 'Session'

@description('Max staleness prefix for BoundedStaleness consistency.')
param maxStalenessPrefix int = 100000

@description('Max interval in seconds for BoundedStaleness consistency.')
param maxIntervalInSeconds int = 300

@description('Enable automatic failover.')
param enableAutomaticFailover bool = true

@description('Database name.')
param databaseName string = 'appdb'

@description('Container name.')
param containerName string = 'items'

@description('Partition key path.')
param partitionKeyPath string = '/partitionKey'

@description('Container throughput in RU/s (0 for autoscale).')
param containerThroughput int = 0

@description('Autoscale max throughput in RU/s.')
param autoscaleMaxThroughput int = 4000

@description('Enable serverless mode (overrides throughput settings).')
param enableServerless bool = false

@description('Enable analytical store.')
param enableAnalyticalStore bool = false

@description('Tags to apply to resources.')
param tags object = {
  environment: 'production'
  purpose: 'cosmos-database'
  examObjective: 'AZ-305-DataStorage'
}

// ============================================================================
// Variables
// ============================================================================

var accountName = 'cosmos-${cosmosAccountName}-${uniqueString(resourceGroup().id)}'
var locations = concat(
  [
    {
      locationName: primaryLocation
      failoverPriority: 0
      isZoneRedundant: true
    }
  ],
  [for (location, i) in additionalLocations: {
    locationName: location
    failoverPriority: i + 1
    isZoneRedundant: true
  }]
)

var consistencyPolicy = {
  Eventual: {
    defaultConsistencyLevel: 'Eventual'
  }
  ConsistentPrefix: {
    defaultConsistencyLevel: 'ConsistentPrefix'
  }
  Session: {
    defaultConsistencyLevel: 'Session'
  }
  BoundedStaleness: {
    defaultConsistencyLevel: 'BoundedStaleness'
    maxStalenessPrefix: maxStalenessPrefix
    maxIntervalInSeconds: maxIntervalInSeconds
  }
  Strong: {
    defaultConsistencyLevel: 'Strong'
  }
}

var capabilities = enableServerless ? [
  {
    name: 'EnableServerless'
  }
] : []

// ============================================================================
// Resources - Cosmos DB Account
// ============================================================================

@description('Azure Cosmos DB account with multi-region configuration')
resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2024-02-15-preview' = {
  name: accountName
  location: primaryLocation
  tags: tags
  kind: 'GlobalDocumentDB'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publicNetworkAccess: 'Enabled' // Set to 'Disabled' for Private Link only
    enableAutomaticFailover: enableAutomaticFailover
    enableMultipleWriteLocations: enableServerless ? false : enableMultiRegionWrites
    isVirtualNetworkFilterEnabled: false
    virtualNetworkRules: []
    disableKeyBasedMetadataWriteAccess: false
    enableFreeTier: false
    enableAnalyticalStorage: enableAnalyticalStore
    analyticalStorageConfiguration: enableAnalyticalStore ? {
      schemaType: 'WellDefined'
    } : null
    databaseAccountOfferType: 'Standard'
    defaultIdentity: 'FirstPartyIdentity'
    networkAclBypass: 'None'
    disableLocalAuth: false // Set to true for AAD-only auth
    enablePartitionMerge: false
    enableBurstCapacity: false
    minimalTlsVersion: 'Tls12'
    consistencyPolicy: consistencyPolicy[defaultConsistencyLevel]
    locations: locations
    cors: []
    capabilities: capabilities
    ipRules: []
    backupPolicy: {
      type: 'Continuous'
      continuousModeProperties: {
        tier: 'Continuous7Days'
      }
    }
    networkAclBypassResourceIds: []
  }
}

// ============================================================================
// Resources - SQL Database
// ============================================================================

@description('Cosmos DB SQL Database')
resource database 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-02-15-preview' = {
  parent: cosmosAccount
  name: databaseName
  properties: {
    resource: {
      id: databaseName
    }
  }
}

// ============================================================================
// Resources - SQL Container with Autoscale
// ============================================================================

@description('Cosmos DB SQL Container')
resource container 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-02-15-preview' = {
  parent: database
  name: containerName
  properties: {
    resource: {
      id: containerName
      indexingPolicy: {
        indexingMode: 'consistent'
        automatic: true
        includedPaths: [
          {
            path: '/*'
          }
        ]
        excludedPaths: [
          {
            path: '/"_etag"/?'
          }
        ]
        compositeIndexes: []
        spatialIndexes: []
      }
      partitionKey: {
        paths: [
          partitionKeyPath
        ]
        kind: 'Hash'
        version: 2
      }
      uniqueKeyPolicy: {
        uniqueKeys: []
      }
      conflictResolutionPolicy: {
        mode: 'LastWriterWins'
        conflictResolutionPath: '/_ts'
      }
      computedProperties: []
      analyticalStorageTtl: enableAnalyticalStore ? -1 : null
    }
    options: enableServerless ? {} : (containerThroughput > 0 ? {
      throughput: containerThroughput
    } : {
      autoscaleSettings: {
        maxThroughput: autoscaleMaxThroughput
      }
    })
  }
}

// ============================================================================
// Resources - Role Definitions and Assignments (Data Plane RBAC)
// ============================================================================

@description('Built-in Cosmos DB Data Reader role')
var cosmosDataReaderRoleId = '00000000-0000-0000-0000-000000000001'

@description('Built-in Cosmos DB Data Contributor role')
var cosmosDataContributorRoleId = '00000000-0000-0000-0000-000000000002'

// Note: Uncomment to assign roles to a specific principal
// @description('Role assignment for data contributor')
// resource dataContributorAssignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-02-15-preview' = {
//   parent: cosmosAccount
//   name: guid(cosmosAccount.id, principalId, cosmosDataContributorRoleId)
//   properties: {
//     roleDefinitionId: '${cosmosAccount.id}/sqlRoleDefinitions/${cosmosDataContributorRoleId}'
//     principalId: principalId
//     scope: cosmosAccount.id
//   }
// }

// ============================================================================
// Outputs
// ============================================================================

@description('Cosmos DB account name')
output accountName string = cosmosAccount.name

@description('Cosmos DB account ID')
output accountId string = cosmosAccount.id

@description('Cosmos DB account endpoint')
output documentEndpoint string = cosmosAccount.properties.documentEndpoint

@description('Cosmos DB account primary key (reference, use Key Vault in production)')
output primaryMasterKeySecretRef string = 'Use listKeys(${cosmosAccount.id}).primaryMasterKey'

@description('Database name')
output databaseName string = database.name

@description('Container name')
output containerName string = container.name

@description('Write regions')
output writeRegions array = [for location in cosmosAccount.properties.writeLocations: {
  region: location.locationName
  endpoint: location.documentEndpoint
}]

@description('Read regions')
output readRegions array = [for location in cosmosAccount.properties.readLocations: {
  region: location.locationName
  endpoint: location.documentEndpoint
}]

@description('Connection string template (use managed identity in production)')
output connectionStringTemplate string = 'AccountEndpoint=${cosmosAccount.properties.documentEndpoint};AccountKey={your-key};'

@description('System-assigned managed identity principal ID')
output systemIdentityPrincipalId string = cosmosAccount.identity.principalId

@description('Cosmos DB Data Reader role definition ID')
output dataReaderRoleId string = '${cosmosAccount.id}/sqlRoleDefinitions/${cosmosDataReaderRoleId}'

@description('Cosmos DB Data Contributor role definition ID')
output dataContributorRoleId string = '${cosmosAccount.id}/sqlRoleDefinitions/${cosmosDataContributorRoleId}'
