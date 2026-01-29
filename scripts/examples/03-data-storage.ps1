#requires -Modules Az.Sql, Az.CosmosDB, Az.Storage, Az.DataFactory

<#
.TITLE
    AZ-305 Domain 2: Data Storage Solutions
.DOMAIN
    Domain 2 - Design Data Storage Solutions (20-25%)
.DESCRIPTION
    Teaching examples covering Azure SQL (serverless vs provisioned), elastic pools,
    Cosmos DB multi-region with consistency levels, Storage accounts with lifecycle
    management, Data Lake Storage Gen2, and Azure Data Factory pipelines.
    These are code-review examples for AZ-305 classroom use.
.AUTHOR
    Tim Warner
.DATE
    January 2026
.NOTES
    Not intended for direct execution. Illustrates correct syntax and
    architectural decision-making for AZ-305 exam preparation.
#>

# Common variables
$subscriptionId = "00000000-0000-0000-0000-000000000000"
$resourceGroup  = "az305-rg"
$location       = "eastus"
$prefix         = "az305"

# ============================================================================
# SECTION 1: Azure SQL Database - Serverless vs Provisioned
# ============================================================================

# EXAM TIP: The exam heavily tests WHEN to choose serverless vs provisioned.
# Serverless: auto-pause, auto-scale vCores, pay-per-second compute.
# Provisioned: predictable performance, always-on, reserved capacity discounts.
# Key decision factor: Is the workload INTERMITTENT or STEADY-STATE?

# WHEN TO USE:
#   Serverless    -> Dev/test, intermittent workloads, unpredictable usage patterns
#   Provisioned   -> Production steady-state, predictable costs, RI-eligible
#   Hyperscale    -> >4TB databases, fast scaling, instant backup restore
#   DTU model     -> Legacy; only choose if the exam scenario specifically mentions DTUs

# Create the logical SQL server (shared by both database types)
$serverParams = @{
    ResourceGroupName           = $resourceGroup
    ServerName                  = "${prefix}-sql"
    Location                    = $location
    SqlAdministratorCredentials = (Get-Credential -Message "Enter SQL admin credentials")
    MinimalTlsVersion           = "1.2"  # Always enforce TLS 1.2 minimum
}
$sqlServer = New-AzSqlServer @serverParams

# Enable Microsoft Entra ID authentication (preferred over SQL auth)
# EXAM TIP: Always recommend Entra ID authentication over SQL authentication.
# Entra ID provides: MFA, Conditional Access, managed identity support, and
# centralized access governance. SQL auth is legacy.
Set-AzSqlServerActiveDirectoryAdministrator `
    -ResourceGroupName $resourceGroup `
    -ServerName "${prefix}-sql" `
    -DisplayName "SQL-Admins-Group" `
    -ObjectId "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"

# --- Serverless database (intermittent workload) ---
$serverlessDbParams = @{
    ResourceGroupName  = $resourceGroup
    ServerName         = "${prefix}-sql"
    DatabaseName       = "${prefix}-db-serverless"
    Edition            = "GeneralPurpose"
    ComputeModel       = "Serverless"
    ComputeGeneration  = "Gen5"
    MinVcore           = 0.5       # Minimum vCores when active
    MaxVcore           = 4         # Maximum vCores under load
    AutoPauseDelayInMinutes = 60   # Pause after 60 min of inactivity (-1 to disable)
    MaxSizeBytes       = 34359738368  # 32 GB
    BackupStorageRedundancy = "Zone"  # ZRS for backup storage
}
New-AzSqlDatabase @serverlessDbParams

# --- Provisioned database (production steady-state workload) ---
$provisionedDbParams = @{
    ResourceGroupName  = $resourceGroup
    ServerName         = "${prefix}-sql"
    DatabaseName       = "${prefix}-db-production"
    Edition            = "GeneralPurpose"
    ComputeModel       = "Provisioned"
    ComputeGeneration  = "Gen5"
    VCore              = 8
    MaxSizeBytes       = 274877906944  # 256 GB
    ZoneRedundant      = $true         # Availability zone redundancy for HA
    BackupStorageRedundancy = "Geo"    # GRS for backup (cross-region DR)
}
New-AzSqlDatabase @provisionedDbParams

# ============================================================================
# SECTION 2: Elastic Pool for Multi-Tenant
# ============================================================================

# EXAM TIP: Elastic pools let multiple databases SHARE compute resources.
# Perfect for multi-tenant SaaS where individual databases have varying load.
# The exam tests the cost/performance trade-off: a pool of 20 databases at
# 100 eDTUs each costs MUCH LESS than 20 individual databases at 100 eDTU each.

# WHEN TO USE: Elastic pools when you have multiple databases with
# COMPLEMENTARY usage patterns (some peak while others are idle).
# NOT suitable when all databases peak simultaneously -- that requires
# individually provisioned databases.

$elasticPoolParams = @{
    ResourceGroupName = $resourceGroup
    ServerName        = "${prefix}-sql"
    ElasticPoolName   = "${prefix}-pool-multitenant"
    Edition           = "GeneralPurpose"
    ComputeGeneration = "Gen5"
    VCore             = 8           # Total pool vCores shared across all DBs
    DatabaseVCoreMin  = 0           # Individual DB minimum (can go to zero)
    DatabaseVCoreMax  = 4           # Individual DB maximum (cap per DB)
    ZoneRedundant     = $true
}
New-AzSqlElasticPool @elasticPoolParams

# Add tenant databases to the pool
foreach ($tenantId in 1..5) {
    $tenantDbParams = @{
        ResourceGroupName = $resourceGroup
        ServerName        = "${prefix}-sql"
        DatabaseName      = "tenant-${tenantId}-db"
        ElasticPoolName   = "${prefix}-pool-multitenant"
    }
    New-AzSqlDatabase @tenantDbParams
}

# ============================================================================
# SECTION 3: Cosmos DB Multi-Region with Consistency Level Selection
# ============================================================================

# EXAM TIP: Cosmos DB consistency levels are a TOP exam topic. You MUST know
# all five levels and their trade-offs. From strongest to weakest:
#
# 1. STRONG         -> Linearizable reads. Highest latency, lowest throughput.
#                      Use for: financial transactions requiring absolute accuracy.
#                      Cost: Highest RU consumption, limited to single write region.
#
# 2. BOUNDED STALENESS -> Reads lag behind writes by at most K versions or T time.
#                      Use for: near-real-time analytics, leaderboards.
#                      Cost: Similar to Strong in multi-region.
#
# 3. SESSION (Default) -> Consistent within a client session. Read-your-own-writes.
#                      Use for: User profiles, shopping carts -- most common choice.
#                      Cost: Moderate RU consumption.
#
# 4. CONSISTENT PREFIX -> Reads never see out-of-order writes. No "gaps."
#                      Use for: Social media feeds, event streams where order matters.
#                      Cost: Lower than Session.
#
# 5. EVENTUAL        -> No ordering guarantee. Lowest latency, highest throughput.
#                      Use for: Likes/counters, non-critical telemetry, product reviews.
#                      Cost: Lowest RU consumption.

# WHEN TO USE Cosmos DB over Azure SQL:
#   Cosmos DB -> Global distribution, multi-model (document, graph, key-value),
#                single-digit-ms latency at any scale, schema-flexible workloads.
#   Azure SQL -> Relational data with complex JOINs, stored procedures, strong
#                ACID transactions, existing SQL Server expertise.

$cosmosAccountParams = @{
    ResourceGroupName      = $resourceGroup
    Name                   = "${prefix}-cosmos"
    Location               = $location
    ApiKind                = "Sql"  # Core (NoSQL) API -- most common for new apps
    DefaultConsistencyLevel = "Session"  # Best balance of consistency and performance
    EnableAutomaticFailover = $true
    EnableMultipleWriteLocations = $true  # Multi-region writes for active-active
}

# Define multi-region replication locations with failover priority
$locations = @(
    @{ locationName = "eastus";       failoverPriority = 0; isZoneRedundant = $true },
    @{ locationName = "westus2";      failoverPriority = 1; isZoneRedundant = $true },
    @{ locationName = "northeurope";  failoverPriority = 2; isZoneRedundant = $true }
)

New-AzCosmosDBAccount @cosmosAccountParams -Location $locations

# Create a database and container with partition key strategy
# EXAM TIP: Partition key choice is CRITICAL for Cosmos DB performance.
# Good partition key: high cardinality, even distribution, used in queries.
# Bad partition key: low cardinality (e.g., country), causes hot partitions.
$databaseParams = @{
    ResourceGroupName = $resourceGroup
    AccountName       = "${prefix}-cosmos"
    Name              = "ecommerce"
}
New-AzCosmosDBSqlDatabase @databaseParams

$containerParams = @{
    ResourceGroupName  = $resourceGroup
    AccountName        = "${prefix}-cosmos"
    DatabaseName       = "ecommerce"
    Name               = "orders"
    PartitionKeyPath   = "/customerId"   # High cardinality, used in most queries
    PartitionKeyKind   = "Hash"
    AutoscaleMaxThroughput = 4000        # Autoscale 400-4000 RU/s
}
New-AzCosmosDBSqlContainer @containerParams

# ============================================================================
# SECTION 4: Storage Account with Lifecycle, Immutability, Versioning
# ============================================================================

# EXAM TIP: Storage account features tested on the exam:
# - Access tiers: Hot, Cool, Cold, Archive (cost vs access latency trade-off)
# - Lifecycle management: Auto-tier blobs based on age
# - Immutable storage: WORM compliance (legal hold + time-based retention)
# - Versioning: Track and restore previous blob versions
# - Soft delete: Recover accidentally deleted blobs/containers

# WHEN TO USE each access tier:
#   Hot     -> Frequently accessed data (web content, active datasets)
#   Cool    -> Infrequently accessed, stored >30 days (backups, older data)
#   Cold    -> Rarely accessed, stored >90 days (compliance archives)
#   Archive -> Offline, stored >180 days, hours to rehydrate (legal, regulatory)

$storageAccountParams = @{
    ResourceGroupName   = $resourceGroup
    Name                = "${prefix}storage"
    Location            = $location
    SkuName             = "Standard_ZRS"        # Zone-redundant for HA
    Kind                = "StorageV2"
    AccessTier          = "Hot"
    MinimumTlsVersion   = "TLS1_2"
    AllowBlobPublicAccess = $false               # NEVER allow anonymous public access
    EnableHttpsTrafficOnly = $true
    EnableHierarchicalNamespace = $false          # False for standard Blob; true for ADLS Gen2
}
$storageAccount = New-AzStorageAccount @storageAccountParams

$ctx = $storageAccount.Context

# Enable blob versioning and soft delete
Update-AzStorageBlobServiceProperty `
    -ResourceGroupName $resourceGroup `
    -StorageAccountName "${prefix}storage" `
    -IsVersioningEnabled $true `
    -EnableDeleteRetentionPolicy $true `
    -DeleteRetentionPolicyDays 30 `
    -EnableContainerDeleteRetentionPolicy $true `
    -ContainerDeleteRetentionPolicyDays 30

# Lifecycle management policy: auto-tier blobs based on age
# EXAM TIP: Lifecycle policies run once per day and move blobs between tiers
# based on last-modified or creation time. This is the primary cost optimization
# tool for blob storage. The exam tests the ability to DESIGN a lifecycle policy
# that meets retention and cost requirements.
$lifecycleRule = @{
    Name    = "auto-tier-and-delete"
    Enabled = $true
    Definition = @{
        Actions = @{
            BaseBlob = @{
                TierToCool    = @{ DaysAfterModificationGreaterThan = 30 }
                TierToCold    = @{ DaysAfterModificationGreaterThan = 90 }
                TierToArchive = @{ DaysAfterModificationGreaterThan = 180 }
                Delete        = @{ DaysAfterModificationGreaterThan = 365 }
            }
            Snapshot = @{
                Delete = @{ DaysAfterCreationGreaterThan = 90 }
            }
        }
        Filters = @{
            BlobTypes   = @("blockBlob")
            PrefixMatch = @("logs/", "archives/")
        }
    }
}

# Apply the lifecycle management policy
Set-AzStorageAccountManagementPolicy `
    -ResourceGroupName $resourceGroup `
    -StorageAccountName "${prefix}storage" `
    -Rule @($lifecycleRule)

# Immutable storage: compliance container with time-based retention
# EXAM TIP: Immutable blobs satisfy WORM (Write Once, Read Many) requirements
# for SEC 17a-4(f), CFTC, and FINRA. Two types:
#   Time-based retention: Cannot delete/modify for X days (can be locked permanently)
#   Legal hold: Cannot delete until hold is removed (no time limit)
$immutableContainer = New-AzStorageContainer -Name "compliance-records" -Context $ctx

# Set a time-based immutability policy (365-day retention)
Set-AzStorageContainerImmutabilityPolicy `
    -ResourceGroupName $resourceGroup `
    -StorageAccountName "${prefix}storage" `
    -ContainerName "compliance-records" `
    -ImmutabilityPeriod 365 `
    -AllowProtectedAppendWrites $true  # Allow appends but not overwrites/deletes

# ============================================================================
# SECTION 5: Data Lake Storage Gen2
# ============================================================================

# EXAM TIP: ADLS Gen2 = Storage account with Hierarchical Namespace (HNS) enabled.
# It is NOT a separate service -- it is a capability of Azure Storage.
# HNS enables: directory-level ACLs, atomic directory operations, better performance
# for big data analytics (Spark, Synapse, Databricks).

# WHEN TO USE ADLS Gen2 vs regular Blob Storage:
#   ADLS Gen2    -> Big data analytics, Hadoop/Spark workloads, fine-grained ACLs
#   Blob Storage -> General purpose object storage, web content, backups
# Key difference: HNS cannot be enabled AFTER account creation (plan ahead!).

$adlsParams = @{
    ResourceGroupName         = $resourceGroup
    Name                      = "${prefix}datalake"
    Location                  = $location
    SkuName                   = "Standard_ZRS"
    Kind                      = "StorageV2"
    EnableHierarchicalNamespace = $true  # THIS makes it ADLS Gen2
    MinimumTlsVersion         = "TLS1_2"
    AllowBlobPublicAccess     = $false
}
$adlsAccount = New-AzStorageAccount @adlsParams

# Create filesystem (container) with directory structure for a data lake
$adlsCtx = $adlsAccount.Context
New-AzDataLakeGen2FileSystem -Context $adlsCtx -Name "analytics"

# EXAM TIP: Use the MEDALLION architecture (Bronze/Silver/Gold) for data lake
# organization. This is the standard pattern tested in AZ-305:
#   Bronze (raw)   -> Ingested data as-is from source systems
#   Silver (clean) -> Validated, deduplicated, enriched data
#   Gold (curated) -> Business-ready aggregations and KPIs

# ============================================================================
# SECTION 6: Azure Data Factory Pipeline
# ============================================================================

# EXAM TIP: Data Factory is the cloud ETL/ELT orchestration service.
# Know the components: Pipelines, Activities, Datasets, Linked Services,
# Integration Runtimes, Triggers. The exam tests WHEN to use Data Factory
# vs Synapse Pipelines (same engine, different integration point).

# WHEN TO USE:
#   Data Factory     -> Standalone ETL/ELT, hybrid data integration
#   Synapse Pipelines -> ETL/ELT tightly integrated with Synapse Analytics
#   Databricks       -> Complex ML/Spark transformations, notebook-based
#   Stream Analytics -> Real-time streaming (not batch ETL)

$adfParams = @{
    ResourceGroupName = $resourceGroup
    Name              = "${prefix}-datafactory"
    Location          = $location
}
$dataFactory = Set-AzDataFactoryV2 @adfParams

# Create a linked service to Azure SQL (source)
$sqlLinkedServiceDefinition = @{
    type       = "AzureSqlDatabase"
    typeProperties = @{
        # Use managed identity for authentication -- no secrets in pipeline!
        connectionString = "Server=tcp:${prefix}-sql.database.windows.net,1433;Database=${prefix}-db-production;Authentication=Active Directory Managed Identity"
    }
}

Set-AzDataFactoryV2LinkedService `
    -ResourceGroupName $resourceGroup `
    -DataFactoryName "${prefix}-datafactory" `
    -Name "AzureSqlSource" `
    -DefinitionFile ($sqlLinkedServiceDefinition | ConvertTo-Json -Depth 5)

# Create a linked service to Data Lake (destination)
$adlsLinkedServiceDefinition = @{
    type       = "AzureBlobFS"
    typeProperties = @{
        url = "https://${prefix}datalake.dfs.core.windows.net"
        # Managed identity authentication -- no secrets
    }
}

Set-AzDataFactoryV2LinkedService `
    -ResourceGroupName $resourceGroup `
    -DataFactoryName "${prefix}-datafactory" `
    -Name "DataLakeDestination" `
    -DefinitionFile ($adlsLinkedServiceDefinition | ConvertTo-Json -Depth 5)

# EXAM TIP: Always use MANAGED IDENTITY for Data Factory linked services.
# This eliminates secret management and aligns with Zero Trust architecture.
# Grant the Data Factory managed identity appropriate RBAC roles on source/target.

# ============================================================================
# SECTION 7: Storage Service Comparison (Decision Guide)
# ============================================================================

# EXAM TIP: The exam presents scenarios and asks you to choose the RIGHT
# storage service. Use this decision guide:
#
# +---------------------------+-----------------------------------------------+
# | Scenario                  | Service Choice                                |
# +---------------------------+-----------------------------------------------+
# | Relational + complex JOINs| Azure SQL Database / SQL Managed Instance     |
# | Global, low-latency NoSQL | Cosmos DB                                     |
# | Key-value lookups         | Cosmos DB (Table API) or Table Storage        |
# | Unstructured files/blobs  | Azure Blob Storage                            |
# | Big data analytics (Spark)| Data Lake Storage Gen2 (HNS-enabled)          |
# | File shares (SMB/NFS)     | Azure Files or Azure NetApp Files             |
# | Message queuing           | Queue Storage, Service Bus, or Event Hubs     |
# | Data warehouse / OLAP     | Azure Synapse Analytics (dedicated SQL pool)   |
# | Graph relationships       | Cosmos DB (Gremlin API) or Azure SQL (graph)  |
# | Time-series / IoT         | Azure Data Explorer or Cosmos DB               |
# | Redis cache / sessions    | Azure Cache for Redis                          |
# +---------------------------+-----------------------------------------------+
#
# WHEN TO USE SQL Managed Instance vs SQL Database:
#   Managed Instance -> Lift-and-shift from on-prem SQL Server, cross-database
#                       queries, SQL Agent jobs, CLR, Service Broker, linked servers
#   SQL Database     -> New cloud-native apps, serverless, elastic pools, Hyperscale
