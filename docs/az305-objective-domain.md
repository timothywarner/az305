# AZ-305: Designing Microsoft Azure Infrastructure Solutions

## Exam Objective Domain Study Guide

**Last Updated:** January 2026 (Skills measured as of October 18, 2024; reviewed January 14, 2026)

---

## Exam Overview

| Attribute | Details |
|-----------|---------|
| **Exam Code** | AZ-305 |
| **Exam Title** | Designing Microsoft Azure Infrastructure Solutions |
| **Passing Score** | 700 (on a scale of 1-1000) |
| **Question Count** | 40-60 questions (typical) |
| **Duration** | 120 minutes (may request additional 30 minutes for non-English speakers) |
| **Format** | Multiple choice, case studies, drag-and-drop, build list |
| **Languages** | English, Japanese, Chinese (Simplified), Korean, German, French, Spanish, Portuguese (Brazil), Chinese (Traditional), Italian |
| **Certification** | Microsoft Certified: Azure Solutions Architect Expert |
| **Prerequisites** | Microsoft Certified: Azure Administrator Associate (AZ-104) |
| **Retirement Date** | None announced |

---

## Audience Profile

As a Microsoft Azure solutions architect, you have subject matter expertise in designing cloud and hybrid solutions that run on Azure, including:

- Compute
- Network
- Storage
- Monitoring
- Security

Your responsibilities include advising stakeholders and translating business requirements into designs for Azure solutions that align with the **Azure Well-Architected Framework** and **Cloud Adoption Framework for Azure**.

### Required Experience

- Advanced experience and knowledge of IT operations
- Networking, virtualization, identity, security
- Business continuity, disaster recovery, data platforms, and governance
- Azure administration and Azure development
- DevOps processes

---

## Skills at a Glance

| Skill Area | Weight |
|------------|--------|
| Design identity, governance, and monitoring solutions | 25-30% |
| Design data storage solutions | 20-25% |
| Design business continuity solutions | 15-20% |
| Design infrastructure solutions | 30-35% |

---

## Domain 1: Design Identity, Governance, and Monitoring Solutions (25-30%)

### Microsoft Learn Path
[AZ-305: Design identity, governance, and monitor solutions](https://learn.microsoft.com/training/paths/design-identity-governance-monitor-solutions/)

---

### 1.1 Design Solutions for Logging and Monitoring

**Module:** [Design a solution to log and monitor Azure resources](https://learn.microsoft.com/training/modules/design-solution-to-log-monitor-azure-resources/)

- [ ] **Recommend a logging solution**
  - Azure Monitor Logs (Log Analytics workspaces)
  - Activity logs, resource logs, and platform metrics
  - Diagnostic settings configuration
  - Log retention and archival strategies

- [ ] **Recommend a solution for routing logs**
  - Azure Event Hubs for streaming to external systems
  - Storage accounts for archival
  - Log Analytics workspace routing
  - Cross-subscription and cross-tenant scenarios

- [ ] **Recommend a monitoring solution**
  - Azure Monitor metrics and alerts
  - Application Insights for application performance monitoring
  - Azure Monitor Workbooks for visualization
  - Network Watcher for network diagnostics
  - Service Health and Resource Health

---

### 1.2 Design Authentication and Authorization Solutions

**Module:** [Design authentication and authorization solutions](https://learn.microsoft.com/training/modules/design-authentication-authorization-solutions/)

- [ ] **Recommend an authentication solution**
  - Microsoft Entra ID (formerly Azure AD) authentication methods
  - Multi-factor authentication (MFA)
  - Passwordless authentication (FIDO2, Microsoft Authenticator, Windows Hello)
  - Conditional Access policies
  - B2B and B2C identity scenarios

- [ ] **Recommend an identity management solution**
  - Microsoft Entra ID vs. Active Directory Domain Services
  - Microsoft Entra Domain Services
  - Hybrid identity with Microsoft Entra Connect
  - Federation services

- [ ] **Recommend a solution for authorizing access to Azure resources**
  - Azure Role-Based Access Control (RBAC)
  - Built-in roles vs. custom roles
  - Role assignments at different scopes
  - Microsoft Entra Privileged Identity Management (PIM)

- [ ] **Recommend a solution for authorizing access to on-premises resources**
  - Microsoft Entra application proxy
  - VPN and ExpressRoute integration
  - Hybrid identity synchronization
  - Pass-through authentication vs. password hash sync

- [ ] **Recommend a solution to manage secrets, certificates, and keys**
  - Azure Key Vault (Standard vs. Premium tiers)
  - Key Vault access policies vs. Azure RBAC
  - Managed identities for Azure resources
  - Certificate management and rotation
  - Hardware Security Modules (HSM)

---

### 1.3 Design Governance

**Module:** [Design governance](https://learn.microsoft.com/training/modules/design-governance/)

- [ ] **Recommend a structure for management groups, subscriptions, and resource groups, and a strategy for resource tagging**
  - Management group hierarchy design
  - Subscription organization strategies
  - Resource group design patterns
  - Tagging taxonomy and enforcement
  - Azure landing zones

- [ ] **Recommend a solution for managing compliance**
  - Azure Policy definitions and initiatives
  - Policy effects (audit, deny, deployIfNotExists, modify)
  - Regulatory compliance dashboards
  - Azure Blueprints for environment standardization
  - Microsoft Defender for Cloud compliance scoring

- [ ] **Recommend a solution for identity governance**
  - Microsoft Entra ID Governance
  - Access reviews and entitlement management
  - Lifecycle workflows
  - Privileged Identity Management (PIM)
  - Terms of use and consent management

---

## Domain 2: Design Data Storage Solutions (20-25%)

### Microsoft Learn Path
[AZ-305: Design data storage solutions](https://learn.microsoft.com/training/paths/design-data-storage-solutions/)

---

### 2.1 Design Data Storage Solutions for Relational Data

**Module:** [Design a data storage solution for relational data](https://learn.microsoft.com/training/modules/design-data-storage-solution-for-relational-data/)

- [ ] **Recommend a solution for storing relational data**
  - Azure SQL Database (single database, elastic pools)
  - Azure SQL Managed Instance
  - SQL Server on Azure Virtual Machines
  - Azure Database for PostgreSQL
  - Azure Database for MySQL

- [ ] **Recommend a database service tier and compute tier**
  - DTU-based vs. vCore-based purchasing models
  - Serverless vs. provisioned compute
  - General Purpose, Business Critical, and Hyperscale tiers
  - Read replicas and read scale-out

- [ ] **Recommend a solution for database scalability**
  - Vertical scaling (scale up/down)
  - Horizontal scaling with sharding
  - Elastic pools for multi-tenant scenarios
  - Hyperscale for large databases
  - Read replicas for read-heavy workloads

- [ ] **Recommend a solution for data protection**
  - Transparent Data Encryption (TDE)
  - Always Encrypted and Always Encrypted with secure enclaves
  - Dynamic data masking
  - Row-level security
  - Azure Defender for SQL

---

### 2.2 Design Data Storage Solutions for Semi-Structured and Unstructured Data

**Module:** [Design a data storage solution for non-relational data](https://learn.microsoft.com/training/modules/design-data-storage-solution-for-non-relational-data/)

- [ ] **Recommend a solution for storing semi-structured data**
  - Azure Cosmos DB (API options: NoSQL, MongoDB, Cassandra, Gremlin, Table)
  - Azure Table Storage
  - Consistency levels and partition strategies
  - Global distribution and multi-region writes

- [ ] **Recommend a solution for storing unstructured data**
  - Azure Blob Storage (Hot, Cool, Cold, Archive tiers)
  - Azure Data Lake Storage Gen2
  - Azure Files (SMB and NFS)
  - Azure NetApp Files

- [ ] **Recommend a data storage solution to balance features, performance, and costs**
  - Storage account types (Standard vs. Premium)
  - Access tiers and lifecycle management
  - Reserved capacity vs. pay-as-you-go
  - Performance optimization strategies

- [ ] **Recommend a data solution for protection and durability**
  - Redundancy options (LRS, ZRS, GRS, GZRS, RA-GRS, RA-GZRS)
  - Soft delete and versioning
  - Immutable storage (legal hold, time-based retention)
  - Object replication

---

### 2.3 Design Data Integration

**Module:** [Design data integration](https://learn.microsoft.com/training/modules/design-data-integration/)

- [ ] **Recommend a solution for data integration**
  - Azure Data Factory
  - Azure Synapse Analytics pipelines
  - Integration runtimes (Azure, self-hosted, Azure-SSIS)
  - Data flows and mapping data flows
  - Event-driven data integration

- [ ] **Recommend a solution for data analysis**
  - Azure Synapse Analytics
  - Azure Databricks
  - Azure HDInsight
  - Azure Stream Analytics for real-time analytics
  - Power BI integration

---

## Domain 3: Design Business Continuity Solutions (15-20%)

### Microsoft Learn Path
[AZ-305: Design business continuity solutions](https://learn.microsoft.com/training/paths/design-business-continuity-solutions/)

---

### 3.1 Design Solutions for Backup and Disaster Recovery

**Module:** [Design a solution for backup and disaster recovery](https://learn.microsoft.com/training/modules/design-solution-for-backup-disaster-recovery/)

- [ ] **Recommend a recovery solution for Azure and hybrid workloads that meets recovery objectives**
  - Recovery Time Objective (RTO) and Recovery Point Objective (RPO)
  - Azure Site Recovery for disaster recovery
  - Cross-region replication strategies
  - Failover and failback procedures
  - Recovery plans and automation

- [ ] **Recommend a backup and recovery solution for compute**
  - Azure Backup for VMs
  - Application-consistent vs. crash-consistent snapshots
  - Backup policies and retention
  - Recovery Services vaults vs. Backup vaults
  - Cross-region restore

- [ ] **Recommend a backup and recovery solution for databases**
  - Automated backups for Azure SQL Database
  - Point-in-time restore (PITR)
  - Long-term retention (LTR) policies
  - Geo-restore and active geo-replication
  - Database export and import

- [ ] **Recommend a backup and recovery solution for unstructured data**
  - Azure Backup for Azure Files
  - Blob soft delete and versioning
  - Point-in-time restore for containers
  - Object replication for blob data

---

### 3.2 Design for High Availability

**Module:** [Describe high availability and disaster recovery strategies](https://learn.microsoft.com/training/modules/describe-high-availability-disaster-recovery-strategies/)

- [ ] **Recommend a high availability solution for compute**
  - Availability Sets (fault domains, update domains)
  - Availability Zones
  - Virtual Machine Scale Sets
  - Azure Kubernetes Service (AKS) availability
  - Multi-region deployments

- [ ] **Recommend a high availability solution for relational data**
  - Azure SQL Database zone redundancy
  - Auto-failover groups
  - Active geo-replication
  - Always On availability groups for SQL Server
  - Read replicas for PostgreSQL and MySQL

- [ ] **Recommend a high availability solution for semi-structured and unstructured data**
  - Zone-redundant storage (ZRS)
  - Geo-redundant storage (GRS, GZRS)
  - Cosmos DB multi-region writes
  - Azure Files zone redundancy
  - Storage account failover

---

## Domain 4: Design Infrastructure Solutions (30-35%)

### Microsoft Learn Path
[AZ-305: Design infrastructure solutions](https://learn.microsoft.com/training/paths/design-infranstructure-solutions/)

---

### 4.1 Design Compute Solutions

**Module:** [Design an Azure compute solution](https://learn.microsoft.com/training/modules/design-compute-solution/)

- [ ] **Specify components of a compute solution based on workload requirements**
  - Compute decision tree
  - Performance requirements (CPU, memory, storage, network)
  - Cost considerations
  - Operational requirements

- [ ] **Recommend a virtual machine-based solution**
  - VM sizes and series (general purpose, compute optimized, memory optimized, etc.)
  - VM Scale Sets for auto-scaling
  - Dedicated hosts and isolated VMs
  - Spot VMs for cost optimization
  - Azure Compute Gallery for image management

- [ ] **Recommend a container-based solution**
  - Azure Kubernetes Service (AKS)
  - Azure Container Instances (ACI)
  - Azure Container Apps
  - Azure Container Registry
  - Container orchestration patterns

- [ ] **Recommend a serverless-based solution**
  - Azure Functions (Consumption, Premium, Dedicated plans)
  - Azure Logic Apps
  - Azure App Service (Web Apps, API Apps)
  - Event-driven architectures
  - Durable Functions for stateful workflows

- [ ] **Recommend a compute solution for batch processing**
  - Azure Batch
  - Azure CycleCloud
  - High-performance computing (HPC) VMs
  - Batch pool configurations

---

### 4.2 Design an Application Architecture

**Module:** [Design an application architecture](https://learn.microsoft.com/training/modules/design-application-architecture/)

- [ ] **Recommend a messaging architecture**
  - Azure Service Bus (queues, topics, subscriptions)
  - Azure Queue Storage
  - Message patterns (competing consumers, dead-letter, sessions)
  - Message ordering and deduplication

- [ ] **Recommend an event-driven architecture**
  - Azure Event Grid
  - Azure Event Hubs
  - Event sourcing patterns
  - Pub/sub vs. push/pull patterns

- [ ] **Recommend a solution for API integration**
  - Azure API Management
  - API Gateway patterns
  - Rate limiting and throttling
  - API versioning strategies
  - Developer portal and documentation

- [ ] **Recommend a caching solution for applications**
  - Azure Cache for Redis
  - Caching patterns (cache-aside, write-through, write-behind)
  - CDN for static content
  - Application-level caching

- [ ] **Recommend an application configuration management solution**
  - Azure App Configuration
  - Feature flags and feature management
  - Configuration refresh strategies
  - Key Vault references

- [ ] **Recommend an automated deployment solution for applications**
  - Azure DevOps pipelines
  - GitHub Actions
  - ARM templates and Bicep
  - Terraform for Infrastructure as Code
  - Blue-green and canary deployments

---

### 4.3 Design Migrations

**Module:** [Design migrations](https://learn.microsoft.com/training/modules/design-migrations/)

- [ ] **Evaluate a migration solution that leverages the Microsoft Cloud Adoption Framework for Azure**
  - Cloud Adoption Framework phases (Strategy, Plan, Ready, Adopt, Govern, Manage)
  - Azure landing zones
  - Migration motivations and business outcomes
  - Azure Migrate hub

- [ ] **Evaluate on-premises servers, data, and applications for migration**
  - Azure Migrate discovery and assessment
  - Dependency analysis
  - Application portfolio assessment
  - Total Cost of Ownership (TCO) calculator

- [ ] **Recommend a solution for migrating workloads to infrastructure as a service (IaaS) and platform as a service (PaaS)**
  - Rehost (lift and shift)
  - Refactor (repackage)
  - Rearchitect (rebuild)
  - Azure Migrate server migration
  - App Service migration assistant

- [ ] **Recommend a solution for migrating databases**
  - Azure Database Migration Service
  - Online vs. offline migration
  - SQL Server to Azure SQL migration paths
  - Open-source database migrations

- [ ] **Recommend a solution for migrating unstructured data**
  - Azure Data Box family (Data Box, Data Box Disk, Data Box Heavy)
  - AzCopy and Storage Explorer
  - Azure File Sync
  - Online data transfer options

---

### 4.4 Design Network Solutions

**Module:** [Design network solutions](https://learn.microsoft.com/training/modules/design-network-solutions/)

- [ ] **Recommend a connectivity solution that connects Azure resources to the internet**
  - Public IP addresses (Standard vs. Basic SKU)
  - Azure NAT Gateway
  - Azure Firewall for outbound traffic
  - DDoS Protection (Basic vs. Standard)

- [ ] **Recommend a connectivity solution that connects Azure resources to on-premises networks**
  - Site-to-Site VPN Gateway
  - Azure ExpressRoute (private peering, Microsoft peering)
  - ExpressRoute Global Reach
  - Virtual WAN
  - VPN Gateway redundancy (active-active, zone-redundant)

- [ ] **Recommend a solution to optimize network performance**
  - ExpressRoute for consistent latency
  - Azure Front Door for global acceleration
  - Virtual network peering (global and regional)
  - Proximity placement groups
  - Accelerated networking

- [ ] **Recommend a solution to optimize network security**
  - Network Security Groups (NSGs)
  - Application Security Groups (ASGs)
  - Azure Firewall (Standard, Premium)
  - Web Application Firewall (WAF)
  - Azure DDoS Protection
  - Private endpoints and Private Link
  - Service endpoints

- [ ] **Recommend a load-balancing and routing solution**
  - Azure Load Balancer (Layer 4)
  - Azure Application Gateway (Layer 7)
  - Azure Front Door (global HTTP load balancing)
  - Azure Traffic Manager (DNS-based routing)
  - Load balancing decision tree

---

## Study Resources

### Official Microsoft Resources

| Resource | Link |
|----------|------|
| AZ-305 Study Guide | [aka.ms/AZ305-StudyGuide](https://aka.ms/AZ305-StudyGuide) |
| Free Practice Assessment | [Practice Assessment](https://learn.microsoft.com/credentials/certifications/exams/az-305/practice/assessment?assessment-type=practice&assessmentId=15) |
| Exam Sandbox | [Try the exam experience](https://aka.ms/examdemo) |
| Exam Readiness Videos | [Exam Readiness Zone](https://learn.microsoft.com/shows/exam-readiness-zone/?terms=AZ-305) |

### Learning Paths

| Path | Description |
|------|-------------|
| [AZ-305 Prerequisites](https://learn.microsoft.com/training/paths/microsoft-azure-architect-design-prerequisites/) | Foundation concepts for Azure architecture |
| [Design identity, governance, and monitor solutions](https://learn.microsoft.com/training/paths/design-identity-governance-monitor-solutions/) | Domain 1 learning path |
| [Design data storage solutions](https://learn.microsoft.com/training/paths/design-data-storage-solutions/) | Domain 2 learning path |
| [Design business continuity solutions](https://learn.microsoft.com/training/paths/design-business-continuity-solutions/) | Domain 3 learning path |
| [Design infrastructure solutions](https://learn.microsoft.com/training/paths/design-infranstructure-solutions/) | Domain 4 learning path |

### Reference Documentation

| Resource | Link |
|----------|------|
| Azure Documentation | [docs.microsoft.com/azure](https://learn.microsoft.com/azure/) |
| Azure Architecture Center | [learn.microsoft.com/azure/architecture](https://learn.microsoft.com/azure/architecture/) |
| Azure Well-Architected Framework | [learn.microsoft.com/azure/well-architected](https://learn.microsoft.com/azure/well-architected/) |
| Cloud Adoption Framework | [learn.microsoft.com/azure/cloud-adoption-framework](https://learn.microsoft.com/azure/cloud-adoption-framework/) |
| Browse Azure Architectures | [Browse reference architectures](https://learn.microsoft.com/azure/architecture/browse/) |

### Community Resources

| Resource | Link |
|----------|------|
| Microsoft Q&A | [learn.microsoft.com/answers](https://learn.microsoft.com/answers/products/) |
| Azure Community Support | [azure.microsoft.com/support/community](https://azure.microsoft.com/support/community/) |
| Microsoft Tech Community | [techcommunity.microsoft.com](https://techcommunity.microsoft.com/t5/microsoft-learn/ct-p/MicrosoftLearn) |
| Azure Fridays | [Azure Friday videos](https://azure.microsoft.com/resources/videos/azure-friday/) |

---

## Exam Tips

1. **Focus on the "recommend" and "design" aspects** - This exam tests your ability to make architectural decisions, not just know what services exist.

2. **Understand trade-offs** - Most questions involve scenarios where you must balance cost, performance, security, and operational complexity.

3. **Know the Well-Architected Framework pillars:**
   - Reliability
   - Security
   - Cost Optimization
   - Operational Excellence
   - Performance Efficiency

4. **Practice with case studies** - The exam includes case study questions that require analyzing complex scenarios.

5. **Review comparison tables** - Know when to use one service over another (e.g., Event Grid vs. Event Hubs vs. Service Bus).

6. **Hands-on experience is essential** - Deploy and configure services in a lab environment.

---

## Progress Tracker

Use this section to track your overall readiness:

| Domain | Weight | Self-Assessment (1-5) | Status |
|--------|--------|----------------------|--------|
| Identity, Governance, and Monitoring | 25-30% | ___ | Not Started / In Progress / Complete |
| Data Storage Solutions | 20-25% | ___ | Not Started / In Progress / Complete |
| Business Continuity Solutions | 15-20% | ___ | Not Started / In Progress / Complete |
| Infrastructure Solutions | 30-35% | ___ | Not Started / In Progress / Complete |

**Practice Assessment Score:** ____%

**Target Exam Date:** _______________

---

*Document prepared for O'Reilly Live Learning courses taught by Tim Warner.*

*Source: Microsoft Learn - [AZ-305 Study Guide](https://learn.microsoft.com/credentials/certifications/resources/study-guides/az-305)*
