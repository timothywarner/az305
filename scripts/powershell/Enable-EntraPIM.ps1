<#
.SYNOPSIS
    Enable and configure Microsoft Entra Privileged Identity Management (PIM) for demo/teaching.

.DESCRIPTION
    This script configures PIM for Microsoft Entra ID roles using the Microsoft Graph PowerShell SDK.
    It demonstrates key PIM concepts critical to the AZ-305 exam and Zero Trust architecture:

    WHAT IS PIM?
    Privileged Identity Management (PIM) is an Microsoft Entra ID Governance service that enables
    you to manage, control, and monitor access to important resources. PIM provides time-based and
    approval-based role activation to mitigate the risks of excessive, unnecessary, or misused
    access permissions.

    WHY PIM MATTERS FOR ZERO TRUST:
    Zero Trust assumes breach and verifies explicitly. PIM enforces this by:
    - Eliminating standing (permanent) privileged access
    - Requiring just-in-time (JIT) activation with MFA and justification
    - Enforcing approval workflows for sensitive roles
    - Creating audit trails of all privileged access
    - Enabling access reviews to detect privilege creep

    KEY EXAM CONCEPTS - ELIGIBLE vs ACTIVE ASSIGNMENTS:
    - ELIGIBLE: User CAN activate the role when needed (just-in-time). The role is not active
      until the user explicitly requests activation. This is the preferred model.
    - ACTIVE: User HAS the role permanently. This should be minimized and reserved for
      break-glass accounts only.

    ACTIVATION REQUIREMENTS AND SECURITY IMPLICATIONS:
    - MFA: Proves identity before granting privileges (prevents credential theft escalation)
    - Justification: Creates audit trail explaining WHY access was needed
    - Ticket Info: Links activation to change management (ITSM integration)
    - Approval: Adds human gate for the most sensitive roles (separation of duties)
    - Time-limited: Automatically revokes access after duration expires (limits blast radius)

    ACCESS REVIEWS AND GOVERNANCE:
    Access reviews ensure that privileged role assignments remain appropriate over time.
    They detect privilege creep where users accumulate roles they no longer need.
    Auto-apply removes access when reviewers confirm it is no longer needed.

    AZ-305 EXAM OBJECTIVE MAPPING:
    - Domain 1: Design identity, governance, and monitoring solutions (25-30%)
      - Design a solution for managing identities
      - Design a solution for identity governance (PIM, access reviews)
      - Design authorization solutions (RBAC, PIM, Conditional Access)

    This script configures PIM policies for 5 key Entra ID roles with varying
    activation requirements to demonstrate the range of PIM controls available.

.PARAMETER AdminUPN
    User Principal Name of the administrator to configure as eligible and approver.

.PARAMETER SubscriptionId
    Optional. Azure subscription ID for configuring PIM for Azure resource roles.

.PARAMETER WhatIf
    Shows what changes would be made without applying them.

.EXAMPLE
    # Configure PIM with eligible assignments
    .\Enable-EntraPIM.ps1 -AdminUPN "admin@contoso.com"

.EXAMPLE
    # Configure PIM including Azure resource roles
    .\Enable-EntraPIM.ps1 -AdminUPN "admin@contoso.com" -SubscriptionId "00000000-0000-0000-0000-000000000000"

.EXAMPLE
    # Preview changes without applying
    .\Enable-EntraPIM.ps1 -AdminUPN "admin@contoso.com" -WhatIf

.NOTES
    AZ-305 EXAM OBJECTIVES:
    - Design identity governance solutions using PIM
    - Understand eligible vs active role assignments
    - Configure activation requirements (MFA, justification, approval)
    - Implement access reviews for privileged roles
    - Apply Zero Trust principles to identity management

    PREREQUISITES:
    - Microsoft Entra ID P2 or Microsoft Entra ID Governance license
    - Global Administrator or Privileged Role Administrator role
    - Microsoft.Graph PowerShell modules installed

.LINK
    https://learn.microsoft.com/entra/id-governance/privileged-identity-management/pim-configure
    https://learn.microsoft.com/graph/api/resources/privilegedidentitymanagementv3-overview
    https://learn.microsoft.com/graph/identity-governance-pim-rules-overview
    https://learn.microsoft.com/graph/how-to-pim-update-rules
    https://learn.microsoft.com/powershell/microsoftgraph/how-to-manage-pim-policies
#>

[CmdletBinding(SupportsShouldProcess)]
param (
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[^@]+@[^@]+\.[^@]+$')]
    [string]$AdminUPN,

    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId
)

#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Identity.SignIns, Microsoft.Graph.Identity.Governance, Microsoft.Graph.Users

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

#-------------------------------------------------------------------------------
# WELL-KNOWN ENTRA ID ROLE DEFINITION IDs
# Reference: https://learn.microsoft.com/entra/identity/role-based-access-control/permissions-reference
#-------------------------------------------------------------------------------
$RoleDefinitions = @{
    GlobalAdministrator      = "62e90394-69f5-4237-9190-012177145e10"
    UserAdministrator        = "fe930be7-5e62-47db-91af-98c3a49a38b1"
    SecurityAdministrator    = "194ae4cb-b126-40b2-bd5b-6091b380977d"
    ApplicationAdministrator = "9b895d92-2cd3-44c7-9d02-a6ac2d5ea5c3"
    BillingAdministrator     = "b0f54661-2d74-4c50-afa3-1ec803f12efe"
}

#-------------------------------------------------------------------------------
# PIM ROLE CONFIGURATION TABLE
# Each entry defines the activation requirements for one Entra ID role.
# These settings map to the PIM rules described at:
# https://learn.microsoft.com/graph/identity-governance-pim-rules-overview
#-------------------------------------------------------------------------------
$PimRoleConfigs = @(
    @{
        RoleName           = "Global Administrator"
        RoleDefinitionId   = $RoleDefinitions.GlobalAdministrator
        MaxDuration        = "PT1H"      # 1 hour - shortest duration for highest privilege
        RequireMFA         = $true
        RequireJustify     = $true
        RequireTicket      = $true
        RequireApproval    = $false       # No approval (Tim is the only GA in demo)
        NotifyOnActivation = $true
        TeachingNote       = "Most restrictive: 1h max, MFA + justification + ticket info. Global Admin is the highest privilege role and should have the tightest controls."
    },
    @{
        RoleName           = "User Administrator"
        RoleDefinitionId   = $RoleDefinitions.UserAdministrator
        MaxDuration        = "PT4H"      # 4 hours
        RequireMFA         = $true
        RequireJustify     = $true
        RequireTicket      = $false
        RequireApproval    = $true        # Requires approval - demonstrates approval workflow
        NotifyOnActivation = $false
        TeachingNote       = "Demonstrates approval workflow. Approval adds a human gate, enforcing separation of duties for user management operations."
    },
    @{
        RoleName           = "Security Administrator"
        RoleDefinitionId   = $RoleDefinitions.SecurityAdministrator
        MaxDuration        = "PT2H"      # 2 hours
        RequireMFA         = $true
        RequireJustify     = $true
        RequireTicket      = $false
        RequireApproval    = $false
        NotifyOnActivation = $false
        TeachingNote       = "Balanced security: MFA + justification without approval overhead. Suitable for security ops roles that need responsive access."
    },
    @{
        RoleName           = "Application Administrator"
        RoleDefinitionId   = $RoleDefinitions.ApplicationAdministrator
        MaxDuration        = "PT4H"      # 4 hours
        RequireMFA         = $false       # No MFA - contrast for teaching
        RequireJustify     = $true
        RequireTicket      = $false
        RequireApproval    = $false
        NotifyOnActivation = $false
        TeachingNote       = "Least restrictive: justification only, no MFA. Demonstrates that different roles can have different risk profiles. In production, MFA should be required for all privileged roles."
    },
    @{
        RoleName           = "Billing Administrator"
        RoleDefinitionId   = $RoleDefinitions.BillingAdministrator
        MaxDuration        = "PT2H"      # 2 hours
        RequireMFA         = $true
        RequireJustify     = $true
        RequireTicket      = $false
        RequireApproval    = $true        # Requires approval - financial controls
        NotifyOnActivation = $false
        TeachingNote       = "Financial role with approval gate. Demonstrates that billing access should be tightly controlled, aligning with SOX and financial compliance requirements."
    }
)

#-------------------------------------------------------------------------------
# HELPER FUNCTIONS
#-------------------------------------------------------------------------------
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "INFO"    { "White" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR"   { "Red" }
    }
    Write-Host "[$Level] $timestamp - $Message" -ForegroundColor $color
}

function Write-TeachingNote {
    param([string]$Note)
    Write-Host ""
    Write-Host "  TEACHING NOTE: " -ForegroundColor Magenta -NoNewline
    Write-Host $Note -ForegroundColor DarkGray
    Write-Host ""
}

#-------------------------------------------------------------------------------
# CONNECT TO MICROSOFT GRAPH
#-------------------------------------------------------------------------------
function Connect-ToGraph {
    Write-Log "Connecting to Microsoft Graph with required PIM scopes..."

    # WHY these scopes:
    # - RoleManagement.ReadWrite.Directory: Read/write role definitions and assignments
    # - RoleManagementPolicy.ReadWrite.Directory: Read/write PIM policy rules (activation settings)
    # - RoleAssignmentSchedule.ReadWrite.Directory: Manage active role assignment schedules
    # - RoleEligibilitySchedule.ReadWrite.Directory: Manage eligible role assignment schedules
    # - AccessReview.ReadWrite.All: Create and manage access reviews
    # - User.Read.All: Look up user objects by UPN
    $scopes = @(
        "RoleManagement.ReadWrite.Directory",
        "RoleManagementPolicy.ReadWrite.Directory",
        "RoleAssignmentSchedule.ReadWrite.Directory",
        "RoleEligibilitySchedule.ReadWrite.Directory",
        "AccessReview.ReadWrite.All",
        "User.Read.All"
    )

    try {
        $context = Get-MgContext -ErrorAction SilentlyContinue
        if ($context) {
            $missingScopes = $scopes | Where-Object { $_ -notin $context.Scopes }
            if ($missingScopes.Count -eq 0) {
                Write-Log "Already connected to Microsoft Graph with required scopes" -Level "SUCCESS"
                return
            }
            Write-Log "Reconnecting with additional scopes: $($missingScopes -join ', ')" -Level "WARNING"
        }

        Connect-MgGraph -Scopes $scopes -NoWelcome
        Write-Log "Connected to Microsoft Graph" -Level "SUCCESS"
    }
    catch {
        Write-Log "Failed to connect to Microsoft Graph: $_" -Level "ERROR"
        throw
    }
}

#-------------------------------------------------------------------------------
# VERIFY PREREQUISITES
#-------------------------------------------------------------------------------
function Test-Prerequisites {
    Write-Log "Verifying prerequisites..."

    # 1. Verify the admin user exists
    Write-Log "Looking up admin user: $AdminUPN"
    try {
        $script:AdminUser = Get-MgUser -Filter "userPrincipalName eq '$AdminUPN'" -ErrorAction Stop
        if (-not $script:AdminUser) {
            throw "User '$AdminUPN' not found in the directory."
        }
        Write-Log "Found user: $($script:AdminUser.DisplayName) ($($script:AdminUser.Id))" -Level "SUCCESS"
    }
    catch {
        Write-Log "Could not find user '$AdminUPN': $_" -Level "ERROR"
        throw
    }

    # 2. Check if current user has Global Admin or Privileged Role Admin
    Write-Log "Checking current user role assignments..."
    try {
        $context = Get-MgContext
        $currentUserId = (Get-MgUser -Filter "userPrincipalName eq '$($context.Account)'" -ErrorAction SilentlyContinue).Id

        if ($currentUserId) {
            $gaAssignment = Get-MgRoleManagementDirectoryRoleAssignmentScheduleInstance `
                -Filter "principalId eq '$currentUserId' and roleDefinitionId eq '$($RoleDefinitions.GlobalAdministrator)'" `
                -ErrorAction SilentlyContinue

            $praRoleId = "e8611ab8-c189-46e8-94e1-60213ab1f814" # Privileged Role Administrator
            $praAssignment = Get-MgRoleManagementDirectoryRoleAssignmentScheduleInstance `
                -Filter "principalId eq '$currentUserId' and roleDefinitionId eq '$praRoleId'" `
                -ErrorAction SilentlyContinue

            if ($gaAssignment -or $praAssignment) {
                $roleName = if ($gaAssignment) { "Global Administrator" } else { "Privileged Role Administrator" }
                Write-Log "Current user has $roleName role" -Level "SUCCESS"
            }
            else {
                Write-Log "Current user may not have sufficient privileges. Proceeding anyway (errors will surface if permissions are insufficient)." -Level "WARNING"
            }
        }
    }
    catch {
        Write-Log "Could not verify current user roles. Proceeding anyway." -Level "WARNING"
    }

    # 3. Check for Entra ID P2 license (required for PIM)
    # WHY: PIM requires Entra ID P2 or Entra ID Governance licensing.
    # Without P2, PIM features are not available and API calls will fail.
    Write-Log "Checking Entra ID P2 license availability..."
    try {
        $subscribedSkus = Get-MgSubscribedSku -ErrorAction SilentlyContinue
        $p2Skus = $subscribedSkus | Where-Object {
            $_.ServicePlans | Where-Object {
                $_.ServicePlanName -like "*AAD_PREMIUM_P2*" -or
                $_.ServicePlanName -like "*ENTRA_ID_GOVERNANCE*" -or
                $_.ServicePlanName -like "*IDENTITY_GOVERNANCE*"
            }
        }

        if ($p2Skus) {
            Write-Log "Entra ID P2 or Governance license detected" -Level "SUCCESS"
        }
        else {
            Write-Log "Entra ID P2 license not detected. PIM requires P2 or Entra ID Governance. Some operations may fail." -Level "WARNING"
        }
    }
    catch {
        Write-Log "Could not verify licensing. Proceeding anyway." -Level "WARNING"
    }

    # 4. Check if PIM is already configured by looking for existing policy assignments
    Write-Log "Checking existing PIM policy assignments..."
    try {
        $existingPolicies = Get-MgPolicyRoleManagementPolicyAssignment `
            -Filter "scopeId eq '/' and scopeType eq 'DirectoryRole'" `
            -ErrorAction SilentlyContinue

        if ($existingPolicies) {
            $count = ($existingPolicies | Measure-Object).Count
            Write-Log "Found $count existing PIM policy assignments. Script will update existing policies." -Level "INFO"
        }
    }
    catch {
        Write-Log "Could not check existing PIM policies." -Level "WARNING"
    }

    Write-TeachingNote "PIM requires Entra ID P2 licensing. In a real environment, verify licensing before attempting configuration. The AZ-305 exam tests your understanding of which features require P2 vs P1 vs Free tier."
}

#-------------------------------------------------------------------------------
# GET PIM POLICY ID FOR A ROLE
# Each Entra ID role has a corresponding PIM policy that contains 17 rules.
# The policy ID follows the format: Directory_{tenantId}_{roleDefinitionId}
# We look it up via the policy assignment API.
#-------------------------------------------------------------------------------
function Get-PimPolicyId {
    param(
        [string]$RoleDefinitionId,
        [string]$RoleName
    )

    try {
        $policyAssignment = Get-MgPolicyRoleManagementPolicyAssignment `
            -Filter "scopeId eq '/' and scopeType eq 'DirectoryRole' and roleDefinitionId eq '$RoleDefinitionId'" `
            -ErrorAction Stop

        if (-not $policyAssignment) {
            Write-Log "No PIM policy found for role '$RoleName'. The role may not be PIM-enabled." -Level "WARNING"
            return $null
        }

        return $policyAssignment.PolicyId
    }
    catch {
        Write-Log "Failed to get PIM policy for '$RoleName': $_" -Level "ERROR"
        return $null
    }
}

#-------------------------------------------------------------------------------
# CONFIGURE PIM ACTIVATION RULES FOR A ROLE
# PIM policies contain 17 predefined rules grouped into:
#   - Activation rules (what end users must do to activate)
#   - Assignment rules (how admins assign eligibility/active)
#   - Notification rules (who gets notified)
#
# Rule IDs used here:
#   Expiration_EndUser_Assignment   - Max activation duration
#   Enablement_EndUser_Assignment   - MFA, justification, ticket requirements
#   Approval_EndUser_Assignment     - Approval workflow settings
#   Notification_Admin_EndUser_Assignment - Admin notification on activation
#
# Reference: https://learn.microsoft.com/graph/identity-governance-pim-rules-overview
#-------------------------------------------------------------------------------
function Set-PimRolePolicy {
    param(
        [hashtable]$Config
    )

    $roleName = $Config.RoleName
    $roleDefId = $Config.RoleDefinitionId

    Write-Log "Configuring PIM policy for: $roleName"
    Write-TeachingNote $Config.TeachingNote

    $policyId = Get-PimPolicyId -RoleDefinitionId $roleDefId -RoleName $roleName
    if (-not $policyId) {
        Write-Log "Skipping '$roleName' - no PIM policy found" -Level "WARNING"
        return $null
    }

    $results = @{
        RoleName = $roleName
        PolicyId = $policyId
        Changes  = @()
    }

    # --- Rule 1: Activation maximum duration ---
    # Controls how long an activated role remains active before auto-expiring.
    # Shorter durations reduce the window of exposure if credentials are compromised.
    try {
        $expirationRule = @{
            "@odata.type"        = "#microsoft.graph.unifiedRoleManagementPolicyExpirationRule"
            id                   = "Expiration_EndUser_Assignment"
            isExpirationRequired = $true
            maximumDuration      = $Config.MaxDuration
            target               = @{
                "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
                caller              = "EndUser"
                operations          = @("All")
                level               = "Assignment"
                inheritableSettings = @()
                enforcedSettings    = @()
            }
        }

        if ($PSCmdlet.ShouldProcess("$roleName - Activation duration: $($Config.MaxDuration)", "Update PIM expiration rule")) {
            Update-MgPolicyRoleManagementPolicyRule `
                -UnifiedRoleManagementPolicyId $policyId `
                -UnifiedRoleManagementPolicyRuleId "Expiration_EndUser_Assignment" `
                -BodyParameter $expirationRule

            Write-Log "  Set max activation duration: $($Config.MaxDuration)" -Level "SUCCESS"
            $results.Changes += "Max duration: $($Config.MaxDuration)"
        }
    }
    catch {
        Write-Log "  Failed to set activation duration for '$roleName': $_" -Level "ERROR"
    }

    # --- Rule 2: Enablement requirements (MFA, justification, ticketing) ---
    # These are the activation controls that end users must satisfy.
    # Each adds a layer of verification aligned with Zero Trust principles.
    try {
        $enabledRules = @()
        if ($Config.RequireMFA)     { $enabledRules += "MultiFactorAuthentication" }
        if ($Config.RequireJustify) { $enabledRules += "Justification" }
        if ($Config.RequireTicket)  { $enabledRules += "Ticketing" }

        $enablementRule = @{
            "@odata.type" = "#microsoft.graph.unifiedRoleManagementPolicyEnablementRule"
            id            = "Enablement_EndUser_Assignment"
            enabledRules  = $enabledRules
            target        = @{
                "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
                caller              = "EndUser"
                operations          = @("All")
                level               = "Assignment"
                inheritableSettings = @()
                enforcedSettings    = @()
            }
        }

        $requirementsList = ($enabledRules | ForEach-Object {
            switch ($_) {
                "MultiFactorAuthentication" { "MFA" }
                "Justification"             { "Justification" }
                "Ticketing"                 { "Ticket Info" }
            }
        }) -join ", "

        if (-not $requirementsList) { $requirementsList = "None" }

        if ($PSCmdlet.ShouldProcess("$roleName - Requirements: $requirementsList", "Update PIM enablement rule")) {
            Update-MgPolicyRoleManagementPolicyRule `
                -UnifiedRoleManagementPolicyId $policyId `
                -UnifiedRoleManagementPolicyRuleId "Enablement_EndUser_Assignment" `
                -BodyParameter $enablementRule

            Write-Log "  Set activation requirements: $requirementsList" -Level "SUCCESS"
            $results.Changes += "Requirements: $requirementsList"
        }
    }
    catch {
        Write-Log "  Failed to set enablement rules for '$roleName': $_" -Level "ERROR"
    }

    # --- Rule 3: Approval requirement ---
    # When enabled, activation requests go to designated approvers before the role becomes active.
    # This enforces separation of duties - the person requesting access is not the one granting it.
    try {
        $approvalRule = @{
            "@odata.type" = "#microsoft.graph.unifiedRoleManagementPolicyApprovalRule"
            id            = "Approval_EndUser_Assignment"
            target        = @{
                "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
                caller              = "EndUser"
                operations          = @("All")
                level               = "Assignment"
                inheritableSettings = @()
                enforcedSettings    = @()
            }
            setting       = @{
                "@odata.type"                      = "microsoft.graph.approvalSettings"
                isApprovalRequired                 = $Config.RequireApproval
                isApprovalRequiredForExtension      = $false
                isRequestorJustificationRequired    = $true
                approvalMode                        = "SingleStage"
                approvalStages                      = @()
            }
        }

        # If approval is required, set the admin user as the approver
        if ($Config.RequireApproval) {
            $approvalRule.setting.approvalStages = @(
                @{
                    approvalStageTimeOutInDays       = 1
                    isApproverJustificationRequired  = $true
                    escalationTimeInMinutes           = 0
                    isEscalationEnabled               = $false
                    primaryApprovers                  = @(
                        @{
                            "@odata.type" = "#microsoft.graph.singleUser"
                            userId        = $script:AdminUser.Id
                        }
                    )
                    escalationApprovers               = @()
                }
            )
        }

        $approvalStatus = if ($Config.RequireApproval) { "Required (approver: $AdminUPN)" } else { "Not required" }

        if ($PSCmdlet.ShouldProcess("$roleName - Approval: $approvalStatus", "Update PIM approval rule")) {
            Update-MgPolicyRoleManagementPolicyRule `
                -UnifiedRoleManagementPolicyId $policyId `
                -UnifiedRoleManagementPolicyRuleId "Approval_EndUser_Assignment" `
                -BodyParameter $approvalRule

            Write-Log "  Set approval: $approvalStatus" -Level "SUCCESS"
            $results.Changes += "Approval: $approvalStatus"
        }
    }
    catch {
        Write-Log "  Failed to set approval rule for '$roleName': $_" -Level "ERROR"
    }

    # --- Rule 4: Admin notification on activation ---
    # When enabled, admins receive email when someone activates this role.
    # Critical for the Global Administrator role to detect unauthorized activation.
    if ($Config.NotifyOnActivation) {
        try {
            $notificationRule = @{
                "@odata.type"       = "#microsoft.graph.unifiedRoleManagementPolicyNotificationRule"
                id                  = "Notification_Admin_EndUser_Assignment"
                notificationType    = "Email"
                recipientType       = "Admin"
                isDefaultRecipientsEnabled = $true
                notificationLevel   = "All"
                notificationRecipients = @($AdminUPN)
                target              = @{
                    "@odata.type"       = "microsoft.graph.unifiedRoleManagementPolicyRuleTarget"
                    caller              = "EndUser"
                    operations          = @("All")
                    level               = "Assignment"
                    inheritableSettings = @()
                    enforcedSettings    = @()
                }
            }

            if ($PSCmdlet.ShouldProcess("$roleName - Notify admin on activation", "Update PIM notification rule")) {
                Update-MgPolicyRoleManagementPolicyRule `
                    -UnifiedRoleManagementPolicyId $policyId `
                    -UnifiedRoleManagementPolicyRuleId "Notification_Admin_EndUser_Assignment" `
                    -BodyParameter $notificationRule

                Write-Log "  Set admin notification on activation: enabled" -Level "SUCCESS"
                $results.Changes += "Admin notification: enabled"
            }
        }
        catch {
            Write-Log "  Failed to set notification rule for '$roleName': $_" -Level "ERROR"
        }
    }

    return $results
}

#-------------------------------------------------------------------------------
# CREATE ELIGIBLE ASSIGNMENT FOR THE ADMIN USER
# Makes the admin user ELIGIBLE (not active) for each configured role.
# The user must then activate the role through PIM when needed.
#-------------------------------------------------------------------------------
function New-EligibleAssignment {
    param(
        [string]$RoleDefinitionId,
        [string]$RoleName
    )

    Write-Log "Creating eligible assignment for '$RoleName'..."

    # Check if an eligible assignment already exists
    try {
        $existingEligibility = Get-MgRoleManagementDirectoryRoleEligibilityScheduleInstance `
            -Filter "principalId eq '$($script:AdminUser.Id)' and roleDefinitionId eq '$RoleDefinitionId'" `
            -ErrorAction SilentlyContinue

        if ($existingEligibility) {
            Write-Log "  Eligible assignment already exists for '$RoleName'" -Level "INFO"
            return
        }
    }
    catch {
        # If the check fails, proceed with creating the assignment
    }

    try {
        $params = @{
            action           = "AdminAssign"
            justification    = "PIM demo setup - making admin eligible for $RoleName"
            roleDefinitionId = $RoleDefinitionId
            directoryScopeId = "/"
            principalId      = $script:AdminUser.Id
            scheduleInfo     = @{
                startDateTime = Get-Date -Format "o"
                expiration    = @{
                    type     = "AfterDuration"
                    duration = "P365D"   # Eligible for 1 year
                }
            }
        }

        if ($PSCmdlet.ShouldProcess("$AdminUPN eligible for $RoleName (365 days)", "Create PIM eligible assignment")) {
            New-MgRoleManagementDirectoryRoleEligibilityScheduleRequest -BodyParameter $params | Out-Null
            Write-Log "  Created eligible assignment: $AdminUPN -> $RoleName (365 days)" -Level "SUCCESS"
        }
    }
    catch {
        if ($_.Exception.Message -like "*RoleAssignmentExists*" -or $_.Exception.Message -like "*already exists*") {
            Write-Log "  Eligible assignment already exists for '$RoleName'" -Level "INFO"
        }
        else {
            Write-Log "  Failed to create eligible assignment for '$RoleName': $_" -Level "WARNING"
        }
    }
}

#-------------------------------------------------------------------------------
# CONFIGURE PIM FOR AZURE RESOURCE ROLES
# PIM can also manage Azure RBAC roles (Contributor, Owner, Reader, etc.)
# This uses a different API surface than Entra ID roles.
# NOTE: Azure resource PIM uses the Azure REST API, not the Graph API directly.
# The Graph PowerShell SDK supports Entra ID roles; for Azure resources,
# we use the Az module or direct REST calls.
#-------------------------------------------------------------------------------
function Set-AzureResourcePim {
    if (-not $SubscriptionId) {
        Write-Log "No SubscriptionId provided. Skipping Azure resource PIM configuration." -Level "INFO"
        Write-TeachingNote "PIM for Azure resources manages RBAC roles (Owner, Contributor, Reader) at subscription, resource group, or resource scope. It uses the same just-in-time activation model as Entra ID roles but applies to Azure resource access."
        return
    }

    Write-Log "Configuring PIM for Azure resource roles on subscription: $SubscriptionId"
    Write-TeachingNote "Azure resource PIM uses the Azure Resource Manager (ARM) API, not Microsoft Graph. The Microsoft.Graph SDK handles Entra ID roles; for Azure RBAC roles, use the Az.Resources module or REST API. The AZ-305 exam covers both PIM for Entra ID roles and PIM for Azure resources."

    # WHY: Azure resource PIM eligible assignments are created via ARM REST API
    # The Az PowerShell module does not have native PIM cmdlets for Azure resources.
    # We demonstrate the concept but note the API difference.

    try {
        # Verify Az module connectivity
        $azContext = Get-AzContext -ErrorAction SilentlyContinue
        if (-not $azContext -or $azContext.Subscription.Id -ne $SubscriptionId) {
            Write-Log "Az module not connected to subscription $SubscriptionId. Attempting connection..." -Level "WARNING"
            try {
                Set-AzContext -SubscriptionId $SubscriptionId -ErrorAction Stop | Out-Null
            }
            catch {
                Write-Log "Could not set Az context. Install Az.Accounts and connect with Connect-AzAccount. Skipping Azure resource PIM." -Level "WARNING"
                return
            }
        }

        $scope = "/subscriptions/$SubscriptionId"

        # Contributor role - eligible assignment
        $contributorRoleId = "b24988ac-6180-42a0-ab88-20f7382dd24c"
        Write-Log "  Creating eligible assignment for Contributor role..."

        $contributorParams = @{
            Properties = @{
                PrincipalId      = $script:AdminUser.Id
                RoleDefinitionId = "$scope/providers/Microsoft.Authorization/roleDefinitions/$contributorRoleId"
                RequestType      = "AdminAssign"
                Justification    = "PIM demo - eligible Contributor on subscription"
                ScheduleInfo     = @{
                    StartDateTime = (Get-Date).ToUniversalTime().ToString("o")
                    Expiration    = @{
                        Type     = "AfterDuration"
                        Duration = "P180D"
                    }
                }
            }
        }

        $requestName = [guid]::NewGuid().ToString()
        $uri = "$scope/providers/Microsoft.Authorization/roleEligibilityScheduleRequests/${requestName}?api-version=2020-10-01"

        if ($PSCmdlet.ShouldProcess("$AdminUPN eligible for Contributor on subscription", "Create Azure resource PIM assignment")) {
            try {
                $token = (Get-AzAccessToken -ResourceUrl "https://management.azure.com").Token
                $headers = @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" }
                $body = $contributorParams | ConvertTo-Json -Depth 10

                Invoke-RestMethod -Uri "https://management.azure.com$uri" -Method Put -Headers $headers -Body $body | Out-Null
                Write-Log "  Created eligible Contributor assignment on subscription" -Level "SUCCESS"
            }
            catch {
                Write-Log "  Could not create Contributor eligible assignment: $_" -Level "WARNING"
            }
        }

        # Owner role - eligible assignment (stricter)
        $ownerRoleId = "8e3af657-a8ff-443c-a75c-2fe8c4bcb635"
        Write-Log "  Creating eligible assignment for Owner role..."

        $ownerParams = @{
            Properties = @{
                PrincipalId      = $script:AdminUser.Id
                RoleDefinitionId = "$scope/providers/Microsoft.Authorization/roleDefinitions/$ownerRoleId"
                RequestType      = "AdminAssign"
                Justification    = "PIM demo - eligible Owner on subscription (strict activation)"
                ScheduleInfo     = @{
                    StartDateTime = (Get-Date).ToUniversalTime().ToString("o")
                    Expiration    = @{
                        Type     = "AfterDuration"
                        Duration = "P90D"
                    }
                }
            }
        }

        $requestName = [guid]::NewGuid().ToString()
        $uri = "$scope/providers/Microsoft.Authorization/roleEligibilityScheduleRequests/${requestName}?api-version=2020-10-01"

        if ($PSCmdlet.ShouldProcess("$AdminUPN eligible for Owner on subscription", "Create Azure resource PIM assignment")) {
            try {
                $token = (Get-AzAccessToken -ResourceUrl "https://management.azure.com").Token
                $headers = @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" }
                $body = $ownerParams | ConvertTo-Json -Depth 10

                Invoke-RestMethod -Uri "https://management.azure.com$uri" -Method Put -Headers $headers -Body $body | Out-Null
                Write-Log "  Created eligible Owner assignment on subscription (90 days)" -Level "SUCCESS"
            }
            catch {
                Write-Log "  Could not create Owner eligible assignment: $_" -Level "WARNING"
            }
        }
    }
    catch {
        Write-Log "Azure resource PIM configuration failed: $_" -Level "WARNING"
    }
}

#-------------------------------------------------------------------------------
# CREATE ACCESS REVIEW FOR GLOBAL ADMIN ROLE
# Access reviews ensure that privileged assignments remain appropriate.
# This creates a monthly review of all active Global Administrator assignments.
#
# Reference: https://learn.microsoft.com/graph/tutorial-accessreviews-roleassignments
#-------------------------------------------------------------------------------
function New-GlobalAdminAccessReview {
    Write-Log "Creating access review for Global Administrator role..."
    Write-TeachingNote "Access reviews are a governance control that periodically validates whether users still need their privileged access. The AZ-305 exam tests when to use access reviews vs PIM vs Conditional Access. Access reviews address the 'privilege creep' problem where users accumulate unnecessary access over time."

    try {
        # Check for existing access review
        $existingReviews = Get-MgIdentityGovernanceAccessReviewDefinition `
            -Filter "displayName eq 'Monthly Global Admin Review'" `
            -ErrorAction SilentlyContinue

        if ($existingReviews) {
            Write-Log "  Access review 'Monthly Global Admin Review' already exists. Skipping creation." -Level "INFO"
            return
        }

        $reviewParams = @{
            displayName        = "Monthly Global Admin Review"
            descriptionForAdmins = "Monthly review of Global Administrator role assignments to ensure only authorized users retain this highest-privilege role."
            descriptionForReviewers = "Review whether each user still requires Global Administrator access. Remove access that is no longer needed."
            scope              = @{
                "@odata.type"   = "#microsoft.graph.principalResourceMembershipsScope"
                principalScopes = @(
                    @{
                        "@odata.type" = "#microsoft.graph.accessReviewQueryScope"
                        query         = "/users"
                        queryType     = "MicrosoftGraph"
                    }
                )
                resourceScopes  = @(
                    @{
                        "@odata.type" = "#microsoft.graph.accessReviewQueryScope"
                        query         = "/roleManagement/directory/roleDefinitions/$($RoleDefinitions.GlobalAdministrator)"
                        queryType     = "MicrosoftGraph"
                    }
                )
            }
            reviewers          = @(
                @{
                    query     = "/users/$($script:AdminUser.Id)"
                    queryType = "MicrosoftGraph"
                }
            )
            fallbackReviewers  = @(
                @{
                    query     = "/users/$($script:AdminUser.Id)"
                    queryType = "MicrosoftGraph"
                }
            )
            settings           = @{
                mailNotificationsEnabled         = $true
                reminderNotificationsEnabled      = $true
                justificationRequiredOnApproval    = $true
                defaultDecisionEnabled            = $true
                defaultDecision                   = "Deny"
                instanceDurationInDays            = 14
                autoApplyDecisionsEnabled         = $true
                recommendationsEnabled            = $true
                recurrence                        = @{
                    pattern = @{
                        type       = "absoluteMonthly"
                        interval   = 1
                        dayOfMonth = 1
                    }
                    range   = @{
                        type      = "noEnd"
                        startDate = (Get-Date).ToString("yyyy-MM-dd")
                    }
                }
            }
        }

        if ($PSCmdlet.ShouldProcess("Monthly Global Admin Review (auto-apply, monthly recurrence)", "Create access review")) {
            $review = New-MgIdentityGovernanceAccessReviewDefinition -BodyParameter $reviewParams
            Write-Log "  Created access review: $($review.DisplayName) (ID: $($review.Id))" -Level "SUCCESS"
            Write-Log "  Schedule: Monthly on the 1st, 14-day review window, auto-apply decisions" -Level "INFO"
        }
    }
    catch {
        Write-Log "  Failed to create access review: $_" -Level "WARNING"
        Write-Log "  Access reviews require Entra ID P2 licensing." -Level "INFO"
    }
}

#-------------------------------------------------------------------------------
# DISPLAY CONFIGURATION SUMMARY
#-------------------------------------------------------------------------------
function Show-Summary {
    param(
        [array]$ConfigResults
    )

    Write-Host ""
    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host "           MICROSOFT ENTRA PIM CONFIGURATION SUMMARY" -ForegroundColor Cyan
    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Admin User: $AdminUPN ($($script:AdminUser.DisplayName))" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "CONFIGURED ROLE POLICIES:" -ForegroundColor Yellow
    Write-Host "-------------------------------------------------------------------------------"

    foreach ($result in $ConfigResults) {
        if ($null -eq $result) { continue }
        Write-Host ""
        Write-Host "  $($result.RoleName)" -ForegroundColor Green
        foreach ($change in $result.Changes) {
            Write-Host "    - $change"
        }
    }

    Write-Host ""
    Write-Host "-------------------------------------------------------------------------------"
    Write-Host ""
    Write-Host "ELIGIBLE ASSIGNMENTS CREATED:" -ForegroundColor Yellow
    Write-Host "  $AdminUPN is now ELIGIBLE for all 5 roles above." -ForegroundColor White
    Write-Host "  The user must ACTIVATE each role through PIM before using it." -ForegroundColor White
    Write-Host ""

    if ($SubscriptionId) {
        Write-Host "AZURE RESOURCE PIM:" -ForegroundColor Yellow
        Write-Host "  Contributor: Eligible (180 days) on subscription $SubscriptionId" -ForegroundColor White
        Write-Host "  Owner:       Eligible (90 days)  on subscription $SubscriptionId" -ForegroundColor White
        Write-Host ""
    }

    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host "                     AZ-305 EXAM CONTEXT" -ForegroundColor Cyan
    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "PIM DECISION FRAMEWORK (When to use what):" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Eligible + MFA + Justification:" -ForegroundColor White
    Write-Host "    Standard for all privileged roles. Balances security with usability."
    Write-Host ""
    Write-Host "  Eligible + MFA + Justification + Approval:" -ForegroundColor White
    Write-Host "    High-risk roles (Global Admin, Owner). Adds human gate but slows access."
    Write-Host ""
    Write-Host "  Eligible + MFA + Justification + Ticket:" -ForegroundColor White
    Write-Host "    ITSM-integrated environments. Links access to change management."
    Write-Host ""
    Write-Host "  Active (permanent):" -ForegroundColor White
    Write-Host "    Break-glass accounts ONLY. Maximum 2 accounts, monitored continuously."
    Write-Host ""
    Write-Host "ACTIVATION DURATION GUIDANCE:" -ForegroundColor Yellow
    Write-Host "  1 hour  - Highest privilege roles (Global Admin)"
    Write-Host "  2 hours - Security-sensitive roles (Security Admin, Billing)"
    Write-Host "  4 hours - Operational roles (User Admin, App Admin)"
    Write-Host "  8 hours - Max recommended for any role"
    Write-Host ""
    Write-Host "WELL-ARCHITECTED FRAMEWORK ALIGNMENT:" -ForegroundColor Yellow
    Write-Host "  Security:    PIM enforces least-privilege and just-in-time access"
    Write-Host "  Reliability: Break-glass accounts ensure emergency access"
    Write-Host "  OpEx:        Access reviews automate governance compliance"
    Write-Host "  Cost:        Entra ID P2 licensing required (~USD 9/user/month)"
    Write-Host ""
    Write-Host "===============================================================================" -ForegroundColor Cyan
}

#-------------------------------------------------------------------------------
# MAIN
#-------------------------------------------------------------------------------
function Main {
    Write-Log "Starting Microsoft Entra PIM configuration..."
    Write-Host ""
    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host "  Microsoft Entra Privileged Identity Management (PIM) Demo Setup" -ForegroundColor Cyan
    Write-Host "  AZ-305: Design Identity, Governance, and Monitoring Solutions" -ForegroundColor Cyan
    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host ""

    try {
        # Step 1: Connect to Microsoft Graph
        Connect-ToGraph

        # Step 2: Verify prerequisites
        Test-Prerequisites

        # Step 3: Configure PIM policies for each role
        Write-Host ""
        Write-Host "-------------------------------------------------------------------------------" -ForegroundColor Cyan
        Write-Host "  CONFIGURING PIM ACTIVATION POLICIES" -ForegroundColor Cyan
        Write-Host "-------------------------------------------------------------------------------" -ForegroundColor Cyan
        Write-Host ""

        $configResults = @()
        foreach ($roleConfig in $PimRoleConfigs) {
            $result = Set-PimRolePolicy -Config $roleConfig
            $configResults += $result
        }

        # Step 4: Create eligible assignments
        Write-Host ""
        Write-Host "-------------------------------------------------------------------------------" -ForegroundColor Cyan
        Write-Host "  CREATING ELIGIBLE ROLE ASSIGNMENTS" -ForegroundColor Cyan
        Write-Host "-------------------------------------------------------------------------------" -ForegroundColor Cyan
        Write-Host ""

        foreach ($roleConfig in $PimRoleConfigs) {
            New-EligibleAssignment `
                -RoleDefinitionId $roleConfig.RoleDefinitionId `
                -RoleName $roleConfig.RoleName
        }

        # Step 5: Configure PIM for Azure resource roles
        Write-Host ""
        Write-Host "-------------------------------------------------------------------------------" -ForegroundColor Cyan
        Write-Host "  CONFIGURING PIM FOR AZURE RESOURCES" -ForegroundColor Cyan
        Write-Host "-------------------------------------------------------------------------------" -ForegroundColor Cyan
        Write-Host ""

        Set-AzureResourcePim

        # Step 6: Create access review
        Write-Host ""
        Write-Host "-------------------------------------------------------------------------------" -ForegroundColor Cyan
        Write-Host "  CREATING ACCESS REVIEW" -ForegroundColor Cyan
        Write-Host "-------------------------------------------------------------------------------" -ForegroundColor Cyan
        Write-Host ""

        New-GlobalAdminAccessReview

        # Step 7: Display summary
        Show-Summary -ConfigResults $configResults

        Write-Log "PIM configuration completed successfully!" -Level "SUCCESS"
    }
    catch {
        Write-Log "PIM configuration failed: $_" -Level "ERROR"
        throw
    }
}

# Execute main function
Main

#-------------------------------------------------------------------------------
# LIVE DEMO COMMANDS (Uncomment and run individually during live teaching)
#
# These commands demonstrate PIM operations that AZ-305 candidates should
# understand. Use them during live demos to show the end-user experience.
#-------------------------------------------------------------------------------

<#
# ==============================================================================
# DEMO 1: Activate a PIM role via PowerShell
# ==============================================================================
# This simulates what an end user does when they need temporary privileged access.
# In the portal, this is the "Activate" button in PIM > My Roles.

# First, get the current user's principal ID
$currentUser = Get-MgUser -Filter "userPrincipalName eq 'admin@contoso.com'"

# Activate the Security Administrator role for 2 hours
$activationParams = @{
    action           = "SelfActivate"
    principalId      = $currentUser.Id
    roleDefinitionId = "194ae4cb-b126-40b2-bd5b-6091b380977d"  # Security Administrator
    directoryScopeId = "/"
    justification    = "Investigating security alert INC-2026-0130"
    scheduleInfo     = @{
        startDateTime = (Get-Date).ToUniversalTime().ToString("o")
        expiration    = @{
            type     = "AfterDuration"
            duration = "PT2H"  # 2 hours
        }
    }
    ticketInfo       = @{
        ticketNumber = "INC-2026-0130"
        ticketSystem = "ServiceNow"
    }
}

New-MgRoleManagementDirectoryRoleAssignmentScheduleRequest -BodyParameter $activationParams |
    Format-List Id, Status, Action, Justification, CreatedDateTime

# ==============================================================================
# DEMO 2: List current eligible assignments for a user
# ==============================================================================
# Shows all roles the user CAN activate (but are not currently active).

Get-MgRoleManagementDirectoryRoleEligibilityScheduleInstance `
    -Filter "principalId eq '$($currentUser.Id)'" |
    Select-Object RoleDefinitionId, StartDateTime, EndDateTime |
    Format-Table

# To get role names, join with role definitions:
$eligibleRoles = Get-MgRoleManagementDirectoryRoleEligibilityScheduleInstance `
    -Filter "principalId eq '$($currentUser.Id)'"

foreach ($role in $eligibleRoles) {
    $roleDef = Get-MgRoleManagementDirectoryRoleDefinition -UnifiedRoleDefinitionId $role.RoleDefinitionId
    [PSCustomObject]@{
        RoleName  = $roleDef.DisplayName
        StartDate = $role.StartDateTime
        EndDate   = $role.EndDateTime
    }
} | Format-Table -AutoSize

# ==============================================================================
# DEMO 3: List currently ACTIVE (activated) assignments
# ==============================================================================
# Shows roles that are currently activated and in use.

Get-MgRoleManagementDirectoryRoleAssignmentScheduleInstance `
    -Filter "principalId eq '$($currentUser.Id)'" |
    ForEach-Object {
        $roleDef = Get-MgRoleManagementDirectoryRoleDefinition -UnifiedRoleDefinitionId $_.RoleDefinitionId
        [PSCustomObject]@{
            RoleName      = $roleDef.DisplayName
            AssignmentType = $_.AssignmentType   # Assigned vs Activated
            StartDateTime  = $_.StartDateTime
            EndDateTime    = $_.EndDateTime
        }
    } | Format-Table -AutoSize

# ==============================================================================
# DEMO 4: Check PIM activation history / audit logs
# ==============================================================================
# Shows recent PIM operations for audit and compliance.

# Get recent role assignment requests (activations, assignments, removals)
Get-MgRoleManagementDirectoryRoleAssignmentScheduleRequest `
    -Filter "createdDateTime ge $((Get-Date).AddDays(-30).ToString('yyyy-MM-ddTHH:mm:ssZ'))" `
    -OrderBy "createdDateTime desc" `
    -Top 20 |
    Select-Object Action, Status, Justification, CreatedDateTime, PrincipalId |
    Format-Table -AutoSize

# ==============================================================================
# DEMO 5: View PIM policy settings for a specific role
# ==============================================================================
# Shows the current activation requirements configured for a role.

$globalAdminRoleId = "62e90394-69f5-4237-9190-012177145e10"

# Get the policy assignment for Global Administrator
$policyAssignment = Get-MgPolicyRoleManagementPolicyAssignment `
    -Filter "scopeId eq '/' and scopeType eq 'DirectoryRole' and roleDefinitionId eq '$globalAdminRoleId'"

# Get all rules for this policy
$rules = Get-MgPolicyRoleManagementPolicyRule -UnifiedRoleManagementPolicyId $policyAssignment.PolicyId

# Display the activation rules
$rules | Where-Object { $_.Id -like "*EndUser*" } | Format-List Id, AdditionalProperties

# ==============================================================================
# DEMO 6: Deactivate a PIM role early
# ==============================================================================
# Demonstrates responsible behavior - deactivating a role before the timer expires.

$deactivateParams = @{
    action           = "SelfDeactivate"
    principalId      = $currentUser.Id
    roleDefinitionId = "194ae4cb-b126-40b2-bd5b-6091b380977d"  # Security Administrator
    directoryScopeId = "/"
}

New-MgRoleManagementDirectoryRoleAssignmentScheduleRequest -BodyParameter $deactivateParams |
    Format-List Id, Status, Action

# ==============================================================================
# DEMO 7: List access reviews and their status
# ==============================================================================

Get-MgIdentityGovernanceAccessReviewDefinition |
    Select-Object DisplayName, Status, CreatedDateTime |
    Format-Table -AutoSize

# Get instances (individual review cycles) for a specific review
$reviewId = (Get-MgIdentityGovernanceAccessReviewDefinition -Filter "displayName eq 'Monthly Global Admin Review'").Id
if ($reviewId) {
    Get-MgIdentityGovernanceAccessReviewDefinitionInstance `
        -AccessReviewScheduleDefinitionId $reviewId |
        Select-Object Status, StartDateTime, EndDateTime |
        Format-Table -AutoSize
}
#>
