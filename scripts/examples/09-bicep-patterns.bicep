// ============================================================================
// Title:       AZ-305 Bicep Patterns Reference Template
// Domains:     AZ-305 Domains 2-4 (Data, Business Continuity, Infrastructure)
// Description: Reference Bicep template demonstrating exam-relevant patterns
//              including secure parameters, conditional deployment, loops,
//              modules, outputs, existing resource references, user-defined
//              types, extension resources (diagnostics, locks, RBAC), and
//              architecture patterns (failover, Private Link, blue-green,
//              identity, networking). Teaching examples for code review.
// Author:      Tim Warner
// Date:        January 2026
// Reference:   https://learn.microsoft.com/azure/azure-resource-manager/bicep/overview
// ============================================================================

// ---------------------------------------------------------------------------
// PARAMETERS: Secure handling, decorators, and user-defined types
// ---------------------------------------------------------------------------

@description('The Azure region for all resources. Defaults to the resource group location.')
param location string = resourceGroup().location

@description('Environment name used for naming conventions and conditional logic.')
@allowed(['dev', 'staging', 'prod'])
param environmentName string

@description('The administrator login for SQL Server. Must not be "admin" or "sa".')
@minLength(3)
@maxLength(128)
param sqlAdminLogin string

// EXAM TIP: @secure() prevents the value from appearing in deployment logs,
// portal UI, or template exports. NEVER pass secrets as regular parameters.
// For production, use Key Vault parameter references instead of @secure().
@secure()
@description('SQL admin password. In production, use Key Vault reference instead.')
param sqlAdminPassword string

// EXAM TIP: Key Vault parameter reference is the AZ-305-recommended approach.
// In the parameter file, reference it like:
// "sqlAdminPassword": {
//   "reference": {
//     "keyVault": { "id": "/subscriptions/.../Microsoft.KeyVault/vaults/myVault" },
//     "secretName": "sqlAdminPassword"
//   }
// }

@description('Enable geo-replication for SQL Database (recommended for prod).')
param enableGeoReplication bool = environmentName == 'prod'

@description('Tags applied to all resources for governance and cost allocation.')
param tags object = {
  environment: environmentName
  managedBy: 'bicep'
  costCenter: 'IT-12345'
  owner: 'platform-team@contoso.com'
}

// ---------------------------------------------------------------------------
// USER-DEFINED TYPES: Structured parameter validation
// EXAM TIP: User-defined types (introduced in Bicep 0.12) provide compile-time
// validation for complex parameter shapes. Use them for reusable config objects.
// ---------------------------------------------------------------------------

type subnetConfig = {
  name: string
  addressPrefix: string
  @description('Optional NSG resource ID to associate with this subnet.')
  nsgId: string?
  @description('Service delegation (e.g., Microsoft.Web/serverFarms for App Service).')
  delegation: string?
}

// ---------------------------------------------------------------------------
// VARIABLES: Naming conventions and computed values
// ---------------------------------------------------------------------------

// EXAM TIP: Consistent naming conventions enable Azure Policy enforcement
// and make resource identification easier. AZ-305 recommends the pattern:
// <resource-type>-<workload>-<environment>-<region>-<instance>
var prefix = 'az305'
var uniqueSuffix = uniqueString(resourceGroup().id)
var sqlServerName = '${prefix}-sql-${environmentName}-${uniqueSuffix}'
var sqlDatabaseName = '${prefix}-db-${environmentName}'
var storageAccountName = '${prefix}st${environmentName}${uniqueSuffix}'
var appServicePlanName = '${prefix}-asp-${environmentName}'
var appServiceName = '${prefix}-app-${environmentName}-${uniqueSuffix}'
var keyVaultName = '${prefix}-kv-${environmentName}-${uniqueSuffix}'
var vnetName = '${prefix}-vnet-${environmentName}'
var logAnalyticsName = '${prefix}-law-${environmentName}'

// Subnet configurations using the user-defined type
var subnets = [
  {
    name: 'snet-app'
    addressPrefix: '10.0.1.0/24'
    nsgId: null
    delegation: 'Microsoft.Web/serverFarms'
  }
  {
    name: 'snet-data'
    addressPrefix: '10.0.2.0/24'
    nsgId: null
    delegation: null
  }
  {
    name: 'snet-pe'
    addressPrefix: '10.0.3.0/24'
    nsgId: null
    delegation: null
  }
]

// ---------------------------------------------------------------------------
// EXISTING RESOURCE REFERENCE: Log Analytics Workspace
// EXAM TIP: Use 'existing' keyword to reference resources already deployed.
// This avoids redeploying shared infrastructure and enables output chaining.
// ---------------------------------------------------------------------------

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: environmentName == 'prod' ? 90 : 30
    // EXAM TIP: Log Analytics retention is 30 days free, then billed per GB/day.
    // AZ-305 recommends 90 days for production, 30 days for dev/test.
    // For compliance (HIPAA, PCI), archive to Storage for long-term retention.
  }
}

// ---------------------------------------------------------------------------
// VIRTUAL NETWORK: Subnet delegation and loops
// EXAM TIP: VNet integration with subnet delegation is required for
// App Service VNet Integration and Private Endpoints. AZ-305 tests on
// network isolation patterns -- always deploy data services with Private Endpoints.
// ---------------------------------------------------------------------------

resource vnet 'Microsoft.Network/virtualNetworks@2024-01-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: ['10.0.0.0/16']
    }
    // RESOURCE LOOP: Deploy multiple subnets from the array variable
    subnets: [for (subnet, i) in subnets: {
      name: subnet.name
      properties: {
        addressPrefix: subnet.addressPrefix
        // CONDITIONAL: Only add delegation if specified
        delegations: subnet.delegation != null ? [
          {
            name: '${subnet.name}-delegation'
            properties: {
              serviceName: subnet.delegation!
            }
          }
        ] : []
        // Enable Private Endpoint network policies for the PE subnet
        privateEndpointNetworkPolicies: subnet.name == 'snet-pe' ? 'Enabled' : 'Disabled'
      }
    }]
  }
}

// ---------------------------------------------------------------------------
// KEY VAULT: RBAC authorization model with role assignment
// EXAM TIP: AZ-305 recommends RBAC authorization over access policies for
// Key Vault. RBAC provides finer-grained control and integrates with
// Entra ID Conditional Access and PIM. Set enableRbacAuthorization: true.
// ---------------------------------------------------------------------------

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      // COST: Standard SKU is sufficient for most workloads ($0.03/10K operations).
      // Premium adds HSM-backed keys ($1/key/month + operations) -- required for
      // FIPS 140-2 Level 2 compliance.
      name: environmentName == 'prod' ? 'premium' : 'standard'
    }
    // EXAM TIP: enableRbacAuthorization = true is the modern recommended approach.
    // This replaces legacy access policies and enables Azure RBAC roles like
    // Key Vault Secrets Officer, Key Vault Crypto Officer, etc.
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    // EXAM TIP: enablePurgeProtection prevents permanent deletion during the
    // soft-delete retention period. Required for encryption key scenarios
    // (CMK for Storage, SQL TDE). Cannot be disabled once enabled.
    enablePurgeProtection: true
    // Network ACLs: deny by default, allow via Private Endpoint
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }
  }
}

// EXTENSION RESOURCE: Diagnostic settings for Key Vault
// EXAM TIP: Always enable diagnostic settings for security-sensitive resources.
// Key Vault audit logs are essential for compliance and threat detection.
resource keyVaultDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${keyVaultName}-diagnostics'
  scope: keyVault
  properties: {
    workspaceId: logAnalytics.id
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// EXTENSION RESOURCE: Resource lock (prevent accidental deletion)
// EXAM TIP: CanNotDelete locks prevent deletion but allow modification.
// ReadOnly locks prevent both. AZ-305 recommends CanNotDelete on production
// resources and ReadOnly on critical networking (VNets, ExpressRoute).
resource keyVaultLock 'Microsoft.Authorization/locks@2020-05-01' = if (environmentName == 'prod') {
  name: '${keyVaultName}-lock'
  scope: keyVault
  properties: {
    level: 'CanNotDelete'
    notes: 'Production Key Vault -- deletion requires lock removal first.'
  }
}

// ---------------------------------------------------------------------------
// SQL SERVER: Failover group for geo-replication (Business Continuity)
// EXAM TIP: SQL failover groups provide automatic geo-failover with a single
// read-write listener endpoint. The app connection string doesn't change during
// failover. AZ-305 tests on RTO/RPO for different SQL HA/DR options:
//   - Availability zones (same region): RPO=0, RTO<30s
//   - Failover groups (cross-region): RPO<5s, RTO<1h
//   - Geo-restore from backups: RPO<1h, RTO=hours
// ---------------------------------------------------------------------------

resource sqlServer 'Microsoft.Sql/servers@2023-08-01-preview' = {
  name: sqlServerName
  location: location
  tags: tags
  properties: {
    // EXAM TIP: Set to Microsoft Entra-only authentication for Zero Trust.
    // SQL authentication should be disabled in production environments.
    administratorLogin: sqlAdminLogin
    administratorLoginPassword: sqlAdminPassword
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Disabled'
    // ALTERNATIVE: For Microsoft Entra-only auth (recommended for prod):
    // administrators: {
    //   administratorType: 'ActiveDirectory'
    //   principalType: 'Group'
    //   login: 'sql-admins@contoso.com'
    //   sid: '<entra-group-object-id>'
    //   tenantId: subscription().tenantId
    //   azureADOnlyAuthentication: true
    // }
  }
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-08-01-preview' = {
  parent: sqlServer
  name: sqlDatabaseName
  location: location
  tags: tags
  sku: {
    // COST: General Purpose S0 (~$15/month) for dev; Business Critical for prod.
    // EXAM TIP: DTU model (S0, S1, P1...) bundles CPU/IO/memory.
    // vCore model (GP_Gen5_2, BC_Gen5_4...) allows independent scaling.
    // AZ-305 recommends vCore for predictable workloads, DTU for simplicity.
    name: environmentName == 'prod' ? 'GP_Gen5' : 'Basic'
    tier: environmentName == 'prod' ? 'GeneralPurpose' : 'Basic'
    capacity: environmentName == 'prod' ? 2 : 5
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: environmentName == 'prod' ? 34359738368 : 2147483648 // 32GB prod, 2GB dev
    zoneRedundant: environmentName == 'prod'
    // EXAM TIP: Zone redundancy replicates across availability zones in the
    // same region for HA. Available on General Purpose (vCore) and Business Critical.
    // Adds ~25% cost but provides RPO=0 and automatic failover within seconds.
    requestedBackupStorageRedundancy: environmentName == 'prod' ? 'Geo' : 'Local'
    // ALTERNATIVE: 'Zone' for zone-redundant backup (cheaper than Geo).
  }
}

// Failover group (conditional -- only for production)
// EXAM TIP: Failover groups require a secondary server in a paired region.
// This resource definition shows the pattern; the secondary server would
// be deployed in a separate module or template targeting the DR region.
resource sqlFailoverGroup 'Microsoft.Sql/servers/failoverGroups@2023-08-01-preview' = if (enableGeoReplication) {
  parent: sqlServer
  name: '${sqlServerName}-fg'
  properties: {
    readWriteEndpoint: {
      failoverPolicy: 'Automatic'
      failoverWithDataLossGracePeriodMinutes: 60
    }
    readOnlyEndpoint: {
      failoverPolicy: 'Enabled'
    }
    // partnerServers would reference the secondary SQL server resource ID
    partnerServers: []
    databases: [
      sqlDatabase.id
    ]
  }
}

// ---------------------------------------------------------------------------
// STORAGE ACCOUNT: Private Endpoint pattern
// EXAM TIP: Private Endpoints assign a private IP from your VNet to the
// Azure service. Traffic stays on the Microsoft backbone network. AZ-305
// ALWAYS recommends Private Endpoints for data services in production.
// COST: Each Private Endpoint costs ~$7.30/month + $0.01/GB processed.
// ---------------------------------------------------------------------------

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  tags: tags
  kind: 'StorageV2'
  sku: {
    // EXAM TIP: Standard_GRS provides 6 copies (3 local + 3 in paired region).
    // Standard_ZRS provides 3 copies across availability zones (same region).
    // For AZ-305: GRS for cross-region DR, ZRS for zone-level HA without DR.
    // COST: GRS ~$0.036/GB, ZRS ~$0.025/GB, LRS ~$0.018/GB (Hot tier, East US).
    name: environmentName == 'prod' ? 'Standard_GRS' : 'Standard_LRS'
  }
  properties: {
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
    // EXAM TIP: Disable public blob access unless specifically required (e.g., CDN origin).
    // AZ-305 always recommends private access patterns for data services.
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }
  }
}

// Private Endpoint for Storage Account (blob sub-resource)
resource storagePrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-01-01' = {
  name: '${storageAccountName}-pe-blob'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: vnet.properties.subnets[2].id // snet-pe subnet
    }
    privateLinkServiceConnections: [
      {
        name: '${storageAccountName}-plsc'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: ['blob']
          // EXAM TIP: groupIds specifies the sub-resource. For Storage:
          // 'blob', 'file', 'table', 'queue', 'dfs' (Data Lake), 'web' (static website).
          // Each sub-resource needs its own Private Endpoint.
        }
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// APP SERVICE: Blue-green deployment with slots
// EXAM TIP: Deployment slots enable zero-downtime deployments by swapping
// between staging and production. AZ-305 tests on blue-green vs. canary
// vs. rolling deployment strategies. Slots are available on Standard+.
// COST: Slots on Standard S1 share the same compute as production (no extra
// cost for the slot itself, but the plan must support the total memory/CPU).
// ---------------------------------------------------------------------------

resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: appServicePlanName
  location: location
  tags: tags
  sku: {
    // EXAM TIP: Standard S1 supports slots, custom domains, SSL, auto-scale (up to 10).
    // Premium P1v3 adds VNet Integration, more slots (20), and better perf.
    // For AZ-305: Premium for production with VNet Integration; Standard for staging.
    name: environmentName == 'prod' ? 'P1v3' : 'S1'
    tier: environmentName == 'prod' ? 'PremiumV3' : 'Standard'
    capacity: environmentName == 'prod' ? 2 : 1
    // ALTERNATIVE: For containers, consider Azure Container Apps (serverless,
    // built-in Dapr, KEDA auto-scaling). AZ-305 tests on when to choose
    // App Service vs. Container Apps vs. AKS.
  }
}

resource appService 'Microsoft.Web/sites@2023-12-01' = {
  name: appServiceName
  location: location
  tags: tags
  // EXAM TIP: System-assigned managed identity is enabled with identity block.
  // This identity gets RBAC roles to access Key Vault, Storage, SQL, etc.
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      alwaysOn: environmentName == 'prod'
      // EXAM TIP: Always On prevents the app from going idle. Required for
      // WebJobs and background processing. Not available on Free/Shared tiers.
      http20Enabled: true
    }
    // VNet Integration (requires Premium or higher plan)
    virtualNetworkSubnetId: environmentName == 'prod' ? vnet.properties.subnets[0].id : null
  }
}

// Staging deployment slot for blue-green deployments
resource stagingSlot 'Microsoft.Web/sites/slots@2023-12-01' = if (environmentName == 'prod') {
  parent: appService
  name: 'staging'
  location: location
  tags: union(tags, { slot: 'staging' })
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      // EXAM TIP: Auto-swap automatically swaps staging to production after
      // warm-up. Use for fully automated CI/CD pipelines where manual
      // verification is not required.
      autoSwapSlotName: 'production'
    }
  }
}

// ---------------------------------------------------------------------------
// EXTENSION RESOURCE: RBAC Role Assignment for App Service -> Key Vault
// EXAM TIP: This grants the App Service managed identity the "Key Vault
// Secrets User" role, allowing it to read secrets. This is the Zero Trust
// pattern: identity-based access with least-privilege RBAC roles.
// ALTERNATIVE: "Key Vault Secrets Officer" for read+write access.
// ---------------------------------------------------------------------------

// Built-in role definition IDs
var keyVaultSecretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'

resource appServiceKeyVaultRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, appService.id, keyVaultSecretsUserRoleId)
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsUserRoleId)
    principalId: appService.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// ---------------------------------------------------------------------------
// DIAGNOSTIC SETTINGS: SQL Server audit and performance
// ---------------------------------------------------------------------------

resource sqlDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${sqlServerName}-diagnostics'
  scope: sqlDatabase
  properties: {
    workspaceId: logAnalytics.id
    logs: [
      {
        category: 'SQLSecurityAuditEvents'
        enabled: true
      }
      {
        category: 'QueryStoreRuntimeStatistics'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'Basic'
        enabled: true
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// OUTPUTS: Chaining values for downstream deployments
// EXAM TIP: Outputs are visible in deployment history. NEVER output secrets.
// Use Key Vault references or managed identity for credential passing.
// ---------------------------------------------------------------------------

@description('SQL Server fully qualified domain name for connection strings.')
output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName

@description('App Service default hostname.')
output appServiceHostname string = appService.properties.defaultHostName

@description('App Service managed identity principal ID for RBAC assignments.')
output appServicePrincipalId string = appService.identity.principalId

@description('Storage Account blob endpoint for application configuration.')
output storageBlobEndpoint string = storageAccount.properties.primaryEndpoints.blob

@description('Key Vault URI for application configuration.')
output keyVaultUri string = keyVault.properties.vaultUri

@description('Log Analytics workspace ID for monitoring configuration.')
output logAnalyticsWorkspaceId string = logAnalytics.properties.customerId

// ============================================================================
// END OF FILE
// Deploy with: az deployment group create -g <rg> -f 09-bicep-patterns.bicep \
//   -p environmentName=dev sqlAdminLogin=sqladmin sqlAdminPassword=<from-keyvault>
// Reference: https://learn.microsoft.com/azure/azure-resource-manager/bicep/
// ============================================================================
