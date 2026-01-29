# AZ-305 Teaching Punchlist -- January 2026

**5 segments × 50 minutes | O'Reilly Live Learning | Tim Warner**

---

## Segment 1: Identity, Governance & Monitoring (25-30%)

### Monitoring (1.1)
- [ ] Log Analytics workspace design: centralized vs distributed
- [ ] Diagnostic settings: route logs to LAW, Event Hub, Storage
- [ ] Azure Monitor: metrics, alerts, action groups
- [ ] Application Insights (workspace-based)
- [ ] Log retention tiers: interactive (2yr max) + archive (12yr total)
- [ ] KQL query basics -- show live in law-az305

### Authentication & Authorization (1.2)
- [ ] Microsoft Entra ID auth methods: MFA, passwordless (FIDO2, Authenticator)
- [ ] Conditional Access policies
- [ ] Microsoft Entra External ID: B2B (partners) vs B2C (consumers)
- [ ] Hybrid identity: Microsoft Entra Connect, pass-through auth vs password hash sync
- [ ] Microsoft Entra Application Proxy for on-prem app access
- [ ] RBAC: built-in vs custom roles, scope inheritance
- [ ] Microsoft Entra Privileged Identity Management (PIM): just-in-time elevation
- [ ] Key Vault: Standard vs Premium, RBAC mode, managed identity access, rotation

### Governance (1.3)
- [ ] Management group → subscription → resource group hierarchy
- [ ] Tagging taxonomy and enforcement via Policy
- [ ] Azure Policy: effects (audit, deny, deployIfNotExists, modify)
- [ ] Policy initiatives for compliance frameworks
- [ ] ~~Azure Blueprints~~ → **Deployment Stacks** (Blueprints deprecated July 2026)
- [ ] Microsoft Defender for Cloud compliance scoring
- [ ] Identity governance: access reviews, entitlement management, lifecycle workflows

---

## Segment 2: Data Storage Solutions (20-25%)

### Relational Data (2.1)
- [ ] SQL Database vs SQL Managed Instance vs SQL Server on VM decision
- [ ] DTU vs vCore purchasing models
- [ ] Serverless vs provisioned compute (show sqldb-az305-demo auto-pause)
- [ ] Elastic pools for multi-tenant SaaS
- [ ] Hyperscale for large databases
- [ ] Data protection: TDE, Always Encrypted, dynamic data masking, row-level security
- [ ] Microsoft Defender for SQL

### Semi-Structured & Unstructured Data (2.2)
- [ ] Cosmos DB: API selection (NoSQL, MongoDB, Cassandra, Gremlin, Table)
- [ ] Cosmos DB: consistency levels (strong → eventual, Session = default sweet spot)
- [ ] Cosmos DB: partition key strategy (high cardinality, even distribution)
- [ ] Cosmos DB: serverless vs provisioned throughput
- [ ] Blob Storage access tiers: Hot, Cool, Cold, Archive
- [ ] Storage lifecycle management (show staz305demo policy)
- [ ] Data Lake Storage Gen2 (hierarchical namespace)
- [ ] Azure Files: SMB vs NFS, Azure NetApp Files for high perf
- [ ] Redundancy: LRS → ZRS → GRS → GZRS → RA-GRS → RA-GZRS
- [ ] Immutable storage: legal hold, time-based retention
- [ ] Soft delete + versioning

### Data Integration (2.3)
- [ ] Azure Data Factory vs Synapse pipelines (same engine, different scope)
- [ ] Integration runtimes: Azure, self-hosted, Azure-SSIS
- [ ] Azure Synapse Analytics: serverless SQL, dedicated pools, Spark
- [ ] Azure Databricks: when to choose over Synapse
- [ ] Stream Analytics for real-time
- [ ] Microsoft Fabric: strategic direction for unified analytics

---

## Segment 3: Business Continuity & High Availability (15-20%)

### Backup & DR (3.1)
- [ ] RTO vs RPO: translate business requirements to technical design
- [ ] Azure Backup: Recovery Services vault vs Backup vault
- [ ] VM backup: application-consistent vs crash-consistent snapshots
- [ ] Backup policies: daily/weekly/monthly retention
- [ ] Cross-region restore
- [ ] Azure Site Recovery: replication, failover, failback, recovery plans
- [ ] SQL Database: automated backups, PITR, long-term retention (LTR)
- [ ] SQL geo-replication + auto-failover groups (show listener endpoints)
- [ ] Blob: soft delete, versioning, point-in-time restore, object replication

### High Availability (3.2)
- [ ] Availability Sets (fault/update domains) vs Availability Zones vs VMSS
- [ ] VM SLA ladder: single (99.9%) → AvSet (99.95%) → AZ (99.99%)
- [ ] SQL Database zone redundancy (all vCore tiers; Hyperscale needs premium-series)
- [ ] Auto-failover groups: customer managed vs Microsoft managed policy
- [ ] Cosmos DB multi-region writes
- [ ] Zone-redundant storage (ZRS), geo-redundant (GRS/GZRS)
- [ ] Storage account failover: customer-managed

---

## Segment 4: Compute & Application Architecture (~17% of Infrastructure)

### Compute Solutions (4.1)
- [ ] Compute decision tree: VM → Container Apps → AKS → Functions → Batch
- [ ] VM sizes/series, VMSS auto-scale, Spot VMs
- [ ] Dedicated hosts, proximity placement groups
- [ ] AKS: Azure CNI, managed identity, RBAC (show aks-az305)
- [ ] Container Apps: scale-to-zero, Dapr, revisions
- [ ] Azure Container Instances: simple/batch containers
- [ ] Azure Functions: Consumption vs Premium (VNet) vs Dedicated
- [ ] Durable Functions for stateful workflows
- [ ] Azure Batch / CycleCloud for HPC

### Application Architecture (4.2)
- [ ] Messaging: Service Bus (queues/topics) vs Queue Storage (show sb-az305-tw)
- [ ] Events: Event Grid (reactive) vs Event Hubs (streaming) -- decision matrix
- [ ] API Management: tiers, policies, rate limiting (show warnerco-apim)
- [ ] Azure Cache for Redis: cache-aside pattern, CDN for static content
- [ ] Azure App Configuration + feature flags
- [ ] Deployment: Azure DevOps, GitHub Actions, Bicep/Terraform
- [ ] Blue-green and canary deployment patterns

---

## Segment 5: Networking & Migrations (~18% of Infrastructure)

### Network Solutions (4.4)
- [ ] Hub-spoke topology with peering (show vnet-win ↔ vnet-linux)
- [ ] VPN Gateway (S2S) vs ExpressRoute (private peering, Microsoft peering)
- [ ] ExpressRoute Global Reach, Virtual WAN (>10 spokes or SD-WAN)
- [ ] Azure Firewall: Standard vs Premium, policy rules, DNS proxy
- [ ] NSG vs ASG vs Azure Firewall decision
- [ ] Application Gateway + WAF v2 (show appgw-az305, OWASP 3.2)
- [ ] Azure Front Door: global HTTP LB + CDN + WAF
- [ ] Load balancing decision tree: LB (L4) vs AppGW (L7) vs Front Door (global) vs Traffic Manager (DNS)
- [ ] Private Endpoints + Private Link vs Service Endpoints
- [ ] DDoS Protection: Infrastructure (free) vs Network Protection vs IP Protection
- [ ] Public IP: Standard SKU only (Basic retired Sept 2025)
- [ ] Network Watcher diagnostics

### Migrations (4.3)
- [ ] Cloud Adoption Framework phases: Strategy → Plan → Ready → Adopt → Govern → Manage
- [ ] Azure Migrate: discovery, assessment, dependency analysis
- [ ] TCO Calculator
- [ ] Migration strategies: rehost vs refactor vs rearchitect
- [ ] Azure Migrate server migration, App Service migration assistant
- [ ] Azure Database Migration Service: online vs offline
- [ ] Azure Data Box family (Data Box, Disk, Heavy) for bulk unstructured data
- [ ] AzCopy, Storage Explorer, Azure File Sync

---

## Cross-Cutting: Weave Into Every Segment

- [ ] **Well-Architected Framework**: Reliability, Security, Cost, Operational Excellence, Performance
- [ ] **Zero Trust**: verify explicitly, least privilege, assume breach
- [ ] **Managed Identity**: use everywhere instead of secrets/keys
- [ ] **Cost optimization**: right-size, reserved instances, serverless, scale-to-zero
- [ ] **Microsoft Entra ID** terminology throughout (not "Azure AD")
