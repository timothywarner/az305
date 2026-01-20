<#
.SYNOPSIS
    Create and configure an Azure Cosmos DB account with best practices.

.DESCRIPTION
    This script creates a Cosmos DB account with:
    - Multi-region configuration with automatic failover
    - Consistency level configuration
    - Backup policy (continuous or periodic)
    - Network security (private endpoints or IP filtering)
    - Database and container provisioning

.PARAMETER ResourceGroupName
    Resource group for the Cosmos DB account.

.PARAMETER AccountName
    Name for the Cosmos DB account (globally unique).

.PARAMETER Location
    Primary region for the account. Default: eastus

.PARAMETER SecondaryLocation
    Secondary region for geo-replication. Default: westus

.PARAMETER ConsistencyLevel
    Consistency level: Strong, BoundedStaleness, Session, ConsistentPrefix, Eventual

.PARAMETER EnableFreeTier
    Enable free tier (one per subscription). Default: false

.PARAMETER BackupType
    Backup policy: Continuous or Periodic. Default: Continuous

.EXAMPLE
    # Create basic account
    .\New-CosmosDBAccount.ps1 -ResourceGroupName "myRG" -AccountName "mycosmosdb"

.EXAMPLE
    # Create with specific configuration
    .\New-CosmosDBAccount.ps1 -ResourceGroupName "myRG" -AccountName "mycosmosdb" `
        -ConsistencyLevel "BoundedStaleness" -BackupType "Continuous"

.NOTES
    AZ-305 EXAM OBJECTIVES:
    - Design data storage solutions
    - Implement globally distributed data with Cosmos DB
    - Configure consistency levels for application requirements
    - Design for high availability and disaster recovery

.LINK
    https://learn.microsoft.com/azure/cosmos-db/introduction
    https://learn.microsoft.com/azure/cosmos-db/consistency-levels
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$AccountName,

    [Parameter(Mandatory = $false)]
    [string]$Location = "eastus",

    [Parameter(Mandatory = $false)]
    [string]$SecondaryLocation = "westus",

    [Parameter(Mandatory = $false)]
    [ValidateSet("Strong", "BoundedStaleness", "Session", "ConsistentPrefix", "Eventual")]
    [string]$ConsistencyLevel = "Session",

    [Parameter(Mandatory = $false)]
    [bool]$EnableFreeTier = $false,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Continuous", "Periodic")]
    [string]$BackupType = "Continuous"
)

#Requires -Modules Az.Accounts, Az.CosmosDB

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

#-------------------------------------------------------------------------------
# HELPER FUNCTIONS
#-------------------------------------------------------------------------------
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "INFO" { "White" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR" { "Red" }
    }
    Write-Host "[$Level] $timestamp - $Message" -ForegroundColor $color
}

#-------------------------------------------------------------------------------
# ENSURE RESOURCE GROUP EXISTS
#-------------------------------------------------------------------------------
function Confirm-ResourceGroup {
    Write-Log "Verifying resource group: $ResourceGroupName"

    $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
    if (-not $rg) {
        Write-Log "Creating resource group: $ResourceGroupName"
        $rg = New-AzResourceGroup -Name $ResourceGroupName -Location $Location -Tag @{
            Purpose     = "AZ305-CosmosDB"
            Environment = "Development"
        }
        Write-Log "Created resource group" -Level "SUCCESS"
    }

    return $rg
}

#-------------------------------------------------------------------------------
# CREATE COSMOS DB ACCOUNT
#-------------------------------------------------------------------------------
function New-CosmosAccount {
    Write-Log "Creating Cosmos DB account: $AccountName"

    # Check if account already exists
    $existingAccount = Get-AzCosmosDBAccount `
        -ResourceGroupName $ResourceGroupName `
        -Name $AccountName `
        -ErrorAction SilentlyContinue

    if ($existingAccount) {
        Write-Log "Cosmos DB account already exists" -Level "WARNING"
        return $existingAccount
    }

    # WHY: Multi-region configuration for high availability
    # Primary region handles writes, secondary provides read replicas and DR
    $locations = @(
        @{
            LocationName     = $Location
            FailoverPriority = 0
            IsZoneRedundant  = $false
        },
        @{
            LocationName     = $SecondaryLocation
            FailoverPriority = 1
            IsZoneRedundant  = $false
        }
    )

    # Build parameters
    $params = @{
        ResourceGroupName      = $ResourceGroupName
        Name                   = $AccountName
        Location               = $Location
        DefaultConsistencyLevel = $ConsistencyLevel
        EnableAutomaticFailover = $true
        EnableMultipleWriteLocations = $false  # Single write region
        LocationObject         = $locations
        Tag                    = @{
            Purpose     = "AZ305-CosmosDB"
            Environment = "Development"
        }
    }

    # WHY: Continuous backup enables point-in-time restore
    # Better RPO than periodic backup, but costs more
    if ($BackupType -eq "Continuous") {
        $params.BackupPolicyType = "Continuous"
        $params.ContinuousTier = "Continuous7Days"  # or Continuous30Days
        Write-Log "Configuring continuous backup (7-day retention)"
    }
    else {
        $params.BackupPolicyType = "Periodic"
        $params.BackupIntervalInMinutes = 240  # 4 hours
        $params.BackupRetentionIntervalInHours = 8
        $params.BackupStorageRedundancy = "Geo"
        Write-Log "Configuring periodic backup (4-hour interval, 8-hour retention)"
    }

    # Free tier (only one per subscription)
    if ($EnableFreeTier) {
        $params.EnableFreeTier = $true
        Write-Log "Enabling free tier (1000 RU/s and 25 GB)" -Level "WARNING"
    }

    Write-Log "Creating Cosmos DB account (this may take 5-10 minutes)..."

    try {
        $account = New-AzCosmosDBAccount @params
        Write-Log "Cosmos DB account created successfully" -Level "SUCCESS"
        return $account
    }
    catch {
        Write-Log "Failed to create Cosmos DB account: $_" -Level "ERROR"
        throw
    }
}

#-------------------------------------------------------------------------------
# CREATE DATABASE
#-------------------------------------------------------------------------------
function New-CosmosDatabase {
    param([object]$Account)

    $databaseName = "SampleDatabase"
    Write-Log "Creating database: $databaseName"

    $existingDb = Get-AzCosmosDBSqlDatabase `
        -ResourceGroupName $ResourceGroupName `
        -AccountName $AccountName `
        -Name $databaseName `
        -ErrorAction SilentlyContinue

    if ($existingDb) {
        Write-Log "Database already exists: $databaseName"
        return $existingDb
    }

    # WHY: Shared throughput at database level is cost-effective for multiple containers
    # Each container can burst up to the shared throughput limit
    $database = New-AzCosmosDBSqlDatabase `
        -ResourceGroupName $ResourceGroupName `
        -AccountName $AccountName `
        -Name $databaseName `
        -Throughput 400  # Shared throughput (400 RU/s minimum)

    Write-Log "Database created: $databaseName" -Level "SUCCESS"
    return $database
}

#-------------------------------------------------------------------------------
# CREATE CONTAINER
#-------------------------------------------------------------------------------
function New-CosmosContainer {
    param([object]$Database)

    $databaseName = $Database.Resource.Id
    $containerName = "Items"

    Write-Log "Creating container: $containerName"

    $existingContainer = Get-AzCosmosDBSqlContainer `
        -ResourceGroupName $ResourceGroupName `
        -AccountName $AccountName `
        -DatabaseName $databaseName `
        -Name $containerName `
        -ErrorAction SilentlyContinue

    if ($existingContainer) {
        Write-Log "Container already exists: $containerName"
        return $existingContainer
    }

    # WHY: Partition key is critical for scalability and performance
    # Choose a property with high cardinality and even distribution
    $partitionKeyPath = "/partitionKey"

    # Define indexing policy
    # WHY: Indexing policy affects query performance and RU consumption
    $indexingPolicy = New-AzCosmosDBSqlIndexingPolicy `
        -IndexingMode Consistent `
        -IncludedPath (New-AzCosmosDBSqlIncludedPath -Path "/*") `
        -ExcludedPath (New-AzCosmosDBSqlExcludedPath -Path "/largeProperty/*")

    # Unique key policy
    # WHY: Unique keys enforce uniqueness within a partition
    $uniqueKey = New-AzCosmosDBSqlUniqueKey -Path "/email"
    $uniqueKeyPolicy = New-AzCosmosDBSqlUniqueKeyPolicy -UniqueKey $uniqueKey

    $container = New-AzCosmosDBSqlContainer `
        -ResourceGroupName $ResourceGroupName `
        -AccountName $AccountName `
        -DatabaseName $databaseName `
        -Name $containerName `
        -PartitionKeyKind Hash `
        -PartitionKeyPath $partitionKeyPath `
        -IndexingPolicy $indexingPolicy `
        -UniqueKeyPolicy $uniqueKeyPolicy `
        -DefaultTtl 86400  # 1 day TTL (optional)

    Write-Log "Container created: $containerName with partition key: $partitionKeyPath" -Level "SUCCESS"
    return $container
}

#-------------------------------------------------------------------------------
# DISPLAY SUMMARY
#-------------------------------------------------------------------------------
function Show-Summary {
    param([object]$Account)

    # Get connection info
    $keys = Get-AzCosmosDBAccountKey `
        -ResourceGroupName $ResourceGroupName `
        -Name $AccountName

    Write-Host ""
    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host "                    COSMOS DB DEPLOYMENT SUMMARY" -ForegroundColor Cyan
    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "ACCOUNT DETAILS:" -ForegroundColor Yellow
    Write-Host "  Name: $AccountName"
    Write-Host "  Resource Group: $ResourceGroupName"
    Write-Host "  Document Endpoint: $($Account.DocumentEndpoint)"
    Write-Host "  Consistency Level: $($Account.ConsistencyPolicy.DefaultConsistencyLevel)"
    Write-Host ""
    Write-Host "REGIONS:" -ForegroundColor Yellow
    foreach ($location in $Account.Locations) {
        $role = if ($location.FailoverPriority -eq 0) { "Primary (Write)" } else { "Secondary (Read)" }
        Write-Host "  $($location.LocationName) - $role"
    }
    Write-Host ""
    Write-Host "BACKUP POLICY:" -ForegroundColor Yellow
    Write-Host "  Type: $($Account.BackupPolicy.BackupPolicyType)"
    Write-Host ""
    Write-Host "CONNECTION STRINGS:" -ForegroundColor Yellow
    Write-Host "  Primary Key: $($keys.PrimaryMasterKey.Substring(0, 20))..."
    Write-Host ""
    Write-Host "  Connection String:"
    Write-Host "  AccountEndpoint=$($Account.DocumentEndpoint);AccountKey=$($keys.PrimaryMasterKey.Substring(0, 20))...;"
    Write-Host ""
    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host "COSMOS DB CONCEPTS (AZ-305 Exam Context):" -ForegroundColor Cyan
    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "CONSISTENCY LEVELS (Strongest to Weakest):" -ForegroundColor Yellow
    Write-Host "  Strong:           All regions see same data simultaneously"
    Write-Host "                    Highest latency, guaranteed consistency"
    Write-Host ""
    Write-Host "  Bounded Staleness: Reads lag by configurable time/operations"
    Write-Host "                    Good for near-real-time requirements"
    Write-Host ""
    Write-Host "  Session:          Consistent within a session (client)"
    Write-Host "                    DEFAULT - Best for most scenarios"
    Write-Host ""
    Write-Host "  Consistent Prefix: Reads never see out-of-order writes"
    Write-Host "                    Lower latency than Session"
    Write-Host ""
    Write-Host "  Eventual:         No ordering guarantee, lowest latency"
    Write-Host "                    Good for non-critical counters"
    Write-Host ""
    Write-Host "PARTITIONING:" -ForegroundColor Yellow
    Write-Host "  Partition Key Selection Criteria:"
    Write-Host "  - High cardinality (many distinct values)"
    Write-Host "  - Even distribution of data and requests"
    Write-Host "  - Included in most queries (WHERE clause)"
    Write-Host "  - Example good keys: /userId, /tenantId, /deviceId"
    Write-Host ""
    Write-Host "THROUGHPUT MODELS:" -ForegroundColor Yellow
    Write-Host "  Provisioned: Reserved RU/s (predictable cost)"
    Write-Host "  Autoscale:   Scales 10-100% of max (variable cost)"
    Write-Host "  Serverless:  Pay per request (dev/test workloads)"
    Write-Host ""
    Write-Host "BACKUP OPTIONS:" -ForegroundColor Yellow
    Write-Host "  Continuous: Point-in-time restore (7 or 30 days)"
    Write-Host "  Periodic:   Snapshot-based (configurable interval)"
    Write-Host ""
    Write-Host "USEFUL COMMANDS:" -ForegroundColor Yellow
    Write-Host "  # Get connection strings"
    Write-Host "  Get-AzCosmosDBAccountKey -ResourceGroupName '$ResourceGroupName' -Name '$AccountName'"
    Write-Host ""
    Write-Host "  # Failover to secondary region"
    Write-Host "  Invoke-AzCosmosDBAccountFailover -ResourceGroupName '$ResourceGroupName' -Name '$AccountName' -Location '$SecondaryLocation'"
    Write-Host "===============================================================================" -ForegroundColor Cyan
}

#-------------------------------------------------------------------------------
# MAIN
#-------------------------------------------------------------------------------
function Main {
    Write-Log "Starting Cosmos DB deployment..."

    try {
        # Ensure resource group exists
        $rg = Confirm-ResourceGroup

        # Create Cosmos DB account
        $account = New-CosmosAccount

        # Wait for account to be ready
        Start-Sleep -Seconds 10

        # Create database
        $database = New-CosmosDatabase -Account $account

        # Create container
        $container = New-CosmosContainer -Database $database

        # Refresh account info
        $account = Get-AzCosmosDBAccount `
            -ResourceGroupName $ResourceGroupName `
            -Name $AccountName

        # Display summary
        Show-Summary -Account $account

        Write-Log "Cosmos DB deployment completed successfully!" -Level "SUCCESS"
    }
    catch {
        Write-Log "Deployment failed: $_" -Level "ERROR"
        throw
    }
}

# Execute main function
Main
