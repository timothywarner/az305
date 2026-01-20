# AZ-305 Practice Questions - Complete Exam Review

**Last Updated**: January 2025 | **Exam Version**: October 18, 2024 Update

Use these questions after each segment. Focus on understanding WHY each answer is correct--the exam tests design decision-making, not memorization.

---

## Domain 1: Identity, Governance & Monitoring (25-30%)

### Logging and Monitoring

**Q1.** Contoso Ltd. operates 50+ Azure subscriptions across multiple business units. They need centralized log collection with 90-day retention for compliance, cost-efficient storage for older logs, and the ability to query across all subscriptions. What is the best solution?

- A. One Log Analytics workspace per subscription with cross-workspace queries
- B. A single centralized Log Analytics workspace with resource-context RBAC
- C. Azure Monitor Logs with dedicated cluster and customer-managed keys
- D. Multiple Log Analytics workspaces federated with Azure Data Explorer

**Correct Answer**: B

**Explanation**:
- **Correct**: A single centralized workspace with resource-context RBAC provides unified querying, cost efficiency (bulk ingestion pricing), and granular access control based on Azure resource permissions. This is the recommended pattern for multi-subscription enterprises. [Learn more](https://learn.microsoft.com/azure/azure-monitor/logs/workspace-design)
- **Incorrect A**: Multiple workspaces increase cost and complexity. Cross-workspace queries have limits and are slower.
- **Incorrect C**: Dedicated clusters require 500GB+/day commitment--overkill unless you need CMK or higher performance.
- **Incorrect D**: ADX federation adds complexity; only justified for petabyte-scale analytics.

---

**Q2.** Wingtip Toys needs to route Azure Activity Logs to their SIEM system (Splunk), retain logs in Azure for 7 years for compliance, and enable near-real-time alerting. Which architecture should you recommend?

- A. Diagnostic settings to Event Hub (SIEM) + Storage Account (archive) + Log Analytics (alerting)
- B. Diagnostic settings to Log Analytics only with 7-year retention
- C. Azure Monitor Agent to Log Analytics with export rules to Storage
- D. Direct API integration from SIEM to Azure Activity Log

**Correct Answer**: A

**Explanation**:
- **Correct**: This fan-out pattern using diagnostic settings to multiple destinations is the standard architecture: Event Hub for real-time SIEM streaming, Storage Account for cost-effective long-term archive, Log Analytics for alerting and investigation. [Learn more](https://learn.microsoft.com/azure/azure-monitor/essentials/diagnostic-settings)
- **Incorrect B**: Log Analytics max retention is 730 days (2 years), not 7 years.
- **Incorrect C**: Azure Monitor Agent is for VMs, not Activity Logs. Export rules go to Storage, not Log Analytics.
- **Incorrect D**: Polling APIs is inefficient and misses real-time requirements.

---

**Q3.** Fabrikam needs Application Insights for their microservices running on AKS. They require distributed tracing, auto-scaling based on custom metrics, and cost control. What should you recommend?

- A. Application Insights with workspace-based mode, sampling enabled, and custom metrics for KEDA
- B. Application Insights with classic mode and Prometheus integration
- C. Azure Monitor for Containers with built-in Application Insights
- D. Third-party APM tool with OpenTelemetry export

**Correct Answer**: A

**Explanation**:
- **Correct**: Workspace-based Application Insights is the modern standard--it provides unified querying with other logs, sampling reduces costs while maintaining trace integrity, and custom metrics can drive KEDA autoscaling. [Learn more](https://learn.microsoft.com/azure/azure-monitor/app/create-workspace-resource)
- **Incorrect B**: Classic mode is deprecated. Prometheus doesn't provide distributed tracing.
- **Incorrect C**: Azure Monitor for Containers provides infrastructure metrics, not application-level traces.
- **Incorrect D**: Third-party tools add cost and complexity when native options meet requirements.

---

### Authentication and Authorization

**Q4.** Contoso is migrating to Azure and needs to provide their 500 consultants (external users) access to specific Azure resources. Consultants should use their own corporate credentials, access must be reviewable quarterly, and least privilege is mandatory. What should you recommend?

- A. Microsoft Entra B2B with access packages and access reviews
- B. Microsoft Entra B2C with custom policies
- C. Sync external users to Microsoft Entra ID with Entra Connect
- D. Create cloud-only accounts for each consultant

**Correct Answer**: A

**Explanation**:
- **Correct**: B2B collaboration with Entitlement Management (access packages) and access reviews is the enterprise pattern for external partner access. Users keep their own credentials, access is time-bound and reviewable, and lifecycle management is automated. [Learn more](https://learn.microsoft.com/entra/external-id/what-is-b2b)
- **Incorrect B**: B2C is for consumer-facing apps, not business partner collaboration.
- **Incorrect C**: Syncing external users violates identity sovereignty principles and complicates management.
- **Incorrect D**: Cloud-only accounts create credential sprawl and don't support quarterly reviews natively.

---

**Q5.** Wingtip Toys runs an e-commerce app on Azure App Service that needs to access Azure SQL Database, Azure Storage, and Azure Key Vault. The solution must have zero secrets in application code and support automatic credential rotation. What should you recommend?

- A. User-assigned managed identity for all services
- B. System-assigned managed identity for each App Service instance
- C. Service principal with certificate authentication stored in Key Vault
- D. Microsoft Entra application with client secret rotated monthly

**Correct Answer**: A

**Explanation**:
- **Correct**: User-assigned managed identity is the best choice when you need to share an identity across multiple resources (like deployment slots) or pre-configure access before resource creation. It provides zero-secret authentication and automatic credential management. [Learn more](https://learn.microsoft.com/entra/identity/managed-identities-azure-resources/overview)
- **Incorrect B**: System-assigned identities are tied to resource lifecycle--works but creates access management overhead with multiple instances.
- **Incorrect C**: Service principals with certificates still require certificate management--managed identity eliminates this entirely.
- **Incorrect D**: Client secrets require rotation management and risk exposure--never use when managed identity is available.

---

**Q6.** Fabrikam's financial services application must store database connection strings, API keys for third-party services, and SSL certificates. They require FIPS 140-2 Level 3 compliance, automatic secret rotation, and private network access only. What should you recommend?

- A. Azure Key Vault Premium with Private Link and managed identity access
- B. Azure Key Vault Standard with service endpoints
- C. Azure App Configuration with Key Vault references
- D. HashiCorp Vault deployed on AKS

**Correct Answer**: A

**Explanation**:
- **Correct**: Key Vault Premium provides HSM-backed keys (FIPS 140-2 Level 3), Private Link ensures no public internet exposure, and managed identity access eliminates secret-based authentication to the vault itself. [Learn more](https://learn.microsoft.com/azure/key-vault/general/private-link-service)
- **Incorrect B**: Standard tier is software-protected (Level 1), not Level 3. Service endpoints still traverse Microsoft backbone, not fully private.
- **Incorrect C**: App Configuration is for app settings, not secrets. It references Key Vault--doesn't replace it.
- **Incorrect D**: Self-managed Vault adds operational overhead when native service meets requirements.

---

**Q7.** Contoso needs to implement decentralized identity verification for their hiring process. Candidates should be able to present verified educational credentials from universities without Contoso directly contacting the university. What should you recommend?

- A. Microsoft Entra Verified ID with verifiable credentials
- B. Microsoft Entra B2B with identity proofing
- C. Microsoft Entra ID Protection with risk-based authentication
- D. Microsoft Entra Conditional Access with Terms of Use

**Correct Answer**: A

**Explanation**:
- **Correct**: Microsoft Entra Verified ID enables decentralized identity verification using W3C verifiable credentials standards. Universities can issue digital credentials that candidates store in their wallet and present to employers without the employer needing to contact the university directly. [Learn more](https://learn.microsoft.com/entra/verified-id/decentralized-identifier-overview)
- **Incorrect B**: B2B is for guest access, not credential verification.
- **Incorrect C**: ID Protection detects risky sign-ins, not credential verification.
- **Incorrect D**: Conditional Access controls access policies, not credential verification.

---

### Governance

**Q8.** Contoso needs to enforce that all resources in their Production subscription must have "CostCenter" and "Environment" tags. Missing tags should prevent resource creation. What should you recommend?

- A. Azure Policy with "Require a tag on resources" using Deny effect
- B. Azure Policy with "Inherit a tag from the resource group" using Modify effect
- C. ARM template deployment with mandatory parameters
- D. Azure Automation runbook to delete untagged resources nightly

**Correct Answer**: A

**Explanation**:
- **Correct**: Azure Policy with Deny effect prevents non-compliant resource creation at deployment time--this is the only way to enforce tagging proactively. Use the built-in "Require a tag on resources" policy for each required tag. [Learn more](https://learn.microsoft.com/azure/governance/policy/tutorials/govern-tags)
- **Incorrect B**: Modify effect auto-applies tags, which is useful for inheritance but doesn't enforce user-specified values like CostCenter.
- **Incorrect C**: ARM templates don't prevent portal or CLI deployments that skip the template.
- **Incorrect D**: Reactive deletion after creation violates the "prevent" requirement and causes service disruption.

---

**Q9.** Wingtip Toys has subscriptions across three Azure regions and needs to: (1) apply consistent security policies across all subscriptions, (2) allow DevOps teams to manage their own resource groups, and (3) prevent any team from disabling audit logging. What hierarchy and approach should you recommend?

- A. Root management group with security policies, child management groups per region, RBAC at resource group level
- B. One subscription per region with Deployment Stacks for governance
- C. Single subscription with resource groups per team and custom RBAC roles
- D. Separate Microsoft Entra tenants per region with cross-tenant sync

**Correct Answer**: A

**Explanation**:
- **Correct**: Management group hierarchy enables policy inheritance--security policies at root apply everywhere and can't be overridden by child scopes with Deny effects. Team RBAC at resource group level provides autonomy within guardrails. [Learn more](https://learn.microsoft.com/azure/governance/management-groups/overview)
- **Incorrect B**: Deployment Stacks are for resource lifecycle management, not ongoing governance enforcement at scale.
- **Incorrect C**: Single subscription limits scale and doesn't provide regional isolation or policy inheritance.
- **Incorrect D**: Multiple tenants create identity fragmentation--only justified for true organizational separation.

---

**Q10.** Fabrikam must demonstrate compliance with ISO 27001, SOC 2, and PCI DSS. They need continuous compliance monitoring, evidence collection for audits, and executive dashboards. What should you recommend?

- A. Microsoft Defender for Cloud with regulatory compliance dashboard and continuous export
- B. Azure Policy compliance view with custom initiative definitions
- C. Third-party GRC tool integrated via Azure Resource Graph
- D. Manual quarterly assessments using Azure Advisor

**Correct Answer**: A

**Explanation**:
- **Correct**: Defender for Cloud provides built-in regulatory compliance assessments mapped to industry standards (ISO, SOC, PCI), continuous monitoring, secure score for executives, and export to Log Analytics or SIEM for evidence retention. [Learn more](https://learn.microsoft.com/azure/defender-for-cloud/regulatory-compliance-dashboard)
- **Incorrect B**: Policy compliance shows policy state but doesn't map to regulatory frameworks directly.
- **Incorrect C**: Third-party tools add cost when native capabilities cover the requirements.
- **Incorrect D**: Quarterly manual assessments don't provide continuous monitoring.

---

**Q11.** Contoso wants to deploy consistent infrastructure across Dev, Test, and Production environments. They need to prevent accidental deletion of managed resources, allow rollback to previous configurations, and use Infrastructure as Code. Azure Blueprints is being deprecated. What should you recommend?

- A. Deployment Stacks with Bicep templates and deny settings
- B. ARM template deployments with resource locks
- C. Azure Resource Graph queries with Azure Automation remediation
- D. Terraform Cloud with Azure provider and state locking

**Correct Answer**: A

**Explanation**:
- **Correct**: Deployment Stacks is the replacement for Azure Blueprints (deprecated July 2026). It provides managed resource lifecycle, deny settings to prevent deletion/modification, and works with Bicep or ARM templates. Template Specs can store versioned templates for deployment via stacks. [Learn more](https://learn.microsoft.com/azure/azure-resource-manager/bicep/deployment-stacks)
- **Incorrect B**: Resource locks don't provide lifecycle management or rollback capabilities.
- **Incorrect C**: Resource Graph is for querying, not deploying or managing resources.
- **Incorrect D**: Terraform is valid but Deployment Stacks is the Azure-native Blueprints replacement.

---

**Q12.** Wingtip Toys needs to implement Cloud Security Posture Management (CSPM) across their Azure, AWS, and GCP environments. They require attack path analysis, data security posture for sensitive data stores, and AI workload security assessment. What should you recommend?

- A. Microsoft Defender CSPM plan with multicloud connectors
- B. Microsoft Defender for Cloud foundational CSPM (free tier)
- C. Azure Policy with custom compliance initiatives
- D. Third-party CSPM tool with API integrations

**Correct Answer**: A

**Explanation**:
- **Correct**: Defender CSPM (paid plan) provides advanced capabilities including attack path analysis, cloud security explorer, data security posture management for sensitive data discovery, and AI security posture management across Azure, AWS, and GCP. [Learn more](https://learn.microsoft.com/azure/defender-for-cloud/concept-cloud-security-posture-management)
- **Incorrect B**: Foundational (free) CSPM provides basic recommendations and secure score but lacks attack path analysis, data security posture, and AI security features.
- **Incorrect C**: Azure Policy provides compliance but not attack path analysis or multicloud coverage.
- **Incorrect D**: Native Defender CSPM meets all requirements without third-party cost.

---

## Domain 2: Data Storage Solutions (20-25%)

### Relational Data

**Q13.** Contoso's ERP system runs on SQL Server and needs: 99.99% SLA, automatic failover under 30 seconds, read replicas for reporting, and predictable costs. What should you recommend?

- A. Azure SQL Database Business Critical tier with zone redundancy and read scale-out
- B. Azure SQL Managed Instance Business Critical with auto-failover group
- C. SQL Server on Azure VMs with Always On availability groups
- D. Azure SQL Database Hyperscale with geo-replication

**Correct Answer**: A

**Explanation**:
- **Correct**: Business Critical tier provides 99.99% SLA with zone redundancy, built-in read replica for reporting (no extra cost), and automatic failover under 30 seconds using Always On technology under the hood. Predictable DTU or vCore pricing. [Learn more](https://learn.microsoft.com/azure/azure-sql/database/service-tier-business-critical)
- **Incorrect B**: Managed Instance is for lift-and-shift with SQL Server compatibility needs--adds complexity if not required.
- **Incorrect C**: VMs require manual HA configuration and don't provide 99.99% SLA.
- **Incorrect D**: Hyperscale is for databases exceeding 4TB--adds cost and complexity for standard workloads.

---

**Q14.** Wingtip Toys has 15 databases with unpredictable usage patterns--some spike during sales events while others are idle. They need cost optimization while maintaining performance during peaks. What should you recommend?

- A. Azure SQL Database elastic pools with Premium tier
- B. Serverless compute tier for each database
- C. Single Azure SQL Database with Hyperscale
- D. Azure SQL Managed Instance with multiple databases

**Correct Answer**: A

**Explanation**:
- **Correct**: Elastic pools share resources across multiple databases--idle databases release resources that active ones can consume. This is the definitive solution for variable, unpredictable multi-database workloads. Premium tier ensures performance during peaks. [Learn more](https://learn.microsoft.com/azure/azure-sql/database/elastic-pool-overview)
- **Incorrect B**: Serverless is per-database and has cold start latency--not ideal for spike scenarios.
- **Incorrect C**: Single database doesn't address multi-database resource sharing.
- **Incorrect D**: Managed Instance pools have higher baseline cost and are for SQL Server compatibility scenarios.

---

**Q15.** Fabrikam has a development database that is used intermittently during business hours and idle overnight and weekends. They want to minimize costs while avoiding cold start delays when developers need the database. What should you recommend?

- A. Azure SQL Database serverless tier with auto-pause delay of 1 hour
- B. Azure SQL Database Basic tier with scheduled start/stop
- C. Azure SQL Database General Purpose with auto-scale
- D. Azure SQL Managed Instance with reserved capacity

**Correct Answer**: A

**Explanation**:
- **Correct**: Serverless compute tier automatically scales based on workload demand and can auto-pause during inactive periods (only storage is billed). The auto-pause delay can be configured (minimum 1 hour) to balance cost savings with avoiding cold starts during active development periods. [Learn more](https://learn.microsoft.com/azure/azure-sql/database/serverless-tier-overview)
- **Incorrect B**: Basic tier doesn't auto-pause; scheduled start/stop requires automation.
- **Incorrect C**: General Purpose doesn't auto-pause or scale to zero.
- **Incorrect D**: Managed Instance is over-engineered for a dev database and doesn't auto-pause.

---

**Q16.** Contoso needs to protect their Azure SQL databases against accidental deletion, point-in-time recovery up to 35 days, and long-term retention for 7 years for compliance. What should you recommend?

- A. Azure SQL built-in PITR with long-term retention (LTR) policies
- B. Azure Backup for Azure SQL with 7-year retention vault
- C. Database export to Azure Storage with lifecycle management
- D. SQL Server native backup to Azure Blob with customer-managed keys

**Correct Answer**: A

**Explanation**:
- **Correct**: Azure SQL Database includes automatic backups with PITR up to 35 days. Long-term retention (LTR) extends this to 10+ years using full backups stored in RA-GRS storage. No additional service required. [Learn more](https://learn.microsoft.com/azure/azure-sql/database/long-term-retention-overview)
- **Incorrect B**: Azure Backup doesn't support Azure SQL Database--it's for VMs and Managed Instance.
- **Incorrect C**: Export (BACPAC) requires manual orchestration and doesn't support PITR.
- **Incorrect D**: Native backup is for SQL Server VMs, not Azure SQL Database PaaS.

---

### Semi-Structured and Unstructured Data

**Q17.** Contoso needs to store IoT telemetry data (JSON documents) with: millisecond latency reads/writes, automatic partitioning, global distribution across 5 regions, and guaranteed 99.999% availability. What should you recommend?

- A. Azure Cosmos DB for NoSQL with multi-region writes
- B. Azure SQL Database Hyperscale with geo-replication
- C. Azure Table Storage with GRS replication
- D. MongoDB Atlas deployed on Azure

**Correct Answer**: A

**Explanation**:
- **Correct**: Cosmos DB for NoSQL provides single-digit millisecond latency, automatic partitioning, multi-region writes with conflict resolution, and 99.999% SLA with multi-region configuration. Purpose-built for this scenario. [Learn more](https://learn.microsoft.com/azure/cosmos-db/introduction)
- **Incorrect B**: SQL Database is relational--schema rigidity doesn't suit variable IoT telemetry. Max 4 geo-replicas.
- **Incorrect C**: Table Storage lacks global distribution, indexing, and has higher latency.
- **Incorrect D**: Third-party service when native Cosmos DB meets requirements adds vendor dependency.

---

**Q18.** Wingtip Toys is designing a Cosmos DB solution for their e-commerce catalog. They expect 500,000 products with queries primarily by category and product ID. Some queries need to filter by price range within a category. What partition key strategy should you recommend?

- A. Hierarchical partition key with CategoryId as first level and ProductId as second level
- B. Single partition key on ProductId only
- C. Single partition key on CategoryId only
- D. Synthetic partition key combining CategoryId and random suffix

**Correct Answer**: A

**Explanation**:
- **Correct**: Hierarchical partition keys allow multi-level partitioning, enabling efficient queries that filter on CategoryId (first level) while avoiding the 20GB logical partition limit per category. Queries targeting CategoryId are scoped to relevant partitions. [Learn more](https://learn.microsoft.com/azure/cosmos-db/hierarchical-partition-keys)
- **Incorrect B**: ProductId alone would create optimal distribution but requires cross-partition queries for category-based lookups.
- **Incorrect C**: CategoryId alone could create hot partitions for popular categories and hit the 20GB limit.
- **Incorrect D**: Random suffix breaks category-based query efficiency.

---

**Q19.** Fabrikam needs to store financial documents with: write-once-read-many (WORM) compliance, 7-year retention, ransomware protection, and audit trail of all access. What should you recommend?

- A. Azure Blob Storage with immutable storage policy (time-based retention) and storage analytics logging
- B. Azure Files with soft delete and Microsoft Entra authentication
- C. Azure Disk Storage with encryption at rest
- D. Azure Archive Storage with manual legal holds

**Correct Answer**: A

**Explanation**:
- **Correct**: Immutable blob storage with time-based retention provides SEC 17a-4(f) compliant WORM storage. Combined with storage analytics logging, you get full audit trails. Versioning provides ransomware protection. [Learn more](https://learn.microsoft.com/azure/storage/blobs/immutable-storage-overview)
- **Incorrect B**: Files doesn't support WORM policies.
- **Incorrect C**: Disk storage is for VMs, not document storage.
- **Incorrect D**: Archive tier is a storage tier, not a compliance feature. Manual holds don't meet automated WORM requirements.

---

**Q20.** Contoso's global application requires session consistency for user-facing operations but can tolerate eventual consistency for analytics queries. They want to minimize RU consumption while ensuring users always see their own writes. What Cosmos DB consistency configuration should you recommend?

- A. Default consistency of Session with per-request override to Eventual for analytics
- B. Default consistency of Strong for all operations
- C. Default consistency of Eventual with per-request override to Strong for user operations
- D. Bounded staleness consistency for all operations

**Correct Answer**: A

**Explanation**:
- **Correct**: Session consistency is the default and most widely used level--it guarantees read-your-writes within a session while providing good performance. Analytics queries can override to Eventual consistency at the request level to reduce RU consumption. Consistency can only be relaxed, not strengthened at request level. [Learn more](https://learn.microsoft.com/azure/cosmos-db/consistency-levels)
- **Incorrect B**: Strong consistency has highest latency and RU cost--overkill when session suffices.
- **Incorrect C**: You cannot strengthen consistency at request level, only relax it.
- **Incorrect D**: Bounded staleness adds complexity and is for specific geo-replication scenarios.

---

### Data Integration

**Q21.** Wingtip Toys needs to integrate data from on-premises SQL Server, SaaS applications (Salesforce, SAP), and Azure SQL Database into Azure Synapse Analytics. Transformations include data cleansing, aggregation, and slowly changing dimensions. What should you recommend?

- A. Azure Data Factory with mapping data flows and Synapse Pipeline integration
- B. Azure Synapse Spark pools with custom notebooks
- C. Azure Logic Apps with SQL connectors
- D. Azure Stream Analytics with reference data

**Correct Answer**: A

**Explanation**:
- **Correct**: Data Factory is the enterprise ETL/ELT service with 100+ native connectors (including Salesforce, SAP, on-premises via IR). Mapping data flows provide visual transformation including SCD handling. Native Synapse integration. [Learn more](https://learn.microsoft.com/azure/data-factory/introduction)
- **Incorrect B**: Spark is for big data processing, not ETL orchestration with SaaS connectors.
- **Incorrect C**: Logic Apps is for workflow automation, not high-volume data integration.
- **Incorrect D**: Stream Analytics is for real-time streaming, not batch ETL.

---

## Domain 3: Business Continuity Solutions (15-20%)

### Backup and Disaster Recovery

**Q22.** Wingtip Toys runs mission-critical workloads on Azure VMs and needs: RPO < 15 minutes, RTO < 1 hour, cross-region failover, and automated failback after recovery. What should you recommend?

- A. Azure Site Recovery with recovery plans and automation runbooks
- B. Azure Backup with cross-region restore
- C. VM snapshots replicated to secondary region
- D. Custom replication using AzCopy and Azure Automation

**Correct Answer**: A

**Explanation**:
- **Correct**: Site Recovery provides continuous replication (RPO ~30 seconds possible), recovery plans for multi-VM orchestration, automation runbooks for post-failover configuration, and failback capability. Sub-hour RTO is achievable. [Learn more](https://learn.microsoft.com/azure/site-recovery/site-recovery-overview)
- **Incorrect B**: Backup is for data protection, not DR. Restore creates new VMs (longer RTO), no failback.
- **Incorrect C**: Snapshots are point-in-time, not continuous. No orchestration or failback.
- **Incorrect D**: Custom solutions don't meet enterprise RPO/RTO requirements reliably.

---

**Q23.** Fabrikam needs to back up their Azure SQL databases, Azure Files shares, and Azure VMs to a central location with: 30-day instant recovery, 1-year monthly retention, RBAC-controlled access, and soft delete protection. What should you recommend?

- A. Azure Backup with Recovery Services vault, RBAC, and soft delete enabled
- B. Azure SQL long-term retention with storage account backups
- C. Snapshots stored in a dedicated storage account
- D. Third-party backup solution with Azure integration

**Correct Answer**: A

**Explanation**:
- **Correct**: Recovery Services vault is the unified backup solution for VMs, SQL, and Files. It provides instant recovery (VM restore < 15 mins), flexible retention policies, built-in RBAC, and soft delete for ransomware protection. [Learn more](https://learn.microsoft.com/azure/backup/backup-overview)
- **Incorrect B**: SQL LTR is database-only and doesn't cover VMs or Files.
- **Incorrect C**: Snapshots don't provide centralized management, RBAC, or soft delete.
- **Incorrect D**: Native solution meets all requirements--no need for third-party.

---

**Q24.** Contoso needs to protect their on-premises VMware environment with Azure-based disaster recovery. Requirements: minimize on-premises infrastructure changes, RPO < 1 hour, and recovery to Azure VMs. What should you recommend?

- A. Azure Site Recovery with agentless VMware replication
- B. Azure Migrate with VMware migration capability
- C. Azure Backup Server (MABS) with cloud backup
- D. Veeam Backup & Replication with Azure integration

**Correct Answer**: A

**Explanation**:
- **Correct**: Site Recovery supports agentless VMware replication to Azure--minimal on-premises changes (just appliance deployment). Provides continuous replication, orchestrated failover, and recovery to Azure VMs. [Learn more](https://learn.microsoft.com/azure/site-recovery/vmware-azure-about-disaster-recovery)
- **Incorrect B**: Azure Migrate is for migration, not ongoing DR protection.
- **Incorrect C**: MABS is backup-focused, not real-time DR with sub-hour RPO.
- **Incorrect D**: Veeam is a third-party option--valid but not the Azure-native answer.

---

### High Availability

**Q25.** Wingtip Toys needs their web tier to survive a complete datacenter failure within an Azure region. The solution must be automatic and maintain session state. What should you recommend?

- A. Virtual machines in Availability Zones with Azure Load Balancer Standard (zone-redundant)
- B. Virtual machines in an Availability Set with Load Balancer Basic
- C. Single VM with Premium SSD and Azure Backup
- D. Virtual Machine Scale Sets with overprovisioning

**Correct Answer**: A

**Explanation**:
- **Correct**: Availability Zones are physically separate datacenters within a region. Zone-redundant Load Balancer distributes traffic across zones and automatically routes around zone failures. This survives datacenter-level failures. [Learn more](https://learn.microsoft.com/azure/availability-zones/az-overview)
- **Incorrect B**: Availability Sets protect against rack/update domain failures, not datacenter failures.
- **Incorrect C**: Single VM has no HA. Backup doesn't provide instant failover.
- **Incorrect D**: VMSS without zone distribution doesn't survive datacenter failure.

---

**Q26.** Fabrikam's SQL database needs 99.995% availability with automatic failover to a secondary region. Read workloads should use the secondary for performance. What should you recommend?

- A. Azure SQL Database with auto-failover group and readable secondary
- B. Azure SQL Database with active geo-replication
- C. Azure SQL Managed Instance with log shipping
- D. SQL Server on VMs with Always On availability groups

**Correct Answer**: A

**Explanation**:
- **Correct**: Auto-failover groups provide automatic failover with listener endpoint (app connection string doesn't change), and the secondary is readable by default for read scale-out. 99.995% SLA with zone redundancy. [Learn more](https://learn.microsoft.com/azure/azure-sql/database/auto-failover-group-overview)
- **Incorrect B**: Geo-replication requires manual failover and connection string changes.
- **Incorrect C**: Managed Instance log shipping is deprecated--use failover groups.
- **Incorrect D**: VMs require manual HA configuration and have lower SLA.

---

**Q27.** Contoso operates a multi-region application and needs their Cosmos DB to remain available even if an entire Azure region goes offline. They need automatic failover with minimal data loss. What should you recommend?

- A. Cosmos DB with multi-region writes and automatic failover enabled
- B. Cosmos DB with single write region and manual failover
- C. Cosmos DB with strong consistency and single region
- D. Multiple Cosmos DB accounts with application-level failover

**Correct Answer**: A

**Explanation**:
- **Correct**: Multi-region writes (active-active) provides 99.999% availability SLA and automatic failover. Each region can accept writes, so region failure doesn't impact write availability. Conflict resolution handles concurrent writes. [Learn more](https://learn.microsoft.com/azure/cosmos-db/high-availability)
- **Incorrect B**: Single write region with manual failover requires operator intervention during outage.
- **Incorrect C**: Single region provides no geo-redundancy.
- **Incorrect D**: Multiple accounts require complex application-level synchronization.

---

**Q28.** Wingtip Toys needs to ensure their Azure Kubernetes Service cluster remains available during planned maintenance and zone failures. Pods should be distributed across zones and nodes should be updated without service disruption. What should you recommend?

- A. AKS cluster spanning availability zones with pod disruption budgets and node surge upgrades
- B. Multiple AKS clusters with Azure Front Door load balancing
- C. Single-zone AKS cluster with multiple node pools
- D. AKS with Azure CNI and availability sets

**Correct Answer**: A

**Explanation**:
- **Correct**: Zone-spanning AKS distributes nodes across availability zones. Pod disruption budgets ensure minimum replicas during maintenance. Node surge upgrades add capacity before removing old nodes to prevent service disruption. [Learn more](https://learn.microsoft.com/azure/aks/availability-zones)
- **Incorrect B**: Multiple clusters add significant operational complexity when single zone-redundant cluster suffices.
- **Incorrect C**: Single-zone doesn't survive zone failures.
- **Incorrect D**: Availability sets are for VMs, not AKS zone redundancy.

---

## Domain 4: Infrastructure Solutions (30-35%)

### Compute Solutions

**Q29.** Contoso needs to run a legacy .NET Framework 4.7 application that requires Windows Server with specific IIS configurations and local disk state. Minimal cloud rearchitecting is acceptable. What should you recommend?

- A. Azure Virtual Machines with Availability Zones
- B. Azure App Service with Windows containers
- C. Azure Container Apps with custom image
- D. Azure Kubernetes Service with Windows node pools

**Correct Answer**: A

**Explanation**:
- **Correct**: Legacy .NET Framework with specific IIS configurations and local disk state screams "lift and shift." VMs provide full Windows Server control, minimal rearchitecting, and Availability Zones for HA. [Learn more](https://learn.microsoft.com/azure/virtual-machines/windows/overview)
- **Incorrect B**: App Service requires app packaging changes and doesn't support arbitrary IIS configs.
- **Incorrect C**: Container Apps doesn't support Windows containers.
- **Incorrect D**: AKS Windows nodes add orchestration complexity for a single legacy app.

---

**Q30.** Wingtip Toys is building a new microservices-based order processing system. Requirements: event-driven scaling, Dapr integration for state and pub/sub, minimal infrastructure management, and cost optimization during low traffic. What should you recommend?

- A. Azure Container Apps with Dapr components and scale-to-zero
- B. Azure Kubernetes Service with KEDA and Dapr
- C. Azure Functions with Durable Functions orchestration
- D. Azure App Service with deployment slots

**Correct Answer**: A

**Explanation**:
- **Correct**: Container Apps is purpose-built for this: native Dapr integration (state, pub/sub, secrets), KEDA-based event scaling, scale-to-zero (no cost when idle), and no cluster management. [Learn more](https://learn.microsoft.com/azure/container-apps/overview)
- **Incorrect B**: AKS provides more control but requires cluster management--overkill if Container Apps features suffice.
- **Incorrect C**: Functions are for event-triggered code, not containerized microservices with Dapr.
- **Incorrect D**: App Service doesn't support Dapr or scale-to-zero.

---

**Q31.** Fabrikam needs to process 10 million financial calculations nightly. Each calculation is independent and takes 2-5 seconds. Results must be stored in Azure SQL Database. Cost optimization is critical. What should you recommend?

- A. Azure Batch with low-priority VMs and auto-scaling pools
- B. Azure Functions Consumption plan with queue trigger
- C. Azure Kubernetes Service with horizontal pod autoscaler
- D. Azure Virtual Machines with Azure Automation scheduling

**Correct Answer**: A

**Explanation**:
- **Correct**: Azure Batch is designed for large-scale parallel batch processing. Low-priority VMs reduce cost by 60-90%, auto-scaling spins up nodes only during processing, and the service handles job scheduling and retry. [Learn more](https://learn.microsoft.com/azure/batch/batch-technical-overview)
- **Incorrect B**: Functions have 5-minute (Consumption) or 60-minute (Premium) timeout limits--not suitable for millions of calculations.
- **Incorrect C**: AKS adds operational overhead for batch workloads.
- **Incorrect D**: Manual VM management doesn't provide the scheduling, scaling, or cost optimization of Batch.

---

**Q32.** Contoso is deploying an AI-powered customer service application that uses Azure OpenAI. They need high availability across regions, load balancing between multiple OpenAI deployments, and the ability to fall back to a secondary model if the primary is throttled. What should you recommend?

- A. Azure API Management gateway in front of multiple Azure OpenAI instances with retry policies
- B. Azure Front Door with backend pools pointing to Azure OpenAI endpoints
- C. Direct application calls to Azure OpenAI with client-side retry logic
- D. Azure Load Balancer Standard with Azure OpenAI backend

**Correct Answer**: A

**Explanation**:
- **Correct**: A gateway pattern (APIM or custom) in front of multiple Azure OpenAI instances provides intelligent routing, retry policies for throttling (429 errors), load balancing across deployments/instances, and fallback to secondary models. This is the recommended enterprise pattern for Azure OpenAI. [Learn more](https://learn.microsoft.com/azure/architecture/ai-ml/guide/azure-openai-gateway-multi-backend)
- **Incorrect B**: Front Door is for HTTP load balancing but lacks the API-specific throttle handling and model routing logic.
- **Incorrect C**: Client-side retry doesn't provide cross-instance load balancing or centralized policy management.
- **Incorrect D**: Load Balancer is Layer 4--doesn't understand HTTP/API semantics for intelligent routing.

---

### Application Architecture

**Q33.** Contoso needs to process real-time IoT telemetry from 100,000 devices. Requirements: ingest millions of events per second, 7-day retention, Spark integration for analytics, and Kafka compatibility for existing producers. What should you recommend?

- A. Azure Event Hubs with Kafka endpoint and Capture to ADLS Gen2
- B. Azure Service Bus Premium with sessions and partitioning
- C. Azure IoT Hub with message routing
- D. Apache Kafka on Azure HDInsight

**Correct Answer**: A

**Explanation**:
- **Correct**: Event Hubs is designed for massive event ingestion (millions/second), provides Kafka API compatibility for existing producers, Capture feature writes to ADLS for Spark analytics, and supports up to 7-day retention. [Learn more](https://learn.microsoft.com/azure/event-hubs/event-hubs-about)
- **Incorrect B**: Service Bus is for enterprise messaging (reliable delivery), not high-throughput telemetry.
- **Incorrect C**: IoT Hub adds device management features--unnecessary if devices can use Kafka protocol.
- **Incorrect D**: Self-managed Kafka adds operational overhead when Event Hubs provides native Kafka compatibility.

---

**Q34.** Wingtip Toys needs to orchestrate order processing across multiple microservices: payment validation, inventory check, shipping, and notification. Each step can fail and requires compensation logic. What should you recommend?

- A. Azure Service Bus with sessions and the saga pattern implemented in application code
- B. Azure Logic Apps with error handling and retry policies
- C. Azure Event Grid with webhook subscriptions
- D. Azure Queue Storage with poison queue handling

**Correct Answer**: A

**Explanation**:
- **Correct**: Service Bus sessions ensure message ordering per order ID (critical for sagas), and the saga pattern with compensation transactions handles distributed failures. This is the enterprise pattern for choreographed microservices. [Learn more](https://learn.microsoft.com/azure/architecture/reference-architectures/saga/saga)
- **Incorrect B**: Logic Apps is for workflow orchestration, not high-throughput transaction processing with custom compensation.
- **Incorrect C**: Event Grid is for event routing, not ordered message processing with sessions.
- **Incorrect D**: Queue Storage lacks sessions, transactions, and dead-letter capabilities.

---

**Q35.** Fabrikam exposes APIs to partners and needs: rate limiting, API key management, developer portal, request/response transformation, and backend protection. What should you recommend?

- A. Azure API Management with policies and developer portal
- B. Azure Application Gateway with WAF
- C. Azure Front Door with rules engine
- D. Azure Functions with HTTP trigger and custom middleware

**Correct Answer**: A

**Explanation**:
- **Correct**: APIM is the purpose-built API gateway: rate limiting policies, subscription keys, built-in developer portal, transformation policies, and backends are secured (no direct internet access). [Learn more](https://learn.microsoft.com/azure/api-management/api-management-key-concepts)
- **Incorrect B**: App Gateway is a load balancer with WAF, not an API management platform.
- **Incorrect C**: Front Door is a global load balancer, not API lifecycle management.
- **Incorrect D**: Custom code doesn't provide developer portal, subscription management, or enterprise API features.

---

**Q36.** Contoso needs to cache frequently accessed product data to reduce SQL Database load. Requirements: sub-millisecond latency, data structures (lists, sets, sorted sets), and geo-replication for global reads. What should you recommend?

- A. Azure Cache for Redis Enterprise with active geo-replication
- B. Azure Cache for Redis Premium with clustering
- C. Azure Cosmos DB with session consistency
- D. Azure CDN with dynamic site acceleration

**Correct Answer**: A

**Explanation**:
- **Correct**: Redis Enterprise provides sub-millisecond performance, native Redis data structures, and active-active geo-replication for global deployments. This is the enterprise caching solution. [Learn more](https://learn.microsoft.com/azure/azure-cache-for-redis/cache-overview)
- **Incorrect B**: Premium tier doesn't support active geo-replication (only passive geo-replication).
- **Incorrect C**: Cosmos DB is a database, not a cache. Higher latency and cost for caching use case.
- **Incorrect D**: CDN caches HTTP responses, not application data structures.

---

### Migrations

**Q37.** Wingtip Toys needs to migrate 500 on-premises servers to Azure. Requirements: discover dependencies, right-size recommendations, and assess cost impact before migration. What should you recommend?

- A. Azure Migrate with dependency analysis and assessment
- B. Azure Site Recovery with test failover
- C. Azure Resource Mover between regions
- D. Manual assessment using Azure Pricing Calculator

**Correct Answer**: A

**Explanation**:
- **Correct**: Azure Migrate is the migration hub: agent-based or agentless discovery, dependency visualization, right-sizing based on utilization, and Azure cost estimation--all before touching production. [Learn more](https://learn.microsoft.com/azure/migrate/migrate-services-overview)
- **Incorrect B**: Site Recovery is for replication and DR, not discovery and assessment.
- **Incorrect C**: Resource Mover is for moving Azure resources between regions, not on-premises migration.
- **Incorrect D**: Manual assessment doesn't scale to 500 servers and lacks dependency analysis.

---

**Q38.** Fabrikam needs to migrate a 5TB Oracle database to Azure with minimal downtime. They're open to replatforming to Azure Database for PostgreSQL. What should you recommend?

- A. Azure Database Migration Service with continuous sync for cutover
- B. Oracle Data Pump export and PostgreSQL import
- C. Azure Data Factory with Oracle connector
- D. Backup and restore using Azure Storage

**Correct Answer**: A

**Explanation**:
- **Correct**: DMS supports Oracle to Azure Database for PostgreSQL migration with continuous sync--changes are replicated until cutover, minimizing downtime. It handles schema conversion and data migration. [Learn more](https://learn.microsoft.com/azure/dms/tutorial-oracle-azure-postgresql-online)
- **Incorrect B**: Data Pump export/import requires downtime for the entire 5TB transfer.
- **Incorrect C**: Data Factory is for data integration, not database migration with schema conversion.
- **Incorrect D**: Backup/restore doesn't support Oracle to PostgreSQL conversion.

---

### Network Solutions

**Q39.** Contoso has 20 branch offices and needs to connect them to Azure and each other. Requirements: centralized security policies, SD-WAN integration, and simplified management. What should you recommend?

- A. Azure Virtual WAN with secured hubs and SD-WAN partner integration
- B. Hub-spoke topology with Azure Firewall
- C. Site-to-site VPN with BGP peering
- D. ExpressRoute with multiple circuits

**Correct Answer**: A

**Explanation**:
- **Correct**: Virtual WAN is designed for large-scale branch connectivity: any-to-any transit, integrated SD-WAN partners, secured hubs (Azure Firewall/NVA), and Microsoft-managed routing. Simplifies 20+ branch management. [Learn more](https://learn.microsoft.com/azure/virtual-wan/virtual-wan-about)
- **Incorrect B**: Hub-spoke requires manual peering and routing--doesn't scale well for 20 branches.
- **Incorrect C**: S2S VPN doesn't provide centralized security or SD-WAN integration.
- **Incorrect D**: ExpressRoute is for dedicated private connectivity, not branch office SD-WAN scenarios.

---

**Q40.** Wingtip Toys needs to access Azure SQL Database, Storage, and Key Vault from their VNet without traffic traversing the public internet. Data exfiltration prevention is required. What should you recommend?

- A. Azure Private Link with private endpoints for each service
- B. Service Endpoints with service endpoint policies
- C. VNet integration with subnet delegation
- D. NAT Gateway with static outbound IP

**Correct Answer**: A

**Explanation**:
- **Correct**: Private Link creates a private IP in your VNet for each PaaS service--traffic never leaves Microsoft's network. Combined with disabling public access, this prevents data exfiltration. [Learn more](https://learn.microsoft.com/azure/private-link/private-link-overview)
- **Incorrect B**: Service Endpoints route traffic through Microsoft backbone but use public IPs. Policies help but don't provide full private access.
- **Incorrect C**: VNet integration is for outbound from PaaS (like App Service), not inbound to PaaS.
- **Incorrect D**: NAT Gateway is for outbound internet connectivity, not private PaaS access.

---

**Q41.** Fabrikam's web application needs: global load balancing, TLS termination, WAF protection, and automatic failover between regions. What should you recommend?

- A. Azure Front Door with WAF and health probes
- B. Azure Application Gateway in each region with Traffic Manager
- C. Azure Load Balancer Standard with cross-region configuration
- D. Azure CDN with custom rules engine

**Correct Answer**: A

**Explanation**:
- **Correct**: Front Door is the global load balancer with built-in WAF, TLS termination at edge, intelligent routing based on latency/health, and automatic regional failover. One service, global reach. [Learn more](https://learn.microsoft.com/azure/frontdoor/front-door-overview)
- **Incorrect B**: App Gateway + Traffic Manager works but requires managing multiple App Gateways and doesn't provide edge WAF.
- **Incorrect C**: Load Balancer is Layer 4--no TLS termination or WAF.
- **Incorrect D**: CDN is for content caching, not application load balancing.

---

**Q42.** Contoso needs dedicated, private connectivity to Azure with: 10 Gbps bandwidth, predictable latency, and access to all Azure regions from their primary datacenter. What should you recommend?

- A. ExpressRoute with Global Reach and Microsoft peering
- B. Site-to-site VPN with multiple tunnels
- C. Azure Virtual WAN with VPN hub
- D. ExpressRoute Local circuit

**Correct Answer**: A

**Explanation**:
- **Correct**: ExpressRoute provides dedicated private connectivity up to 100 Gbps. Global Reach connects on-premises through Azure backbone to all regions. Microsoft peering enables access to Microsoft 365 and Azure PaaS. [Learn more](https://learn.microsoft.com/azure/expressroute/expressroute-introduction)
- **Incorrect B**: VPN uses public internet--doesn't provide predictable latency or 10 Gbps sustained.
- **Incorrect C**: Virtual WAN with VPN still uses internet tunnels.
- **Incorrect D**: ExpressRoute Local is limited to local Azure regions only--doesn't meet "all regions" requirement.

---

### Advanced Scenarios

**Q43.** Contoso is implementing a Zero Trust architecture. Their Azure resources need to be accessed only from compliant devices, with conditional access based on user risk, and all network traffic inspected. What combination should you recommend?

- A. Microsoft Entra Conditional Access + Microsoft Intune compliance + Azure Firewall Premium with TLS inspection
- B. Network Security Groups + Microsoft Entra MFA + Application Gateway WAF
- C. Azure Private Link + Service Endpoints + Basic Azure Firewall
- D. ExpressRoute + Just-in-Time VM Access + Azure Bastion

**Correct Answer**: A

**Explanation**:
- **Correct**: Zero Trust requires: (1) verify explicitly with Conditional Access + device compliance via Intune, (2) least privilege through Conditional Access policies, (3) assume breach with network inspection via Azure Firewall Premium TLS decryption. [Learn more](https://learn.microsoft.com/azure/security/fundamentals/zero-trust)
- **Incorrect B**: NSGs don't inspect traffic content. MFA alone isn't device compliance.
- **Incorrect C**: Network controls without identity verification doesn't implement Zero Trust.
- **Incorrect D**: These are good security features but don't address device compliance or traffic inspection.

---

**Q44.** Wingtip Toys needs to deploy the same application stack across Dev, Test, and Production environments with consistent governance but different scaling. Infrastructure must be version-controlled and deployable via CI/CD. What should you recommend?

- A. Bicep modules with parameter files per environment, deployed via GitHub Actions
- B. ARM templates with nested deployments
- C. Deployment Stacks with Template Specs for versioned storage
- D. Terraform with separate state files per environment

**Correct Answer**: A

**Explanation**:
- **Correct**: Bicep is Microsoft's recommended IaC language: cleaner syntax than ARM, native VS Code support, modules for reusability, and parameter files for environment-specific values. GitHub Actions for CI/CD. [Learn more](https://learn.microsoft.com/azure/azure-resource-manager/bicep/overview)
- **Incorrect B**: ARM templates work but Bicep is preferred (simpler, better tooling).
- **Incorrect C**: Deployment Stacks manage deployed resources--Bicep handles the template definition.
- **Incorrect D**: Terraform is valid but Bicep is the Azure-native choice with better integration.

---

**Q45.** Fabrikam needs to implement a cost management strategy for their Azure environment. Requirements: budget alerts, resource rightsizing recommendations, reserved instance optimization, and chargeback to departments. What should you recommend?

- A. Microsoft Cost Management with budgets, Azure Advisor, Reservations, and cost allocation rules
- B. Azure Monitor with custom metrics and Log Analytics
- C. Third-party FinOps tool with Azure integration
- D. Custom Power BI reports from Azure Resource Graph

**Correct Answer**: A

**Explanation**:
- **Correct**: Cost Management is the native FinOps solution: budgets with alerts, Advisor recommendations for rightsizing and reservations, cost allocation rules for chargeback by tags. All included at no extra cost. [Learn more](https://learn.microsoft.com/azure/cost-management-billing/costs/overview-cost-management)
- **Incorrect B**: Azure Monitor is for operational metrics, not cost management.
- **Incorrect C**: Native tools meet requirements--no need for third-party cost.
- **Incorrect D**: Resource Graph provides resource inventory, not cost analysis.

---

**Q46.** Contoso needs to deploy a highly available application with: frontend web tier, API tier, and database tier. Each tier should scale independently, and the database should have read replicas. What architecture should you recommend?

- A. App Service with auto-scale + API Management + Azure SQL with read scale-out
- B. Single VM with all tiers + Azure Load Balancer
- C. AKS cluster with all services + Cosmos DB
- D. Virtual Machine Scale Sets for all tiers + SQL Server on VM

**Correct Answer**: A

**Explanation**:
- **Correct**: Tiered PaaS architecture: App Service provides auto-scale for web/API tiers, APIM provides API governance and caching, SQL Database read scale-out handles reporting without impacting transactions. Each tier scales independently. [Learn more](https://learn.microsoft.com/azure/architecture/reference-architectures/app-service-web-app/scalable-web-app)
- **Incorrect B**: Single VM is not highly available or independently scalable.
- **Incorrect C**: AKS adds orchestration complexity; Cosmos DB isn't justified for structured transactional data.
- **Incorrect D**: VMSS requires more management than PaaS and doesn't provide native read replicas.

---

**Q47.** Wingtip Toys is planning a cloud adoption initiative using the Microsoft Cloud Adoption Framework. They need to establish a landing zone with: identity integration, network connectivity, governance policies, and monitoring. What should you recommend?

- A. Azure Landing Zone accelerator with platform and application landing zones
- B. Custom ARM templates for each resource type
- C. Manual Azure Portal configuration with screenshots for documentation
- D. Third-party cloud management platform

**Correct Answer**: A

**Explanation**:
- **Correct**: Azure Landing Zone accelerator implements CAF best practices: management group hierarchy, identity with Microsoft Entra ID, hub-spoke or Virtual WAN networking, Azure Policy for governance, and centralized logging. Reference architecture with deployment automation. [Learn more](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/)
- **Incorrect B**: Custom templates miss CAF governance patterns and require significant effort.
- **Incorrect C**: Portal configuration doesn't scale or version control.
- **Incorrect D**: Native Azure Landing Zone meets requirements without third-party dependency.

---

**Q48.** Fabrikam's application requires real-time data synchronization between Azure SQL Database in East US and Cosmos DB in West Europe for low-latency reads. Changes in either database should propagate to the other. What should you recommend?

- A. Azure Data Factory with change data capture (CDC) triggers and bi-directional pipelines
- B. Azure SQL to Cosmos DB Change Feed with custom sync function
- C. Azure Synapse Link for SQL
- D. Database replication using Azure Site Recovery

**Correct Answer**: A

**Explanation**:
- **Correct**: Data Factory with CDC captures incremental changes from SQL (via CT/CDC), and Cosmos DB Change Feed can trigger pipelines for reverse sync. Bi-directional pipelines handle both directions. [Learn more](https://learn.microsoft.com/azure/data-factory/concepts-change-data-capture)
- **Incorrect B**: Change Feed is Cosmos-outbound only--doesn't capture SQL changes.
- **Incorrect C**: Synapse Link is for analytics, not operational sync.
- **Incorrect D**: Site Recovery is for disaster recovery, not data synchronization between different database engines.

---

**Q49.** Contoso is building a RAG (Retrieval-Augmented Generation) application using Azure OpenAI. They need to ground the AI responses in their enterprise documents stored in various formats. The solution should provide semantic search with hybrid ranking. What should you recommend?

- A. Azure AI Search with integrated vectorization and Azure OpenAI for completions
- B. Azure Cosmos DB with vector search and custom embeddings
- C. Azure Blob Storage with Azure OpenAI direct file access
- D. SQL Server full-text search with Azure OpenAI integration

**Correct Answer**: A

**Explanation**:
- **Correct**: Azure AI Search provides integrated vectorization (no separate embedding code needed), hybrid search combining keyword and vector similarity, semantic reranking, and works as a data source for Azure OpenAI "On Your Data" feature. This is the recommended RAG architecture. [Learn more](https://learn.microsoft.com/azure/search/retrieval-augmented-generation-overview)
- **Incorrect B**: Cosmos DB vector search is for scenarios already using Cosmos DB--AI Search provides better hybrid search capabilities.
- **Incorrect C**: Azure OpenAI doesn't directly access Blob Storage for document retrieval.
- **Incorrect D**: Full-text search lacks vector/semantic capabilities needed for RAG.

---

**Q50.** Wingtip Toys needs to scale their Container Apps deployment based on Azure Service Bus queue depth. During peak hours, messages can spike to 10,000 in the queue. During off-peak, the queue is empty and no replicas should run. What should you recommend?

- A. Container Apps with KEDA Service Bus scaler and scale-to-zero enabled
- B. Container Apps with HTTP-based autoscaling
- C. AKS with Horizontal Pod Autoscaler based on CPU
- D. Azure Functions with Service Bus trigger

**Correct Answer**: A

**Explanation**:
- **Correct**: Container Apps has built-in KEDA support--the Service Bus scaler monitors queue depth and scales replicas accordingly. Scale-to-zero is supported (no cost when queue is empty). No cluster management required. [Learn more](https://learn.microsoft.com/azure/container-apps/scale-app)
- **Incorrect B**: HTTP autoscaling doesn't respond to queue depth.
- **Incorrect C**: AKS HPA based on CPU doesn't scale based on queue messages and adds cluster overhead.
- **Incorrect D**: Functions work but Container Apps is better for containerized workloads with Dapr integration.

---

## Quick Reference: Domain Weight Distribution

| Domain | Weight | Questions |
|--------|--------|-----------|
| Identity, Governance, Monitoring | 25-30% | Q1-Q12 (12 questions) |
| Data Storage Solutions | 20-25% | Q13-Q21 (9 questions) |
| Business Continuity | 15-20% | Q22-Q28 (7 questions) |
| Infrastructure Solutions | 30-35% | Q29-Q50 (22 questions) |

**Total: 50 Questions**

---

## Key Updates for October 2024 Exam

### Service Name Changes
- **Azure Active Directory** is now **Microsoft Entra ID**
- **Azure AD B2B/B2C** is now **Microsoft Entra External ID (B2B/B2C)**
- **Azure AD Conditional Access** is now **Microsoft Entra Conditional Access**
- **Azure AD tenant** is now **Microsoft Entra tenant**

### Deprecated Services
- **Azure Blueprints** deprecated July 2026 - use **Deployment Stacks** + **Template Specs** instead

### New Topics to Study
- **Microsoft Entra Verified ID** - decentralized identity and verifiable credentials
- **Deployment Stacks** - managed resource lifecycle with deny settings
- **Microsoft Defender CSPM** - advanced cloud security posture management
- **Azure OpenAI Service** - enterprise AI architecture patterns
- **Azure Container Apps** - serverless containers with Dapr and KEDA
- **Azure Landing Zone accelerator** - CAF implementation patterns

---

## Study Resources

- [AZ-305 Study Guide](https://learn.microsoft.com/credentials/certifications/resources/study-guides/az-305)
- [Microsoft Free Practice Assessment](https://learn.microsoft.com/credentials/certifications/exams/az-305/practice/assessment)
- [Azure Architecture Center](https://learn.microsoft.com/azure/architecture/)
- [Well-Architected Framework](https://learn.microsoft.com/azure/well-architected/)
- [Cloud Adoption Framework](https://learn.microsoft.com/azure/cloud-adoption-framework/)
- [MeasureUp Practice Exams](https://www.measureup.com/az-305-microsoft-azure-solutions-architect-expert-practice-test.html)
