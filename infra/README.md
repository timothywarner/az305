# AZ-305 Infrastructure as Code Templates

This repository contains production-ready Bicep templates organized by AZ-305 exam domains. Each template demonstrates Azure best practices including Zero Trust architecture, managed identities, and proper resource naming conventions.

## Prerequisites

- Azure CLI 2.50+ or Azure PowerShell 10.0+
- Bicep CLI 0.22+ (included with Azure CLI)
- Azure subscription with appropriate permissions
- Resource group(s) created for deployment

## Repository Structure

```
infra/
├── Domain 1: Identity, Governance & Monitoring
│   ├── log-analytics-workspace.bicep
│   ├── custom-rbac-role.bicep
│   ├── azure-policy-initiative.bicep
│   └── managed-identity.bicep
│
├── Domain 2: Data Storage Solutions
│   ├── sql-database-elastic-pool.bicep
│   ├── cosmosdb-multi-region.bicep
│   ├── storage-account-tiered.bicep
│   └── keyvault-with-private-link.bicep
│
├── Domain 3: Business Continuity
│   ├── recovery-services-vault.bicep
│   ├── site-recovery-config.bicep
│   └── sql-failover-group.bicep
│
├── Domain 4: Infrastructure Solutions
│   ├── container-apps-environment.bicep
│   ├── aks-cluster.bicep
│   ├── apim-with-backends.bicep
│   ├── hub-spoke-network.bicep
│   ├── private-endpoint-services.bicep
│   ├── application-gateway-waf.bicep
│   └── front-door-global.bicep
│
└── README.md
```

## AZ-305 Exam Objective Mapping

| Template | Exam Objective | Domain |
|----------|---------------|--------|
| log-analytics-workspace.bicep | Design monitoring (1.3) | Identity & Monitoring |
| custom-rbac-role.bicep | Design authorization (1.1, 1.2) | Identity & Governance |
| azure-policy-initiative.bicep | Design governance (1.4) | Governance |
| managed-identity.bicep | Design authentication (1.1, 1.2) | Identity |
| sql-database-elastic-pool.bicep | Design data storage (2.1), DR (3.1), HA (3.2) | Data Storage |
| cosmosdb-multi-region.bicep | Design data storage (2.1), HA (3.2), DR (3.1) | Data Storage |
| storage-account-tiered.bicep | Design data storage (2.1), DR (3.1), Secrets (2.4) | Data Storage |
| keyvault-with-private-link.bicep | Design secrets management (2.4), Auth (1.1), Network (4.2) | Secrets & Security |
| recovery-services-vault.bicep | Design backup & DR (3.1), HA (3.2) | Business Continuity |
| site-recovery-config.bicep | Design backup & DR (3.1), HA (3.2) | Business Continuity |
| sql-failover-group.bicep | Design backup & DR (3.1), HA (3.2), Data storage (2.1) | Business Continuity |
| container-apps-environment.bicep | Design compute (4.1), Application architecture (4.3) | Compute |
| aks-cluster.bicep | Design compute (4.1), Application architecture (4.3), Auth (1.1) | Compute |
| apim-with-backends.bicep | Design application architecture (4.3), Auth (1.1), Network (4.2) | Application |
| hub-spoke-network.bicep | Design network connectivity (4.2), Auth (1.1) | Networking |
| private-endpoint-services.bicep | Design network connectivity (4.2), Secrets (2.4) | Networking |
| application-gateway-waf.bicep | Design network connectivity (4.2), Auth (1.1) | Networking |
| front-door-global.bicep | Design network connectivity (4.2), HA (3.2), App architecture (4.3) | Networking |

## Deployment Commands

### Azure CLI

```bash
# Set variables
SUBSCRIPTION_ID="your-subscription-id"
RESOURCE_GROUP="rg-az305-lab"
LOCATION="eastus"

# Login and set subscription
az login
az account set --subscription $SUBSCRIPTION_ID

# Create resource group
az group create --name $RESOURCE_GROUP --location $LOCATION

# Deploy a template (example: Log Analytics)
az deployment group create \
  --resource-group $RESOURCE_GROUP \
  --template-file log-analytics-workspace.bicep \
  --parameters log-analytics-workspace.parameters.json

# Deploy with parameter overrides
az deployment group create \
  --resource-group $RESOURCE_GROUP \
  --template-file storage-account-tiered.bicep \
  --parameters storageAccountNamePrefix=myapp location=eastus

# Validate a template before deployment
az deployment group validate \
  --resource-group $RESOURCE_GROUP \
  --template-file aks-cluster.bicep \
  --parameters aks-cluster.parameters.json

# What-if deployment (preview changes)
az deployment group what-if \
  --resource-group $RESOURCE_GROUP \
  --template-file hub-spoke-network.bicep \
  --parameters hub-spoke-network.parameters.json
```

### Azure PowerShell

```powershell
# Set variables
$SubscriptionId = "your-subscription-id"
$ResourceGroup = "rg-az305-lab"
$Location = "eastus"

# Login and set subscription
Connect-AzAccount
Set-AzContext -SubscriptionId $SubscriptionId

# Create resource group
New-AzResourceGroup -Name $ResourceGroup -Location $Location

# Deploy a template
New-AzResourceGroupDeployment `
  -ResourceGroupName $ResourceGroup `
  -TemplateFile "log-analytics-workspace.bicep" `
  -TemplateParameterFile "log-analytics-workspace.parameters.json"

# What-if deployment
New-AzResourceGroupDeployment `
  -ResourceGroupName $ResourceGroup `
  -TemplateFile "cosmosdb-multi-region.bicep" `
  -TemplateParameterFile "cosmosdb-multi-region.parameters.json" `
  -WhatIf
```

### Subscription-Scoped Deployments

Some templates require subscription-level deployment:

```bash
# Azure Policy Initiative (subscription scope)
az deployment sub create \
  --location $LOCATION \
  --template-file azure-policy-initiative.bicep \
  --parameters azure-policy-initiative.parameters.json

# Custom RBAC Role (subscription scope)
az deployment sub create \
  --location $LOCATION \
  --template-file custom-rbac-role.bicep \
  --parameters custom-rbac-role.parameters.json
```

## Template Features

### Security Best Practices (Zero Trust)

All templates implement Zero Trust principles:

- **Managed Identities**: System-assigned or user-assigned identities for authentication
- **Private Endpoints**: Network isolation for PaaS services
- **RBAC**: Role-based access control instead of access keys
- **Encryption**: Data encrypted at rest and in transit
- **Minimal TLS**: TLS 1.2 minimum enforced
- **Network Security**: NSGs, Azure Firewall, and WAF configurations

### High Availability Patterns

- **Availability Zones**: Zone-redundant deployments where supported
- **Multi-region**: Geo-replication and failover configurations
- **Auto-scaling**: Automatic scaling based on demand
- **Health Probes**: Application health monitoring

### Monitoring & Observability

- **Azure Monitor Integration**: All templates support diagnostic settings
- **Log Analytics**: Centralized logging and analytics
- **Application Insights**: Application performance monitoring
- **Alerts**: Built-in alert configurations

## Template Dependencies

Some templates have dependencies on other resources:

```
┌─────────────────────────────────────────────────────────────────┐
│                    Recommended Deployment Order                  │
├─────────────────────────────────────────────────────────────────┤
│ 1. log-analytics-workspace.bicep (monitoring foundation)        │
│ 2. managed-identity.bicep (authentication foundation)           │
│ 3. hub-spoke-network.bicep (networking foundation)             │
│ 4. keyvault-with-private-link.bicep (secrets management)       │
│ 5. private-endpoint-services.bicep (network security)          │
│ 6. Storage/Database templates (data layer)                      │
│ 7. Compute templates (AKS, Container Apps)                      │
│ 8. Gateway templates (App Gateway, Front Door)                  │
│ 9. recovery-services-vault.bicep (backup/DR)                   │
└─────────────────────────────────────────────────────────────────┘
```

## Parameter File Customization

Before deployment, customize the `.parameters.json` files:

1. Replace placeholder values (e.g., `{subscription-id}`, `{your-value}`)
2. Update resource IDs to match your environment
3. Adjust SKUs based on your requirements and budget
4. Configure tags according to your organization's standards

### Common Parameters to Update

| Parameter | Description | Example |
|-----------|-------------|---------|
| `location` | Azure region | `eastus`, `westeurope` |
| `tags` | Resource tags | `{"environment": "production"}` |
| `vnetId` | Virtual network resource ID | `/subscriptions/.../virtualNetworks/vnet-hub` |
| `logAnalyticsWorkspaceId` | Log Analytics workspace ID | `/subscriptions/.../workspaces/log-prod` |
| `aadAdminObjectId` | Microsoft Entra ID group/user object ID | `00000000-0000-0000-0000-000000000000` |

## Exam Study Tips

### Domain 1: Design Identity, Governance, and Monitoring
- Understand when to use system-assigned vs user-assigned managed identities
- Know the difference between Azure RBAC and resource-specific RBAC (e.g., Key Vault, Cosmos DB)
- Practice creating custom RBAC roles with least-privilege permissions
- Understand Azure Policy effects: Deny, Audit, Modify, DeployIfNotExists

### Domain 2: Design Data Storage Solutions
- Compare SQL Database vs Cosmos DB for different workloads
- Understand storage account redundancy options (LRS, ZRS, GRS, GZRS, RA-GZRS)
- Know when to use elastic pools vs single databases
- Understand Cosmos DB consistency levels and their trade-offs

### Domain 3: Design Business Continuity Solutions
- Calculate RTO/RPO requirements for different backup strategies
- Understand failover group vs geo-replication
- Know the differences between Azure Backup and Azure Site Recovery
- Practice designing multi-region architectures

### Domain 4: Design Infrastructure Solutions
- Compare AKS vs Container Apps for different scenarios
- Understand hub-spoke network topology benefits
- Know when to use Application Gateway vs Front Door vs Traffic Manager
- Practice Private Link and Private Endpoint configurations

## Cost Considerations

To minimize costs during learning:

1. Use **Developer** SKUs where available (APIM, SQL)
2. Enable **auto-shutdown** for non-production resources
3. Use **Consumption** tier for serverless options
4. Clean up resources after each lab session
5. Use **Azure Cost Management** to monitor spending

```bash
# Delete resource group and all resources
az group delete --name $RESOURCE_GROUP --yes --no-wait
```

## Contributing

When contributing new templates:

1. Follow the established naming conventions
2. Include comprehensive parameter descriptions
3. Add exam objective mappings in comments
4. Provide sensible default values
5. Create corresponding `.parameters.json` file
6. Update this README with new template information

## Resources

- [AZ-305 Exam Skills Outline](https://learn.microsoft.com/en-us/certifications/exams/az-305)
- [Azure Architecture Center](https://learn.microsoft.com/en-us/azure/architecture/)
- [Azure Well-Architected Framework](https://learn.microsoft.com/en-us/azure/well-architected/)
- [Bicep Documentation](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
- [Azure Naming Conventions](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming)

## License

This project is licensed under the MIT License - see the LICENSE file for details.
