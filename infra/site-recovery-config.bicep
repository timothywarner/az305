// ============================================================================
// Azure Site Recovery Configuration
// ============================================================================
// Purpose: Configure Site Recovery for VM disaster recovery
// AZ-305 Exam Objectives:
//   - Design a solution for backup and disaster recovery (Objective 3.1)
//   - Design high availability solutions (Objective 3.2)
// Prerequisites:
//   - Recovery Services Vault must exist
//   - Source and target virtual networks
//   - Storage account for cache
// ============================================================================

targetScope = 'resourceGroup'

// ============================================================================
// Parameters
// ============================================================================

@description('Name of the existing Recovery Services Vault.')
param recoveryServicesVaultName string

@description('Primary (source) region.')
param primaryLocation string = resourceGroup().location

@description('Secondary (recovery) region.')
param secondaryLocation string = 'westus2'

@description('Source resource group name.')
param sourceResourceGroupName string

@description('Target (recovery) resource group name.')
param targetResourceGroupName string

@description('Source virtual network resource ID.')
param sourceVnetId string

@description('Target virtual network resource ID.')
param targetVnetId string

@description('Cache storage account ID for replication.')
param cacheStorageAccountId string

@description('Recovery replication policy name.')
param replicationPolicyName string = 'policy-24hour-retention'

@description('Application consistent snapshot frequency in minutes.')
@allowed([
  60
  120
  240
  480
  720
  1440
])
param appConsistentFrequencyInMinutes int = 240

@description('Crash consistent snapshot frequency in minutes.')
@allowed([
  5
  15
  30
  60
])
param crashConsistentFrequencyInMinutes int = 5

@description('Recovery point retention in hours.')
@minValue(0)
@maxValue(72)
param recoveryPointRetentionInHours int = 24

@description('Tags to apply to resources.')
param tags object = {
  environment: 'production'
  purpose: 'disaster-recovery'
  examObjective: 'AZ-305-BusinessContinuity'
}

// ============================================================================
// Variables
// ============================================================================

var primaryFabricName = 'fabric-${primaryLocation}'
var recoveryFabricName = 'fabric-${secondaryLocation}'
var primaryContainerName = 'container-${primaryLocation}'
var recoveryContainerName = 'container-${secondaryLocation}'
var networkMappingName = 'mapping-${primaryLocation}-to-${secondaryLocation}'

// ============================================================================
// Existing Resources
// ============================================================================

@description('Reference to existing Recovery Services Vault')
resource recoveryServicesVault 'Microsoft.RecoveryServices/vaults@2023-06-01' existing = {
  name: recoveryServicesVaultName
}

// ============================================================================
// Resources - Replication Fabrics
// ============================================================================

@description('Primary region replication fabric')
resource primaryFabric 'Microsoft.RecoveryServices/vaults/replicationFabrics@2023-06-01' = {
  parent: recoveryServicesVault
  name: primaryFabricName
  properties: {
    customDetails: {
      instanceType: 'Azure'
      location: primaryLocation
    }
  }
}

@description('Recovery region replication fabric')
resource recoveryFabric 'Microsoft.RecoveryServices/vaults/replicationFabrics@2023-06-01' = {
  parent: recoveryServicesVault
  name: recoveryFabricName
  properties: {
    customDetails: {
      instanceType: 'Azure'
      location: secondaryLocation
    }
  }
}

// ============================================================================
// Resources - Protection Containers
// ============================================================================

@description('Primary region protection container')
resource primaryContainer 'Microsoft.RecoveryServices/vaults/replicationFabrics/replicationProtectionContainers@2023-06-01' = {
  parent: primaryFabric
  name: primaryContainerName
  properties: {
    providerSpecificInput: [
      {
        instanceType: 'A2A'
      }
    ]
  }
}

@description('Recovery region protection container')
resource recoveryContainer 'Microsoft.RecoveryServices/vaults/replicationFabrics/replicationProtectionContainers@2023-06-01' = {
  parent: recoveryFabric
  name: recoveryContainerName
  properties: {
    providerSpecificInput: [
      {
        instanceType: 'A2A'
      }
    ]
  }
}

// ============================================================================
// Resources - Replication Policy
// ============================================================================

@description('Replication policy with RPO and retention settings')
resource replicationPolicy 'Microsoft.RecoveryServices/vaults/replicationPolicies@2023-06-01' = {
  parent: recoveryServicesVault
  name: replicationPolicyName
  properties: {
    providerSpecificInput: {
      instanceType: 'A2A'
      appConsistentFrequencyInMinutes: appConsistentFrequencyInMinutes
      crashConsistentFrequencyInMinutes: crashConsistentFrequencyInMinutes
      recoveryPointHistory: recoveryPointRetentionInHours * 60 // Convert to minutes
      multiVmSyncStatus: 'Enable'
    }
  }
}

// ============================================================================
// Resources - Protection Container Mapping
// ============================================================================

@description('Container mapping from primary to recovery')
resource containerMapping 'Microsoft.RecoveryServices/vaults/replicationFabrics/replicationProtectionContainers/replicationProtectionContainerMappings@2023-06-01' = {
  parent: primaryContainer
  name: '${primaryContainerName}-to-${recoveryContainerName}'
  properties: {
    targetProtectionContainerId: recoveryContainer.id
    policyId: replicationPolicy.id
    providerSpecificInput: {
      instanceType: 'A2A'
    }
  }
  dependsOn: [
    replicationPolicy
    recoveryContainer
  ]
}

@description('Container mapping from recovery to primary (for failback)')
resource containerMappingReverse 'Microsoft.RecoveryServices/vaults/replicationFabrics/replicationProtectionContainers/replicationProtectionContainerMappings@2023-06-01' = {
  parent: recoveryContainer
  name: '${recoveryContainerName}-to-${primaryContainerName}'
  properties: {
    targetProtectionContainerId: primaryContainer.id
    policyId: replicationPolicy.id
    providerSpecificInput: {
      instanceType: 'A2A'
    }
  }
  dependsOn: [
    replicationPolicy
    primaryContainer
    containerMapping
  ]
}

// ============================================================================
// Resources - Network Mapping
// ============================================================================

@description('Network mapping from primary to recovery VNet')
resource networkMapping 'Microsoft.RecoveryServices/vaults/replicationFabrics/replicationNetworks/replicationNetworkMappings@2023-06-01' = {
  name: '${recoveryServicesVaultName}/${primaryFabricName}/azureNetwork/${networkMappingName}'
  properties: {
    recoveryFabricName: recoveryFabricName
    recoveryNetworkId: targetVnetId
    fabricSpecificDetails: {
      instanceType: 'AzureToAzure'
      primaryNetworkId: sourceVnetId
    }
  }
  dependsOn: [
    primaryFabric
    recoveryFabric
  ]
}

// ============================================================================
// Outputs
// ============================================================================

@description('Primary fabric ID')
output primaryFabricId string = primaryFabric.id

@description('Recovery fabric ID')
output recoveryFabricId string = recoveryFabric.id

@description('Primary protection container ID')
output primaryContainerId string = primaryContainer.id

@description('Recovery protection container ID')
output recoveryContainerId string = recoveryContainer.id

@description('Replication policy ID')
output replicationPolicyId string = replicationPolicy.id

@description('Replication policy name')
output replicationPolicyName string = replicationPolicy.name

@description('Container mapping ID')
output containerMappingId string = containerMapping.id

@description('Network mapping ID')
output networkMappingId string = networkMapping.id

@description('Primary location')
output primaryRegion string = primaryLocation

@description('Recovery location')
output recoveryRegion string = secondaryLocation

@description('RPO in minutes (crash consistent)')
output rpoMinutes int = crashConsistentFrequencyInMinutes

@description('Recovery point retention hours')
output retentionHours int = recoveryPointRetentionInHours
