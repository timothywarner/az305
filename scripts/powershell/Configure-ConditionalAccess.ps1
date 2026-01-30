<#
.SYNOPSIS
    Create AZ-305 demo Conditional Access policies in Report-only mode.

.DESCRIPTION
    This script creates seven Conditional Access policies that cover the core
    CA concepts tested on the AZ-305 exam. Every policy is deployed in
    "reportOnly" mode so it can be demonstrated safely in a live classroom
    without affecting sign-in behavior.

    Policies created:
      1. Require MFA for All Users
      2. Block Legacy Authentication
      3. Require Compliant Device for Office 365
      4. Restrict Access by Location (with Named Location)
      5. Require App Protection Policy for Mobile
      6. Sign-in Risk Policy (Identity Protection)
      7. User Risk Policy (Identity Protection)

    The script is idempotent -- it checks for existing policies by display
    name before creating and skips any that already exist.

.PARAMETER BreakGlassUPN
    UPN of the emergency/break-glass account to exclude from policies.
    Example: "BreakGlass@contoso.onmicrosoft.com"

.PARAMETER CorporateIPRanges
    One or more IPv4 CIDR ranges that represent the corporate network.
    Used for the Named Location in the location-based policy.
    Example: @("203.0.113.0/24", "198.51.100.0/24")

.EXAMPLE
    .\Configure-ConditionalAccess.ps1 `
        -BreakGlassUPN "BreakGlass@contoso.onmicrosoft.com" `
        -CorporateIPRanges @("203.0.113.0/24")

.EXAMPLE
    # Preview what would be created without making changes
    .\Configure-ConditionalAccess.ps1 `
        -BreakGlassUPN "BreakGlass@contoso.onmicrosoft.com" `
        -CorporateIPRanges @("10.0.0.0/8") `
        -WhatIf

.NOTES
    AZ-305 EXAM OBJECTIVES:
    - Design identity, governance, and monitoring solutions (25-30%)
    - Recommend a Conditional Access architecture
    - Understand Identity Protection risk policies
    - Design for Zero Trust and least-privilege access

    PREREQUISITES:
    - Microsoft.Graph.Identity.SignIns module installed
    - Microsoft.Graph.Authentication module installed
    - Global Administrator or Conditional Access Administrator role
    - Microsoft Entra ID P2 license (for risk-based policies)

    SAFETY:
    - All policies are created in "reportOnly" state
    - No user sign-in behavior is affected
    - Use Remove-ConditionalAccess.ps1 to clean up demo policies

.LINK
    https://learn.microsoft.com/entra/identity/conditional-access/overview
    https://learn.microsoft.com/entra/identity/conditional-access/concept-conditional-access-report-only
    https://learn.microsoft.com/entra/identity/conditional-access/howto-conditional-access-policy-all-users-mfa
#>

[CmdletBinding(SupportsShouldProcess)]
param (
    [Parameter(Mandatory = $true, HelpMessage = "UPN of the break-glass account to exclude from all policies")]
    [ValidateNotNullOrEmpty()]
    [string]$BreakGlassUPN,

    [Parameter(Mandatory = $true, HelpMessage = "IPv4 CIDR ranges for the corporate named location")]
    [ValidateNotNullOrEmpty()]
    [string[]]$CorporateIPRanges
)

#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Identity.SignIns

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
$PolicyPrefix = 'AZ305-Demo:'
$NamedLocationName = "$PolicyPrefix Corporate Network"

# Well-known application IDs
# Office365 = Microsoft Office 365 portal and shared services
$Office365AppId = 'Office365'

# Required Graph API permission scopes
$RequiredScopes = @(
    'Policy.ReadWrite.ConditionalAccess'
    'Policy.Read.All'
    'Application.Read.All'
)

# ---------------------------------------------------------------------------
# Helper: Resolve break-glass user object ID from UPN
# ---------------------------------------------------------------------------
function Get-BreakGlassUserId {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$UPN
    )

    Write-Verbose "Resolving break-glass account UPN: $UPN"
    try {
        $user = Get-MgUser -Filter "userPrincipalName eq '$UPN'" -ErrorAction Stop
    }
    catch {
        throw "Failed to resolve break-glass UPN '$UPN'. Ensure the account exists and you have User.Read.All scope. Error: $_"
    }

    if (-not $user) {
        throw "Break-glass account '$UPN' not found in the directory."
    }

    return $user.Id
}

# ---------------------------------------------------------------------------
# Helper: Check whether a CA policy already exists by display name
# ---------------------------------------------------------------------------
function Test-PolicyExists {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$DisplayName
    )

    $existing = Get-MgIdentityConditionalAccessPolicy -Filter "displayName eq '$DisplayName'" -ErrorAction SilentlyContinue
    return ($null -ne $existing -and @($existing).Count -gt 0)
}

# ---------------------------------------------------------------------------
# Helper: Create a policy (with idempotency and ShouldProcess support)
# ---------------------------------------------------------------------------
function New-DemoPolicy {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [string]$DisplayName,

        [Parameter(Mandatory)]
        [hashtable]$Body,

        [Parameter(Mandatory)]
        [string]$ExamRelevance
    )

    if (Test-PolicyExists -DisplayName $DisplayName) {
        Write-Host "  [SKIP] '$DisplayName' already exists." -ForegroundColor Yellow
        return [PSCustomObject]@{
            DisplayName = $DisplayName
            Status      = 'AlreadyExists'
            Id          = 'N/A'
        }
    }

    if ($PSCmdlet.ShouldProcess($DisplayName, 'Create Conditional Access policy (reportOnly)')) {
        try {
            $policy = New-MgIdentityConditionalAccessPolicy -BodyParameter $Body -ErrorAction Stop
            Write-Host "  [CREATED] '$DisplayName' (Id: $($policy.Id))" -ForegroundColor Green
            return [PSCustomObject]@{
                DisplayName = $DisplayName
                Status      = 'Created'
                Id          = $policy.Id
            }
        }
        catch {
            Write-Warning "  [ERROR] Failed to create '$DisplayName': $_"
            return [PSCustomObject]@{
                DisplayName = $DisplayName
                Status      = "Error: $_"
                Id          = 'N/A'
            }
        }
    }
    else {
        return [PSCustomObject]@{
            DisplayName = $DisplayName
            Status      = 'WhatIf'
            Id          = 'N/A'
        }
    }
}

# ===========================================================================
# MAIN
# ===========================================================================

Write-Host "`n======================================================" -ForegroundColor Cyan
Write-Host "  AZ-305 Demo: Conditional Access Policy Deployment" -ForegroundColor Cyan
Write-Host "  All policies will be created in REPORT-ONLY mode." -ForegroundColor Cyan
Write-Host "======================================================`n" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# Step 1: Connect to Microsoft Graph with required scopes
# ---------------------------------------------------------------------------
Write-Host "[1/9] Connecting to Microsoft Graph..." -ForegroundColor Cyan

try {
    $context = Get-MgContext
    if ($null -eq $context) {
        Connect-MgGraph -Scopes $RequiredScopes -ErrorAction Stop
    }
    else {
        # Verify we have the needed scopes; reconnect if missing
        $missingScopes = $RequiredScopes | Where-Object { $_ -notin $context.Scopes }
        if ($missingScopes.Count -gt 0) {
            Write-Verbose "Missing scopes: $($missingScopes -join ', '). Reconnecting..."
            Connect-MgGraph -Scopes $RequiredScopes -ErrorAction Stop
        }
        else {
            Write-Host "  Already connected as $($context.Account)." -ForegroundColor Gray
        }
    }
}
catch {
    throw "Failed to connect to Microsoft Graph. Error: $_"
}

# ---------------------------------------------------------------------------
# Step 2: Resolve break-glass user ID
# ---------------------------------------------------------------------------
Write-Host "[2/9] Resolving break-glass account..." -ForegroundColor Cyan
$breakGlassId = Get-BreakGlassUserId -UPN $BreakGlassUPN
Write-Host "  Resolved '$BreakGlassUPN' to object ID: $breakGlassId" -ForegroundColor Gray

# ---------------------------------------------------------------------------
# Step 3: Create Named Location for corporate network
#
# AZ-305 EXAM RELEVANCE:
#   Named locations let you define trusted network boundaries. The exam tests
#   whether you can combine named locations with Conditional Access to enforce
#   location-aware policies -- for example, requiring MFA only when a user
#   signs in from outside the corporate network.
# ---------------------------------------------------------------------------
Write-Host "[3/9] Creating Named Location '$NamedLocationName'..." -ForegroundColor Cyan

$namedLocationId = $null
$existingLocation = Get-MgIdentityConditionalAccessNamedLocation -Filter "displayName eq '$NamedLocationName'" -ErrorAction SilentlyContinue

if ($null -ne $existingLocation -and @($existingLocation).Count -gt 0) {
    $namedLocationId = $existingLocation.Id
    Write-Host "  [SKIP] Named location already exists (Id: $namedLocationId)." -ForegroundColor Yellow
}
else {
    if ($PSCmdlet.ShouldProcess($NamedLocationName, 'Create Named Location')) {
        $ipRanges = $CorporateIPRanges | ForEach-Object {
            @{
                '@odata.type' = '#microsoft.graph.iPv4CidrRange'
                CidrAddress   = $_
            }
        }

        $locationParams = @{
            '@odata.type' = '#microsoft.graph.ipNamedLocation'
            DisplayName   = $NamedLocationName
            IsTrusted     = $true
            IpRanges      = @($ipRanges)
        }

        try {
            $location = New-MgIdentityConditionalAccessNamedLocation -BodyParameter $locationParams -ErrorAction Stop
            $namedLocationId = $location.Id
            Write-Host "  [CREATED] Named location (Id: $namedLocationId)." -ForegroundColor Green
        }
        catch {
            throw "Failed to create named location: $_"
        }
    }
}

# Collect results for summary table
$results = [System.Collections.Generic.List[PSCustomObject]]::new()

# ---------------------------------------------------------------------------
# Policy 1: Require MFA for All Users
#
# AZ-305 EXAM RELEVANCE:
#   This is the most fundamental Conditional Access policy and appears on
#   nearly every AZ-305 exam. Microsoft recommends requiring MFA for all
#   users as a security baseline. The break-glass exclusion demonstrates
#   the critical concept of emergency access accounts that bypass CA to
#   prevent tenant lockout.
#
# REAL-WORLD PURPOSE:
#   MFA blocks over 99.9% of account compromise attacks. Every production
#   tenant should have this as policy number one.
# ---------------------------------------------------------------------------
Write-Host "[4/9] Policy 1: Require MFA for All Users..." -ForegroundColor Cyan

$policy1Body = @{
    displayName = "$PolicyPrefix Require MFA for All Users"
    state       = 'reportOnly'
    conditions  = @{
        clientAppTypes    = @('all')
        applications      = @{
            includeApplications = @('All')
        }
        users             = @{
            includeUsers  = @('All')
            excludeUsers  = @($breakGlassId)
        }
    }
    grantControls = @{
        operator        = 'OR'
        builtInControls = @('mfa')
    }
}

$results.Add((New-DemoPolicy `
    -DisplayName "$PolicyPrefix Require MFA for All Users" `
    -Body $policy1Body `
    -ExamRelevance 'Foundational CA policy; break-glass exclusion pattern'))

# ---------------------------------------------------------------------------
# Policy 2: Block Legacy Authentication
#
# AZ-305 EXAM RELEVANCE:
#   Legacy authentication protocols (POP, IMAP, SMTP, ActiveSync with basic
#   auth) cannot perform MFA. Attackers exploit these protocols to bypass
#   MFA policies. The exam tests whether candidates know to block legacy
#   auth as a security baseline alongside the MFA policy.
#
# REAL-WORLD PURPOSE:
#   Microsoft telemetry shows legacy auth accounts for over 97% of
#   credential-stuffing attacks. Blocking legacy auth is the single
#   highest-impact security improvement after enabling MFA.
# ---------------------------------------------------------------------------
Write-Host "[5/9] Policy 2: Block Legacy Authentication..." -ForegroundColor Cyan

$policy2Body = @{
    displayName = "$PolicyPrefix Block Legacy Authentication"
    state       = 'reportOnly'
    conditions  = @{
        clientAppTypes    = @('exchangeActiveSync', 'other')
        applications      = @{
            includeApplications = @('All')
        }
        users             = @{
            includeUsers  = @('All')
            excludeUsers  = @($breakGlassId)
        }
    }
    grantControls = @{
        operator        = 'OR'
        builtInControls = @('block')
    }
}

$results.Add((New-DemoPolicy `
    -DisplayName "$PolicyPrefix Block Legacy Authentication" `
    -Body $policy2Body `
    -ExamRelevance 'Legacy auth bypasses MFA; critical security baseline'))

# ---------------------------------------------------------------------------
# Policy 3: Require Compliant Device for Office 365
#
# AZ-305 EXAM RELEVANCE:
#   Device-based Conditional Access is a major exam topic. This policy
#   demonstrates the OR operator allowing either compliant (Intune-managed)
#   OR hybrid Microsoft Entra joined devices. The exam tests when to use
#   compliant vs. hybrid join vs. both, and the relationship between
#   Intune compliance policies and CA grant controls.
#
# REAL-WORLD PURPOSE:
#   Ensures only managed, patched, encrypted devices access corporate
#   data in Office 365 -- a core Zero Trust control.
# ---------------------------------------------------------------------------
Write-Host "[6/9] Policy 3: Require Compliant Device for Office 365..." -ForegroundColor Cyan

$policy3Body = @{
    displayName = "$PolicyPrefix Require Compliant Device for O365"
    state       = 'reportOnly'
    conditions  = @{
        clientAppTypes    = @('all')
        applications      = @{
            includeApplications = @($Office365AppId)
        }
        users             = @{
            includeUsers  = @('All')
            excludeUsers  = @($breakGlassId)
        }
    }
    grantControls = @{
        operator        = 'OR'
        builtInControls = @('compliantDevice', 'domainJoinedDevice')
    }
}

$results.Add((New-DemoPolicy `
    -DisplayName "$PolicyPrefix Require Compliant Device for O365" `
    -Body $policy3Body `
    -ExamRelevance 'Device-based access; compliant vs. hybrid join'))

# ---------------------------------------------------------------------------
# Policy 4: Restrict Access by Location
#
# AZ-305 EXAM RELEVANCE:
#   Named locations and location-based policies are frequently tested.
#   The exam requires you to know how to define trusted IP ranges, how
#   to combine them with CA policies to require MFA from untrusted
#   locations, and the difference between trusted and untrusted named
#   locations. This policy demonstrates excluding trusted locations so
#   that MFA is only required from outside the corporate network.
#
# REAL-WORLD PURPOSE:
#   Reduces MFA friction for on-premises users while maintaining
#   security for remote and external access.
# ---------------------------------------------------------------------------
Write-Host "[7/9] Policy 4: Restrict Access by Location..." -ForegroundColor Cyan

if ($null -ne $namedLocationId) {
    $policy4Body = @{
        displayName = "$PolicyPrefix Require MFA Outside Corporate Network"
        state       = 'reportOnly'
        conditions  = @{
            clientAppTypes    = @('all')
            applications      = @{
                includeApplications = @('All')
            }
            users             = @{
                includeUsers  = @('All')
                excludeUsers  = @($breakGlassId)
            }
            locations         = @{
                includeLocations  = @('All')
                excludeLocations  = @($namedLocationId)
            }
        }
        grantControls = @{
            operator        = 'OR'
            builtInControls = @('mfa')
        }
    }

    $results.Add((New-DemoPolicy `
        -DisplayName "$PolicyPrefix Require MFA Outside Corporate Network" `
        -Body $policy4Body `
        -ExamRelevance 'Named locations; location-based CA'))
}
else {
    Write-Warning "  [SKIP] Cannot create location policy without named location ID (WhatIf mode?)."
    $results.Add([PSCustomObject]@{
        DisplayName = "$PolicyPrefix Require MFA Outside Corporate Network"
        Status      = 'Skipped (no named location)'
        Id          = 'N/A'
    })
}

# ---------------------------------------------------------------------------
# Policy 5: Require App Protection Policy for Mobile
#
# AZ-305 EXAM RELEVANCE:
#   Mobile Application Management (MAM) without device enrollment is a
#   key architecture pattern. The exam tests when to require approved
#   client apps vs. app protection policies. This policy targets only
#   Android and iOS platforms and uses the OR operator to accept either
#   an approved client app or an Intune app protection policy, enabling
#   BYOD scenarios where the organization protects data at the app layer.
#
# REAL-WORLD PURPOSE:
#   Protects corporate data on personal mobile devices without requiring
#   full device enrollment, balancing security with user privacy.
# ---------------------------------------------------------------------------
Write-Host "[8/9] Policy 5: Require App Protection Policy for Mobile..." -ForegroundColor Cyan

$policy5Body = @{
    displayName = "$PolicyPrefix Require App Protection for Mobile"
    state       = 'reportOnly'
    conditions  = @{
        clientAppTypes    = @('all')
        applications      = @{
            includeApplications = @($Office365AppId)
        }
        users             = @{
            includeUsers  = @('All')
            excludeUsers  = @($breakGlassId)
        }
        platforms         = @{
            includePlatforms = @('android', 'iOS')
        }
    }
    grantControls = @{
        operator        = 'OR'
        builtInControls = @('approvedApplication', 'compliantApplication')
    }
}

$results.Add((New-DemoPolicy `
    -DisplayName "$PolicyPrefix Require App Protection for Mobile" `
    -Body $policy5Body `
    -ExamRelevance 'MAM without enrollment; BYOD pattern'))

# ---------------------------------------------------------------------------
# Policy 6: Sign-in Risk Policy (Identity Protection)
#
# AZ-305 EXAM RELEVANCE:
#   Sign-in risk is evaluated by Microsoft Entra ID Protection in real
#   time. The exam tests the difference between sign-in risk (per-session)
#   and user risk (persistent). This policy requires MFA for medium and
#   high risk sign-ins and forces sign-in frequency to "every time",
#   meaning cached tokens cannot bypass the risk evaluation.
#
# REAL-WORLD PURPOSE:
#   Detects anomalous sign-in patterns (unfamiliar location, atypical
#   travel, anonymous IP, malware-linked IP) and challenges with MFA
#   before granting access.
#
# NOTE: Requires Microsoft Entra ID P2 license for risk detection.
# ---------------------------------------------------------------------------
Write-Host "[9/9] Policy 6 & 7: Identity Protection Risk Policies..." -ForegroundColor Cyan

$policy6Body = @{
    displayName = "$PolicyPrefix Sign-in Risk - Require MFA"
    state       = 'reportOnly'
    conditions  = @{
        clientAppTypes    = @('all')
        applications      = @{
            includeApplications = @('All')
        }
        users             = @{
            includeUsers  = @('All')
            excludeUsers  = @($breakGlassId)
        }
        signInRiskLevels  = @('medium', 'high')
    }
    grantControls = @{
        operator        = 'OR'
        builtInControls = @('mfa')
    }
    sessionControls = @{
        signInFrequency = @{
            value     = 1
            type      = 'hours'
            isEnabled = $true
            authenticationType = 'primaryAndSecondaryAuthentication'
            frequencyInterval  = 'everyTime'
        }
    }
}

$results.Add((New-DemoPolicy `
    -DisplayName "$PolicyPrefix Sign-in Risk - Require MFA" `
    -Body $policy6Body `
    -ExamRelevance 'Identity Protection sign-in risk; session controls'))

# ---------------------------------------------------------------------------
# Policy 7: User Risk Policy (Identity Protection)
#
# AZ-305 EXAM RELEVANCE:
#   User risk represents the probability that a user's identity has been
#   compromised (leaked credentials, impossible travel confirmed). The
#   exam distinguishes user risk from sign-in risk. This policy requires
#   both a password change AND MFA for high-risk users, which is the
#   recommended remediation strategy per Microsoft guidance.
#
# REAL-WORLD PURPOSE:
#   Automatically remediates compromised accounts by forcing a password
#   change, which resets the user risk level. Combined with MFA, this
#   ensures the legitimate user is performing the reset.
#
# NOTE: Requires Microsoft Entra ID P2 license and self-service password
#       reset (SSPR) enabled for password change to work.
# ---------------------------------------------------------------------------

$policy7Body = @{
    displayName = "$PolicyPrefix User Risk - Require Password Change"
    state       = 'reportOnly'
    conditions  = @{
        clientAppTypes    = @('all')
        applications      = @{
            includeApplications = @('All')
        }
        users             = @{
            includeUsers  = @('All')
            excludeUsers  = @($breakGlassId)
        }
        userRiskLevels    = @('high')
    }
    grantControls = @{
        operator        = 'AND'
        builtInControls = @('mfa', 'passwordChange')
    }
}

$results.Add((New-DemoPolicy `
    -DisplayName "$PolicyPrefix User Risk - Require Password Change" `
    -Body $policy7Body `
    -ExamRelevance 'Identity Protection user risk; password change remediation'))

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host "`n======================================================" -ForegroundColor Cyan
Write-Host "  Deployment Summary" -ForegroundColor Cyan
Write-Host "======================================================`n" -ForegroundColor Cyan

$results | Format-Table -AutoSize -Property DisplayName, Status, Id

Write-Host "Named Location:     $NamedLocationName" -ForegroundColor Gray
Write-Host "Break-glass Account: $BreakGlassUPN (excluded from all policies)" -ForegroundColor Gray
Write-Host "Policy State:        reportOnly (no user impact)" -ForegroundColor Green
Write-Host "`nTo clean up all demo policies, run:" -ForegroundColor Gray
Write-Host "  .\Remove-ConditionalAccess.ps1`n" -ForegroundColor White

# ---------------------------------------------------------------------------
# Prioritized Next Steps (per repo style)
# ---------------------------------------------------------------------------
# [IMMEDIATE] Review policies in Microsoft Entra admin center >
#             Protection > Conditional Access to verify report-only state.
# [SHORT-TERM] Check the Conditional Access Insights workbook in Azure
#              Monitor to see what sign-ins would be affected.
# [LONG-TERM] Gradually move policies from reportOnly to enabled after
#             validating no legitimate users are blocked.
