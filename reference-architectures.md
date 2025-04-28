# Key Reference Architectures for AZ-305

## Identity & Governance (25-30%)

### 1. Zero Trust Architecture
- **Source**: [Azure Zero Trust Architecture](https://learn.microsoft.com/azure/architecture/guide/security/security-zero-trust)
- **Key Components**:
  - Entra ID (Azure AD) B2B/B2C
  - Conditional Access
  - Managed Identities
  - Key Vault with Private Link
- **Exam Focus**: Identity management, authorization, and secrets management

### 2. Management Group Hierarchy
- **Source**: [Management Group Hierarchy](https://learn.microsoft.com/azure/governance/management-groups/overview)
- **Key Components**:
  - Management group structure
  - Policy assignments
  - RBAC inheritance
  - Resource tagging
- **Exam Focus**: Governance and compliance

## Data Storage (20-25%)

### 3. Data Lake Architecture
- **Source**: [Data Lake Architecture](https://learn.microsoft.com/azure/architecture/data-guide/scenarios/data-lake)
- **Key Components**:
  - Azure Data Lake Storage Gen2
  - Azure Synapse Analytics
  - Azure Databricks
  - Azure Data Factory
- **Exam Focus**: Data storage solutions and integration

### 4. Multi-Region Database Architecture
- **Source**: [Multi-Region Database Architecture](https://learn.microsoft.com/azure/architecture/guide/technology-choices/data-store-overview)
- **Key Components**:
  - Azure SQL Database
  - Cosmos DB
  - Geo-replication
  - Auto-failover groups
- **Exam Focus**: High availability and data protection

## Business Continuity (15-20%)

### 5. Disaster Recovery Architecture
- **Source**: [Disaster Recovery Architecture](https://learn.microsoft.com/azure/architecture/framework/resiliency/backup-and-recovery)
- **Key Components**:
  - Azure Site Recovery
  - Azure Backup
  - Cross-region replication
  - Recovery time objectives
- **Exam Focus**: Backup and disaster recovery

### 6. High Availability Architecture
- **Source**: [High Availability Architecture](https://learn.microsoft.com/azure/architecture/framework/resiliency/high-availability)
- **Key Components**:
  - Availability Zones
  - Availability Sets
  - Load Balancers
  - Traffic Manager
- **Exam Focus**: High availability solutions

## Infrastructure (30-35%)

### 7. Container Apps Architecture
- **Source**: [Container Apps Architecture](https://learn.microsoft.com/azure/architecture/guide/technology-choices/compute-decision-tree)
- **Key Components**:
  - Azure Container Apps
  - Azure Kubernetes Service
  - Dapr integration
  - Managed identities
- **Exam Focus**: Container and serverless solutions

### 8. Hub-Spoke Network Architecture
- **Source**: [Hub-Spoke Network Architecture](https://learn.microsoft.com/azure/architecture/reference-architectures/hybrid-networking/hub-spoke)
- **Key Components**:
  - Virtual WAN
  - Azure Firewall
  - Private Link
  - Service Endpoints
- **Exam Focus**: Network connectivity and security

### 9. Event-Driven Architecture
- **Source**: [Event-Driven Architecture](https://learn.microsoft.com/azure/architecture/guide/architecture-styles/event-driven)
- **Key Components**:
  - Event Grid
  - Event Hubs
  - Service Bus
  - Logic Apps
- **Exam Focus**: Application architecture patterns

## Implementation Tips

1. **Use Azure Architecture Center**
   - [Azure Architecture Center](https://learn.microsoft.com/azure/architecture/)
   - [Reference Architectures](https://learn.microsoft.com/azure/architecture/browse/reference-architectures)
   - [Example Scenarios](https://learn.microsoft.com/azure/architecture/browse/example-scenarios)

2. **Practice with Azure Bicep**
   - [Bicep Playground](https://learn.microsoft.com/azure/azure-resource-manager/bicep/playground)
   - [Bicep Samples](https://github.com/Azure/bicep)

3. **Cost Optimization**
   - Use [Azure Pricing Calculator](https://azure.microsoft.com/pricing/calculator/)
   - Enable cost alerts
   - Review [Cost Optimization Guide](https://learn.microsoft.com/azure/cost-management-billing/costs/cost-mgt-best-practices)

## Attribution
All architecture diagrams and content are © Microsoft Corporation and are used for educational purposes in accordance with Microsoft's documentation guidelines. 