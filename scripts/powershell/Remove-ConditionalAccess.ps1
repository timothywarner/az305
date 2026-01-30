<#
.SYNOPSIS
    Remove all AZ305-Demo Conditional Access policies and named locations.

.DESCRIPTION
    Cleans up Conditional Access policies and named locations created by
    Configure-ConditionalAccess.ps1. Identifies demo resources by the
    "AZ305-Demo:" display name prefix.

    This script prompts for confirmation before deleting each policy
    unless -Force is specified.

.PARAMETER Force
    Skip individual confirmation prompts and remove all matching policies.
    A single confirmation prompt is still shown unless -Confirm:$false.

.EXAMPLE
    # Interactive removal with per-policy confirmation
    .\Remove-ConditionalAccess.ps1

.EXAMPLE
    # Remove all demo policies without individual prompts
    .\Remove-ConditionalAccess.ps1 -Force

.NOTES
    AZ-305 EXAM OBJECTIVES:
    - Understand Conditional Access policy lifecycle management
    - Practice safe policy deployment and rollback patterns

.LINK
    https://learn.microsoft.com/entra/identity/conditional-access/plan-conditional-access
#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param (
    [Parameter(Mandatory = $false)]
    [switch]$Force
)

#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Identity.SignIns

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$PolicyPrefix = 'AZ305-Demo:'

# ---------------------------------------------------------------------------
# Connect to Microsoft Graph
# ---------------------------------------------------------------------------
Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host "  AZ-305 Demo: Conditional Access Cleanup" -ForegroundColor Cyan
Write-Host "==================================================`n" -ForegroundColor Cyan

try {
    $context = Get-MgContext
    if ($null -eq $context) {
        Connect-MgGraph -Scopes 'Policy.ReadWrite.ConditionalAccess', 'Policy.Read.All' -ErrorAction Stop
    }
    else {
        Write-Host "Connected as $($context.Account)." -ForegroundColor Gray
    }
}
catch {
    throw "Failed to connect to Microsoft Graph. Error: $_"
}

# ---------------------------------------------------------------------------
# Find and remove demo CA policies
# ---------------------------------------------------------------------------
Write-Host "Searching for Conditional Access policies with prefix '$PolicyPrefix'...`n" -ForegroundColor Cyan

$allPolicies = Get-MgIdentityConditionalAccessPolicy -All -ErrorAction Stop
$demoPolicies = $allPolicies | Where-Object { $_.DisplayName -like "$PolicyPrefix*" }

if ($demoPolicies.Count -eq 0) {
    Write-Host "No demo policies found. Nothing to remove." -ForegroundColor Yellow
}
else {
    Write-Host "Found $($demoPolicies.Count) demo policies:`n" -ForegroundColor White
    $demoPolicies | ForEach-Object { Write-Host "  - $($_.DisplayName) ($($_.Id))" -ForegroundColor Gray }
    Write-Host ""

    if ($Force -or $PSCmdlet.ShouldProcess("$($demoPolicies.Count) Conditional Access policies", 'Remove all AZ305-Demo policies')) {
        foreach ($policy in $demoPolicies) {
            $shouldRemove = $Force -or $PSCmdlet.ShouldProcess($policy.DisplayName, 'Remove')
            if ($shouldRemove) {
                try {
                    Remove-MgIdentityConditionalAccessPolicy -ConditionalAccessPolicyId $policy.Id -ErrorAction Stop
                    Write-Host "  [REMOVED] $($policy.DisplayName)" -ForegroundColor Green
                }
                catch {
                    Write-Warning "  [ERROR] Failed to remove '$($policy.DisplayName)': $_"
                }
            }
            else {
                Write-Host "  [SKIP] $($policy.DisplayName)" -ForegroundColor Yellow
            }
        }
    }
}

# ---------------------------------------------------------------------------
# Find and remove demo named locations
# ---------------------------------------------------------------------------
Write-Host "`nSearching for named locations with prefix '$PolicyPrefix'...`n" -ForegroundColor Cyan

$allLocations = Get-MgIdentityConditionalAccessNamedLocation -All -ErrorAction Stop
$demoLocations = $allLocations | Where-Object { $_.DisplayName -like "$PolicyPrefix*" }

if ($demoLocations.Count -eq 0) {
    Write-Host "No demo named locations found. Nothing to remove." -ForegroundColor Yellow
}
else {
    foreach ($loc in $demoLocations) {
        if ($Force -or $PSCmdlet.ShouldProcess($loc.DisplayName, 'Remove named location')) {
            try {
                Remove-MgIdentityConditionalAccessNamedLocation -NamedLocationId $loc.Id -ErrorAction Stop
                Write-Host "  [REMOVED] $($loc.DisplayName)" -ForegroundColor Green
            }
            catch {
                Write-Warning "  [ERROR] Failed to remove '$($loc.DisplayName)': $_"
            }
        }
    }
}

Write-Host "`nCleanup complete.`n" -ForegroundColor Cyan
