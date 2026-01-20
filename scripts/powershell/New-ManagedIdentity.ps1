<#
.SYNOPSIS
    Create and configure managed identities for Azure resources.

.DESCRIPTION
    This script demonstrates managed identity patterns including:
    - Creating user-assigned managed identities
    - Assigning roles to managed identities
    - Configuring Key Vault access
    - Enabling managed identity on Azure resources
    - Best practices for identity management

.PARAMETER ResourceGroupName
    The resource group for the managed identity.

.PARAMETER Location
    Azure region for resources. Default: eastus

.PARAMETER IdentityName
    Name for the user-assigned managed identity.

.PARAMETER TargetResource
    Resource to assign the identity to (VM, App Service, etc.).

.EXAMPLE
    # Create user-assigned managed identity
    .\New-ManagedIdentity.ps1 -ResourceGroupName "myRG" -IdentityName "my-app-identity"

.EXAMPLE
    # Create and assign to VM
    .\New-ManagedIdentity.ps1 -ResourceGroupName "myRG" -IdentityName "vm-identity" -TargetResource "myVM"

.NOTES
    AZ-305 EXAM OBJECTIVES:
    - Design identity solutions for Azure resources
    - Understand managed identity types and use cases
    - Implement secure authentication without credentials
    - Design for zero-trust security model

.LINK
    https://learn.microsoft.com/azure/active-directory/managed-identities-azure-resources/overview
    https://learn.microsoft.com/azure/active-directory/managed-identities-azure-resources/how-manage-user-assigned-managed-identities
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [string]$Location = "eastus",

    [Parameter(Mandatory = $false)]
    [string]$IdentityName = "az305-managed-identity",

    [Parameter(Mandatory = $false)]
    [string]$TargetResource
)

#Requires -Modules Az.Accounts, Az.Resources, Az.ManagedServiceIdentity, Az.KeyVault

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
            Purpose     = "AZ305-ManagedIdentity"
            Environment = "Development"
        }
        Write-Log "Created resource group: $ResourceGroupName" -Level "SUCCESS"
    }
    else {
        Write-Log "Resource group exists: $ResourceGroupName"
    }

    return $rg
}

#-------------------------------------------------------------------------------
# CREATE USER-ASSIGNED MANAGED IDENTITY
#-------------------------------------------------------------------------------
function New-UserAssignedManagedIdentity {
    Write-Log "Creating user-assigned managed identity: $IdentityName..."

    # WHY: User-assigned managed identities are:
    # - Reusable across multiple resources
    # - Lifecycle independent from the resource
    # - Easier to pre-configure with permissions
    # - Better for shared services and workloads

    $existingIdentity = Get-AzUserAssignedIdentity `
        -ResourceGroupName $ResourceGroupName `
        -Name $IdentityName `
        -ErrorAction SilentlyContinue

    if (-not $existingIdentity) {
        $identity = New-AzUserAssignedIdentity `
            -ResourceGroupName $ResourceGroupName `
            -Name $IdentityName `
            -Location $Location `
            -Tag @{
            Purpose     = "ApplicationIdentity"
            Environment = "Development"
        }

        Write-Log "Created user-assigned managed identity: $IdentityName" -Level "SUCCESS"
        Write-Log "  Principal ID: $($identity.PrincipalId)"
        Write-Log "  Client ID: $($identity.ClientId)"
        Write-Log "  Resource ID: $($identity.Id)"

        return $identity
    }
    else {
        Write-Log "Managed identity already exists: $IdentityName"
        return $existingIdentity
    }
}

#-------------------------------------------------------------------------------
# ASSIGN ROLES TO MANAGED IDENTITY
#-------------------------------------------------------------------------------
function Set-IdentityRoleAssignments {
    param([object]$Identity)

    Write-Log "Assigning roles to managed identity..."

    # WHY: RBAC roles grant the identity permissions to access Azure resources
    # Use principle of least privilege - only assign required permissions

    $subscriptionId = (Get-AzContext).Subscription.Id
    $scope = "/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName"

    # Common roles for applications
    $rolesToAssign = @(
        @{
            RoleDefinitionName = "Reader"
            Description        = "Read access to resource group resources"
        },
        @{
            RoleDefinitionName = "Key Vault Secrets User"
            Description        = "Read secrets from Key Vault (RBAC mode)"
        },
        @{
            RoleDefinitionName = "Storage Blob Data Reader"
            Description        = "Read blobs from storage accounts"
        }
    )

    foreach ($role in $rolesToAssign) {
        try {
            $existingAssignment = Get-AzRoleAssignment `
                -ObjectId $Identity.PrincipalId `
                -RoleDefinitionName $role.RoleDefinitionName `
                -Scope $scope `
                -ErrorAction SilentlyContinue

            if (-not $existingAssignment) {
                New-AzRoleAssignment `
                    -ObjectId $Identity.PrincipalId `
                    -RoleDefinitionName $role.RoleDefinitionName `
                    -Scope $scope | Out-Null

                Write-Log "Assigned role: $($role.RoleDefinitionName) - $($role.Description)" -Level "SUCCESS"
            }
            else {
                Write-Log "Role already assigned: $($role.RoleDefinitionName)"
            }
        }
        catch {
            Write-Log "Could not assign role $($role.RoleDefinitionName): $_" -Level "WARNING"
        }
    }
}

#-------------------------------------------------------------------------------
# CREATE KEY VAULT WITH RBAC
#-------------------------------------------------------------------------------
function New-KeyVaultForIdentity {
    param([object]$Identity)

    Write-Log "Creating Key Vault with RBAC authorization..."

    # WHY: Key Vault with RBAC is the modern approach
    # - Uses Azure RBAC instead of vault access policies
    # - Consistent with Azure resource management model
    # - Better integration with managed identities

    $keyVaultName = "kv-$(Get-Random -Maximum 9999)"

    $existingKv = Get-AzKeyVault -VaultName $keyVaultName -ErrorAction SilentlyContinue

    if (-not $existingKv) {
        $keyVault = New-AzKeyVault `
            -VaultName $keyVaultName `
            -ResourceGroupName $ResourceGroupName `
            -Location $Location `
            -EnableRbacAuthorization `
            -EnableSoftDelete `
            -SoftDeleteRetentionInDays 7 `
            -Tag @{
            Purpose     = "ApplicationSecrets"
            Environment = "Development"
        }

        Write-Log "Created Key Vault: $keyVaultName" -Level "SUCCESS"

        # Assign Key Vault roles to managed identity
        $kvScope = $keyVault.ResourceId

        # Key Vault Secrets User - read secrets
        New-AzRoleAssignment `
            -ObjectId $Identity.PrincipalId `
            -RoleDefinitionName "Key Vault Secrets User" `
            -Scope $kvScope | Out-Null

        Write-Log "Assigned Key Vault Secrets User role to identity" -Level "SUCCESS"

        # Add a sample secret
        $secretValue = ConvertTo-SecureString "SampleSecretValue123!" -AsPlainText -Force
        Set-AzKeyVaultSecret -VaultName $keyVaultName -Name "sample-secret" -SecretValue $secretValue | Out-Null
        Write-Log "Added sample secret to Key Vault"

        return $keyVault
    }
    else {
        Write-Log "Key Vault already exists: $keyVaultName"
        return $existingKv
    }
}

#-------------------------------------------------------------------------------
# ASSIGN IDENTITY TO VM (if specified)
#-------------------------------------------------------------------------------
function Set-VMIdentity {
    param([object]$Identity)

    if (-not $TargetResource) {
        Write-Log "No target resource specified. Skipping VM identity assignment."
        return
    }

    Write-Log "Assigning managed identity to VM: $TargetResource..."

    try {
        $vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $TargetResource -ErrorAction Stop

        # WHY: VMs can have both system-assigned and user-assigned identities
        # - System-assigned: tied to VM lifecycle
        # - User-assigned: independent, can be pre-configured

        $currentIdentities = $vm.Identity.UserAssignedIdentities.Keys
        $identityId = $Identity.Id

        if ($currentIdentities -contains $identityId) {
            Write-Log "VM already has this identity assigned"
        }
        else {
            Update-AzVM `
                -ResourceGroupName $ResourceGroupName `
                -VM $vm `
                -IdentityType "UserAssigned" `
                -IdentityId $identityId | Out-Null

            Write-Log "Assigned managed identity to VM: $TargetResource" -Level "SUCCESS"
        }
    }
    catch {
        Write-Log "Could not assign identity to VM: $_" -Level "WARNING"
    }
}

#-------------------------------------------------------------------------------
# DISPLAY SUMMARY
#-------------------------------------------------------------------------------
function Show-DeploymentSummary {
    param(
        [object]$Identity,
        [object]$KeyVault
    )

    Write-Host ""
    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host "                  MANAGED IDENTITY DEPLOYMENT SUMMARY" -ForegroundColor Cyan
    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "MANAGED IDENTITY:" -ForegroundColor Yellow
    Write-Host "  Name: $($Identity.Name)"
    Write-Host "  Principal ID: $($Identity.PrincipalId)"
    Write-Host "  Client ID: $($Identity.ClientId)"
    Write-Host "  Resource ID: $($Identity.Id)"
    Write-Host ""

    if ($KeyVault) {
        Write-Host "KEY VAULT:" -ForegroundColor Yellow
        Write-Host "  Name: $($KeyVault.VaultName)"
        Write-Host "  URI: $($KeyVault.VaultUri)"
        Write-Host "  RBAC Enabled: True"
        Write-Host ""
    }

    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host "MANAGED IDENTITY CONCEPTS (AZ-305 Exam Context):" -ForegroundColor Cyan
    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "IDENTITY TYPES:" -ForegroundColor Yellow
    Write-Host "  System-Assigned:"
    Write-Host "    - Created with the Azure resource"
    Write-Host "    - Deleted when resource is deleted"
    Write-Host "    - Cannot be shared across resources"
    Write-Host "    - Best for: Single-resource scenarios"
    Write-Host ""
    Write-Host "  User-Assigned:"
    Write-Host "    - Created as standalone Azure resource"
    Write-Host "    - Can be assigned to multiple resources"
    Write-Host "    - Independent lifecycle"
    Write-Host "    - Best for: Shared identities, pre-provisioning"
    Write-Host ""
    Write-Host "SUPPORTED SERVICES:" -ForegroundColor Yellow
    Write-Host "  Virtual Machines, App Service, Functions, Container Apps"
    Write-Host "  Logic Apps, API Management, Azure Data Factory"
    Write-Host "  Azure Kubernetes Service (AKS), Azure Arc"
    Write-Host ""
    Write-Host "KEY VAULT ACCESS MODELS:" -ForegroundColor Yellow
    Write-Host "  RBAC (Recommended): Uses Azure role assignments"
    Write-Host "    - Key Vault Administrator, Secrets Officer, etc."
    Write-Host "  Access Policies (Legacy): Vault-specific policies"
    Write-Host ""
    Write-Host "USAGE IN CODE:" -ForegroundColor Yellow
    Write-Host "  # .NET / C#"
    Write-Host "  var credential = new DefaultAzureCredential();"
    Write-Host "  var client = new SecretClient(vaultUri, credential);"
    Write-Host ""
    Write-Host "  # Python"
    Write-Host "  from azure.identity import DefaultAzureCredential"
    Write-Host "  credential = DefaultAzureCredential()"
    Write-Host ""
    Write-Host "  # PowerShell"
    Write-Host "  Connect-AzAccount -Identity -AccountId '$($Identity.ClientId)'"
    Write-Host "===============================================================================" -ForegroundColor Cyan
}

#-------------------------------------------------------------------------------
# MAIN
#-------------------------------------------------------------------------------
function Main {
    Write-Log "Starting Managed Identity deployment..."

    try {
        # Ensure resource group exists
        $rg = Confirm-ResourceGroup

        # Create user-assigned managed identity
        $identity = New-UserAssignedManagedIdentity

        # Assign roles to identity
        Set-IdentityRoleAssignments -Identity $identity

        # Create Key Vault with RBAC
        $keyVault = New-KeyVaultForIdentity -Identity $identity

        # Assign to VM if specified
        if ($TargetResource) {
            Set-VMIdentity -Identity $identity
        }

        # Display summary
        Show-DeploymentSummary -Identity $identity -KeyVault $keyVault

        Write-Log "Managed Identity deployment completed successfully!" -Level "SUCCESS"
    }
    catch {
        Write-Log "Deployment failed: $_" -Level "ERROR"
        throw
    }
}

# Execute main function
Main
