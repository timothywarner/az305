// ============================================================================
// Azure SQL Database with Elastic Pool and Auto-Failover Group
// ============================================================================
// Purpose: Deploy Azure SQL with elastic pool for multi-tenant scenarios
// AZ-305 Exam Objectives:
//   - Design data storage solutions (Objective 2.1)
//   - Design a solution for backup and disaster recovery (Objective 3.1)
//   - Design high availability solutions (Objective 3.2)
// Prerequisites:
//   - Two resource groups in different regions for failover
//   - Azure AD admin configured for SQL Server
// ============================================================================

targetScope = 'resourceGroup'

// ============================================================================
// Parameters
// ============================================================================

@description('Name prefix for SQL Server resources.')
@minLength(1)
@maxLength(20)
param sqlServerNamePrefix string

@description('Primary region for SQL Server.')
param primaryLocation string = resourceGroup().location

@description('Secondary region for failover.')
param secondaryLocation string = 'westus2'

@description('Azure AD administrator object ID.')
param aadAdminObjectId string

@description('Azure AD administrator login name.')
param aadAdminLogin string = 'sql-admin-group'

@description('SQL administrator login username.')
param sqlAdminLogin string = 'sqladmin'

@description('SQL administrator login password.')
@secure()
param sqlAdminPassword string

@description('Elastic pool name.')
param elasticPoolName string = 'pool-standard'

@description('Elastic pool SKU.')
@allowed([
  'BasicPool'
  'StandardPool'
  'PremiumPool'
  'GP_Gen5'
  'BC_Gen5'
])
param elasticPoolSku string = 'GP_Gen5'

@description('Elastic pool capacity (DTUs or vCores based on SKU).')
param elasticPoolCapacity int = 2

@description('Elastic pool max size in GB.')
param elasticPoolMaxSizeGB int = 32

@description('Database names to create in the elastic pool.')
param databaseNames array = [
  'db-tenant1'
  'db-tenant2'
  'db-shared'
]

@description('Failover group name (must be globally unique).')
param failoverGroupName string

@description('Failover policy: Automatic or Manual.')
@allowed([
  'Automatic'
  'Manual'
])
param failoverPolicy string = 'Automatic'

@description('Grace period in minutes for automatic failover.')
param gracePeriodMinutes int = 60

@description('Tags to apply to resources.')
param tags object = {
  environment: 'production'
  purpose: 'database'
  examObjective: 'AZ-305-DataStorage'
}

// ============================================================================
// Variables
// ============================================================================

var primaryServerName = 'sql-${sqlServerNamePrefix}-primary-${uniqueString(resourceGroup().id)}'
var secondaryServerName = 'sql-${sqlServerNamePrefix}-secondary-${uniqueString(resourceGroup().id)}'

// ============================================================================
// Resources - Primary SQL Server
// ============================================================================

@description('Primary Azure SQL Server')
resource primarySqlServer 'Microsoft.Sql/servers@2023-05-01-preview' = {
  name: primaryServerName
  location: primaryLocation
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    administratorLogin: sqlAdminLogin
    administratorLoginPassword: sqlAdminPassword
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled' // Set to 'Disabled' for Private Link only
    administrators: {
      administratorType: 'ActiveDirectory'
      azureADOnlyAuthentication: false // Set to true for AAD-only auth
      login: aadAdminLogin
      sid: aadAdminObjectId
      tenantId: tenant().tenantId
      principalType: 'Group'
    }
  }
}

@description('Primary SQL Server firewall rule - Allow Azure Services')
resource primaryFirewallAzure 'Microsoft.Sql/servers/firewallRules@2023-05-01-preview' = {
  parent: primarySqlServer
  name: 'AllowAllAzureIps'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

@description('Auditing settings for primary SQL Server')
resource primaryAuditSettings 'Microsoft.Sql/servers/auditingSettings@2023-05-01-preview' = {
  parent: primarySqlServer
  name: 'default'
  properties: {
    state: 'Enabled'
    isAzureMonitorTargetEnabled: true
    retentionDays: 90
  }
}

@description('Threat detection settings for primary SQL Server')
resource primaryThreatDetection 'Microsoft.Sql/servers/securityAlertPolicies@2023-05-01-preview' = {
  parent: primarySqlServer
  name: 'default'
  properties: {
    state: 'Enabled'
    emailAccountAdmins: true
  }
}

// ============================================================================
// Resources - Elastic Pool on Primary Server
// ============================================================================

@description('Elastic pool on primary server')
resource primaryElasticPool 'Microsoft.Sql/servers/elasticPools@2023-05-01-preview' = {
  parent: primarySqlServer
  name: elasticPoolName
  location: primaryLocation
  tags: tags
  sku: {
    name: elasticPoolSku
    tier: elasticPoolSku == 'GP_Gen5' ? 'GeneralPurpose' : elasticPoolSku == 'BC_Gen5' ? 'BusinessCritical' : 'Standard'
    capacity: elasticPoolCapacity
    family: contains(elasticPoolSku, 'Gen5') ? 'Gen5' : null
  }
  properties: {
    maxSizeBytes: elasticPoolMaxSizeGB * 1073741824 // Convert GB to bytes
    perDatabaseSettings: {
      minCapacity: 0
      maxCapacity: elasticPoolCapacity
    }
    zoneRedundant: elasticPoolSku == 'BC_Gen5' ? true : false
  }
}

// ============================================================================
// Resources - Databases in Elastic Pool
// ============================================================================

@description('Databases in the elastic pool')
resource databases 'Microsoft.Sql/servers/databases@2023-05-01-preview' = [for dbName in databaseNames: {
  parent: primarySqlServer
  name: dbName
  location: primaryLocation
  tags: tags
  sku: {
    name: 'ElasticPool'
    tier: elasticPoolSku == 'GP_Gen5' ? 'GeneralPurpose' : elasticPoolSku == 'BC_Gen5' ? 'BusinessCritical' : 'Standard'
    capacity: 0
  }
  properties: {
    elasticPoolId: primaryElasticPool.id
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: 10737418240 // 10 GB per database
    catalogCollation: 'SQL_Latin1_General_CP1_CI_AS'
    zoneRedundant: elasticPoolSku == 'BC_Gen5' ? true : false
    readScale: 'Disabled'
    requestedBackupStorageRedundancy: 'Geo'
  }
}]

// ============================================================================
// Resources - Secondary SQL Server for Failover
// ============================================================================

@description('Secondary Azure SQL Server for failover')
resource secondarySqlServer 'Microsoft.Sql/servers@2023-05-01-preview' = {
  name: secondaryServerName
  location: secondaryLocation
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    administratorLogin: sqlAdminLogin
    administratorLoginPassword: sqlAdminPassword
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
    administrators: {
      administratorType: 'ActiveDirectory'
      azureADOnlyAuthentication: false
      login: aadAdminLogin
      sid: aadAdminObjectId
      tenantId: tenant().tenantId
      principalType: 'Group'
    }
  }
}

@description('Secondary SQL Server firewall rule - Allow Azure Services')
resource secondaryFirewallAzure 'Microsoft.Sql/servers/firewallRules@2023-05-01-preview' = {
  parent: secondarySqlServer
  name: 'AllowAllAzureIps'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

@description('Elastic pool on secondary server (required for failover)')
resource secondaryElasticPool 'Microsoft.Sql/servers/elasticPools@2023-05-01-preview' = {
  parent: secondarySqlServer
  name: elasticPoolName
  location: secondaryLocation
  tags: tags
  sku: {
    name: elasticPoolSku
    tier: elasticPoolSku == 'GP_Gen5' ? 'GeneralPurpose' : elasticPoolSku == 'BC_Gen5' ? 'BusinessCritical' : 'Standard'
    capacity: elasticPoolCapacity
    family: contains(elasticPoolSku, 'Gen5') ? 'Gen5' : null
  }
  properties: {
    maxSizeBytes: elasticPoolMaxSizeGB * 1073741824
    perDatabaseSettings: {
      minCapacity: 0
      maxCapacity: elasticPoolCapacity
    }
    zoneRedundant: elasticPoolSku == 'BC_Gen5' ? true : false
  }
}

// ============================================================================
// Resources - Failover Group
// ============================================================================

@description('Auto-failover group for high availability')
resource failoverGroup 'Microsoft.Sql/servers/failoverGroups@2023-05-01-preview' = {
  parent: primarySqlServer
  name: failoverGroupName
  properties: {
    readWriteEndpoint: {
      failoverPolicy: failoverPolicy
      failoverWithDataLossGracePeriodMinutes: failoverPolicy == 'Automatic' ? gracePeriodMinutes : null
    }
    readOnlyEndpoint: {
      failoverPolicy: 'Enabled'
    }
    partnerServers: [
      {
        id: secondarySqlServer.id
      }
    ]
    databases: [for (dbName, i) in databaseNames: databases[i].id]
  }
  dependsOn: [
    secondaryElasticPool // Elastic pool must exist on secondary before failover group
  ]
}

// ============================================================================
// Outputs
// ============================================================================

@description('Primary SQL Server fully qualified domain name')
output primaryServerFqdn string = primarySqlServer.properties.fullyQualifiedDomainName

@description('Secondary SQL Server fully qualified domain name')
output secondaryServerFqdn string = secondarySqlServer.properties.fullyQualifiedDomainName

@description('Failover group read-write endpoint')
output failoverGroupReadWriteEndpoint string = '${failoverGroupName}.database.windows.net'

@description('Failover group read-only endpoint')
output failoverGroupReadOnlyEndpoint string = '${failoverGroupName}.secondary.database.windows.net'

@description('Primary SQL Server resource ID')
output primaryServerId string = primarySqlServer.id

@description('Secondary SQL Server resource ID')
output secondaryServerId string = secondarySqlServer.id

@description('Elastic pool resource ID')
output elasticPoolId string = primaryElasticPool.id

@description('Database resource IDs')
output databaseIds array = [for (dbName, i) in databaseNames: databases[i].id]

@description('Connection string template (use failover group endpoint)')
output connectionStringTemplate string = 'Server=tcp:${failoverGroupName}.database.windows.net,1433;Database={database_name};Authentication=Active Directory Default;Encrypt=True;TrustServerCertificate=False;'
