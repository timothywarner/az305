# AZ-305 Exam Preparation Scripts

This collection of scripts provides hands-on learning materials for the **Microsoft Azure Solutions Architect Expert (AZ-305)** exam. Each script demonstrates Azure architectural patterns and best practices aligned with the exam objectives.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Directory Structure](#directory-structure)
- [Exam Objective Mapping](#exam-objective-mapping)
- [Azure CLI Scripts](#azure-cli-scripts)
- [KQL Queries](#kql-queries)
- [PowerShell Scripts](#powershell-scripts)
- [Usage Guidelines](#usage-guidelines)
- [Cost Considerations](#cost-considerations)
- [References](#references)

## Overview

The AZ-305 exam tests your ability to design solutions that run on Microsoft Azure. This repository provides practical scripts that demonstrate key concepts across all exam domains:

- **Design identity, governance, and monitoring solutions**
- **Design data storage solutions**
- **Design business continuity solutions**
- **Design infrastructure solutions**

## Prerequisites

### Azure CLI Scripts
- Azure CLI 2.50+ installed
- Bash shell (Git Bash on Windows, native on Linux/macOS)
- Azure subscription with appropriate permissions

### KQL Queries
- Log Analytics Workspace with data sources configured
- Application Insights (for app monitoring queries)
- Appropriate RBAC permissions to query logs

### PowerShell Scripts
- PowerShell 7.0+ recommended
- Az PowerShell module installed (`Install-Module -Name Az`)
- Azure subscription with appropriate permissions

### Installation

```bash
# Install Azure CLI (Windows)
winget install Microsoft.AzureCLI

# Install Az PowerShell module
Install-Module -Name Az -AllowClobber -Scope CurrentUser

# Login to Azure
az login
Connect-AzAccount
```

## Directory Structure

```
scripts/
├── az-cli/                      # Azure CLI Bash scripts
│   ├── deploy-hub-spoke.sh      # Hub-spoke network topology
│   ├── create-private-endpoints.sh  # Private Link configuration
│   ├── configure-diagnostic-settings.sh  # Azure Monitor setup
│   ├── create-rbac-assignments.sh   # Custom RBAC roles
│   ├── deploy-container-apps.sh     # Container Apps deployment
│   ├── configure-backup-policy.sh   # Recovery Services vault
│   ├── setup-sql-failover-group.sh  # SQL geo-replication
│   └── deploy-apim.sh              # API Management
│
├── kql/                         # Kusto Query Language files
│   ├── security-audit.kql       # Security monitoring queries
│   ├── performance-analysis.kql # VM and SQL performance
│   ├── cost-analysis.kql        # Cost and usage queries
│   ├── network-diagnostics.kql  # NSG flow log analysis
│   ├── application-insights.kql # App monitoring queries
│   └── resource-changes.kql     # Activity log tracking
│
├── powershell/                  # Azure PowerShell scripts
│   ├── Deploy-LandingZone.ps1   # Landing zone foundation
│   ├── Configure-PolicyInitiative.ps1  # Azure Policy governance
│   ├── New-ManagedIdentity.ps1  # Managed identity setup
│   ├── Export-ResourceInventory.ps1    # Resource auditing
│   ├── Test-PrivateEndpoint.ps1 # Private endpoint validation
│   ├── Set-StorageLifecycle.ps1 # Storage tiering policies
│   ├── New-CosmosDBAccount.ps1  # Cosmos DB deployment
│   └── Enable-DefenderForCloud.ps1     # Security configuration
│
└── README.md                    # This file
```

## Exam Objective Mapping

### Design Identity, Governance, and Monitoring Solutions (25-30%)

| Script | Exam Objective | Key Concepts |
|--------|---------------|--------------|
| `create-rbac-assignments.sh` | Design authorization | Custom RBAC roles, Actions/NotActions, DataActions |
| `Configure-PolicyInitiative.ps1` | Design governance | Policy definitions, initiatives, effects |
| `New-ManagedIdentity.ps1` | Design identities | System vs user-assigned, Key Vault integration |
| `configure-diagnostic-settings.sh` | Design monitoring | Log Analytics, diagnostic settings, alerts |
| `Enable-DefenderForCloud.ps1` | Design security | Defender plans, CSPM, threat protection |
| `security-audit.kql` | Monitor security | Failed logins, privilege escalation, RBAC changes |
| `resource-changes.kql` | Design governance | Activity log analysis, compliance tracking |

### Design Data Storage Solutions (20-25%)

| Script | Exam Objective | Key Concepts |
|--------|---------------|--------------|
| `New-CosmosDBAccount.ps1` | Design NoSQL solutions | Consistency levels, partitioning, global distribution |
| `setup-sql-failover-group.sh` | Design relational storage | Auto-failover groups, geo-replication, RPO/RTO |
| `Set-StorageLifecycle.ps1` | Design storage accounts | Access tiers, lifecycle management, cost optimization |
| `create-private-endpoints.sh` | Design data security | Private Link, DNS configuration |
| `cost-analysis.kql` | Optimize costs | Usage tracking, underutilized resources |

### Design Business Continuity Solutions (15-20%)

| Script | Exam Objective | Key Concepts |
|--------|---------------|--------------|
| `configure-backup-policy.sh` | Design backup strategies | Recovery Services vault, backup policies |
| `setup-sql-failover-group.sh` | Design DR solutions | Geo-replication, failover groups |
| `New-CosmosDBAccount.ps1` | Design HA | Multi-region, automatic failover |
| `performance-analysis.kql` | Monitor for reliability | VM metrics, SQL performance |

### Design Infrastructure Solutions (30-35%)

| Script | Exam Objective | Key Concepts |
|--------|---------------|--------------|
| `deploy-hub-spoke.sh` | Design network topology | Hub-spoke, VNet peering, NSGs |
| `create-private-endpoints.sh` | Design network security | Private Link, DNS zones |
| `deploy-container-apps.sh` | Design compute solutions | Containers, scaling, Dapr |
| `deploy-apim.sh` | Design API integration | API Management, policies, products |
| `Deploy-LandingZone.ps1` | Design landing zones | Resource organization, governance |
| `network-diagnostics.kql` | Monitor networking | NSG flow logs, traffic analysis |
| `application-insights.kql` | Monitor applications | Performance, exceptions, dependencies |

## Azure CLI Scripts

### deploy-hub-spoke.sh
Creates a complete hub-spoke network topology with:
- Hub VNet with firewall, bastion, and gateway subnets
- Two spoke VNets with workload subnets
- Bidirectional VNet peering
- Network Security Groups

```bash
# Deploy with defaults
./deploy-hub-spoke.sh

# Deploy with custom settings
LOCATION="westus2" PREFIX="prod" ./deploy-hub-spoke.sh
```

### create-private-endpoints.sh
Configures Private Link connectivity for PaaS services:
- Private DNS zones for blob, SQL, Key Vault, ACR
- Private endpoints with automatic DNS registration
- Disables public access after configuration

```bash
./create-private-endpoints.sh
```

### configure-diagnostic-settings.sh
Sets up Azure Monitor data collection:
- Log Analytics workspace
- Storage account for archival
- Event Hub for streaming
- Diagnostic settings for resources
- Sample metric alerts

```bash
./configure-diagnostic-settings.sh
```

### create-rbac-assignments.sh
Demonstrates Azure RBAC patterns:
- Custom role definitions (VM Operator, Cost Viewer, etc.)
- Actions, NotActions, DataActions, NotDataActions
- Role assignments at different scopes

```bash
# Create roles
./create-rbac-assignments.sh

# Cleanup
./create-rbac-assignments.sh --cleanup
```

### deploy-container-apps.sh
Deploys Azure Container Apps environment:
- Container Apps Environment with Log Analytics
- Sample containerized application
- HTTP scaling rules
- Managed identity configuration
- Backend service with internal ingress

```bash
# Deploy with Dapr
ENABLE_DAPR=true ./deploy-container-apps.sh
```

### configure-backup-policy.sh
Configures Recovery Services vault and policies:
- Geo-redundant vault with soft delete
- Enhanced VM backup policy (4-hour RPO)
- Standard VM backup policy
- Azure Files backup policy

```bash
./configure-backup-policy.sh
```

### setup-sql-failover-group.sh
Creates Azure SQL Database with geo-replication:
- Primary and secondary servers in different regions
- Auto-failover group configuration
- Listener endpoints for automatic failover
- Test failover commands

```bash
# Create failover group
./setup-sql-failover-group.sh

# Create and test failover
./setup-sql-failover-group.sh --test-failover
```

### deploy-apim.sh
Deploys Azure API Management:
- APIM instance with Application Insights
- Sample API from OpenAPI specification
- Custom API with rate limiting policy
- Products and subscriptions

```bash
# Deploy Developer tier (30-45 minutes)
./deploy-apim.sh

# Deploy Consumption tier (faster)
APIM_SKU=Consumption ./deploy-apim.sh
```

## KQL Queries

### security-audit.kql
Security monitoring queries including:
- Failed sign-in attempts and patterns
- Impossible travel detection
- Privilege escalation monitoring
- RBAC role assignment changes
- MFA gap analysis

### performance-analysis.kql
Performance monitoring queries:
- VM CPU, memory, disk metrics
- Azure SQL DTU and storage usage
- Performance anomaly detection
- Network throughput analysis

### cost-analysis.kql
Cost optimization queries:
- Log Analytics ingestion by table
- Underutilized VM detection
- Resource provisioning trends
- Tag compliance analysis

### network-diagnostics.kql
Network troubleshooting queries:
- NSG flow log analysis
- Traffic pattern identification
- Cross-subscription traffic detection
- Malicious IP detection

### application-insights.kql
Application monitoring queries:
- Request performance analysis
- Exception correlation
- Dependency performance
- Availability test results

### resource-changes.kql
Governance and compliance queries:
- Resource creation/deletion tracking
- Configuration change detection
- Policy compliance monitoring
- After-hours activity detection

## PowerShell Scripts

### Deploy-LandingZone.ps1
Creates foundational landing zone:
- Resource groups for different functions
- Hub virtual network with subnets
- Network security groups
- Log Analytics workspace
- Azure Bastion (optional)

```powershell
.\Deploy-LandingZone.ps1 -SubscriptionId "xxx" -EnvironmentName "dev"
```

### Configure-PolicyInitiative.ps1
Azure Policy governance setup:
- Custom policy definitions
- Policy initiative (policy set)
- Assignment with enforcement mode
- Compliance status checking

```powershell
.\Configure-PolicyInitiative.ps1 -SubscriptionId "xxx" -EnforcementMode "DoNotEnforce"
```

### New-ManagedIdentity.ps1
Managed identity configuration:
- User-assigned managed identity creation
- RBAC role assignments
- Key Vault with RBAC integration
- Identity assignment to VMs

```powershell
.\New-ManagedIdentity.ps1 -ResourceGroupName "myRG" -IdentityName "app-identity"
```

### Export-ResourceInventory.ps1
Resource auditing and reporting:
- Resource Graph queries for inventory
- Tag compliance analysis
- Export to CSV and JSON
- Summary reports

```powershell
.\Export-ResourceInventory.ps1 -OutputPath "C:\Reports"
```

### Test-PrivateEndpoint.ps1
Private endpoint validation:
- Configuration verification
- DNS resolution testing
- Private DNS zone validation
- Troubleshooting guidance

```powershell
.\Test-PrivateEndpoint.ps1 -ResourceGroupName "myRG" -PrivateEndpointName "pe-storage"
```

### Set-StorageLifecycle.ps1
Storage lifecycle management:
- Tiering policies (Hot -> Cool -> Archive)
- Automatic blob deletion
- Snapshot and version management
- Cost optimization

```powershell
.\Set-StorageLifecycle.ps1 -StorageAccountName "mystorageacct" -ResourceGroupName "myRG"
```

### New-CosmosDBAccount.ps1
Cosmos DB deployment:
- Multi-region configuration
- Consistency level setup
- Backup policy configuration
- Database and container creation

```powershell
.\New-CosmosDBAccount.ps1 -ResourceGroupName "myRG" -AccountName "mycosmosdb"
```

### Enable-DefenderForCloud.ps1
Microsoft Defender for Cloud setup:
- Enable Defender plans
- Auto-provisioning configuration
- Security benchmark assignment
- Security contact setup

```powershell
.\Enable-DefenderForCloud.ps1 -SubscriptionId "xxx" -SecurityContactEmail "security@company.com"
```

## Usage Guidelines

### Before Running Scripts

1. **Review the script** - Understand what resources will be created
2. **Check costs** - Some resources (APIM, Bastion) have significant costs
3. **Use test subscriptions** - Avoid running in production without testing
4. **Set appropriate variables** - Review default values and customize as needed

### Environment Variables

Most scripts support configuration via environment variables:

```bash
# Azure CLI scripts
export LOCATION="eastus"
export PREFIX="az305"
export RESOURCE_GROUP="my-custom-rg"
```

```powershell
# PowerShell scripts accept parameters
-Location "eastus" -Prefix "az305"
```

### Cleanup

Scripts create resources that incur costs. Clean up after learning:

```bash
# Delete resource group (removes all contained resources)
az group delete --name "az305-demo-rg" --yes --no-wait
```

## Cost Considerations

| Resource | Approximate Cost | Notes |
|----------|-----------------|-------|
| API Management (Developer) | ~$50/month | Takes 30-45 min to deploy |
| API Management (Consumption) | Pay-per-call | Faster deployment |
| Azure Bastion | ~$140/month | Can skip in deploy-hub-spoke |
| Recovery Services Vault | ~$10/month + storage | Backup storage costs extra |
| Cosmos DB | ~$25/month (400 RU/s) | Free tier available |
| Log Analytics | ~$2.76/GB ingested | 5GB free per month |
| SQL Database (GP Gen5 2vCore) | ~$200/month | Use Basic tier for learning |
| Container Apps | Pay-per-use | Scales to zero |

### Cost Optimization Tips

1. **Use free tiers** where available (Cosmos DB, Log Analytics)
2. **Delete resources** immediately after learning
3. **Use Consumption SKU** for APIM learning
4. **Skip Bastion** unless specifically needed
5. **Set auto-shutdown** on VMs
6. **Use resource tags** to track costs

## References

### Microsoft Learn
- [AZ-305 Learning Path](https://learn.microsoft.com/certifications/exams/az-305)
- [Azure Architecture Center](https://learn.microsoft.com/azure/architecture/)
- [Azure Well-Architected Framework](https://learn.microsoft.com/azure/well-architected/)
- [Cloud Adoption Framework](https://learn.microsoft.com/azure/cloud-adoption-framework/)

### Documentation Links
- [Azure CLI Reference](https://learn.microsoft.com/cli/azure/)
- [Az PowerShell Reference](https://learn.microsoft.com/powershell/azure/)
- [KQL Reference](https://learn.microsoft.com/azure/data-explorer/kusto/query/)

### Architecture Patterns
- [Hub-Spoke Network Topology](https://learn.microsoft.com/azure/architecture/reference-architectures/hybrid-networking/hub-spoke)
- [Private Link and Private Endpoints](https://learn.microsoft.com/azure/private-link/private-link-overview)
- [Landing Zone Architecture](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/)

## Contributing

These scripts are designed for learning. Contributions that improve educational value are welcome:

1. Add comments explaining "WHY" not just "WHAT"
2. Include exam objective mapping
3. Provide cost estimates
4. Add error handling examples
5. Include cleanup procedures

## License

These scripts are provided for educational purposes. Use at your own risk in production environments.

---

**Good luck with your AZ-305 exam!**
