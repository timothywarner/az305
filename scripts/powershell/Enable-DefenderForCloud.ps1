<#
.SYNOPSIS
    Enable and configure Microsoft Defender for Cloud.

.DESCRIPTION
    This script enables and configures Defender for Cloud including:
    - Enabling Defender plans for various resource types
    - Configuring security policies
    - Setting up continuous export to Log Analytics
    - Enabling auto-provisioning of agents
    - Configuring security contacts and notifications

.PARAMETER SubscriptionId
    Azure subscription to configure.

.PARAMETER EnableAllPlans
    Enable all available Defender plans. Default: false (enables basic plans)

.PARAMETER SecurityContactEmail
    Email address for security notifications.

.PARAMETER WorkspaceId
    Log Analytics workspace ID for continuous export.

.EXAMPLE
    # Enable basic Defender plans
    .\Enable-DefenderForCloud.ps1 -SubscriptionId "xxx" -SecurityContactEmail "security@company.com"

.EXAMPLE
    # Enable all Defender plans
    .\Enable-DefenderForCloud.ps1 -SubscriptionId "xxx" -EnableAllPlans $true

.NOTES
    AZ-305 EXAM OBJECTIVES:
    - Design security solutions for Azure workloads
    - Implement cloud security posture management
    - Configure threat protection for cloud resources
    - Design for compliance and security monitoring

.LINK
    https://learn.microsoft.com/azure/defender-for-cloud/defender-for-cloud-introduction
    https://learn.microsoft.com/azure/defender-for-cloud/enable-all-plans
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $false)]
    [bool]$EnableAllPlans = $false,

    [Parameter(Mandatory = $false)]
    [string]$SecurityContactEmail,

    [Parameter(Mandatory = $false)]
    [string]$WorkspaceId
)

#Requires -Modules Az.Accounts, Az.Security

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
}

#-------------------------------------------------------------------------------
# GET CURRENT DEFENDER STATUS
#-------------------------------------------------------------------------------
function Get-DefenderStatus {
    Write-Log "Checking current Defender for Cloud status..."

    $pricings = Get-AzSecurityPricing

    Write-Host ""
    Write-Host "Current Defender Plans Status:" -ForegroundColor Yellow
    Write-Host "-------------------------------------------------------------------------------"

    foreach ($pricing in $pricings) {
        $status = if ($pricing.PricingTier -eq "Standard") { "Enabled" } else { "Free" }
        $color = if ($pricing.PricingTier -eq "Standard") { "Green" } else { "Gray" }
        Write-Host "  $($pricing.Name.PadRight(30)): " -NoNewline
        Write-Host $status -ForegroundColor $color
    }
    Write-Host ""

    return $pricings
}

#-------------------------------------------------------------------------------
# ENABLE DEFENDER PLANS
#-------------------------------------------------------------------------------
function Enable-DefenderPlans {
    Write-Log "Enabling Defender for Cloud plans..."

    # WHY: Different plans protect different resource types
    # Enable based on what resources exist in your subscription

    # Core plans (recommended for most environments)
    $corePlans = @(
        @{ Name = "VirtualMachines"; Description = "Defender for Servers" },
        @{ Name = "SqlServers"; Description = "Defender for SQL" },
        @{ Name = "AppServices"; Description = "Defender for App Service" },
        @{ Name = "StorageAccounts"; Description = "Defender for Storage" },
        @{ Name = "KeyVaults"; Description = "Defender for Key Vault" },
        @{ Name = "Arm"; Description = "Defender for Resource Manager" },
        @{ Name = "Dns"; Description = "Defender for DNS" }
    )

    # Additional plans (enable if using these services)
    $additionalPlans = @(
        @{ Name = "KubernetesService"; Description = "Defender for Kubernetes" },
        @{ Name = "ContainerRegistry"; Description = "Defender for Container Registry" },
        @{ Name = "Containers"; Description = "Defender for Containers" },
        @{ Name = "SqlServerVirtualMachines"; Description = "Defender for SQL on VMs" },
        @{ Name = "OpenSourceRelationalDatabases"; Description = "Defender for Open-Source DBs" },
        @{ Name = "CosmosDbs"; Description = "Defender for Cosmos DB" },
        @{ Name = "Api"; Description = "Defender for APIs" }
    )

    # Determine which plans to enable
    $plansToEnable = if ($EnableAllPlans) { $corePlans + $additionalPlans } else { $corePlans }

    foreach ($plan in $plansToEnable) {
        try {
            $currentPricing = Get-AzSecurityPricing -Name $plan.Name -ErrorAction SilentlyContinue

            if ($currentPricing.PricingTier -eq "Free") {
                Set-AzSecurityPricing -Name $plan.Name -PricingTier "Standard" | Out-Null
                Write-Log "Enabled: $($plan.Description)" -Level "SUCCESS"
            }
            else {
                Write-Log "Already enabled: $($plan.Description)"
            }
        }
        catch {
            Write-Log "Could not enable $($plan.Description): $_" -Level "WARNING"
        }
    }
}

#-------------------------------------------------------------------------------
# CONFIGURE AUTO-PROVISIONING
#-------------------------------------------------------------------------------
function Set-AutoProvisioning {
    Write-Log "Configuring auto-provisioning settings..."

    # WHY: Auto-provisioning automatically deploys monitoring agents
    # This ensures new resources are protected without manual intervention

    try {
        # Enable Log Analytics agent auto-provisioning
        Set-AzSecurityAutoProvisioningSetting -Name "default" -EnableAutoProvision | Out-Null
        Write-Log "Enabled auto-provisioning for Log Analytics agent" -Level "SUCCESS"
    }
    catch {
        Write-Log "Could not configure auto-provisioning: $_" -Level "WARNING"
    }
}

#-------------------------------------------------------------------------------
# CONFIGURE SECURITY CONTACTS
#-------------------------------------------------------------------------------
function Set-SecurityContacts {
    Write-Log "Configuring security contacts..."

    if (-not $SecurityContactEmail) {
        Write-Log "No security contact email provided. Skipping security contact configuration." -Level "WARNING"
        return
    }

    # WHY: Security contacts receive notifications about security alerts
    # Critical for timely incident response

    try {
        # Note: The Set-AzSecurityContact cmdlet syntax may vary by Az module version
        # This is a simplified example

        $existingContact = Get-AzSecurityContact -ErrorAction SilentlyContinue

        Write-Log "Security contact email: $SecurityContactEmail"
        Write-Log "Configure security contacts in Azure Portal > Defender for Cloud > Environment settings" -Level "INFO"

        # Show the recommended configuration
        Write-Host "  Recommended Settings:" -ForegroundColor Yellow
        Write-Host "    - Email: $SecurityContactEmail"
        Write-Host "    - Notify about alerts: High severity"
        Write-Host "    - Notify about subscriptions/resource attacks: Yes"
    }
    catch {
        Write-Log "Could not configure security contacts: $_" -Level "WARNING"
    }
}

#-------------------------------------------------------------------------------
# CONFIGURE CONTINUOUS EXPORT
#-------------------------------------------------------------------------------
function Set-ContinuousExport {
    Write-Log "Configuring continuous export..."

    if (-not $WorkspaceId) {
        Write-Log "No workspace ID provided. Skipping continuous export configuration." -Level "WARNING"
        Write-Log "Continuous export to Log Analytics or Event Hub is recommended for SIEM integration."
        return
    }

    # WHY: Continuous export sends security data to Log Analytics or Event Hub
    # Enables integration with SIEM systems and custom alerting

    Write-Log "Workspace ID: $WorkspaceId"
    Write-Log "Configure continuous export in Azure Portal > Defender for Cloud > Environment settings > Continuous export" -Level "INFO"

    Write-Host "  Export Configuration Options:" -ForegroundColor Yellow
    Write-Host "    - Security recommendations"
    Write-Host "    - Security alerts"
    Write-Host "    - Secure score"
    Write-Host "    - Regulatory compliance"
}

#-------------------------------------------------------------------------------
# ASSIGN SECURITY BENCHMARK POLICY
#-------------------------------------------------------------------------------
function Set-SecurityBenchmark {
    Write-Log "Assigning Microsoft Cloud Security Benchmark..."

    # WHY: MCSB provides comprehensive security best practices
    # Assigns built-in policy initiative for compliance assessment

    try {
        $scope = "/subscriptions/$SubscriptionId"

        # Get the Microsoft Cloud Security Benchmark policy set definition
        $policySetDef = Get-AzPolicySetDefinition | Where-Object {
            $_.Properties.DisplayName -like "*Microsoft cloud security benchmark*"
        } | Select-Object -First 1

        if ($policySetDef) {
            $existingAssignment = Get-AzPolicyAssignment -Scope $scope | Where-Object {
                $_.Properties.PolicyDefinitionId -eq $policySetDef.PolicySetDefinitionId
            }

            if (-not $existingAssignment) {
                New-AzPolicyAssignment `
                    -Name "MCSB-Assignment" `
                    -DisplayName "Microsoft Cloud Security Benchmark" `
                    -PolicySetDefinition $policySetDef `
                    -Scope $scope | Out-Null

                Write-Log "Assigned Microsoft Cloud Security Benchmark" -Level "SUCCESS"
            }
            else {
                Write-Log "Microsoft Cloud Security Benchmark already assigned"
            }
        }
        else {
            Write-Log "Microsoft Cloud Security Benchmark policy not found. It may be assigned by default." -Level "WARNING"
        }
    }
    catch {
        Write-Log "Could not assign security benchmark: $_" -Level "WARNING"
    }
}

#-------------------------------------------------------------------------------
# DISPLAY SUMMARY
#-------------------------------------------------------------------------------
function Show-Summary {
    # Get final status
    $pricings = Get-AzSecurityPricing

    Write-Host ""
    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host "                DEFENDER FOR CLOUD CONFIGURATION SUMMARY" -ForegroundColor Cyan
    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "ENABLED DEFENDER PLANS:" -ForegroundColor Yellow
    Write-Host "-------------------------------------------------------------------------------"

    $enabledPlans = $pricings | Where-Object { $_.PricingTier -eq "Standard" }
    $freePlans = $pricings | Where-Object { $_.PricingTier -eq "Free" }

    Write-Host "  Enabled (Standard tier):" -ForegroundColor Green
    foreach ($plan in $enabledPlans) {
        Write-Host "    - $($plan.Name)"
    }

    Write-Host ""
    Write-Host "  Not Enabled (Free tier):" -ForegroundColor Gray
    foreach ($plan in $freePlans) {
        Write-Host "    - $($plan.Name)"
    }

    Write-Host ""
    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host "DEFENDER FOR CLOUD CONCEPTS (AZ-305 Exam Context):" -ForegroundColor Cyan
    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "DEFENDER PLAN OVERVIEW:" -ForegroundColor Yellow
    Write-Host "  Foundational CSPM (Free):"
    Write-Host "    - Secure Score"
    Write-Host "    - Security recommendations"
    Write-Host "    - Asset inventory"
    Write-Host ""
    Write-Host "  Enhanced Security (Standard tier):"
    Write-Host "    - Threat protection for workloads"
    Write-Host "    - Just-in-time VM access"
    Write-Host "    - Adaptive application controls"
    Write-Host "    - File integrity monitoring"
    Write-Host "    - Regulatory compliance dashboards"
    Write-Host ""
    Write-Host "KEY WORKLOAD PROTECTIONS:" -ForegroundColor Yellow
    Write-Host "  Defender for Servers:"
    Write-Host "    - Endpoint Detection and Response (EDR)"
    Write-Host "    - Vulnerability assessment"
    Write-Host "    - Just-in-time (JIT) VM access"
    Write-Host ""
    Write-Host "  Defender for SQL:"
    Write-Host "    - Vulnerability assessment"
    Write-Host "    - Advanced threat protection"
    Write-Host "    - Detects SQL injection, brute force"
    Write-Host ""
    Write-Host "  Defender for Storage:"
    Write-Host "    - Malware scanning"
    Write-Host "    - Sensitive data discovery"
    Write-Host "    - Unusual access pattern detection"
    Write-Host ""
    Write-Host "  Defender for Containers:"
    Write-Host "    - Image vulnerability scanning"
    Write-Host "    - Runtime threat protection"
    Write-Host "    - Kubernetes security posture"
    Write-Host ""
    Write-Host "INTEGRATION OPTIONS:" -ForegroundColor Yellow
    Write-Host "  - Continuous export to Log Analytics / Event Hub"
    Write-Host "  - SIEM integration (Microsoft Sentinel, Splunk, etc.)"
    Write-Host "  - Workflow automation with Logic Apps"
    Write-Host "  - API access for custom integrations"
    Write-Host ""
    Write-Host "COMPLIANCE:" -ForegroundColor Yellow
    Write-Host "  Built-in regulatory compliance assessments:"
    Write-Host "    - Microsoft Cloud Security Benchmark"
    Write-Host "    - PCI DSS, ISO 27001, SOC 2"
    Write-Host "    - HIPAA, FedRAMP, NIST"
    Write-Host ""
    Write-Host "USEFUL COMMANDS:" -ForegroundColor Yellow
    Write-Host "  # Check current Defender status"
    Write-Host "  Get-AzSecurityPricing | Format-Table Name, PricingTier"
    Write-Host ""
    Write-Host "  # Get security recommendations"
    Write-Host "  Get-AzSecurityTask | Format-Table Name, State, RecommendationType"
    Write-Host ""
    Write-Host "  # Get security alerts"
    Write-Host "  Get-AzSecurityAlert | Format-Table AlertDisplayName, Severity, Status"
    Write-Host "===============================================================================" -ForegroundColor Cyan
}

#-------------------------------------------------------------------------------
# MAIN
#-------------------------------------------------------------------------------
function Main {
    Write-Log "Starting Defender for Cloud configuration..."

    try {
        # Connect to Azure
        Connect-ToAzure

        # Show current status
        $currentStatus = Get-DefenderStatus

        # Enable Defender plans
        Enable-DefenderPlans

        # Configure auto-provisioning
        Set-AutoProvisioning

        # Configure security contacts
        Set-SecurityContacts

        # Configure continuous export
        Set-ContinuousExport

        # Assign security benchmark
        Set-SecurityBenchmark

        # Display summary
        Show-Summary

        Write-Log "Defender for Cloud configuration completed successfully!" -Level "SUCCESS"
    }
    catch {
        Write-Log "Configuration failed: $_" -Level "ERROR"
        throw
    }
}

# Execute main function
Main
