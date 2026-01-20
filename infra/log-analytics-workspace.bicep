// ============================================================================
// Log Analytics Workspace with Diagnostic Settings
// ============================================================================
// Purpose: Centralized Log Analytics workspace for monitoring and diagnostics
// AZ-305 Exam Objectives:
//   - Design a solution for logging and monitoring (Objective 1.3)
//   - Design authentication and authorization solutions (Objective 1.1)
// Prerequisites:
//   - Resource group must exist
//   - Appropriate RBAC permissions (Contributor or Log Analytics Contributor)
// ============================================================================

targetScope = 'resourceGroup'

// ============================================================================
// Parameters
// ============================================================================

@description('Name of the Log Analytics workspace. Must be unique within the resource group.')
@minLength(4)
@maxLength(63)
param workspaceName string

@description('Azure region for the workspace. Defaults to the resource group location.')
param location string = resourceGroup().location

@description('SKU for the Log Analytics workspace.')
@allowed([
  'PerGB2018'
  'Free'
  'Standalone'
  'PerNode'
  'Standard'
  'Premium'
])
param sku string = 'PerGB2018'

@description('Data retention period in days. Range: 30-730 days.')
@minValue(30)
@maxValue(730)
param retentionInDays int = 30

@description('Daily quota for data ingestion in GB. -1 means unlimited.')
param dailyQuotaGb int = -1

@description('Enable public network access for ingestion.')
param publicNetworkAccessForIngestion string = 'Enabled'

@description('Enable public network access for query.')
param publicNetworkAccessForQuery string = 'Enabled'

@description('Tags to apply to all resources.')
param tags object = {
  environment: 'production'
  purpose: 'monitoring'
  examObjective: 'AZ-305-LoggingMonitoring'
}

// ============================================================================
// Variables
// ============================================================================

var workspaceResourceName = 'log-${workspaceName}'

// ============================================================================
// Resources
// ============================================================================

@description('Log Analytics Workspace - Central monitoring hub for Azure resources')
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: workspaceResourceName
  location: location
  tags: tags
  properties: {
    sku: {
      name: sku
    }
    retentionInDays: retentionInDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
      immediatePurgeDataOn30Days: false
    }
    workspaceCapping: {
      dailyQuotaGb: dailyQuotaGb
    }
    publicNetworkAccessForIngestion: publicNetworkAccessForIngestion
    publicNetworkAccessForQuery: publicNetworkAccessForQuery
  }
}

@description('Security-related solution for the workspace')
resource securitySolution 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  name: 'Security(${logAnalyticsWorkspace.name})'
  location: location
  tags: tags
  properties: {
    workspaceResourceId: logAnalyticsWorkspace.id
  }
  plan: {
    name: 'Security(${logAnalyticsWorkspace.name})'
    publisher: 'Microsoft'
    product: 'OMSGallery/Security'
    promotionCode: ''
  }
}

@description('Container Insights solution for AKS monitoring')
resource containerInsightsSolution 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  name: 'ContainerInsights(${logAnalyticsWorkspace.name})'
  location: location
  tags: tags
  properties: {
    workspaceResourceId: logAnalyticsWorkspace.id
  }
  plan: {
    name: 'ContainerInsights(${logAnalyticsWorkspace.name})'
    publisher: 'Microsoft'
    product: 'OMSGallery/ContainerInsights'
    promotionCode: ''
  }
}

@description('VM Insights solution for virtual machine monitoring')
resource vmInsightsSolution 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  name: 'VMInsights(${logAnalyticsWorkspace.name})'
  location: location
  tags: tags
  properties: {
    workspaceResourceId: logAnalyticsWorkspace.id
  }
  plan: {
    name: 'VMInsights(${logAnalyticsWorkspace.name})'
    publisher: 'Microsoft'
    product: 'OMSGallery/VMInsights'
    promotionCode: ''
  }
}

@description('Saved search for failed sign-ins (example query)')
resource savedSearchFailedSignIns 'Microsoft.OperationalInsights/workspaces/savedSearches@2020-08-01' = {
  parent: logAnalyticsWorkspace
  name: 'FailedSignIns'
  properties: {
    displayName: 'Failed Sign-in Attempts'
    category: 'Security'
    query: '''
      SigninLogs
      | where ResultType != 0
      | summarize FailedAttempts = count() by UserPrincipalName, IPAddress, ResultDescription
      | order by FailedAttempts desc
    '''
  }
}

@description('Saved search for resource health events')
resource savedSearchResourceHealth 'Microsoft.OperationalInsights/workspaces/savedSearches@2020-08-01' = {
  parent: logAnalyticsWorkspace
  name: 'ResourceHealthEvents'
  properties: {
    displayName: 'Resource Health Events'
    category: 'Operations'
    query: '''
      AzureActivity
      | where CategoryValue == "ResourceHealth"
      | summarize count() by ResourceGroup, Resource, ActivityStatusValue
      | order by count_ desc
    '''
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('Resource ID of the Log Analytics workspace')
output workspaceId string = logAnalyticsWorkspace.id

@description('Name of the Log Analytics workspace')
output workspaceName string = logAnalyticsWorkspace.name

@description('Customer ID (Workspace ID) for agent configuration')
output workspaceCustomerId string = logAnalyticsWorkspace.properties.customerId

@description('Primary shared key for agent configuration (use Key Vault in production)')
output workspacePrimaryKey string = logAnalyticsWorkspace.listKeys().primarySharedKey

@description('Resource ID for use in diagnostic settings')
output diagnosticSettingsDestinationId string = logAnalyticsWorkspace.id
