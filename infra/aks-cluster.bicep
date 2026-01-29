// ============================================================================
// Azure Kubernetes Service (AKS) Cluster
// ============================================================================
// Purpose: Deploy production-ready AKS cluster with best practices
// AZ-305 Exam Objectives:
//   - Design a compute solution (Objective 4.1)
//   - Design an application architecture (Objective 4.3)
//   - Design authentication and authorization solutions (Objective 1.1)
// Prerequisites:
//   - Resource group must exist
//   - Log Analytics workspace for monitoring
//   - Microsoft Entra ID group for cluster admins
//   - Virtual network with subnet for AKS (optional)
// ============================================================================

targetScope = 'resourceGroup'

// ============================================================================
// Parameters
// ============================================================================

@description('Name of the AKS cluster.')
@minLength(1)
@maxLength(63)
param clusterName string

@description('Azure region for the cluster.')
param location string = resourceGroup().location

@description('Kubernetes version.')
param kubernetesVersion string = '1.29'

@description('DNS prefix for the cluster.')
param dnsPrefix string = clusterName

@description('System node pool VM size.')
param systemNodeVmSize string = 'Standard_D4s_v5'

@description('System node pool node count.')
@minValue(1)
@maxValue(100)
param systemNodeCount int = 3

@description('User node pool VM size.')
param userNodeVmSize string = 'Standard_D4s_v5'

@description('User node pool minimum count.')
@minValue(1)
@maxValue(100)
param userNodeMinCount int = 2

@description('User node pool maximum count.')
@minValue(1)
@maxValue(100)
param userNodeMaxCount int = 10

@description('Enable Microsoft Entra ID integration.')
param enableAadIntegration bool = true

@description('Microsoft Entra ID admin group object IDs.')
param aadAdminGroupObjectIds array = []

@description('Enable Azure RBAC for Kubernetes authorization.')
param enableAzureRbac bool = true

@description('Enable private cluster.')
param enablePrivateCluster bool = false

@description('Virtual network resource ID.')
param vnetId string = ''

@description('Subnet name for AKS nodes.')
param aksSubnetName string = 'AksNodes'

@description('Pod CIDR for Azure CNI Overlay.')
param podCidr string = '10.244.0.0/16'

@description('Service CIDR.')
param serviceCidr string = '10.0.0.0/16'

@description('DNS service IP.')
param dnsServiceIp string = '10.0.0.10'

@description('Log Analytics workspace resource ID.')
param logAnalyticsWorkspaceId string = ''

@description('Enable Container Insights.')
param enableContainerInsights bool = true

@description('Enable Defender for Containers.')
param enableDefender bool = true

@description('Enable Key Vault secrets provider.')
param enableKeyVaultSecretsProvider bool = true

@description('Enable Azure Policy add-on.')
param enableAzurePolicy bool = true

@description('Tags to apply to resources.')
param tags object = {
  environment: 'production'
  purpose: 'kubernetes'
  examObjective: 'AZ-305-Compute'
}

// ============================================================================
// Variables
// ============================================================================

var aksClusterName = 'aks-${clusterName}-${uniqueString(resourceGroup().id)}'
var systemNodePoolName = 'system'
var userNodePoolName = 'user'

// ============================================================================
// Resources - AKS Cluster
// ============================================================================

@description('Azure Kubernetes Service cluster')
resource aksCluster 'Microsoft.ContainerService/managedClusters@2024-01-01' = {
  name: aksClusterName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'Base'
    tier: 'Standard'
  }
  properties: {
    kubernetesVersion: kubernetesVersion
    dnsPrefix: dnsPrefix
    enableRBAC: true
    aadProfile: enableAadIntegration ? {
      managed: true
      enableAzureRBAC: enableAzureRbac
      adminGroupObjectIDs: aadAdminGroupObjectIds
      tenantID: tenant().tenantId
    } : null
    agentPoolProfiles: [
      {
        name: systemNodePoolName
        count: systemNodeCount
        vmSize: systemNodeVmSize
        osDiskSizeGB: 128
        osDiskType: 'Ephemeral'
        osType: 'Linux'
        osSKU: 'AzureLinux'
        mode: 'System'
        enableAutoScaling: false
        enableNodePublicIP: false
        availabilityZones: [
          '1'
          '2'
          '3'
        ]
        nodeTaints: [
          'CriticalAddonsOnly=true:NoSchedule'
        ]
        vnetSubnetID: !empty(vnetId) ? '${vnetId}/subnets/${aksSubnetName}' : null
        maxPods: 110
        upgradeSettings: {
          maxSurge: '33%'
        }
      }
      {
        name: userNodePoolName
        count: userNodeMinCount
        vmSize: userNodeVmSize
        osDiskSizeGB: 128
        osDiskType: 'Ephemeral'
        osType: 'Linux'
        osSKU: 'AzureLinux'
        mode: 'User'
        enableAutoScaling: true
        minCount: userNodeMinCount
        maxCount: userNodeMaxCount
        enableNodePublicIP: false
        availabilityZones: [
          '1'
          '2'
          '3'
        ]
        vnetSubnetID: !empty(vnetId) ? '${vnetId}/subnets/${aksSubnetName}' : null
        maxPods: 110
        upgradeSettings: {
          maxSurge: '33%'
        }
      }
    ]
    networkProfile: {
      networkPlugin: 'azure'
      networkPluginMode: 'overlay'
      networkPolicy: 'azure'
      loadBalancerSku: 'standard'
      outboundType: 'loadBalancer'
      podCidr: podCidr
      serviceCidr: serviceCidr
      dnsServiceIP: dnsServiceIp
    }
    apiServerAccessProfile: {
      enablePrivateCluster: enablePrivateCluster
      enablePrivateClusterPublicFQDN: enablePrivateCluster
      privateDNSZone: enablePrivateCluster ? 'system' : null
    }
    autoUpgradeProfile: {
      upgradeChannel: 'patch'
      nodeOSUpgradeChannel: 'NodeImage'
    }
    disableLocalAccounts: enableAadIntegration
    securityProfile: {
      defender: enableDefender ? {
        logAnalyticsWorkspaceResourceId: logAnalyticsWorkspaceId
        securityMonitoring: {
          enabled: true
        }
      } : null
      imageCleaner: {
        enabled: true
        intervalHours: 168
      }
      workloadIdentity: {
        enabled: true
      }
    }
    oidcIssuerProfile: {
      enabled: true
    }
    addonProfiles: {
      omsagent: enableContainerInsights ? {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: logAnalyticsWorkspaceId
          useAADAuth: 'true'
        }
      } : {
        enabled: false
      }
      azurepolicy: {
        enabled: enableAzurePolicy
      }
      azureKeyvaultSecretsProvider: enableKeyVaultSecretsProvider ? {
        enabled: true
        config: {
          enableSecretRotation: 'true'
          rotationPollInterval: '2m'
        }
      } : {
        enabled: false
      }
    }
    storageProfile: {
      blobCSIDriver: {
        enabled: true
      }
      diskCSIDriver: {
        enabled: true
      }
      fileCSIDriver: {
        enabled: true
      }
      snapshotController: {
        enabled: true
      }
    }
  }
}

// ============================================================================
// Resources - Diagnostic Settings
// ============================================================================

@description('AKS diagnostic settings')
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  name: 'aks-diagnostics'
  scope: aksCluster
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
      {
        categoryGroup: 'audit'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('AKS cluster name')
output clusterName string = aksCluster.name

@description('AKS cluster resource ID')
output clusterId string = aksCluster.id

@description('AKS cluster FQDN')
output clusterFqdn string = enablePrivateCluster ? aksCluster.properties.privateFQDN : aksCluster.properties.fqdn

@description('AKS cluster API server URL')
output apiServerUrl string = 'https://${enablePrivateCluster ? aksCluster.properties.privateFQDN : aksCluster.properties.fqdn}:443'

@description('Kubernetes version')
output kubernetesVersion string = aksCluster.properties.kubernetesVersion

@description('Node resource group')
output nodeResourceGroup string = aksCluster.properties.nodeResourceGroup

@description('Kubelet identity object ID')
output kubeletIdentityObjectId string = aksCluster.properties.identityProfile.kubeletidentity.objectId

@description('Kubelet identity client ID')
output kubeletIdentityClientId string = aksCluster.properties.identityProfile.kubeletidentity.clientId

@description('OIDC issuer URL')
output oidcIssuerUrl string = aksCluster.properties.oidcIssuerProfile.issuerURL

@description('System-assigned managed identity principal ID')
output clusterIdentityPrincipalId string = aksCluster.identity.principalId

@description('Microsoft Entra ID integration enabled')
output aadEnabled bool = enableAadIntegration

@description('Azure RBAC for Kubernetes enabled')
output azureRbacEnabled bool = enableAzureRbac

@description('Private cluster enabled')
output privateClusterEnabled bool = enablePrivateCluster

@description('kubectl command to get credentials')
output getCredentialsCommand string = 'az aks get-credentials --resource-group ${resourceGroup().name} --name ${aksCluster.name} --overwrite-existing'
