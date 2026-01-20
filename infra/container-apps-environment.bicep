// ============================================================================
// Azure Container Apps Environment with Dapr
// ============================================================================
// Purpose: Deploy Container Apps environment with Dapr sidecar support
// AZ-305 Exam Objectives:
//   - Design a compute solution (Objective 4.1)
//   - Design an application architecture (Objective 4.3)
// Prerequisites:
//   - Resource group must exist
//   - Log Analytics workspace for monitoring
//   - Virtual network for internal environment (optional)
// ============================================================================

targetScope = 'resourceGroup'

// ============================================================================
// Parameters
// ============================================================================

@description('Name of the Container Apps environment.')
@minLength(1)
@maxLength(32)
param environmentName string

@description('Azure region for the environment.')
param location string = resourceGroup().location

@description('Log Analytics workspace resource ID.')
param logAnalyticsWorkspaceId string

@description('Enable internal-only environment (requires VNet).')
param isInternalOnly bool = false

@description('Virtual network resource ID for internal environment.')
param vnetId string = ''

@description('Subnet name for Container Apps infrastructure.')
param infrastructureSubnetName string = 'ContainerAppsInfra'

@description('Enable zone redundancy.')
param zoneRedundant bool = true

@description('Enable Dapr.')
param enableDapr bool = true

@description('Enable workload profiles.')
param enableWorkloadProfiles bool = true

@description('Deploy sample container app.')
param deploySampleApp bool = false

@description('Tags to apply to resources.')
param tags object = {
  environment: 'production'
  purpose: 'container-apps'
  examObjective: 'AZ-305-Compute'
}

// ============================================================================
// Variables
// ============================================================================

var envName = 'cae-${environmentName}-${uniqueString(resourceGroup().id)}'
var workloadProfiles = enableWorkloadProfiles ? [
  {
    name: 'Consumption'
    workloadProfileType: 'Consumption'
  }
  {
    name: 'Dedicated-D4'
    workloadProfileType: 'D4'
    minimumCount: 0
    maximumCount: 10
  }
] : []

// ============================================================================
// Resources - Container Apps Environment
// ============================================================================

@description('Container Apps managed environment')
resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2023-11-02-preview' = {
  name: envName
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: reference(logAnalyticsWorkspaceId, '2023-09-01').customerId
        sharedKey: listKeys(logAnalyticsWorkspaceId, '2023-09-01').primarySharedKey
      }
    }
    daprAIConnectionString: ''
    daprAIInstrumentationKey: ''
    infrastructureResourceGroup: ''
    peerAuthentication: {
      mtls: {
        enabled: true
      }
    }
    vnetConfiguration: !empty(vnetId) ? {
      infrastructureSubnetId: '${vnetId}/subnets/${infrastructureSubnetName}'
      internal: isInternalOnly
    } : null
    workloadProfiles: enableWorkloadProfiles ? workloadProfiles : null
    zoneRedundant: zoneRedundant
  }
}

// ============================================================================
// Resources - Dapr Components (Examples)
// ============================================================================

@description('Dapr state store component (Azure Blob Storage)')
resource daprStateStore 'Microsoft.App/managedEnvironments/daprComponents@2023-11-02-preview' = if (enableDapr) {
  parent: containerAppsEnvironment
  name: 'statestore'
  properties: {
    componentType: 'state.azure.blobstorage'
    version: 'v1'
    ignoreErrors: false
    initTimeout: '5m'
    metadata: [
      {
        name: 'accountName'
        value: '{storage-account-name}'
      }
      {
        name: 'containerName'
        value: 'state'
      }
      {
        name: 'azureClientId'
        value: '{managed-identity-client-id}'
      }
    ]
    scopes: []
  }
}

@description('Dapr pub/sub component (Azure Service Bus)')
resource daprPubSub 'Microsoft.App/managedEnvironments/daprComponents@2023-11-02-preview' = if (enableDapr) {
  parent: containerAppsEnvironment
  name: 'pubsub'
  properties: {
    componentType: 'pubsub.azure.servicebus.topics'
    version: 'v1'
    ignoreErrors: false
    initTimeout: '5m'
    metadata: [
      {
        name: 'namespaceName'
        value: '{servicebus-namespace}.servicebus.windows.net'
      }
      {
        name: 'azureClientId'
        value: '{managed-identity-client-id}'
      }
    ]
    scopes: []
  }
}

@description('Dapr secrets component (Azure Key Vault)')
resource daprSecretStore 'Microsoft.App/managedEnvironments/daprComponents@2023-11-02-preview' = if (enableDapr) {
  parent: containerAppsEnvironment
  name: 'secretstore'
  properties: {
    componentType: 'secretstores.azure.keyvault'
    version: 'v1'
    ignoreErrors: false
    initTimeout: '5m'
    metadata: [
      {
        name: 'vaultName'
        value: '{keyvault-name}'
      }
      {
        name: 'azureClientId'
        value: '{managed-identity-client-id}'
      }
    ]
    scopes: []
  }
}

// ============================================================================
// Resources - Sample Container App
// ============================================================================

@description('Sample Container App with Dapr sidecar')
resource sampleApp 'Microsoft.App/containerApps@2023-11-02-preview' = if (deploySampleApp) {
  name: 'ca-sample-api'
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    managedEnvironmentId: containerAppsEnvironment.id
    workloadProfileName: enableWorkloadProfiles ? 'Consumption' : null
    configuration: {
      activeRevisionsMode: 'Multiple'
      dapr: enableDapr ? {
        enabled: true
        appId: 'sample-api'
        appPort: 8080
        appProtocol: 'http'
        enableApiLogging: true
        logLevel: 'info'
      } : null
      ingress: {
        external: true
        targetPort: 8080
        transport: 'auto'
        allowInsecure: false
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
        corsPolicy: {
          allowedOrigins: [
            '*'
          ]
          allowedMethods: [
            'GET'
            'POST'
            'PUT'
            'DELETE'
            'OPTIONS'
          ]
          allowedHeaders: [
            '*'
          ]
          maxAge: 86400
        }
      }
      maxInactiveRevisions: 10
      registries: []
      secrets: []
    }
    template: {
      containers: [
        {
          name: 'main'
          image: 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: [
            {
              name: 'ASPNETCORE_ENVIRONMENT'
              value: 'Production'
            }
          ]
          probes: [
            {
              type: 'Liveness'
              httpGet: {
                path: '/health/live'
                port: 8080
                scheme: 'HTTP'
              }
              initialDelaySeconds: 10
              periodSeconds: 10
              failureThreshold: 3
            }
            {
              type: 'Readiness'
              httpGet: {
                path: '/health/ready'
                port: 8080
                scheme: 'HTTP'
              }
              initialDelaySeconds: 5
              periodSeconds: 5
              failureThreshold: 3
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 10
        rules: [
          {
            name: 'http-scaling'
            http: {
              metadata: {
                concurrentRequests: '100'
              }
            }
          }
        ]
      }
    }
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('Container Apps environment ID')
output environmentId string = containerAppsEnvironment.id

@description('Container Apps environment name')
output environmentName string = containerAppsEnvironment.name

@description('Container Apps environment default domain')
output defaultDomain string = containerAppsEnvironment.properties.defaultDomain

@description('Container Apps environment static IP')
output staticIp string = containerAppsEnvironment.properties.staticIp

@description('Is internal only')
output isInternalOnly bool = isInternalOnly

@description('Zone redundancy enabled')
output zoneRedundant bool = zoneRedundant

@description('Dapr enabled')
output daprEnabled bool = enableDapr

@description('Workload profiles enabled')
output workloadProfilesEnabled bool = enableWorkloadProfiles

@description('Sample app FQDN')
output sampleAppFqdn string = deploySampleApp ? sampleApp.properties.configuration.ingress.fqdn : ''

@description('Sample app URL')
output sampleAppUrl string = deploySampleApp ? 'https://${sampleApp.properties.configuration.ingress.fqdn}' : ''
