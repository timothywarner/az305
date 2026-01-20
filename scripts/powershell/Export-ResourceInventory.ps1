<#
.SYNOPSIS
    Export a comprehensive inventory of Azure resources.

.DESCRIPTION
    This script generates a detailed inventory report of Azure resources including:
    - Resource counts by type and region
    - Resource metadata and tags
    - Cost-related information
    - Compliance and security status
    - Export to CSV and JSON formats

    Useful for auditing, cost optimization, and governance reporting.

.PARAMETER SubscriptionId
    Azure subscription to inventory. If not specified, uses current context.

.PARAMETER OutputPath
    Path for output files. Default: current directory.

.PARAMETER IncludeTags
    Include resource tags in the export. Default: true.

.PARAMETER ExportFormat
    Output format: CSV, JSON, or Both. Default: Both.

.EXAMPLE
    # Export inventory for current subscription
    .\Export-ResourceInventory.ps1 -OutputPath "C:\Reports"

.EXAMPLE
    # Export specific subscription
    .\Export-ResourceInventory.ps1 -SubscriptionId "xxx" -ExportFormat "CSV"

.NOTES
    AZ-305 EXAM OBJECTIVES:
    - Design monitoring and governance solutions
    - Implement resource inventory and compliance tracking
    - Understand Azure Resource Graph for querying at scale
    - Design for operational visibility

.LINK
    https://learn.microsoft.com/azure/governance/resource-graph/overview
    https://learn.microsoft.com/azure/azure-resource-manager/management/azure-resource-manager-security-controls
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = ".",

    [Parameter(Mandatory = $false)]
    [bool]$IncludeTags = $true,

    [Parameter(Mandatory = $false)]
    [ValidateSet("CSV", "JSON", "Both")]
    [string]$ExportFormat = "Both"
)

#Requires -Modules Az.Accounts, Az.Resources, Az.ResourceGraph

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
# CONNECT TO AZURE
#-------------------------------------------------------------------------------
function Connect-ToAzure {
    Write-Log "Connecting to Azure..."

    $context = Get-AzContext -ErrorAction SilentlyContinue
    if (-not $context) {
        Connect-AzAccount
    }

    if ($SubscriptionId) {
        Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
    }

    $script:SubscriptionId = (Get-AzContext).Subscription.Id
    $script:SubscriptionName = (Get-AzContext).Subscription.Name

    Write-Log "Connected to: $SubscriptionName ($SubscriptionId)" -Level "SUCCESS"
}

#-------------------------------------------------------------------------------
# GET ALL RESOURCES USING RESOURCE GRAPH
#-------------------------------------------------------------------------------
function Get-AllResources {
    Write-Log "Querying all resources using Azure Resource Graph..."

    # WHY: Resource Graph provides fast, efficient queries across subscriptions
    # Much faster than iterating through Get-AzResource for large environments

    $query = @"
Resources
| project
    id,
    name,
    type,
    resourceGroup,
    location,
    subscriptionId,
    sku = properties.sku,
    kind,
    tags,
    properties
| order by type asc, name asc
"@

    try {
        $resources = Search-AzGraph -Query $query -Subscription $SubscriptionId -First 1000

        # Handle pagination for large environments
        $allResources = @($resources)
        while ($resources.SkipToken) {
            $resources = Search-AzGraph -Query $query -Subscription $SubscriptionId -First 1000 -SkipToken $resources.SkipToken
            $allResources += $resources
        }

        Write-Log "Found $($allResources.Count) resources" -Level "SUCCESS"
        return $allResources
    }
    catch {
        Write-Log "Resource Graph query failed. Falling back to Get-AzResource..." -Level "WARNING"
        $resources = Get-AzResource
        Write-Log "Found $($resources.Count) resources using Get-AzResource"
        return $resources
    }
}

#-------------------------------------------------------------------------------
# GET RESOURCE GROUPS
#-------------------------------------------------------------------------------
function Get-ResourceGroupInventory {
    Write-Log "Getting resource group inventory..."

    $resourceGroups = Get-AzResourceGroup | Select-Object `
        ResourceGroupName,
        Location,
        ProvisioningState,
        @{N = 'Tags'; E = { ($_.Tags | ConvertTo-Json -Compress) } }

    Write-Log "Found $($resourceGroups.Count) resource groups"
    return $resourceGroups
}

#-------------------------------------------------------------------------------
# GET RESOURCE SUMMARY BY TYPE
#-------------------------------------------------------------------------------
function Get-ResourceSummaryByType {
    param([array]$Resources)

    Write-Log "Generating resource summary by type..."

    $summary = $Resources | Group-Object -Property type | ForEach-Object {
        [PSCustomObject]@{
            ResourceType = $_.Name
            Count        = $_.Count
            Percentage   = [math]::Round(($_.Count / $Resources.Count) * 100, 2)
        }
    } | Sort-Object -Property Count -Descending

    return $summary
}

#-------------------------------------------------------------------------------
# GET RESOURCE SUMMARY BY LOCATION
#-------------------------------------------------------------------------------
function Get-ResourceSummaryByLocation {
    param([array]$Resources)

    Write-Log "Generating resource summary by location..."

    $summary = $Resources | Group-Object -Property location | ForEach-Object {
        [PSCustomObject]@{
            Location   = $_.Name
            Count      = $_.Count
            Percentage = [math]::Round(($_.Count / $Resources.Count) * 100, 2)
        }
    } | Sort-Object -Property Count -Descending

    return $summary
}

#-------------------------------------------------------------------------------
# GET TAG COMPLIANCE
#-------------------------------------------------------------------------------
function Get-TagComplianceReport {
    param([array]$Resources)

    Write-Log "Analyzing tag compliance..."

    # WHY: Tag compliance is essential for cost allocation and governance
    # Identifying untagged resources helps improve organizational hygiene

    $requiredTags = @("Environment", "Owner", "CostCenter", "Project")

    $tagReport = foreach ($resource in $Resources) {
        $resourceTags = if ($resource.tags) { $resource.tags.PSObject.Properties.Name } else { @() }

        $missingTags = $requiredTags | Where-Object { $_ -notin $resourceTags }

        [PSCustomObject]@{
            ResourceName       = $resource.name
            ResourceType       = $resource.type
            ResourceGroup      = $resource.resourceGroup
            HasEnvironmentTag  = "Environment" -in $resourceTags
            HasOwnerTag        = "Owner" -in $resourceTags
            HasCostCenterTag   = "CostCenter" -in $resourceTags
            HasProjectTag      = "Project" -in $resourceTags
            MissingTags        = ($missingTags -join ", ")
            CompliancePercent  = [math]::Round((($requiredTags.Count - $missingTags.Count) / $requiredTags.Count) * 100, 0)
        }
    }

    $compliantCount = ($tagReport | Where-Object { $_.CompliancePercent -eq 100 }).Count
    $totalCount = $tagReport.Count

    Write-Log "Tag Compliance: $compliantCount / $totalCount resources fully tagged ($([math]::Round(($compliantCount / $totalCount) * 100, 1))%)"

    return $tagReport
}

#-------------------------------------------------------------------------------
# BUILD COMPREHENSIVE INVENTORY
#-------------------------------------------------------------------------------
function Build-ResourceInventory {
    param([array]$Resources)

    Write-Log "Building comprehensive resource inventory..."

    $inventory = foreach ($resource in $Resources) {
        # Extract common tag values
        $tags = $resource.tags

        [PSCustomObject]@{
            # Basic Information
            Name              = $resource.name
            Type              = $resource.type
            TypeShort         = ($resource.type -split '/')[-1]
            Kind              = $resource.kind
            Location          = $resource.location
            ResourceGroup     = $resource.resourceGroup
            SubscriptionId    = $resource.subscriptionId

            # Resource ID
            ResourceId        = $resource.id

            # Tags (if included)
            Environment       = if ($tags) { $tags.Environment } else { $null }
            Owner             = if ($tags) { $tags.Owner } else { $null }
            CostCenter        = if ($tags) { $tags.CostCenter } else { $null }
            Project           = if ($tags) { $tags.Project } else { $null }
            AllTags           = if ($IncludeTags -and $tags) { ($tags | ConvertTo-Json -Compress) } else { $null }

            # Metadata
            ExportDate        = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            ExportedBy        = (Get-AzContext).Account.Id
        }
    }

    return $inventory
}

#-------------------------------------------------------------------------------
# EXPORT REPORTS
#-------------------------------------------------------------------------------
function Export-Reports {
    param(
        [array]$Inventory,
        [array]$ResourceGroups,
        [array]$TypeSummary,
        [array]$LocationSummary,
        [array]$TagReport
    )

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $baseName = "azure-inventory-$SubscriptionId-$timestamp"

    # Ensure output directory exists
    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath | Out-Null
    }

    if ($ExportFormat -in @("CSV", "Both")) {
        Write-Log "Exporting to CSV..."

        # Main inventory
        $Inventory | Export-Csv -Path (Join-Path $OutputPath "$baseName-resources.csv") -NoTypeInformation

        # Resource groups
        $ResourceGroups | Export-Csv -Path (Join-Path $OutputPath "$baseName-resourcegroups.csv") -NoTypeInformation

        # Summaries
        $TypeSummary | Export-Csv -Path (Join-Path $OutputPath "$baseName-summary-by-type.csv") -NoTypeInformation
        $LocationSummary | Export-Csv -Path (Join-Path $OutputPath "$baseName-summary-by-location.csv") -NoTypeInformation

        # Tag compliance
        $TagReport | Export-Csv -Path (Join-Path $OutputPath "$baseName-tag-compliance.csv") -NoTypeInformation

        Write-Log "CSV files exported to: $OutputPath" -Level "SUCCESS"
    }

    if ($ExportFormat -in @("JSON", "Both")) {
        Write-Log "Exporting to JSON..."

        $fullReport = @{
            Metadata        = @{
                SubscriptionId   = $SubscriptionId
                SubscriptionName = $SubscriptionName
                ExportDate       = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                ExportedBy       = (Get-AzContext).Account.Id
                TotalResources   = $Inventory.Count
            }
            Resources       = $Inventory
            ResourceGroups  = $ResourceGroups
            SummaryByType   = $TypeSummary
            SummaryByLoc    = $LocationSummary
            TagCompliance   = $TagReport
        }

        $fullReport | ConvertTo-Json -Depth 10 | Out-File (Join-Path $OutputPath "$baseName-full-report.json")

        Write-Log "JSON file exported to: $OutputPath" -Level "SUCCESS"
    }

    return @{
        BaseName   = $baseName
        OutputPath = $OutputPath
    }
}

#-------------------------------------------------------------------------------
# DISPLAY SUMMARY
#-------------------------------------------------------------------------------
function Show-InventorySummary {
    param(
        [array]$Inventory,
        [array]$TypeSummary,
        [array]$LocationSummary,
        [array]$TagReport,
        [hashtable]$ExportInfo
    )

    Write-Host ""
    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host "                    RESOURCE INVENTORY SUMMARY" -ForegroundColor Cyan
    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Subscription: $SubscriptionName"
    Write-Host "Total Resources: $($Inventory.Count)"
    Write-Host "Export Path: $($ExportInfo.OutputPath)"
    Write-Host ""

    Write-Host "TOP 10 RESOURCE TYPES:" -ForegroundColor Yellow
    Write-Host "-------------------------------------------------------------------------------"
    $TypeSummary | Select-Object -First 10 | Format-Table -AutoSize

    Write-Host "RESOURCES BY LOCATION:" -ForegroundColor Yellow
    Write-Host "-------------------------------------------------------------------------------"
    $LocationSummary | Format-Table -AutoSize

    Write-Host "TAG COMPLIANCE SUMMARY:" -ForegroundColor Yellow
    Write-Host "-------------------------------------------------------------------------------"
    $compliant = ($TagReport | Where-Object { $_.CompliancePercent -eq 100 }).Count
    $partial = ($TagReport | Where-Object { $_.CompliancePercent -gt 0 -and $_.CompliancePercent -lt 100 }).Count
    $none = ($TagReport | Where-Object { $_.CompliancePercent -eq 0 }).Count

    Write-Host "  Fully Tagged:     $compliant resources"
    Write-Host "  Partially Tagged: $partial resources"
    Write-Host "  No Tags:          $none resources"
    Write-Host ""

    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host "INVENTORY CONCEPTS (AZ-305 Exam Context):" -ForegroundColor Cyan
    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "AZURE RESOURCE GRAPH:" -ForegroundColor Yellow
    Write-Host "  - Query resources at scale across subscriptions"
    Write-Host "  - Much faster than ARM REST API iteration"
    Write-Host "  - Supports complex queries with joins"
    Write-Host "  - Used by Azure Policy compliance checks"
    Write-Host ""
    Write-Host "GOVERNANCE REPORTING:" -ForegroundColor Yellow
    Write-Host "  - Tag compliance for cost allocation"
    Write-Host "  - Resource distribution analysis"
    Write-Host "  - Orphaned resource identification"
    Write-Host "  - Security and compliance auditing"
    Write-Host ""
    Write-Host "COST OPTIMIZATION:" -ForegroundColor Yellow
    Write-Host "  - Identify unused/underutilized resources"
    Write-Host "  - Track resource sprawl by region"
    Write-Host "  - Ensure proper tagging for cost attribution"
    Write-Host "===============================================================================" -ForegroundColor Cyan
}

#-------------------------------------------------------------------------------
# MAIN
#-------------------------------------------------------------------------------
function Main {
    Write-Log "Starting Resource Inventory export..."

    try {
        # Connect to Azure
        Connect-ToAzure

        # Get all resources
        $resources = Get-AllResources

        # Get resource groups
        $resourceGroups = Get-ResourceGroupInventory

        # Generate summaries
        $typeSummary = Get-ResourceSummaryByType -Resources $resources
        $locationSummary = Get-ResourceSummaryByLocation -Resources $resources

        # Tag compliance analysis
        $tagReport = Get-TagComplianceReport -Resources $resources

        # Build comprehensive inventory
        $inventory = Build-ResourceInventory -Resources $resources

        # Export reports
        $exportInfo = Export-Reports `
            -Inventory $inventory `
            -ResourceGroups $resourceGroups `
            -TypeSummary $typeSummary `
            -LocationSummary $locationSummary `
            -TagReport $tagReport

        # Display summary
        Show-InventorySummary `
            -Inventory $inventory `
            -TypeSummary $typeSummary `
            -LocationSummary $locationSummary `
            -TagReport $tagReport `
            -ExportInfo $exportInfo

        Write-Log "Resource Inventory export completed successfully!" -Level "SUCCESS"
    }
    catch {
        Write-Log "Export failed: $_" -Level "ERROR"
        throw
    }
}

# Execute main function
Main
