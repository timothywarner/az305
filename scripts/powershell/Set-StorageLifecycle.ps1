<#
.SYNOPSIS
    Configure Azure Storage lifecycle management policies.

.DESCRIPTION
    This script configures storage lifecycle management including:
    - Tiering policies (Hot -> Cool -> Cold -> Archive)
    - Automatic deletion of old data
    - Blob version management
    - Snapshot management
    - Cost optimization through data lifecycle

.PARAMETER StorageAccountName
    Name of the storage account to configure.

.PARAMETER ResourceGroupName
    Resource group containing the storage account.

.PARAMETER PolicyName
    Name for the lifecycle policy. Default: default-lifecycle-policy

.PARAMETER DaysToMoveHotToCool
    Days before moving blobs from Hot to Cool tier. Default: 30

.PARAMETER DaysToMoveCoolToArchive
    Days before moving blobs from Cool to Archive tier. Default: 90

.PARAMETER DaysToDelete
    Days before deleting blobs. Default: 365

.EXAMPLE
    # Apply default lifecycle policy
    .\Set-StorageLifecycle.ps1 -StorageAccountName "mystorageacct" -ResourceGroupName "myRG"

.EXAMPLE
    # Custom tiering policy
    .\Set-StorageLifecycle.ps1 -StorageAccountName "mystorageacct" -ResourceGroupName "myRG" `
        -DaysToMoveHotToCool 14 -DaysToMoveCoolToArchive 60

.NOTES
    AZ-305 EXAM OBJECTIVES:
    - Design data storage solutions
    - Implement cost optimization for storage
    - Configure data retention and lifecycle policies
    - Understand storage tiers and access patterns

.LINK
    https://learn.microsoft.com/azure/storage/blobs/lifecycle-management-overview
    https://learn.microsoft.com/azure/storage/blobs/access-tiers-overview
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$StorageAccountName,

    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [string]$PolicyName = "default-lifecycle-policy",

    [Parameter(Mandatory = $false)]
    [int]$DaysToMoveHotToCool = 30,

    [Parameter(Mandatory = $false)]
    [int]$DaysToMoveCoolToArchive = 90,

    [Parameter(Mandatory = $false)]
    [int]$DaysToDelete = 365
)

#Requires -Modules Az.Accounts, Az.Storage

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
# VALIDATE STORAGE ACCOUNT
#-------------------------------------------------------------------------------
function Confirm-StorageAccount {
    Write-Log "Validating storage account: $StorageAccountName"

    $storageAccount = Get-AzStorageAccount `
        -ResourceGroupName $ResourceGroupName `
        -Name $StorageAccountName `
        -ErrorAction SilentlyContinue

    if (-not $storageAccount) {
        Write-Log "Storage account not found: $StorageAccountName" -Level "ERROR"
        throw "Storage account not found"
    }

    # WHY: Lifecycle management requires certain storage account configurations
    # - Must be GPv2, BlobStorage, or BlockBlobStorage
    # - Must have Blob service

    $supportedKinds = @("StorageV2", "BlobStorage", "BlockBlobStorage")
    if ($storageAccount.Kind -notin $supportedKinds) {
        Write-Log "Storage account kind '$($storageAccount.Kind)' does not support lifecycle management" -Level "ERROR"
        Write-Log "Supported kinds: $($supportedKinds -join ', ')"
        throw "Unsupported storage account kind"
    }

    Write-Log "Storage account validated: Kind=$($storageAccount.Kind), AccessTier=$($storageAccount.AccessTier)" -Level "SUCCESS"
    return $storageAccount
}

#-------------------------------------------------------------------------------
# GET CURRENT LIFECYCLE POLICY
#-------------------------------------------------------------------------------
function Get-CurrentLifecyclePolicy {
    Write-Log "Checking existing lifecycle policy..."

    try {
        $policy = Get-AzStorageAccountManagementPolicy `
            -ResourceGroupName $ResourceGroupName `
            -StorageAccountName $StorageAccountName `
            -ErrorAction SilentlyContinue

        if ($policy) {
            Write-Log "Existing policy found with $($policy.Rules.Count) rules"
            return $policy
        }
    }
    catch {
        # No existing policy
    }

    Write-Log "No existing lifecycle policy found"
    return $null
}

#-------------------------------------------------------------------------------
# CREATE LIFECYCLE RULES
#-------------------------------------------------------------------------------
function New-LifecycleRules {
    Write-Log "Creating lifecycle management rules..."

    $rules = @()

    # WHY: Rule 1 - Tier base blobs from Hot to Cool to Archive
    # This optimizes costs by moving infrequently accessed data to cheaper tiers

    $tieringAction = Add-AzStorageAccountManagementPolicyAction `
        -BaseBlobAction `
        -TierToCool -DaysAfterModificationGreaterThan $DaysToMoveHotToCool

    $tieringAction = Add-AzStorageAccountManagementPolicyAction `
        -InputObject $tieringAction `
        -BaseBlobAction `
        -TierToArchive -DaysAfterModificationGreaterThan $DaysToMoveCoolToArchive

    $tieringAction = Add-AzStorageAccountManagementPolicyAction `
        -InputObject $tieringAction `
        -BaseBlobAction `
        -Delete -DaysAfterModificationGreaterThan $DaysToDelete

    $tieringFilter = New-AzStorageAccountManagementPolicyFilter -BlobType blockBlob

    $tieringRule = New-AzStorageAccountManagementPolicyRule `
        -Name "TierAndDeleteRule" `
        -Enabled `
        -Action $tieringAction `
        -Filter $tieringFilter

    $rules += $tieringRule
    Write-Log "Created rule: TierAndDeleteRule (Hot->Cool:${DaysToMoveHotToCool}d, Cool->Archive:${DaysToMoveCoolToArchive}d, Delete:${DaysToDelete}d)"

    # WHY: Rule 2 - Delete old snapshots
    # Snapshots can accumulate and increase costs if not managed

    $snapshotAction = Add-AzStorageAccountManagementPolicyAction `
        -SnapshotAction `
        -Delete -DaysAfterCreationGreaterThan 90

    $snapshotFilter = New-AzStorageAccountManagementPolicyFilter -BlobType blockBlob

    $snapshotRule = New-AzStorageAccountManagementPolicyRule `
        -Name "DeleteOldSnapshots" `
        -Enabled `
        -Action $snapshotAction `
        -Filter $snapshotFilter

    $rules += $snapshotRule
    Write-Log "Created rule: DeleteOldSnapshots (delete after 90 days)"

    # WHY: Rule 3 - Delete old blob versions (if versioning enabled)
    # Versions can multiply storage costs if not cleaned up

    $versionAction = Add-AzStorageAccountManagementPolicyAction `
        -BlobVersionAction `
        -Delete -DaysAfterCreationGreaterThan 180

    $versionFilter = New-AzStorageAccountManagementPolicyFilter -BlobType blockBlob

    $versionRule = New-AzStorageAccountManagementPolicyRule `
        -Name "DeleteOldVersions" `
        -Enabled `
        -Action $versionAction `
        -Filter $versionFilter

    $rules += $versionRule
    Write-Log "Created rule: DeleteOldVersions (delete after 180 days)"

    # WHY: Rule 4 - Archive logs container more aggressively
    # Log data is typically needed for compliance but rarely accessed

    $logsAction = Add-AzStorageAccountManagementPolicyAction `
        -BaseBlobAction `
        -TierToCool -DaysAfterModificationGreaterThan 7

    $logsAction = Add-AzStorageAccountManagementPolicyAction `
        -InputObject $logsAction `
        -BaseBlobAction `
        -TierToArchive -DaysAfterModificationGreaterThan 30

    $logsAction = Add-AzStorageAccountManagementPolicyAction `
        -InputObject $logsAction `
        -BaseBlobAction `
        -Delete -DaysAfterModificationGreaterThan 365

    $logsFilter = New-AzStorageAccountManagementPolicyFilter `
        -BlobType blockBlob `
        -PrefixMatch "logs/", "audit-logs/"

    $logsRule = New-AzStorageAccountManagementPolicyRule `
        -Name "LogsLifecycle" `
        -Enabled `
        -Action $logsAction `
        -Filter $logsFilter

    $rules += $logsRule
    Write-Log "Created rule: LogsLifecycle (aggressive tiering for logs/ and audit-logs/ containers)"

    return $rules
}

#-------------------------------------------------------------------------------
# APPLY LIFECYCLE POLICY
#-------------------------------------------------------------------------------
function Set-LifecyclePolicy {
    param([array]$Rules)

    Write-Log "Applying lifecycle management policy..."

    try {
        $policy = Set-AzStorageAccountManagementPolicy `
            -ResourceGroupName $ResourceGroupName `
            -StorageAccountName $StorageAccountName `
            -Rule $Rules

        Write-Log "Lifecycle policy applied successfully with $($Rules.Count) rules" -Level "SUCCESS"
        return $policy
    }
    catch {
        Write-Log "Failed to apply lifecycle policy: $_" -Level "ERROR"
        throw
    }
}

#-------------------------------------------------------------------------------
# ESTIMATE COST SAVINGS
#-------------------------------------------------------------------------------
function Show-CostEstimate {
    Write-Host ""
    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host "                    ESTIMATED COST SAVINGS" -ForegroundColor Cyan
    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "STORAGE TIER PRICING (US East, per GB/month):" -ForegroundColor Yellow
    Write-Host "  Hot:     ~`$0.0184"
    Write-Host "  Cool:    ~`$0.01"
    Write-Host "  Cold:    ~`$0.0036"
    Write-Host "  Archive: ~`$0.00099"
    Write-Host ""
    Write-Host "POTENTIAL SAVINGS EXAMPLE (1 TB of data):" -ForegroundColor Yellow
    Write-Host "  All in Hot tier:                 ~`$18.84/month"
    Write-Host "  With lifecycle (70% archived):   ~`$6.00/month"
    Write-Host "  Monthly savings:                 ~`$12.84 (68%)"
    Write-Host ""
    Write-Host "NOTE: Actual savings depend on access patterns. Consider:" -ForegroundColor Gray
    Write-Host "  - Archive tier has higher access costs and retrieval time"
    Write-Host "  - Early deletion fees apply to Cool (30 days) and Archive (180 days)"
    Write-Host "  - Read/write transaction costs vary by tier"
    Write-Host ""
}

#-------------------------------------------------------------------------------
# DISPLAY SUMMARY
#-------------------------------------------------------------------------------
function Show-Summary {
    param([object]$Policy, [object]$StorageAccount)

    Write-Host ""
    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host "                 LIFECYCLE POLICY CONFIGURATION SUMMARY" -ForegroundColor Cyan
    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "STORAGE ACCOUNT:" -ForegroundColor Yellow
    Write-Host "  Name: $StorageAccountName"
    Write-Host "  Resource Group: $ResourceGroupName"
    Write-Host "  Kind: $($StorageAccount.Kind)"
    Write-Host "  Default Access Tier: $($StorageAccount.AccessTier)"
    Write-Host ""
    Write-Host "LIFECYCLE RULES:" -ForegroundColor Yellow
    Write-Host "-------------------------------------------------------------------------------"

    foreach ($rule in $Policy.Rules) {
        Write-Host "  Rule: $($rule.Name) [Enabled: $($rule.Enabled)]" -ForegroundColor Cyan
        Write-Host "    Filters:"
        Write-Host "      Blob Types: $($rule.Definition.Filters.BlobTypes -join ', ')"
        if ($rule.Definition.Filters.PrefixMatch) {
            Write-Host "      Prefix Match: $($rule.Definition.Filters.PrefixMatch -join ', ')"
        }

        Write-Host "    Actions:"
        if ($rule.Definition.Actions.BaseBlob) {
            $baseBlob = $rule.Definition.Actions.BaseBlob
            if ($baseBlob.TierToCool) {
                Write-Host "      Tier to Cool: After $($baseBlob.TierToCool.DaysAfterModificationGreaterThan) days"
            }
            if ($baseBlob.TierToArchive) {
                Write-Host "      Tier to Archive: After $($baseBlob.TierToArchive.DaysAfterModificationGreaterThan) days"
            }
            if ($baseBlob.Delete) {
                Write-Host "      Delete: After $($baseBlob.Delete.DaysAfterModificationGreaterThan) days"
            }
        }
        if ($rule.Definition.Actions.Snapshot) {
            Write-Host "      Delete Snapshots: After $($rule.Definition.Actions.Snapshot.Delete.DaysAfterCreationGreaterThan) days"
        }
        if ($rule.Definition.Actions.Version) {
            Write-Host "      Delete Versions: After $($rule.Definition.Actions.Version.Delete.DaysAfterCreationGreaterThan) days"
        }
        Write-Host ""
    }

    # Show cost estimate
    Show-CostEstimate

    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host "LIFECYCLE MANAGEMENT CONCEPTS (AZ-305 Exam Context):" -ForegroundColor Cyan
    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "ACCESS TIERS:" -ForegroundColor Yellow
    Write-Host "  Hot:     Frequent access, highest storage cost, lowest access cost"
    Write-Host "  Cool:    Infrequent access (30+ days), lower storage, higher access"
    Write-Host "  Cold:    Rarely accessed (90+ days), very low storage cost"
    Write-Host "  Archive: Long-term retention, lowest storage, hours to rehydrate"
    Write-Host ""
    Write-Host "RULE COMPONENTS:" -ForegroundColor Yellow
    Write-Host "  Filters: Which blobs the rule applies to (type, prefix, tags)"
    Write-Host "  Actions: What to do (tier change, delete)"
    Write-Host "  Conditions: When to act (days since modification/creation)"
    Write-Host ""
    Write-Host "BEST PRACTICES:" -ForegroundColor Yellow
    Write-Host "  - Understand data access patterns before configuring"
    Write-Host "  - Consider early deletion fees (Cool: 30d, Archive: 180d)"
    Write-Host "  - Use prefix filters for different data classifications"
    Write-Host "  - Test with audit mode before enabling delete actions"
    Write-Host "  - Monitor Blob Inventory reports for optimization"
    Write-Host ""
    Write-Host "USEFUL COMMANDS:" -ForegroundColor Yellow
    Write-Host "  # View current policy"
    Write-Host "  Get-AzStorageAccountManagementPolicy -ResourceGroupName '$ResourceGroupName' -StorageAccountName '$StorageAccountName'"
    Write-Host ""
    Write-Host "  # Remove policy"
    Write-Host "  Remove-AzStorageAccountManagementPolicy -ResourceGroupName '$ResourceGroupName' -StorageAccountName '$StorageAccountName'"
    Write-Host "===============================================================================" -ForegroundColor Cyan
}

#-------------------------------------------------------------------------------
# MAIN
#-------------------------------------------------------------------------------
function Main {
    Write-Log "Starting Storage Lifecycle configuration..."

    try {
        # Validate storage account
        $storageAccount = Confirm-StorageAccount

        # Check existing policy
        $existingPolicy = Get-CurrentLifecyclePolicy

        if ($existingPolicy) {
            Write-Log "Existing policy will be replaced" -Level "WARNING"
        }

        # Create rules
        $rules = New-LifecycleRules

        # Apply policy
        $policy = Set-LifecyclePolicy -Rules $rules

        # Display summary
        Show-Summary -Policy $policy -StorageAccount $storageAccount

        Write-Log "Storage Lifecycle configuration completed successfully!" -Level "SUCCESS"
    }
    catch {
        Write-Log "Configuration failed: $_" -Level "ERROR"
        throw
    }
}

# Execute main function
Main
