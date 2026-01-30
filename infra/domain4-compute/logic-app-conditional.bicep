// ============================================================================
// Logic App (Consumption) - Conditional Logic, Branching, Loops & M365
// ============================================================================
//
// AZ-305 EXAM RELEVANCE:
//   Domain 4 - Design Infrastructure Solutions (30-35% of exam)
//   Objective: Design a compute solution - recommend a solution for compute
//   Sub-topic: Logic Apps vs Azure Functions decision framework
//
// WHY LOGIC APPS vs AZURE FUNCTIONS FOR THIS PATTERN:
//   Logic Apps (Consumption) is the right choice when you need:
//     - Visual workflow orchestration with branching/conditions
//     - Built-in connectors to M365, Dynamics 365, SAP, Salesforce (400+)
//     - No-code/low-code implementation for business process automation
//     - Per-execution pricing (pay only when workflows run)
//     - Built-in retry policies, error handling scopes, and run history
//
//   Azure Functions would be better when you need:
//     - Custom code execution with full language support (C#, Python, JS, etc.)
//     - Sub-second execution with minimal cold start (Flex Consumption)
//     - Fine-grained control over dependencies and libraries
//     - Complex data transformations or algorithmic processing
//     - Unit-testable business logic
//
//   KEY EXAM TIP: Logic Apps Consumption is serverless and billed per action
//   execution. Logic Apps Standard runs on App Service and supports stateful
//   and stateless workflows with VNET integration. Know the difference.
//
// HOW CONDITIONAL LOGIC WORKS IN LOGIC APPS (Workflow Definition Language):
//   The workflow definition uses a JSON schema defined at:
//   https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#
//
//   Key concepts demonstrated in this template:
//   1. TRIGGERS: Define how the workflow starts (HTTP, recurrence, event-based)
//   2. ACTIONS: Individual steps that execute sequentially or in parallel
//   3. CONDITIONS: Use "If" type with expression evaluation (@equals, @greater, etc.)
//   4. SWITCH: Route to different branches based on a value (like switch/case)
//   5. FOR EACH: Iterate over arrays with @body or @triggerBody references
//   6. SCOPE: Group actions for collective error handling (try/catch pattern)
//   7. runAfter: Controls execution order and handles failure states
//
// HOW M365 CONNECTORS AUTHENTICATE (OAuth Consent Flow):
//   Office 365 Outlook and Microsoft Teams connectors use OAuth 2.0:
//   1. Deploy creates a Microsoft.Web/connections resource (API Connection)
//   2. The API Connection references the managed API (e.g., 'office365', 'teams')
//   3. After deployment, a user must MANUALLY authorize the connection in the
//      Azure Portal by clicking "Edit API connection" and signing in with
//      their M365 account (OAuth consent grant)
//   4. The connection stores the OAuth token securely in Azure
//   5. The Logic App references the connection via $connections parameter
//
//   IMPORTANT: Bicep/ARM can create the connection resource, but cannot
//   complete the OAuth consent flow. This is a manual post-deployment step.
//   For automated deployments, consider using managed identity with
//   Microsoft Graph API instead of OAuth-based connectors.
//
// REFERENCE:
//   https://learn.microsoft.com/azure/logic-apps/quickstart-create-deploy-bicep
//   https://learn.microsoft.com/azure/logic-apps/logic-apps-azure-resource-manager-templates-overview
//   https://learn.microsoft.com/azure/logic-apps/logic-apps-workflow-definition-language
// ============================================================================

// ============================================================================
// Parameters
// ============================================================================

@description('Name of the Logic App. Follow Azure naming conventions: logic-<workload>-<env>-<region>')
@minLength(3)
@maxLength(80)
param logicAppName string

@description('Azure region for all resources. Defaults to the resource group location.')
param location string = resourceGroup().location

@description('Environment identifier used for tagging and naming conventions.')
@allowed([
  'dev'
  'test'
  'prod'
])
param environment string = 'dev'

@description('Microsoft Entra ID tenant ID for M365 connector authentication.')
param tenantId string = subscription().tenantId

@description('Log Analytics workspace resource ID for diagnostic settings. Leave empty to skip diagnostics.')
param logAnalyticsWorkspaceId string = ''

@description('Finance team email address for budget request routing.')
param financeTeamEmail string = 'finance@contoso.com'

@description('IT Security team email address for access request routing.')
param itSecurityEmail string = 'itsecurity@contoso.com'

@description('Helpdesk email address for general request routing.')
param helpdeskEmail string = 'helpdesk@contoso.com'

@description('Error notification email address for failed workflow runs.')
param errorNotificationEmail string = 'ops-alerts@contoso.com'

@description('Microsoft Teams channel ID for high-priority notifications.')
param teamsChannelId string = ''

@description('Microsoft Teams team ID for high-priority notifications.')
param teamsTeamId string = ''

@description('Budget threshold amount above which approval is required.')
param budgetApprovalThreshold int = 5000

@description('Tags to apply to all resources for governance and cost tracking.')
param tags object = {}

// ============================================================================
// Variables
// ============================================================================

// Workflow Definition Language schema - this is the contract for all Logic App
// workflow definitions. AZ-305 TIP: This schema version has been stable since
// 2016-06-01 and is used for both Consumption and Standard (with extensions).
var workflowSchema = 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'

// API Connection names follow the pattern: conn-<connector>-<logicapp>
var office365ConnectionName = 'conn-office365-${logicAppName}'
var teamsConnectionName = 'conn-teams-${logicAppName}'

// Managed API references - these point to the Microsoft-managed connector
// implementations hosted in each Azure region. The connector infrastructure
// is shared across all Logic Apps in that region.
var office365ApiId = subscriptionResourceId(
  'Microsoft.Web/locations/managedApis',
  location,
  'office365'
)
var teamsApiId = subscriptionResourceId(
  'Microsoft.Web/locations/managedApis',
  location,
  'teams'
)

// Standard tags merged with user-provided tags
var defaultTags = {
  environment: environment
  application: 'az305-logic-app-demo'
  'exam-domain': 'domain4-compute'
  'iac-tool': 'bicep'
  'cost-center': 'training'
}
var allTags = union(defaultTags, tags)

// ============================================================================
// API Connection Resources
// ============================================================================
// AZ-305 EXAM TIP: API Connections (Microsoft.Web/connections) are separate
// Azure resources from the Logic App itself. They:
//   - Have their own lifecycle and can be shared across Logic Apps
//   - Store authentication credentials (OAuth tokens, API keys)
//   - Must exist in the same resource group and region as the Logic App
//   - Require manual OAuth consent after deployment for M365 connectors

@description('Office 365 Outlook API Connection for sending emails. Requires post-deployment OAuth consent.')
resource office365Connection 'Microsoft.Web/connections@2016-06-01' = {
  name: office365ConnectionName
  location: location
  tags: allTags
  properties: {
    displayName: 'Office 365 Outlook - ${logicAppName}'
    api: {
      id: office365ApiId
      displayName: 'Office 365 Outlook'
      description: 'Microsoft Office 365 email connector for sending notifications'
      // AZ-305 NOTE: The 'type' field identifies this as a managed (shared)
      // connector vs. a custom connector. Managed connectors are maintained
      // by Microsoft and include SLA guarantees.
    }
    // parameterValues would contain credentials, but for OAuth connectors
    // the user must complete the consent flow in the Azure Portal after
    // deployment. This is by design for security - secrets are never stored
    // in Bicep templates or parameter files.
  }
}

@description('Microsoft Teams API Connection for posting channel messages. Requires post-deployment OAuth consent.')
resource teamsConnection 'Microsoft.Web/connections@2016-06-01' = {
  name: teamsConnectionName
  location: location
  tags: allTags
  properties: {
    displayName: 'Microsoft Teams - ${logicAppName}'
    api: {
      id: teamsApiId
      displayName: 'Microsoft Teams'
      description: 'Microsoft Teams connector for posting high-priority notifications'
    }
  }
}

// ============================================================================
// Logic App Resource (Consumption Tier)
// ============================================================================
// AZ-305 EXAM TIP: Consumption Logic Apps:
//   - Resource type: Microsoft.Logic/workflows
//   - Pricing: Per-action execution (triggers, actions, connectors)
//   - Scale: Automatic, no infrastructure to manage
//   - Networking: Public endpoint only (no VNET integration)
//   - Multi-tenant: Runs in shared Azure infrastructure
//
// For VNET integration, Private Endpoints, or dedicated compute, use
// Logic Apps Standard (Microsoft.Web/sites with kind 'workflowapp').

@description('Consumption Logic App with conditional routing, branching, loops, and M365 integration.')
resource logicApp 'Microsoft.Logic/workflows@2019-05-01' = {
  name: logicAppName
  location: location
  tags: allTags

  // AZ-305 EXAM TIP: System-assigned managed identity enables the Logic App
  // to authenticate to Azure services (Key Vault, Storage, SQL) without
  // storing credentials. This is a Zero Trust best practice.
  // Note: Managed identity does NOT replace OAuth consent for M365 connectors.
  // M365 connectors authenticate as a USER, not as the application identity.
  identity: {
    type: 'SystemAssigned'
  }

  properties: {
    state: 'Enabled'

    // ========================================================================
    // Workflow Definition Parameter Values
    // ========================================================================
    // These pass Bicep parameter values INTO the workflow definition at runtime.
    // AZ-305 TIP: There are TWO levels of parameters:
    //   1. Bicep/ARM template parameters (evaluated at DEPLOYMENT time)
    //   2. Workflow definition parameters (evaluated at RUNTIME)
    // You bridge them here in this 'parameters' block.
    parameters: {
      '$connections': {
        value: {
          office365: {
            connectionId: office365Connection.id
            connectionName: office365Connection.name
            id: office365ApiId
          }
          teams: {
            connectionId: teamsConnection.id
            connectionName: teamsConnection.name
            id: teamsApiId
          }
        }
      }
      financeTeamEmail: {
        value: financeTeamEmail
      }
      itSecurityEmail: {
        value: itSecurityEmail
      }
      helpdeskEmail: {
        value: helpdeskEmail
      }
      errorNotificationEmail: {
        value: errorNotificationEmail
      }
      teamsChannelId: {
        value: teamsChannelId
      }
      teamsTeamId: {
        value: teamsTeamId
      }
      budgetApprovalThreshold: {
        value: budgetApprovalThreshold
      }
    }

    // ========================================================================
    // Workflow Definition (Inline)
    // ========================================================================
    // This is the actual workflow logic expressed in Workflow Definition Language.
    // It is equivalent to what you see in the Logic App Designer's Code View.
    definition: {
      '$schema': workflowSchema
      contentVersion: '1.0.0.0'

      // ======================================================================
      // Workflow Definition Parameters
      // ======================================================================
      // These are declared here and receive values from the 'parameters' block
      // above (outside the definition). Use @parameters('name') to reference.
      parameters: {
        '$connections': {
          defaultValue: {}
          type: 'Object'
        }
        financeTeamEmail: {
          defaultValue: ''
          type: 'String'
        }
        itSecurityEmail: {
          defaultValue: ''
          type: 'String'
        }
        helpdeskEmail: {
          defaultValue: ''
          type: 'String'
        }
        errorNotificationEmail: {
          defaultValue: ''
          type: 'String'
        }
        teamsChannelId: {
          defaultValue: ''
          type: 'String'
        }
        teamsTeamId: {
          defaultValue: ''
          type: 'String'
        }
        budgetApprovalThreshold: {
          defaultValue: 5000
          type: 'Int'
        }
      }

      // ======================================================================
      // TRIGGER: HTTP Request (Webhook Pattern)
      // ======================================================================
      // AZ-305 EXAM TIP: The Request trigger creates an HTTPS endpoint that
      // external systems can call. The URL is generated after deployment and
      // includes a SAS token for authentication. This is the webhook pattern.
      //
      // Alternative triggers to know for the exam:
      //   - Recurrence: Time-based scheduling
      //   - Event Grid: React to Azure resource events
      //   - Service Bus: Message queue processing
      //   - Blob Storage: React to file uploads
      triggers: {
        'When_an_HTTP_request_is_received': {
          type: 'Request'
          kind: 'Http'
          inputs: {
            schema: {
              type: 'object'
              properties: {
                requestType: {
                  type: 'string'
                  description: 'Type of request: budget, access, or general'
                }
                priority: {
                  type: 'string'
                  description: 'Priority level: high, medium, or low'
                }
                department: {
                  type: 'string'
                  description: 'Requesting department name'
                }
                description: {
                  type: 'string'
                  description: 'Detailed description of the request'
                }
                amount: {
                  type: 'number'
                  description: 'Budget amount (applicable for budget requests)'
                }
                requestedBy: {
                  type: 'string'
                  description: 'Email of the person making the request'
                }
                attachments: {
                  type: 'array'
                  items: {
                    type: 'object'
                    properties: {
                      fileName: {
                        type: 'string'
                      }
                      fileSize: {
                        type: 'integer'
                      }
                      contentType: {
                        type: 'string'
                      }
                    }
                  }
                  description: 'Array of attachment metadata objects'
                }
              }
              required: [
                'requestType'
                'priority'
                'department'
                'description'
              ]
            }
            method: 'POST'
          }
        }
      }

      // ======================================================================
      // ACTIONS
      // ======================================================================
      // Actions execute in order determined by 'runAfter' dependencies.
      // If runAfter is empty {}, the action runs immediately after the trigger.
      //
      // AZ-305 EXAM TIP: Understanding runAfter is critical:
      //   {} = runs after trigger
      //   { "ActionName": ["Succeeded"] } = runs after ActionName succeeds
      //   { "ActionName": ["Failed"] } = runs after ActionName FAILS (error handling)
      //   { "ActionName": ["Succeeded","Failed","Skipped","TimedOut"] } = always runs
      actions: {

        // ====================================================================
        // STEP 1: Initialize Variables
        // ====================================================================
        // AZ-305 TIP: Variables in Logic Apps are mutable (unlike best practices
        // in code). They are initialized once and can be updated with Set Variable.
        // Variables are scoped to the entire workflow run, not to individual scopes.

        'Initialize_approvalRequired': {
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'approvalRequired'
                type: 'boolean'
                value: false
              }
            ]
          }
          runAfter: {}
        }

        'Initialize_routingEmail': {
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'routingEmail'
                type: 'string'
                value: ''
              }
            ]
          }
          runAfter: {
            'Initialize_approvalRequired': [
              'Succeeded'
            ]
          }
        }

        'Initialize_responseMessage': {
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'responseMessage'
                type: 'string'
                value: ''
              }
            ]
          }
          runAfter: {
            'Initialize_routingEmail': [
              'Succeeded'
            ]
          }
        }

        'Initialize_slaDeadline': {
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'slaDeadline'
                type: 'string'
                value: ''
              }
            ]
          }
          runAfter: {
            'Initialize_responseMessage': [
              'Succeeded'
            ]
          }
        }

        // ====================================================================
        // STEP 2: Main Processing Scope (Try Block)
        // ====================================================================
        // AZ-305 EXAM TIP: Scopes group actions together for:
        //   1. Collective error handling (like try/catch in code)
        //   2. Organizational clarity in the designer
        //   3. Conditional execution of action groups
        //
        // A Scope's status is determined by its child actions:
        //   - Succeeded: All children succeeded or were skipped
        //   - Failed: Any child action failed
        //   - Cancelled: Workflow was cancelled during scope execution
        'Scope_Main_Processing': {
          type: 'Scope'
          runAfter: {
            'Initialize_slaDeadline': [
              'Succeeded'
            ]
          }
          actions: {

            // ================================================================
            // STEP 2a: Switch on requestType
            // ================================================================
            // AZ-305 EXAM TIP: Switch is more efficient than nested conditions
            // when you have multiple discrete values to evaluate. Each case
            // branch runs independently. The Default case handles unexpected
            // values (defensive programming in workflows).
            //
            // HOW SWITCH WORKS IN THE JSON:
            //   - 'expression' evaluates a value (here: triggerBody requestType)
            //   - 'cases' contains named branches, each with a 'case' value
            //   - 'default' runs when no case matches
            //   - Only ONE branch executes per run
            'Switch_on_requestType': {
              type: 'Switch'
              expression: '@triggerBody()?[\'requestType\']'
              cases: {

                // CASE: Budget Request
                // Route to finance, conditionally require approval based on amount
                'Case_Budget': {
                  case: 'budget'
                  actions: {
                    'Set_routingEmail_Finance': {
                      type: 'SetVariable'
                      inputs: {
                        name: 'routingEmail'
                        value: '@parameters(\'financeTeamEmail\')'
                      }
                    }

                    // CONDITION: Check if budget amount exceeds threshold
                    // AZ-305 EXAM TIP: Conditions use @greater, @less, @equals,
                    // @and, @or expressions. The 'expression' must evaluate to
                    // true/false. Actions go in 'ifTrue' or 'ifFalse' branches.
                    'Condition_Budget_Threshold': {
                      type: 'If'
                      expression: {
                        and: [
                          {
                            greater: [
                              '@triggerBody()?[\'amount\']'
                              '@parameters(\'budgetApprovalThreshold\')'
                            ]
                          }
                        ]
                      }
                      actions: {
                        // ifTrue: Amount exceeds threshold, require approval
                        'Set_approvalRequired_True_Budget': {
                          type: 'SetVariable'
                          inputs: {
                            name: 'approvalRequired'
                            value: true
                          }
                        }
                        'Set_responseMessage_Budget_Approval': {
                          type: 'SetVariable'
                          inputs: {
                            name: 'responseMessage'
                            // String interpolation in Workflow Definition Language
                            // uses @{expression} syntax inside string literals
                            value: 'Budget request for @{triggerBody()?[\'amount\']} routed to Finance. Approval required (exceeds threshold).'
                          }
                          runAfter: {
                            'Set_approvalRequired_True_Budget': [
                              'Succeeded'
                            ]
                          }
                        }
                      }
                      'else': {
                        actions: {
                          // ifFalse: Amount within threshold, no approval needed
                          'Set_responseMessage_Budget_NoApproval': {
                            type: 'SetVariable'
                            inputs: {
                              name: 'responseMessage'
                              value: 'Budget request for @{triggerBody()?[\'amount\']} routed to Finance. No approval required.'
                            }
                          }
                        }
                      }
                      runAfter: {
                        'Set_routingEmail_Finance': [
                          'Succeeded'
                        ]
                      }
                    }
                  }
                }

                // CASE: Access Request
                // Route to IT Security, always require approval
                'Case_Access': {
                  case: 'access'
                  actions: {
                    'Set_routingEmail_ITSecurity': {
                      type: 'SetVariable'
                      inputs: {
                        name: 'routingEmail'
                        value: '@parameters(\'itSecurityEmail\')'
                      }
                    }
                    'Set_approvalRequired_True_Access': {
                      type: 'SetVariable'
                      inputs: {
                        name: 'approvalRequired'
                        value: true
                      }
                      runAfter: {
                        'Set_routingEmail_ITSecurity': [
                          'Succeeded'
                        ]
                      }
                    }
                    'Set_responseMessage_Access': {
                      type: 'SetVariable'
                      inputs: {
                        name: 'responseMessage'
                        value: 'Access request routed to IT Security. Approval is always required for access requests.'
                      }
                      runAfter: {
                        'Set_approvalRequired_True_Access': [
                          'Succeeded'
                        ]
                      }
                    }
                  }
                }

                // CASE: General Request
                // Route to helpdesk, no approval needed
                'Case_General': {
                  case: 'general'
                  actions: {
                    'Set_routingEmail_Helpdesk': {
                      type: 'SetVariable'
                      inputs: {
                        name: 'routingEmail'
                        value: '@parameters(\'helpdeskEmail\')'
                      }
                    }
                    'Set_responseMessage_General': {
                      type: 'SetVariable'
                      inputs: {
                        name: 'responseMessage'
                        value: 'General request routed to Helpdesk. No approval required.'
                      }
                      runAfter: {
                        'Set_routingEmail_Helpdesk': [
                          'Succeeded'
                        ]
                      }
                    }
                  }
                }
              }

              // DEFAULT: Unknown request type
              default: {
                actions: {
                  'Set_routingEmail_Error': {
                    type: 'SetVariable'
                    inputs: {
                      name: 'routingEmail'
                      value: '@parameters(\'errorNotificationEmail\')'
                    }
                  }
                  'Set_responseMessage_Error': {
                    type: 'SetVariable'
                    inputs: {
                      name: 'responseMessage'
                      value: 'Unknown request type: @{triggerBody()?[\'requestType\']}. Routed to operations for review.'
                    }
                    runAfter: {
                      'Set_routingEmail_Error': [
                        'Succeeded'
                      ]
                    }
                  }
                }
              }

              runAfter: {}
            }

            // ================================================================
            // STEP 2b: Conditional Branch - Priority Check
            // ================================================================
            // AZ-305 EXAM TIP: This demonstrates parallel branching after a
            // common action. Both the priority check and the send email action
            // depend on the Switch completing, but are independent of each other
            // in certain scenarios. Here we chain them for SLA tracking.
            'Condition_High_Priority': {
              type: 'If'
              expression: {
                and: [
                  {
                    equals: [
                      '@triggerBody()?[\'priority\']'
                      'high'
                    ]
                  }
                ]
              }
              actions: {
                // ifTrue: High priority - send Teams notification, set short SLA
                'Set_slaDeadline_Short': {
                  type: 'SetVariable'
                  inputs: {
                    name: 'slaDeadline'
                    // addHours adds hours to the current UTC timestamp
                    value: '@{addHours(utcNow(), 4)}'
                  }
                }

                // Post to Microsoft Teams channel
                // AZ-305 EXAM TIP: This action uses the Microsoft Teams
                // managed connector (ApiConnection type). The connection
                // reference uses the $connections parameter pattern.
                'Post_Teams_Notification': {
                  type: 'ApiConnection'
                  inputs: {
                    host: {
                      connection: {
                        name: '@parameters(\'$connections\')[\'teams\'][\'connectionId\']'
                      }
                    }
                    method: 'post'
                    path: '/v3/beta/teams/@{encodeURIComponent(parameters(\'teamsTeamId\'))}/channels/@{encodeURIComponent(parameters(\'teamsChannelId\'))}/messages'
                    body: {
                      body: {
                        content: '<h3>HIGH PRIORITY Request</h3><p><strong>Type:</strong> @{triggerBody()?[\'requestType\']}</p><p><strong>Department:</strong> @{triggerBody()?[\'department\']}</p><p><strong>Description:</strong> @{triggerBody()?[\'description\']}</p><p><strong>SLA Deadline:</strong> @{variables(\'slaDeadline\')}</p><p><strong>Approval Required:</strong> @{variables(\'approvalRequired\')}</p>'
                        contentType: 'html'
                      }
                    }
                  }
                  runAfter: {
                    'Set_slaDeadline_Short': [
                      'Succeeded'
                    ]
                  }
                }
              }
              'else': {
                actions: {
                  // ifFalse: Normal priority - standard SLA
                  'Set_slaDeadline_Standard': {
                    type: 'SetVariable'
                    inputs: {
                      name: 'slaDeadline'
                      value: '@{addHours(utcNow(), 24)}'
                    }
                  }
                }
              }
              runAfter: {
                'Switch_on_requestType': [
                  'Succeeded'
                ]
              }
            }

            // ================================================================
            // STEP 2c: For Each Loop - Process Attachments
            // ================================================================
            // AZ-305 EXAM TIP: For_Each loops in Logic Apps:
            //   - Iterate over arrays from trigger body or previous actions
            //   - Can run sequentially or in parallel (concurrency control)
            //   - Use @items('For_Each_name') to reference current item
            //   - Have a default concurrency of 20 parallel iterations
            //   - Can be nested (but be careful of execution limits)
            //
            // The 'runtimeConfiguration' below sets sequential processing.
            // For high-throughput scenarios, remove this to enable parallelism.
            'For_Each_Attachment': {
              type: 'Foreach'
              foreach: '@triggerBody()?[\'attachments\']'
              actions: {
                // Compose action creates a structured log entry for each attachment
                // AZ-305 TIP: Compose is useful for data transformation and
                // creating structured objects without external service calls.
                'Compose_Attachment_Log': {
                  type: 'Compose'
                  inputs: {
                    timestamp: '@utcNow()'
                    requestType: '@triggerBody()?[\'requestType\']'
                    department: '@triggerBody()?[\'department\']'
                    fileName: '@items(\'For_Each_Attachment\')?[\'fileName\']'
                    fileSize: '@items(\'For_Each_Attachment\')?[\'fileSize\']'
                    contentType: '@items(\'For_Each_Attachment\')?[\'contentType\']'
                    workflowRunId: '@workflow().run.name'
                  }
                }
              }
              runAfter: {
                'Condition_High_Priority': [
                  'Succeeded'
                  'Skipped'
                ]
              }
              runtimeConfiguration: {
                concurrency: {
                  // Sequential processing - set to higher number for parallelism
                  repetitions: 1
                }
              }
            }

            // ================================================================
            // STEP 2d: Send Email Notification
            // ================================================================
            // AZ-305 EXAM TIP: Office 365 Outlook connector actions:
            //   - Send an email (V2): Basic email sending
            //   - Send an email with options: Includes voting buttons
            //   - Send an approval email: Built-in approval workflow
            //   - Shared Mailbox operations: Send from shared mailboxes
            //
            // The connector authenticates as the USER who consented during
            // the OAuth flow, not as the Logic App's managed identity.
            'Send_Routing_Email': {
              type: 'ApiConnection'
              inputs: {
                host: {
                  connection: {
                    name: '@parameters(\'$connections\')[\'office365\'][\'connectionId\']'
                  }
                }
                method: 'post'
                path: '/v2/Mail'
                body: {
                  To: '@variables(\'routingEmail\')'
                  Subject: '[@{triggerBody()?[\'priority\']}] @{triggerBody()?[\'requestType\']} request from @{triggerBody()?[\'department\']}'
                  Body: '<h2>New @{triggerBody()?[\'requestType\']} Request</h2><table border="1" cellpadding="8"><tr><td><strong>Department</strong></td><td>@{triggerBody()?[\'department\']}</td></tr><tr><td><strong>Priority</strong></td><td>@{triggerBody()?[\'priority\']}</td></tr><tr><td><strong>Description</strong></td><td>@{triggerBody()?[\'description\']}</td></tr><tr><td><strong>Approval Required</strong></td><td>@{variables(\'approvalRequired\')}</td></tr><tr><td><strong>SLA Deadline</strong></td><td>@{variables(\'slaDeadline\')}</td></tr><tr><td><strong>Requested By</strong></td><td>@{triggerBody()?[\'requestedBy\']}</td></tr></table>'
                  Importance: '@{if(equals(triggerBody()?[\'priority\'], \'high\'), \'High\', \'Normal\')}'
                  IsHtml: true
                }
              }
              runAfter: {
                'For_Each_Attachment': [
                  'Succeeded'
                  'Skipped'
                ]
              }
            }
          }
        }

        // ====================================================================
        // STEP 3: Error Handling Scope (Catch Block)
        // ====================================================================
        // AZ-305 EXAM TIP: Error handling in Logic Apps uses the runAfter
        // pattern with 'Failed' status. This is the equivalent of a catch
        // block in code. The scope runs ONLY when the main processing scope
        // fails. This pattern is critical for production-grade workflows.
        //
        // Best practices for error handling:
        //   1. Always wrap main logic in a Scope
        //   2. Add a parallel error-handling Scope with runAfter: Failed
        //   3. Send notifications for failures (email, Teams, PagerDuty)
        //   4. Include run details for troubleshooting (workflow().run.name)
        //   5. Consider retry policies on individual actions
        'Scope_Error_Handling': {
          type: 'Scope'
          runAfter: {
            'Scope_Main_Processing': [
              'Failed'
              'TimedOut'
            ]
          }
          actions: {
            'Send_Error_Notification': {
              type: 'ApiConnection'
              inputs: {
                host: {
                  connection: {
                    name: '@parameters(\'$connections\')[\'office365\'][\'connectionId\']'
                  }
                }
                method: 'post'
                path: '/v2/Mail'
                body: {
                  To: '@parameters(\'errorNotificationEmail\')'
                  Subject: 'WORKFLOW FAILURE: Request routing logic app'
                  Body: '<h2>Workflow Execution Failed</h2><p><strong>Workflow Run ID:</strong> @{workflow().run.name}</p><p><strong>Timestamp:</strong> @{utcNow()}</p><p><strong>Request Type:</strong> @{triggerBody()?[\'requestType\']}</p><p><strong>Department:</strong> @{triggerBody()?[\'department\']}</p><p>Please investigate in the Azure Portal under Logic App run history.</p>'
                  Importance: 'High'
                  IsHtml: true
                }
              }
              runAfter: {}
            }
          }
        }

        // ====================================================================
        // STEP 4: Success Response
        // ====================================================================
        // Returns HTTP 200 with routing details when processing succeeds.
        // AZ-305 EXAM TIP: The Response action is only available when the
        // trigger is an HTTP Request trigger. It sets the HTTP status code,
        // headers, and body returned to the caller.
        'Response_Success': {
          type: 'Response'
          kind: 'Http'
          inputs: {
            statusCode: 200
            headers: {
              'Content-Type': 'application/json'
            }
            body: {
              status: 'accepted'
              message: '@variables(\'responseMessage\')'
              routedTo: '@variables(\'routingEmail\')'
              approvalRequired: '@variables(\'approvalRequired\')'
              slaDeadline: '@variables(\'slaDeadline\')'
              workflowRunId: '@workflow().run.name'
              timestamp: '@utcNow()'
            }
          }
          runAfter: {
            'Scope_Main_Processing': [
              'Succeeded'
            ]
          }
        }

        // ====================================================================
        // STEP 5: Failure Response
        // ====================================================================
        // Returns HTTP 500 when processing fails.
        'Response_Failure': {
          type: 'Response'
          kind: 'Http'
          inputs: {
            statusCode: 500
            headers: {
              'Content-Type': 'application/json'
            }
            body: {
              status: 'failed'
              message: 'Request processing failed. The operations team has been notified.'
              workflowRunId: '@workflow().run.name'
              timestamp: '@utcNow()'
            }
          }
          runAfter: {
            'Scope_Error_Handling': [
              'Succeeded'
              'Failed'
            ]
          }
        }
      }

      // No outputs defined for this workflow
      outputs: {}
    }
  }

  // The Logic App depends on both API connections existing first
  dependsOn: [
    office365Connection
    teamsConnection
  ]
}

// ============================================================================
// Diagnostic Settings
// ============================================================================
// AZ-305 EXAM TIP: Diagnostic settings are essential for Operational Excellence.
// Logic Apps emit:
//   - WorkflowRuntime: Trigger/action execution events, durations, status
//   - IntegrationAccountTrackingEvents: B2B integration events (if applicable)
//
// Send to Log Analytics for KQL querying, alerting, and dashboarding.
// Also consider sending to a Storage Account for long-term retention
// and/or Event Hubs for SIEM integration.

@description('Diagnostic settings for Logic App monitoring. Sends workflow runtime logs and metrics to Log Analytics.')
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  name: 'diag-${logicAppName}'
  scope: logicApp
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'WorkflowRuntime'
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

@description('Resource ID of the deployed Logic App.')
output logicAppId string = logicApp.id

@description('Name of the deployed Logic App.')
output logicAppName string = logicApp.name

@description('Principal ID of the Logic App system-assigned managed identity.')
output logicAppPrincipalId string = logicApp.identity.principalId

@description('Resource ID of the Office 365 API Connection (requires post-deployment OAuth consent).')
output office365ConnectionId string = office365Connection.id

@description('Resource ID of the Teams API Connection (requires post-deployment OAuth consent).')
output teamsConnectionId string = teamsConnection.id

// NOTE: The HTTP trigger URL is not available as a Bicep output because it
// contains a SAS token that is generated after deployment. Retrieve it via:
//   az rest --method POST \
//     --uri "https://management.azure.com{logicAppId}/triggers/When_an_HTTP_request_is_received/listCallbackUrl?api-version=2016-06-01"
//
// Or in the Azure Portal: Logic App > Overview > Trigger URL
