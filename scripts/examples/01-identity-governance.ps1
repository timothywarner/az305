#requires -Modules Az.Accounts, Az.Resources, Az.ManagedServiceIdentity

<#
.TITLE
    AZ-305 Domain 1: Identity, Governance & Monitoring - Identity and Governance
.DOMAIN
    Domain 1 - Design Identity, Governance, and Monitoring Solutions (25-30%)
.DESCRIPTION
    Teaching examples covering Microsoft Entra ID Conditional Access, RBAC custom roles,
    Privileged Identity Management (PIM), management groups, Azure Policy initiatives,
    and resource tagging strategies. These are code-review examples for classroom use.
.AUTHOR
    Tim Warner
.DATE
    January 2026
.NOTES
    These scripts are for AZ-305 exam preparation and classroom demonstration.
    They illustrate correct syntax and architectural decision-making -- they are
    NOT intended to be run as-is against a live subscription.
#>

# ============================================================================
# SECTION 1: Microsoft Entra ID Conditional Access Policy
# ============================================================================

# EXAM TIP: Conditional Access is the ZERO TRUST policy engine for Microsoft Entra ID.
# The exam tests your ability to choose the RIGHT conditions and controls.
# Key concept: Conditional Access = Assignments (WHO + WHAT + WHERE) + Controls (BLOCK/GRANT/SESSION).

# WHEN TO USE: Conditional Access over simple MFA per-user settings when you need
# granular, context-aware policies. Per-user MFA is legacy -- always recommend
# Conditional Access in AZ-305 scenarios.

# Connect with sufficient privileges (requires Conditional Access Administrator or higher)
Connect-AzAccount

# Install the Microsoft Graph module for Entra ID operations
# Install-Module Microsoft.Graph.Identity.SignIns -Scope CurrentUser

Import-Module Microsoft.Graph.Identity.SignIns

Connect-MgGraph -Scopes "Policy.ReadWrite.ConditionalAccess", "Application.Read.All"

# Define a Conditional Access policy requiring MFA for Azure Management access
# This protects the Azure portal, CLI, and PowerShell from compromised accounts
$policyParams = @{
    DisplayName = "CA001-Require-MFA-AzureManagement"
    State       = "enabledForReportingButNotEnforced"  # Always start in report-only mode!
    Conditions  = @{
        # WHO: All users except emergency access (break-glass) accounts
        Users = @{
            IncludeUsers  = @("All")
            ExcludeGroups = @("BreakGlassAccounts-GroupId")  # NEVER lock out break-glass accounts
        }
        # WHAT: Target Azure Management endpoints (portal, CLI, PowerShell, REST API)
        Applications = @{
            IncludeApplications = @("797f4846-ba00-4fd7-ba43-dac1f8f63013")  # Azure Management app ID
        }
        # WHERE: Any location (no location exclusion for this critical policy)
        Locations = @{
            IncludeLocations = @("All")
        }
    }
    # CONTROLS: Require MFA grant control
    GrantControls = @{
        Operator        = "OR"
        BuiltInControls = @("mfa")
    }
}

New-MgIdentityConditionalAccessPolicy @policyParams

# EXAM TIP: Named Locations let you trust corporate IP ranges.
# Exam scenarios often ask you to REDUCE MFA prompts for trusted locations
# while ENFORCING them for untrusted networks.
$namedLocationParams = @{
    DisplayName = "Corporate-Office-IPs"
    IsTrusted   = $true
    IpRanges    = @(
        @{ CidrAddress = "203.0.113.0/24" }
        @{ CidrAddress = "198.51.100.0/24" }
    )
}

# ============================================================================
# SECTION 2: RBAC Custom Role Definition and Assignment
# ============================================================================

# EXAM TIP: The exam expects you to know WHEN to create custom roles vs. using
# built-in roles. Custom roles are appropriate when built-in roles are either
# too broad (security risk) or too narrow (operational friction).
# Key principle: LEAST PRIVILEGE -- grant only the permissions needed.

# WHEN TO USE: Custom RBAC roles when no built-in role matches the requirement.
# Built-in roles cover ~95% of scenarios. Common exam trap: choosing custom roles
# when a built-in role already exists (e.g., "Virtual Machine Contributor").

# Custom role: Allow operators to restart VMs and read metrics, but NOT delete or create VMs.
# Real scenario: NOC team needs restart capability without full VM management.
$customRoleDefinition = @{
    Name             = "Virtual Machine Operator"
    Description      = "Can restart and monitor VMs but cannot create or delete them"
    IsCustom         = $true
    Actions          = @(
        "Microsoft.Compute/virtualMachines/start/action",
        "Microsoft.Compute/virtualMachines/restart/action",
        "Microsoft.Compute/virtualMachines/deallocate/action",
        "Microsoft.Compute/virtualMachines/read",
        "Microsoft.Compute/virtualMachines/instanceView/read",
        "Microsoft.Insights/metrics/read",                      # Read VM metrics
        "Microsoft.Insights/alertRules/read",                   # Read alert rules
        "Microsoft.Resources/subscriptions/resourceGroups/read" # Navigate portal
    )
    NotActions       = @()   # Explicitly empty -- no denied actions within scope
    DataActions      = @()   # No data plane access needed
    NotDataActions   = @()
    AssignableScopes = @(
        "/subscriptions/00000000-0000-0000-0000-000000000000"  # Scope to specific subscription
    )
}

$customRole = New-AzRoleDefinition -Role $customRoleDefinition

# Assign the custom role to a security group at resource group scope
# EXAM TIP: Always assign roles to GROUPS, not individual users.
# This simplifies management and aligns with Entra ID best practices.
$roleAssignmentParams = @{
    ObjectId           = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"  # Security group object ID
    RoleDefinitionName = "Virtual Machine Operator"
    Scope              = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/az305-rg"
}

New-AzRoleAssignment @roleAssignmentParams

# ============================================================================
# SECTION 3: Privileged Identity Management (PIM) Eligible Role Assignment
# ============================================================================

# EXAM TIP: PIM provides JUST-IN-TIME (JIT) privileged access. The exam tests
# the difference between ELIGIBLE (must activate) vs. ACTIVE (always on) assignments.
# Eligible assignments reduce the attack surface by limiting standing access.

# WHEN TO USE: PIM for any privileged role (Contributor, Owner, User Access Administrator).
# Permanent assignments should be limited to break-glass accounts only.
# PIM requires Microsoft Entra ID P2 licensing.

Import-Module Microsoft.Graph.Identity.Governance

# Create an eligible assignment for the Contributor role (not permanent!)
$eligibleAssignmentParams = @{
    PrincipalId      = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"  # User or group object ID
    RoleDefinitionId = "b24988ac-6180-42a0-ab88-20f7382dd24c"  # Contributor built-in role ID
    DirectoryScopeId = "/subscriptions/00000000-0000-0000-0000-000000000000"
    Action           = "adminAssign"
    Justification    = "Project lead needs Contributor access for Q1 deployment"
    ScheduleInfo     = @{
        # Eligible for 90 days -- forces periodic review
        Expiration = @{
            Type     = "afterDuration"
            Duration = "P90D"  # ISO 8601 duration: 90 days
        }
    }
}

New-MgRoleManagementDirectoryRoleEligibilityScheduleRequest @eligibleAssignmentParams

# Configure PIM role settings: require approval + MFA for activation
# EXAM TIP: PIM activation policies can require MFA, approval, justification,
# and ticket information. Exam scenarios test which combination to use for
# different risk levels.

# ============================================================================
# SECTION 4: Management Group Hierarchy
# ============================================================================

# EXAM TIP: Management groups enable governance AT SCALE. They sit ABOVE
# subscriptions in the Azure resource hierarchy:
#   Tenant Root Group > Management Groups > Subscriptions > Resource Groups > Resources
# Policies and RBAC assigned at a management group flow DOWN to all child subscriptions.

# WHEN TO USE: Management groups when you have multiple subscriptions that need
# consistent governance. Even with 2-3 subscriptions, management groups simplify
# policy and RBAC inheritance.

# Create a management group hierarchy: Contoso > Production + Non-Production
$parentMgParams = @{
    GroupName = "Contoso"
    DisplayName = "Contoso Corporation"
}
New-AzManagementGroup @parentMgParams

$prodMgParams = @{
    GroupName         = "Contoso-Production"
    DisplayName       = "Production Workloads"
    ParentId          = "/providers/Microsoft.Management/managementGroups/Contoso"
}
New-AzManagementGroup @prodMgParams

$nonprodMgParams = @{
    GroupName         = "Contoso-NonProduction"
    DisplayName       = "Non-Production (Dev/Test/Staging)"
    ParentId          = "/providers/Microsoft.Management/managementGroups/Contoso"
}
New-AzManagementGroup @nonprodMgParams

# EXAM TIP: Maximum depth is 6 levels (excluding root and subscription level).
# Microsoft recommends keeping hierarchies FLAT -- 2-4 levels is typical.
# Deep hierarchies create complexity and slow down policy evaluation.

# ============================================================================
# SECTION 5: Azure Policy Initiative Assignment
# ============================================================================

# EXAM TIP: Azure Policy ENFORCES organizational standards. Know the difference:
#   - Policy Definition: A single rule (e.g., "require a tag")
#   - Policy Initiative (Set): A GROUP of related definitions
#   - Assignment: Applying a definition or initiative to a scope
# Effect order of evaluation: Disabled > Append/Modify > Deny > Audit

# WHEN TO USE: Policy over manual compliance checks. Use INITIATIVES over individual
# policies when you have related rules (e.g., all tagging rules in one initiative).
# Use "Audit" effect first, then switch to "Deny" after validating impact.

# Create a custom policy definition: require CostCenter tag on resource groups
$policyRule = @{
    "if"   = @{
        "allOf" = @(
            @{
                "field"  = "type"
                "equals" = "Microsoft.Resources/subscriptions/resourceGroups"
            },
            @{
                "field"  = "[concat('tags[', 'CostCenter', ']')]"
                "exists" = "false"
            }
        )
    }
    "then" = @{
        # Start with Audit, move to Deny after validating compliance state
        "effect" = "Deny"
    }
}

$policyDefinitionParams = @{
    Name         = "require-costcenter-tag-rg"
    DisplayName  = "Require CostCenter tag on resource groups"
    Description  = "Denies creation of resource groups without a CostCenter tag"
    Policy       = ($policyRule | ConvertTo-Json -Depth 10)
    Mode         = "All"
    ManagementGroupName = "Contoso"  # Define at management group for reuse
}

$policyDef = New-AzPolicyDefinition @policyDefinitionParams

# Create a policy initiative (set) combining multiple tagging policies
$initiativeDefinitions = @(
    @{
        policyDefinitionId          = $policyDef.PolicyDefinitionId
        policyDefinitionReferenceId = "requireCostCenterTag"
    }
    # In production, you would add more policy references here:
    # - Require Environment tag
    # - Require Owner tag
    # - Require Application tag
    # - Inherit tags from resource group (using Modify effect)
)

$initiativeParams = @{
    Name                  = "tagging-governance-initiative"
    DisplayName           = "Tagging Governance Initiative"
    Description           = "Enforces organizational tagging standards across all resources"
    PolicyDefinition      = ($initiativeDefinitions | ConvertTo-Json -Depth 10)
    ManagementGroupName   = "Contoso"
}

$initiative = New-AzPolicySetDefinition @initiativeParams

# Assign the initiative to the Production management group
$assignmentParams = @{
    Name                 = "prod-tagging-governance"
    DisplayName          = "Production Tagging Governance"
    PolicySetDefinition  = $initiative
    Scope                = "/providers/Microsoft.Management/managementGroups/Contoso-Production"
    EnforcementMode      = "Default"  # DoNotEnforce for testing
    IdentityType         = "SystemAssigned"  # Required for Modify/DeployIfNotExists effects
    Location             = "eastus"          # Required when using managed identity
}

New-AzPolicyAssignment @assignmentParams

# ============================================================================
# SECTION 6: Resource Tagging Strategy Enforcement
# ============================================================================

# EXAM TIP: Tags are critical for cost management, operations, and governance.
# The exam tests your ability to DESIGN a tagging strategy, not just apply tags.
# Key tags every organization should have: CostCenter, Environment, Owner, Application.

# WHEN TO USE: Tags + Policy together for enforcement. Tags alone are optional
# metadata; Policy makes them mandatory. Use the "Modify" effect to auto-inherit
# tags from parent resource groups -- this prevents tag drift.

# Apply tags to an existing resource group
$tags = @{
    "CostCenter"   = "CC-12345"
    "Environment"  = "Production"
    "Owner"        = "platform-team@contoso.com"
    "Application"  = "ECommerce-Backend"
    "Department"   = "Engineering"
    "CreatedBy"    = "IaC-Pipeline"
    "DataClass"    = "Confidential"   # Data classification for security governance
}

# Use Update-AzTag with -Operation Merge to ADD tags without removing existing ones
# EXAM TIP: -Operation Replace OVERWRITES all tags; Merge ADDS/UPDATES individual tags.
$tagUpdateParams = @{
    ResourceId = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/az305-rg"
    Tag        = $tags
    Operation  = "Merge"
}

Update-AzTag @tagUpdateParams

# Auto-inherit tags from resource group using Azure Policy with Modify effect
# This policy automatically copies the CostCenter tag from the resource group
# to any child resource that is missing it -- prevents tag drift at scale
$inheritTagPolicyId = "/providers/Microsoft.Authorization/policyDefinitions/ea3f2387-9b95-492a-a190-fcbf17d57f59"

$inheritTagAssignmentParams = @{
    Name                = "inherit-costcenter-tag"
    DisplayName         = "Inherit CostCenter tag from resource group"
    PolicyDefinition    = (Get-AzPolicyDefinition -Id $inheritTagPolicyId)
    Scope               = "/providers/Microsoft.Management/managementGroups/Contoso-Production"
    PolicyParameterObject = @{
        tagName = "CostCenter"
    }
    EnforcementMode     = "Default"
    IdentityType        = "SystemAssigned"
    Location            = "eastus"
}

New-AzPolicyAssignment @inheritTagAssignmentParams

# EXAM TIP: After assigning a Modify policy, run a REMEDIATION TASK to apply
# the policy to existing non-compliant resources. New resources are handled
# automatically, but existing resources need explicit remediation.
# Start-AzPolicyRemediation -Name "remediate-costcenter-tags" `
#     -PolicyAssignmentId $assignment.PolicyAssignmentId
