// ============================================================================
// Azure SQL Failover Group (Standalone)
// ============================================================================
// Purpose: Add failover group to existing SQL servers for HA/DR
// AZ-305 Exam Objectives:
//   - Design a solution for backup and disaster recovery (Objective 3.1)
//   - Design high availability solutions (Objective 3.2)
//   - Design data storage solutions (Objective 2.1)
// Prerequisites:
//   - Primary and secondary SQL servers must exist
//   - Databases to add to failover group must exist on primary server
// ============================================================================

targetScope = 'resourceGroup'

// ============================================================================
// Parameters
// ============================================================================

@description('Name of the primary SQL server.')
param primaryServerName string

@description('Name of the secondary SQL server.')
param secondaryServerName string

@description('Resource group name of the secondary server.')
param secondaryServerResourceGroup string = resourceGroup().name

@description('Subscription ID of the secondary server.')
param secondaryServerSubscriptionId string = subscription().subscriptionId

@description('Failover group name (must be globally unique).')
@minLength(1)
@maxLength(63)
param failoverGroupName string

@description('Database names to include in the failover group.')
param databaseNames array

@description('Failover policy: Automatic or Manual.')
@allowed([
  'Automatic'
  'Manual'
])
param failoverPolicy string = 'Automatic'

@description('Grace period in minutes before automatic failover (0 to disable data loss protection).')
@minValue(0)
@maxValue(1440)
param gracePeriodMinutes int = 60

@description('Enable read-only endpoint failover.')
param enableReadOnlyFailover bool = true

@description('Tags to apply to resources.')
param tags object = {
  environment: 'production'
  purpose: 'sql-failover'
  examObjective: 'AZ-305-BusinessContinuity'
}

// ============================================================================
// Existing Resources
// ============================================================================

@description('Reference to existing primary SQL server')
resource primaryServer 'Microsoft.Sql/servers@2023-05-01-preview' existing = {
  name: primaryServerName
}

@description('Reference to existing databases on primary server')
resource databases 'Microsoft.Sql/servers/databases@2023-05-01-preview' existing = [for dbName in databaseNames: {
  parent: primaryServer
  name: dbName
}]

// ============================================================================
// Resources - Failover Group
// ============================================================================

@description('Auto-failover group configuration')
resource failoverGroup 'Microsoft.Sql/servers/failoverGroups@2023-05-01-preview' = {
  parent: primaryServer
  name: failoverGroupName
  tags: tags
  properties: {
    readWriteEndpoint: {
      failoverPolicy: failoverPolicy
      failoverWithDataLossGracePeriodMinutes: failoverPolicy == 'Automatic' && gracePeriodMinutes > 0 ? gracePeriodMinutes : null
    }
    readOnlyEndpoint: {
      failoverPolicy: enableReadOnlyFailover ? 'Enabled' : 'Disabled'
    }
    partnerServers: [
      {
        id: resourceId(secondaryServerSubscriptionId, secondaryServerResourceGroup, 'Microsoft.Sql/servers', secondaryServerName)
      }
    ]
    databases: [for (dbName, i) in databaseNames: databases[i].id]
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('Failover group resource ID')
output failoverGroupId string = failoverGroup.id

@description('Failover group name')
output failoverGroupName string = failoverGroup.name

@description('Read-write listener endpoint')
output readWriteEndpoint string = '${failoverGroupName}.database.windows.net'

@description('Read-only listener endpoint')
output readOnlyEndpoint string = '${failoverGroupName}.secondary.database.windows.net'

@description('Primary server name')
output primaryServerName string = primaryServerName

@description('Secondary server name')
output secondaryServerName string = secondaryServerName

@description('Replication role of primary server')
output primaryReplicationRole string = failoverGroup.properties.replicationRole

@description('Replication state')
output replicationState string = failoverGroup.properties.replicationState

@description('Failover policy')
output configuredFailoverPolicy string = failoverPolicy

@description('Grace period minutes')
output configuredGracePeriodMinutes int = gracePeriodMinutes

@description('Databases in failover group')
output databasesInGroup array = databaseNames

@description('Connection string template using failover group endpoint')
output connectionStringTemplate string = 'Server=tcp:${failoverGroupName}.database.windows.net,1433;Database={database};Authentication=Active Directory Default;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;'

@description('Read-only connection string template')
output readOnlyConnectionStringTemplate string = 'Server=tcp:${failoverGroupName}.secondary.database.windows.net,1433;Database={database};Authentication=Active Directory Default;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;ApplicationIntent=ReadOnly;'
