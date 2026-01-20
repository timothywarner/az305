<#
.SYNOPSIS
    Create and assign Azure Policy initiatives for governance.

.DESCRIPTION
    This script demonstrates Azure Policy governance including:
    - Creating custom policy definitions
    - Building policy initiatives (policy sets)
    - Assigning initiatives at different scopes
    - Checking compliance status
    - Creating remediation tasks

    Implements common governance scenarios for AZ-305 exam preparation.

.PARAMETER SubscriptionId
    The Azure subscription ID for policy deployment.

.PARAMETER Scope
    The scope for policy assignment (subscription, resource group).

.PARAMETER InitiativeName
    Name for the policy initiative. Default: AZ305-Governance-Initiative

.PARAMETER EnforcementMode
    Policy enforcement mode: Default (enforce) or DoNotEnforce (audit only).

.EXAMPLE
    # Deploy initiative in audit mode
    .\Configure-PolicyInitiative.ps1 -SubscriptionId "xxx" -EnforcementMode "DoNotEnforce"

.EXAMPLE
    # Deploy and enforce at resource group scope
    .\Configure-PolicyInitiative.ps1 -SubscriptionId "xxx" -Scope "/subscriptions/xxx/resourceGroups/myRG"

.NOTES
    AZ-305 EXAM OBJECTIVES:
    - Design identity, governance, and monitoring solutions
    - Implement Azure Policy for resource governance
    - Understand policy effects (Deny, Audit, DeployIfNotExists, Modify)
    - Design for compliance and regulatory requirements

.LINK
    https://learn.microsoft.com/azure/governance/policy/overview
    https://learn.microsoft.com/azure/governance/policy/concepts/initiative-definition-structure
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $false)]
    [string]$Scope,

    [Parameter(Mandatory = $false)]
    [string]$InitiativeName = "AZ305-Governance-Initiative",

    [Parameter(Mandatory = $false)]
    [ValidateSet("Default", "DoNotEnforce")]
    [string]$EnforcementMode = "DoNotEnforce"
)

#Requires -Modules Az.Accounts, Az.Resources

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
    Write-Log "Connecting to Azure subscription: $SubscriptionId"

    $context = Get-AzContext -ErrorAction SilentlyContinue
    if (-not $context -or $context.Subscription.Id -ne $SubscriptionId) {
        Connect-AzAccount -SubscriptionId $SubscriptionId
    }

    Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
    Write-Log "Connected to subscription: $((Get-AzContext).Subscription.Name)" -Level "SUCCESS"

    # Set default scope if not provided
    if (-not $Scope) {
        $script:Scope = "/subscriptions/$SubscriptionId"
        Write-Log "Using subscription scope: $Scope"
    }
}

#-------------------------------------------------------------------------------
# CREATE CUSTOM POLICY DEFINITION: REQUIRE TAGS
#-------------------------------------------------------------------------------
function New-RequireTagsPolicy {
    Write-Log "Creating custom policy: Require specific tags on resources..."

    # WHY: Tags enable cost allocation, resource organization, and automation
    # This policy ensures resources have required tags for governance

    $policyName = "require-environment-tag"
    $displayName = "Require Environment tag on resources"

    $existingPolicy = Get-AzPolicyDefinition -Name $policyName -ErrorAction SilentlyContinue

    if (-not $existingPolicy) {
        # Policy rule definition
        # WHY: 'deny' effect prevents non-compliant resources from being created
        $policyRule = @{
            if   = @{
                allOf = @(
                    @{
                        field  = "type"
                        equals = "Microsoft.Resources/subscriptions/resourceGroups"
                    },
                    @{
                        field  = "tags['Environment']"
                        exists = "false"
                    }
                )
            }
            then = @{
                effect = "[parameters('effect')]"
            }
        }

        $policyParams = @{
            effect = @{
                type          = "String"
                metadata      = @{
                    displayName = "Effect"
                    description = "The effect to apply when the policy rule is matched"
                }
                allowedValues = @("Audit", "Deny", "Disabled")
                defaultValue  = "Audit"
            }
        }

        $policy = New-AzPolicyDefinition `
            -Name $policyName `
            -DisplayName $displayName `
            -Description "Ensures all resource groups have an Environment tag for cost allocation and governance." `
            -Policy ($policyRule | ConvertTo-Json -Depth 10) `
            -Parameter ($policyParams | ConvertTo-Json -Depth 10) `
            -Mode "Indexed" `
            -Metadata '{"category":"Tags"}'

        Write-Log "Created custom policy: $displayName" -Level "SUCCESS"
        return $policy
    }
    else {
        Write-Log "Policy already exists: $displayName"
        return $existingPolicy
    }
}

#-------------------------------------------------------------------------------
# CREATE CUSTOM POLICY DEFINITION: ALLOWED LOCATIONS
#-------------------------------------------------------------------------------
function New-AllowedLocationsPolicy {
    Write-Log "Creating custom policy: Allowed locations for resources..."

    # WHY: Location restrictions ensure data residency compliance
    # and help control costs by preventing deployment to expensive regions

    $policyName = "allowed-locations-custom"
    $displayName = "Allowed resource locations (Custom)"

    $existingPolicy = Get-AzPolicyDefinition -Name $policyName -ErrorAction SilentlyContinue

    if (-not $existingPolicy) {
        $policyRule = @{
            if   = @{
                allOf = @(
                    @{
                        field    = "location"
                        notIn    = "[parameters('allowedLocations')]"
                    },
                    @{
                        field    = "location"
                        notEquals = "global"
                    }
                )
            }
            then = @{
                effect = "[parameters('effect')]"
            }
        }

        $policyParams = @{
            allowedLocations = @{
                type     = "Array"
                metadata = @{
                    displayName = "Allowed locations"
                    description = "The list of allowed locations for resources"
                    strongType  = "location"
                }
                defaultValue = @("eastus", "eastus2", "westus", "westus2")
            }
            effect           = @{
                type          = "String"
                allowedValues = @("Audit", "Deny", "Disabled")
                defaultValue  = "Audit"
            }
        }

        $policy = New-AzPolicyDefinition `
            -Name $policyName `
            -DisplayName $displayName `
            -Description "Restricts resource deployment to specific Azure regions for compliance and cost control." `
            -Policy ($policyRule | ConvertTo-Json -Depth 10) `
            -Parameter ($policyParams | ConvertTo-Json -Depth 10) `
            -Mode "Indexed" `
            -Metadata '{"category":"General"}'

        Write-Log "Created custom policy: $displayName" -Level "SUCCESS"
        return $policy
    }
    else {
        Write-Log "Policy already exists: $displayName"
        return $existingPolicy
    }
}

#-------------------------------------------------------------------------------
# CREATE POLICY INITIATIVE (POLICY SET)
#-------------------------------------------------------------------------------
function New-GovernanceInitiative {
    param(
        [object]$RequireTagsPolicy,
        [object]$AllowedLocationsPolicy
    )

    Write-Log "Creating policy initiative: $InitiativeName..."

    # WHY: Initiatives group related policies for easier assignment and management
    # Assigning an initiative applies all contained policies at once

    $existingInitiative = Get-AzPolicySetDefinition -Name $InitiativeName -ErrorAction SilentlyContinue

    if (-not $existingInitiative) {
        # Get built-in policies to include
        $httpsStoragePolicy = Get-AzPolicyDefinition | Where-Object {
            $_.Properties.DisplayName -eq "Secure transfer to storage accounts should be enabled"
        } | Select-Object -First 1

        $sqlAuditPolicy = Get-AzPolicyDefinition | Where-Object {
            $_.Properties.DisplayName -eq "Auditing on SQL server should be enabled"
        } | Select-Object -First 1

        # Build policy definitions array for initiative
        $policyDefinitions = @(
            @{
                policyDefinitionId          = $RequireTagsPolicy.PolicyDefinitionId
                policyDefinitionReferenceId = "require-environment-tag"
                parameters                  = @{
                    effect = @{ value = "[parameters('tagPolicyEffect')]" }
                }
            },
            @{
                policyDefinitionId          = $AllowedLocationsPolicy.PolicyDefinitionId
                policyDefinitionReferenceId = "allowed-locations"
                parameters                  = @{
                    effect           = @{ value = "[parameters('locationPolicyEffect')]" }
                    allowedLocations = @{ value = "[parameters('allowedLocations')]" }
                }
            }
        )

        # Add built-in policies if found
        if ($httpsStoragePolicy) {
            $policyDefinitions += @{
                policyDefinitionId          = $httpsStoragePolicy.PolicyDefinitionId
                policyDefinitionReferenceId = "storage-https-only"
            }
        }

        if ($sqlAuditPolicy) {
            $policyDefinitions += @{
                policyDefinitionId          = $sqlAuditPolicy.PolicyDefinitionId
                policyDefinitionReferenceId = "sql-auditing-enabled"
            }
        }

        # Initiative parameters
        $initiativeParams = @{
            tagPolicyEffect      = @{
                type          = "String"
                allowedValues = @("Audit", "Deny", "Disabled")
                defaultValue  = "Audit"
            }
            locationPolicyEffect = @{
                type          = "String"
                allowedValues = @("Audit", "Deny", "Disabled")
                defaultValue  = "Audit"
            }
            allowedLocations     = @{
                type         = "Array"
                defaultValue = @("eastus", "eastus2", "westus", "westus2")
            }
        }

        $initiative = New-AzPolicySetDefinition `
            -Name $InitiativeName `
            -DisplayName "AZ-305 Governance Initiative" `
            -Description "Policy initiative demonstrating governance patterns for AZ-305 exam preparation" `
            -PolicyDefinition ($policyDefinitions | ConvertTo-Json -Depth 10) `
            -Parameter ($initiativeParams | ConvertTo-Json -Depth 10) `
            -Metadata '{"category":"Governance","version":"1.0.0"}'

        Write-Log "Created policy initiative: $InitiativeName" -Level "SUCCESS"
        return $initiative
    }
    else {
        Write-Log "Policy initiative already exists: $InitiativeName"
        return $existingInitiative
    }
}

#-------------------------------------------------------------------------------
# ASSIGN POLICY INITIATIVE
#-------------------------------------------------------------------------------
function New-InitiativeAssignment {
    param([object]$Initiative)

    Write-Log "Assigning policy initiative to scope: $Scope..."

    # WHY: Policy assignment determines where the policy is enforced
    # EnforcementMode allows testing policies without blocking deployments

    $assignmentName = "$InitiativeName-assignment"

    $existingAssignment = Get-AzPolicyAssignment -Name $assignmentName -Scope $Scope -ErrorAction SilentlyContinue

    if (-not $existingAssignment) {
        $assignmentParams = @{
            tagPolicyEffect      = "Audit"
            locationPolicyEffect = "Audit"
            allowedLocations     = @("eastus", "eastus2", "westus", "westus2")
        }

        $assignment = New-AzPolicyAssignment `
            -Name $assignmentName `
            -DisplayName "AZ-305 Governance Initiative Assignment" `
            -PolicySetDefinition $Initiative `
            -Scope $Scope `
            -EnforcementMode $EnforcementMode `
            -PolicyParameterObject $assignmentParams `
            -IdentityType "SystemAssigned" `
            -Location "eastus"

        Write-Log "Created policy assignment: $assignmentName" -Level "SUCCESS"
        Write-Log "Enforcement Mode: $EnforcementMode (DoNotEnforce = audit only)" -Level "WARNING"
        return $assignment
    }
    else {
        Write-Log "Policy assignment already exists: $assignmentName"
        return $existingAssignment
    }
}

#-------------------------------------------------------------------------------
# CHECK COMPLIANCE STATUS
#-------------------------------------------------------------------------------
function Get-ComplianceStatus {
    param([string]$AssignmentName)

    Write-Log "Checking compliance status (may take a few minutes to populate)..."

    # WHY: Compliance evaluation helps identify non-compliant resources
    # and track governance progress over time

    try {
        $complianceState = Get-AzPolicyState `
            -PolicyAssignmentName $AssignmentName `
            -Filter "ComplianceState eq 'NonCompliant'" `
            -Top 10 `
            -ErrorAction SilentlyContinue

        if ($complianceState) {
            Write-Log "Found $($complianceState.Count) non-compliant resources" -Level "WARNING"
            return $complianceState
        }
        else {
            Write-Log "No compliance data available yet. Evaluation may take up to 30 minutes." -Level "INFO"
            return $null
        }
    }
    catch {
        Write-Log "Compliance data not yet available. This is normal for new assignments." -Level "WARNING"
        return $null
    }
}

#-------------------------------------------------------------------------------
# DISPLAY SUMMARY
#-------------------------------------------------------------------------------
function Show-DeploymentSummary {
    param(
        [object]$Initiative,
        [object]$Assignment
    )

    Write-Host ""
    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host "                   POLICY INITIATIVE DEPLOYMENT SUMMARY" -ForegroundColor Cyan
    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "INITIATIVE:" -ForegroundColor Yellow
    Write-Host "  Name: $($Initiative.Name)"
    Write-Host "  Display Name: $($Initiative.Properties.DisplayName)"
    Write-Host "  Policies Included: $($Initiative.Properties.PolicyDefinitions.Count)"
    Write-Host ""
    Write-Host "ASSIGNMENT:" -ForegroundColor Yellow
    Write-Host "  Name: $($Assignment.Name)"
    Write-Host "  Scope: $Scope"
    Write-Host "  Enforcement Mode: $EnforcementMode"
    Write-Host ""
    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host "AZURE POLICY CONCEPTS (AZ-305 Exam Context):" -ForegroundColor Cyan
    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "POLICY EFFECTS:" -ForegroundColor Yellow
    Write-Host "  Deny: Prevents non-compliant resource creation/modification"
    Write-Host "  Audit: Logs warning but allows resource creation"
    Write-Host "  AuditIfNotExists: Audits if related resource doesn't exist"
    Write-Host "  DeployIfNotExists: Deploys related resource if missing"
    Write-Host "  Modify: Adds/updates/removes tags or properties"
    Write-Host "  Disabled: Policy is not evaluated"
    Write-Host ""
    Write-Host "INITIATIVE vs POLICY:" -ForegroundColor Yellow
    Write-Host "  Policy Definition: Single rule (e.g., require HTTPS)"
    Write-Host "  Initiative (Policy Set): Group of related policies"
    Write-Host "  Assignment: Applies policy/initiative to a scope"
    Write-Host ""
    Write-Host "EVALUATION ORDER:" -ForegroundColor Yellow
    Write-Host "  1. Disabled"
    Write-Host "  2. Append/Modify"
    Write-Host "  3. Deny"
    Write-Host "  4. Audit"
    Write-Host ""
    Write-Host "USEFUL COMMANDS:" -ForegroundColor Yellow
    Write-Host "  # Check compliance status"
    Write-Host "  Get-AzPolicyState -PolicyAssignmentName '$($Assignment.Name)' -Filter `"ComplianceState eq 'NonCompliant'`""
    Write-Host ""
    Write-Host "  # Start remediation"
    Write-Host "  Start-AzPolicyRemediation -Name 'remediate-tags' -PolicyAssignmentId '$($Assignment.PolicyAssignmentId)'"
    Write-Host ""
    Write-Host "  # List all assignments"
    Write-Host "  Get-AzPolicyAssignment | Format-Table Name, DisplayName, EnforcementMode"
    Write-Host "===============================================================================" -ForegroundColor Cyan
}

#-------------------------------------------------------------------------------
# MAIN
#-------------------------------------------------------------------------------
function Main {
    Write-Log "Starting Policy Initiative deployment..."

    try {
        # Connect to Azure
        Connect-ToAzure

        # Create custom policies
        $requireTagsPolicy = New-RequireTagsPolicy
        $allowedLocationsPolicy = New-AllowedLocationsPolicy

        # Create initiative
        $initiative = New-GovernanceInitiative `
            -RequireTagsPolicy $requireTagsPolicy `
            -AllowedLocationsPolicy $allowedLocationsPolicy

        # Assign initiative
        $assignment = New-InitiativeAssignment -Initiative $initiative

        # Check compliance (informational)
        $compliance = Get-ComplianceStatus -AssignmentName $assignment.Name

        # Display summary
        Show-DeploymentSummary -Initiative $initiative -Assignment $assignment

        Write-Log "Policy Initiative deployment completed successfully!" -Level "SUCCESS"
    }
    catch {
        Write-Log "Deployment failed: $_" -Level "ERROR"
        throw
    }
}

# Execute main function
Main
