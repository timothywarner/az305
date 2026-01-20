
$resourceGroupName = 'oreilly'
$storageAccountName = 'oreillygpstorage'
$keyVaultName = 'tim-keyvault-001'
$keyVaultSpAppId = 'cfa8b339-82a2-471a-a3c9-0fc0be7a4093'

# Authenticate your PowerShell session with Azure AD
$azureProfile = Connect-AzAccount

# Get a reference to your Azure storage account
$storageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -StorageAccountName $storageAccountName

# In the storage account, assign RBAC role "Storage Account Key Operator Service Role" to Key Vault
New-AzRoleAssignment -ApplicationId $keyVaultSpAppId -RoleDefinitionName 'Storage Account Key Operator Service Role' -Scope $storageAccount.Id

# Give your user principal access to all storage account permissions, on your Key Vault instance

Set-AzKeyVaultAccessPolicy -VaultName $keyVaultName -UserPrincipalName $azureProfile.Context.Account.Id -PermissionsToStorage get, list, listsas, delete, set, update, regeneratekey, recover, backup, restore, purge

# Add your storage account to your Key Vault's managed storage accounts
$managedStorageAccount = @{
    VaultName          = $keyVaultName
    AccountName        = $storageAccount.StorageAccountName
    AccountResourceId  = $storageAccount.Id
    ActiveKeyName      = "key1"
    RegenerationPeriod = [System.Timespan]::FromDays(90)
}

Add-AzKeyVaultManagedStorageAccount @managedStorageAccount