# AZ-305 Microsoft Learn Resource Map

Use these URL patterns and search terms with the `microsoft-learn` MCP server tools to ground every question in first-party documentation.

## Objective Domain 1: Design Identity, Governance, and Monitoring Solutions (25-30%)

### Identity
| Topic | Search Terms | Base URL Pattern |
|-------|-------------|-----------------|
| Azure AD B2B/B2C | "Azure AD B2C overview", "external identities" | `learn.microsoft.com/en-us/azure/active-directory-b2c/` |
| Conditional Access | "conditional access policies Azure AD" | `learn.microsoft.com/en-us/azure/active-directory/conditional-access/` |
| Managed Identities | "managed identities Azure resources" | `learn.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/` |
| Azure AD Connect | "hybrid identity Azure AD Connect" | `learn.microsoft.com/en-us/azure/active-directory/hybrid/` |
| RBAC | "Azure RBAC built-in roles" | `learn.microsoft.com/en-us/azure/role-based-access-control/` |

### Governance
| Topic | Search Terms | Base URL Pattern |
|-------|-------------|-----------------|
| Azure Policy | "Azure Policy built-in definitions" | `learn.microsoft.com/en-us/azure/governance/policy/` |
| Management Groups | "management group hierarchy Azure" | `learn.microsoft.com/en-us/azure/governance/management-groups/` |
| Blueprints / Deployment Stacks | "Azure deployment stacks" | `learn.microsoft.com/en-us/azure/azure-resource-manager/` |
| Resource Locks | "lock resources prevent changes Azure" | `learn.microsoft.com/en-us/azure/azure-resource-manager/management/` |
| Cost Management | "Azure cost management budgets" | `learn.microsoft.com/en-us/azure/cost-management-billing/` |

### Monitoring
| Topic | Search Terms | Base URL Pattern |
|-------|-------------|-----------------|
| Azure Monitor | "Azure Monitor overview metrics logs" | `learn.microsoft.com/en-us/azure/azure-monitor/` |
| Log Analytics | "Log Analytics workspace design" | `learn.microsoft.com/en-us/azure/azure-monitor/logs/` |
| Application Insights | "Application Insights monitoring" | `learn.microsoft.com/en-us/azure/azure-monitor/app/` |
| Alerts and Actions | "Azure Monitor alerts action groups" | `learn.microsoft.com/en-us/azure/azure-monitor/alerts/` |

## Objective Domain 2: Design Data Storage Solutions (25-30%)

### Relational Data
| Topic | Search Terms | Base URL Pattern |
|-------|-------------|-----------------|
| Azure SQL Database | "Azure SQL Database service tiers" | `learn.microsoft.com/en-us/azure/azure-sql/database/` |
| SQL Managed Instance | "SQL Managed Instance features" | `learn.microsoft.com/en-us/azure/azure-sql/managed-instance/` |
| SQL vs MI vs VM | "compare SQL deployment options Azure" | `learn.microsoft.com/en-us/azure/azure-sql/azure-sql-iaas-vs-paas-what-is-overview` |

### Non-Relational Data
| Topic | Search Terms | Base URL Pattern |
|-------|-------------|-----------------|
| Cosmos DB | "Cosmos DB consistency levels", "partition key design" | `learn.microsoft.com/en-us/azure/cosmos-db/` |
| Table Storage vs Cosmos Table | "Azure Table Storage vs Cosmos DB Table API" | `learn.microsoft.com/en-us/azure/cosmos-db/table/` |

### Storage
| Topic | Search Terms | Base URL Pattern |
|-------|-------------|-----------------|
| Storage Account Types | "storage account overview types" | `learn.microsoft.com/en-us/azure/storage/common/` |
| Blob Storage Tiers | "blob storage access tiers hot cool archive" | `learn.microsoft.com/en-us/azure/storage/blobs/` |
| Data Lake Storage | "Azure Data Lake Storage Gen2" | `learn.microsoft.com/en-us/azure/storage/blobs/data-lake-storage-introduction` |
| Storage Redundancy | "Azure Storage redundancy LRS ZRS GRS" | `learn.microsoft.com/en-us/azure/storage/common/storage-redundancy` |

### Data Integration
| Topic | Search Terms | Base URL Pattern |
|-------|-------------|-----------------|
| Azure Data Factory | "Azure Data Factory pipelines" | `learn.microsoft.com/en-us/azure/data-factory/` |
| Azure Synapse | "Azure Synapse Analytics overview" | `learn.microsoft.com/en-us/azure/synapse-analytics/` |
| Azure Databricks | "Azure Databricks workspace" | `learn.microsoft.com/en-us/azure/databricks/` |

## Objective Domain 3: Design Business Continuity Solutions (10-15%)

| Topic | Search Terms | Base URL Pattern |
|-------|-------------|-----------------|
| Azure Backup | "Azure Backup overview vault" | `learn.microsoft.com/en-us/azure/backup/` |
| Azure Site Recovery | "Azure Site Recovery replication" | `learn.microsoft.com/en-us/azure/site-recovery/` |
| SQL Geo-Replication | "active geo-replication Azure SQL" | `learn.microsoft.com/en-us/azure/azure-sql/database/active-geo-replication-overview` |
| Failover Groups | "auto-failover groups Azure SQL" | `learn.microsoft.com/en-us/azure/azure-sql/database/auto-failover-group-overview` |
| RPO/RTO | "business continuity Azure SQL" | `learn.microsoft.com/en-us/azure/azure-sql/database/business-continuity-high-availability-disaster-recover-hadr-overview` |
| Availability Zones | "availability zones Azure regions" | `learn.microsoft.com/en-us/azure/reliability/availability-zones-overview` |

## Objective Domain 4: Design Infrastructure Solutions (25-30%)

### Compute
| Topic | Search Terms | Base URL Pattern |
|-------|-------------|-----------------|
| App Service | "App Service plans pricing tiers" | `learn.microsoft.com/en-us/azure/app-service/` |
| Azure Functions | "Azure Functions hosting options" | `learn.microsoft.com/en-us/azure/azure-functions/` |
| AKS | "Azure Kubernetes Service overview" | `learn.microsoft.com/en-us/azure/aks/` |
| Container Apps | "Azure Container Apps overview" | `learn.microsoft.com/en-us/azure/container-apps/` |
| Virtual Machines | "VM sizes Azure", "availability sets" | `learn.microsoft.com/en-us/azure/virtual-machines/` |
| Azure Batch | "Azure Batch large-scale parallel" | `learn.microsoft.com/en-us/azure/batch/` |

### Networking
| Topic | Search Terms | Base URL Pattern |
|-------|-------------|-----------------|
| Virtual Network | "Azure VNet design", "subnet planning" | `learn.microsoft.com/en-us/azure/virtual-network/` |
| Load Balancer | "Azure Load Balancer vs Application Gateway" | `learn.microsoft.com/en-us/azure/load-balancer/` |
| Application Gateway | "Application Gateway WAF v2" | `learn.microsoft.com/en-us/azure/application-gateway/` |
| Azure Front Door | "Azure Front Door routing" | `learn.microsoft.com/en-us/azure/frontdoor/` |
| ExpressRoute | "ExpressRoute circuit overview" | `learn.microsoft.com/en-us/azure/expressroute/` |
| VPN Gateway | "VPN Gateway Azure" | `learn.microsoft.com/en-us/azure/vpn-gateway/` |
| Private Link | "Azure Private Link private endpoint" | `learn.microsoft.com/en-us/azure/private-link/` |
| Service Endpoints | "virtual network service endpoints" | `learn.microsoft.com/en-us/azure/virtual-network/virtual-network-service-endpoints-overview` |

### Messaging and Events
| Topic | Search Terms | Base URL Pattern |
|-------|-------------|-----------------|
| Service Bus | "Azure Service Bus queues topics" | `learn.microsoft.com/en-us/azure/service-bus-messaging/` |
| Event Grid | "Azure Event Grid overview" | `learn.microsoft.com/en-us/azure/event-grid/` |
| Event Hubs | "Azure Event Hubs streaming" | `learn.microsoft.com/en-us/azure/event-hubs/` |
| Queue Storage | "Azure Queue Storage overview" | `learn.microsoft.com/en-us/azure/storage/queues/` |
| Compare Messaging | "choose Azure messaging service" | `learn.microsoft.com/en-us/azure/service-bus-messaging/compare-messaging-services` |

## Objective Domain 5: Design Network Solutions (subset of Infrastructure)

| Topic | Search Terms | Base URL Pattern |
|-------|-------------|-----------------|
| Hub-Spoke Topology | "hub-spoke network topology Azure" | `learn.microsoft.com/en-us/azure/architecture/reference-architectures/hybrid-networking/hub-spoke` |
| Azure Firewall | "Azure Firewall features" | `learn.microsoft.com/en-us/azure/firewall/` |
| Network Security Groups | "NSG rules Azure" | `learn.microsoft.com/en-us/azure/virtual-network/network-security-groups-overview` |
| Azure DNS | "Azure DNS private zones" | `learn.microsoft.com/en-us/azure/dns/` |
| Traffic Manager | "Traffic Manager routing methods" | `learn.microsoft.com/en-us/azure/traffic-manager/` |
| Azure Bastion | "Azure Bastion secure VM access" | `learn.microsoft.com/en-us/azure/bastion/` |

## Architecture Center References

| Reference Architecture | Search Terms |
|------------------------|-------------|
| Multi-region web app | "multi-region web application Azure architecture" |
| Microservices on AKS | "microservices architecture Azure Kubernetes" |
| Serverless web app | "serverless web application Azure architecture" |
| Hybrid network | "hybrid network architecture Azure ExpressRoute" |
| Data analytics | "analytics end-to-end Azure architecture" |
| IoT reference architecture | "IoT reference architecture Azure" |

## Search Strategy

When generating a question on any topic:
1. Start with the **Search Terms** column for `microsoft_docs_search`
2. Fetch the most relevant result with `microsoft_docs_fetch`
3. For implementation questions, also call `microsoft_code_sample_search` with the topic
4. Cross-reference the **Base URL Pattern** to verify you're citing the canonical source
