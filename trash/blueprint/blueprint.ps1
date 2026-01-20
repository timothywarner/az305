# Manage Azure Blueprints with PowerShell

# Ref: https://timw.info/3xu

# Login first with Connect-AzAccount if not using Cloud Shell

# Get a reference to the new blueprint object, we'll use it in subsequent steps
$blueprint = New-AzBlueprint -Name 'MyBlueprint' -BlueprintFile .\blueprint.json

# Use the reference to the new blueprint object from the previous steps
New-AzBlueprintArtifact -Blueprint $blueprint -Name 'roleContributor' -ArtifactFile .\artifacts\roleContributor.json

# Use the reference to the new blueprint object from the previous steps
New-AzBlueprintArtifact -Blueprint $blueprint -Name 'policyTags' -ArtifactFile .\artifacts\policyTags.json

# Use the reference to the new blueprint object from the previous steps
New-AzBlueprintArtifact -Blueprint $blueprint -Name 'policyStorageTags' -ArtifactFile .\artifacts\policyStorageTags.json

# Use the reference to the new blueprint object from the previous steps
New-AzBlueprintArtifact -Blueprint $blueprint -Type TemplateArtifact -Name 'templateStorage' -TemplateFile .\artifacts\templateStorage.json -TemplateParameterFile .\artifacts\templateStorageParams.json -ResourceGroupName storageRG

# Use the reference to the new blueprint object from the previous steps
New-AzBlueprintArtifact -Blueprint $blueprint -Name 'roleOwner' -ArtifactFile .\artifacts\roleOwner.json

# Use the reference to the new blueprint object from the previous steps
Publish-AzBlueprint -Blueprint $blueprint -Version '{BlueprintVersion}'

# Use the reference to the new blueprint object from the previous steps
New-AzBlueprintAssignment -Blueprint $blueprint -Name 'assignMyBlueprint' -AssignmentFile .\blueprintAssignment.json

Remove-AzBlueprintAssignment -Name 'assignMyBlueprint'

