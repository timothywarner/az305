# AZ-305 Quick Reference Cards

**Last Updated**: January 2025 | **Exam Version**: October 18, 2024 Update

Condensed study cards for rapid review. Each card follows Tim's rule: one best answer, clear justification.

---

## Domain 1: Identity, Governance & Monitoring (25-30%)

### Card 1.1: Logging Solutions

| Scenario | Best Solution | Why |
|----------|---------------|-----|
| Multi-subscription enterprise logging | Single Log Analytics workspace with resource-context RBAC | Unified querying, bulk pricing (commitment tiers), access follows resource permissions |
| Long-term compliance archive (7+ years) | Storage Account with diagnostic settings | Log Analytics max is 730 days (interactive) + 12 years archive; Storage is cost-effective for cold data |
| Real-time SIEM integration | Event Hub with diagnostic settings | Streaming ingestion, Splunk/Sentinel connectors built-in |
| Application performance tracing | Application Insights (workspace-based) | Distributed tracing, sampling for cost control, auto-instrumentation |
| Security monitoring and threat detection | Microsoft Sentinel with Log Analytics | SIEM + SOAR, built-in AI/ML, 200+ connectors |

**Tim's Decision Tree**:
```
Need to query logs? --> Log Analytics
Need to archive > 2 years? --> Storage Account (or Log Analytics archive tier)
Need real-time streaming? --> Event Hub
Need security analytics? --> Microsoft Sentinel
Need all? --> Diagnostic settings to multiple destinations
```

**Log Analytics Workspace Design Best Practices (2025)**:
- Start with a single workspace to minimize complexity
- Use resource-context RBAC for access control (not workspace-level)
- Deploy workspace in same region as resources for performance
- Use IaC (Bicep/Terraform) for consistent configuration
- Monitor workspace health with Log Analytics Insights

[Azure Monitor Overview](https://learn.microsoft.com/azure/azure-monitor/overview) | [Workspace Design](https://learn.microsoft.com/azure/azure-monitor/logs/workspace-design)

---

### Card 1.2: Authentication Solutions

| Scenario | Best Solution | Why |
|----------|---------------|-----|
| External partner access | Microsoft Entra External ID (B2B collaboration) | Partners use own credentials, access packages for lifecycle |
| Consumer-facing app (new projects) | Microsoft Entra External ID | Social logins, custom branding, self-service flows (replaces Azure AD B2C for new customers as of May 2025) |
| On-premises AD integration (new deployments) | Entra Cloud Sync | Cloud-managed, lightweight agent, multi-forest support, automatic updates |
| On-premises AD integration (complex scenarios) | Entra Connect Sync v2 | Full feature set, device sync, pass-through auth, AD FS federation |
| Highly sensitive (no cloud passwords) | Pass-through authentication or Federation | Passwords never leave on-premises |

**Tim's Rule**:
- For **new** consumer apps: Use Microsoft Entra External ID (Azure AD B2C end-of-sale May 2025)
- For partners: Always B2B collaboration, never sync external users into your tenant
- For hybrid identity: Prefer Entra Cloud Sync unless you need features only in Connect Sync

**Entra Cloud Sync vs. Connect Sync**:
| Feature | Cloud Sync | Connect Sync |
|---------|------------|--------------|
| Management | Cloud-based portal | On-premises server |
| Agent footprint | Lightweight provisioning agent | Full application |
| Multi-forest disconnected | Yes | Limited |
| Device sync | No | Yes |
| Pass-through auth | No | Yes |
| Large groups (50K+) | Yes | Yes |

[Entra External Identities](https://learn.microsoft.com/entra/external-id/) | [Cloud Sync](https://learn.microsoft.com/entra/identity/hybrid/cloud-sync/what-is-cloud-sync)

---

### Card 1.3: Authorization and Secrets

| Scenario | Best Solution | Why |
|----------|---------------|-----|
| Azure resource access from apps | Managed Identity (user-assigned) | Zero secrets, auto-rotation, works across deployment slots |
| Multiple resources sharing same identity | User-assigned managed identity | Fewer role assignments, pre-created before resources |
| Single resource with unique lifecycle | System-assigned managed identity | Identity deleted with resource, simpler for single-purpose |
| Secrets/certificates storage | Azure Key Vault Premium with Private Link | HSM-backed (FIPS 140-2 L3), private network only |
| Azure RBAC with custom permissions | Custom role with specific actions | Least privilege principle |
| Cross-subscription resource access | Service Principal with federated credential | No secrets, works with GitHub/Azure DevOps OIDC |
| Rapid resource creation (ephemeral compute) | User-assigned managed identity | Avoids rate limits on identity creation |

**Tim's Non-Negotiable**: If managed identity is available, use it. Never store secrets in code, config files, or environment variables directly.

**Managed Identity Decision Flow**:
```
App needs to access Azure resource?
  |
  v
Can the app host a managed identity?
  |
  YES --> Multiple resources need same access?
  |         |
  |         YES --> User-assigned managed identity
  |         NO --> System-assigned (simpler) or User-assigned (pre-provision)
  |
  NO --> Use Key Vault with workload identity federation
```

**Tim's Managed Identity Best Practices (2025)**:
- User-assigned for shared access, compliance requirements, or pre-provisioning
- System-assigned for audit logging per resource or when identity should die with resource
- Use one managed identity per region for regional isolation
- Never use both types on same resource unless absolutely necessary

[Managed Identities](https://learn.microsoft.com/entra/identity/managed-identities-azure-resources/overview) | [Best Practices](https://learn.microsoft.com/entra/identity/managed-identities-azure-resources/managed-identity-best-practice-recommendations)

---

### Card 1.4: Governance Structure

| Level | Purpose | What Goes Here |
|-------|---------|----------------|
| Root Management Group | Enterprise-wide guardrails | Security policies with Deny effect (can't be overridden) |
| Intermediate Management Groups | Organizational structure | Platform vs. Landing Zones, Regions, Business Units |
| Subscriptions | Billing and scale boundaries | Environments (Prod, Dev), Applications, Teams |
| Resource Groups | Lifecycle management | Resources that deploy/delete together |

**Tim's Tagging Strategy**:
| Required Tag | Purpose | Enforcement |
|--------------|---------|-------------|
| CostCenter | Chargeback | Policy Deny |
| Environment | Prod/Dev/Test | Policy Deny |
| Owner | Accountability | Policy Deny |
| Application | Grouping | Policy Modify (inherit from RG) |
| DataClassification | Security | Policy Deny |

**Policy Effects Cheat Sheet (Order of Evaluation)**:
1. **Disabled**: Skip evaluation (use for testing)
2. **Append/Modify**: Auto-fix during deployment (tags, settings)
3. **Deny**: Block non-compliant deployments
4. **Audit**: Report only (evaluate before enforcement)
5. **AuditIfNotExists**: Check for related resources
6. **DeployIfNotExists**: Create dependent resources (diagnostics, extensions)
7. **DenyAction**: Block specific actions (like delete)

**Tim's Policy Patterns**:
- **Mandatory tags**: Deny effect at Management Group level
- **Diagnostic settings**: DeployIfNotExists to auto-configure
- **Tag inheritance**: Modify effect to copy from RG to resources
- **Allowed locations**: Deny with parameter for data residency

[Management Groups](https://learn.microsoft.com/azure/governance/management-groups/overview) | [Policy Effects](https://learn.microsoft.com/azure/governance/policy/concepts/effect-basics)

---

### Card 1.5: Compliance and Identity Governance

| Need | Best Solution | Why |
|------|---------------|-----|
| Regulatory compliance dashboard | Microsoft Defender for Cloud | Built-in ISO, SOC, PCI, HIPAA mappings with continuous assessment |
| Cloud security posture management | Defender CSPM | Attack path analysis, risk-based secure score, AI security posture |
| Guest user access reviews | Entra ID Governance access reviews | Quarterly attestation, auto-remove on denial |
| Privileged role management | Entra Privileged Identity Management (PIM) | Just-in-time access, approval workflows, audit trails |
| Entitlement automation | Access packages with expiration | Self-service request, automatic lifecycle |
| Workload identity protection | Defender for Cloud CIEM | Permissions creep detection, identity risk |

**Microsoft Defender for Cloud Capabilities (2025)**:
- **Defender CSPM**: Cloud security posture, attack paths, agentless scanning
- **Defender for Servers**: VM protection, vulnerability assessment
- **Defender for Containers**: AKS/EKS/GKE protection, runtime threat detection, gated deployment
- **Defender for Storage**: Malware scanning, sensitive data detection
- **Defender for Databases**: SQL, Cosmos DB, PostgreSQL protection
- **Defender for APIs**: API security posture management
- **Defender for DevOps**: GitHub/Azure DevOps security scanning

**Tim's Security Posture Rule**: Enable Defender CSPM + Defender for Servers on all production workloads. The attack path analysis alone is worth it.

[Defender for Cloud](https://learn.microsoft.com/azure/defender-for-cloud/defender-for-cloud-introduction) | [Regulatory Compliance](https://learn.microsoft.com/azure/defender-for-cloud/regulatory-compliance-dashboard)

---

## Domain 2: Data Storage Solutions (20-25%)

### Card 2.1: Relational Database Selection

| Requirement | Best Solution | Why |
|-------------|---------------|-----|
| New cloud-native SQL workload | Azure SQL Database | Fully managed, auto-patching, built-in HA |
| Lift-and-shift SQL Server | Azure SQL Managed Instance | 100% SQL Server compatibility, agent jobs, CLR |
| Full OS/SQL control needed | SQL Server on Azure VMs | Custom configs, legacy versions, unsupported features |
| Open-source PostgreSQL/MySQL | Azure Database for PostgreSQL/MySQL Flexible | Managed, cost-effective, zone redundancy |
| Database > 100TB or rapid scale | Azure SQL Database Hyperscale | Up to 128TB, rapid scale out/in, fast backups |

**Azure SQL Service Tier Decision (vCore Model)**:
| Tier | Use When | Key Features |
|------|----------|--------------|
| General Purpose | Most production workloads | Remote storage, zone redundancy, 99.99% SLA |
| Business Critical | High IOPS, low latency, read replicas | Local SSD, built-in read replica, 99.99% SLA |
| Hyperscale | Database > 4TB, rapid scale, fast restore | 128TB max, instant backups, up to 4 read replicas |

**DTU vs. vCore (2025 Guidance)**:
- **DTU**: Simpler, bundled resources, good for predictable workloads
- **vCore**: Flexible, independent CPU/memory/storage, Azure Hybrid Benefit eligible
- **Tim's Rule**: Use vCore for new workloads - more flexibility and cost optimization options

**Compute Tiers**:
- **Provisioned**: Fixed compute, pay per hour
- **Serverless**: Auto-scale, auto-pause, pay per second (General Purpose and Hyperscale)

**Tim's Cost Tips**:
- Elastic pools for 5+ databases with variable usage
- Serverless for dev/test with sporadic activity
- Reserved capacity for predictable production workloads (1-3 year)

[Azure SQL Database](https://learn.microsoft.com/azure/azure-sql/database/sql-database-paas-overview) | [Service Tiers](https://learn.microsoft.com/azure/azure-sql/database/service-tiers-sql-database-vcore)

---

### Card 2.2: NoSQL and Unstructured Storage

| Data Type | Best Solution | Why |
|-----------|---------------|-----|
| JSON documents, global distribution | Azure Cosmos DB for NoSQL | <10ms latency, multi-region writes, 99.999% SLA |
| Key-value lookups, simple queries | Azure Table Storage or Cosmos DB Table API | Table Storage = cheap; Cosmos = low latency |
| Graph relationships | Azure Cosmos DB for Gremlin | Native graph traversal, social networks |
| Time-series telemetry | Azure Data Explorer | Purpose-built for analytics on streaming data |
| Blobs, images, videos | Azure Blob Storage | Tiering, lifecycle, CDN integration |
| File shares (SMB/NFS) | Azure Files or Azure NetApp Files | Files = standard; NetApp = enterprise performance |

**Cosmos DB Consistency Levels** (strongest to weakest):
1. **Strong**: Linearizable reads (highest latency, single-region writes only)
2. **Bounded Staleness**: Guaranteed lag window (multi-region with ordering)
3. **Session**: Consistency within a session (default, recommended)
4. **Consistent Prefix**: Ordered, no gaps (lower latency)
5. **Eventual**: Highest performance, no ordering guarantees

**Cosmos DB Multi-Region (2025)**:
| Configuration | Strong Consistency | Bounded/Session/Eventual |
|---------------|-------------------|--------------------------|
| Single-region write | Supported | Supported |
| Multi-region write | NOT supported | Supported |

**Tim's Default**: Use Session consistency unless you have a specific reason not to. For multi-region writes, you CANNOT use Strong consistency.

**Cosmos DB Availability**:
- Single region: 99.99% SLA
- Multi-region (single write): 99.99% read, 99.99% write
- Multi-region (multi-write): 99.999% read AND write

[Cosmos DB Introduction](https://learn.microsoft.com/azure/cosmos-db/introduction) | [Consistency Levels](https://learn.microsoft.com/azure/cosmos-db/consistency-levels)

---

### Card 2.3: Storage Account Configuration

| Scenario | Redundancy | Access Tier | Why |
|----------|------------|-------------|-----|
| Production data, regional HA | ZRS | Hot | Survives datacenter failure within region |
| DR with regional failover | GZRS | Hot | Zone redundancy + cross-region replication |
| DR with read access to secondary | RA-GZRS | Hot | Read from secondary during outages |
| Backup/archive (access < yearly) | LRS | Archive | Lowest cost, hours to rehydrate |
| Compliance/WORM | LRS + Immutability | Cool/Archive | Legal holds, time-based retention |
| Global content delivery | GRS + CDN | Hot | Edge caching worldwide |

**Storage Redundancy Options (2025)**:
| Option | Durability | Regions | AZ Protection | Use Case |
|--------|------------|---------|---------------|----------|
| LRS | 11 nines | 1 | No | Dev/test, easily recreated data |
| ZRS | 12 nines | 1 | Yes | Production, regional HA |
| GRS/RA-GRS | 16 nines | 2 | No | DR, cross-region |
| GZRS/RA-GZRS | 16 nines | 2 | Yes (primary) | Maximum durability, production DR |

**Blob Access Tiers**:
| Tier | Access Pattern | Min Storage Duration | Rehydration |
|------|----------------|---------------------|-------------|
| Hot | Frequent | None | Immediate |
| Cool | Infrequent (30+ days) | 30 days | Immediate |
| Cold | Rare (90+ days) | 90 days | Immediate |
| Archive | Almost never (180+ days) | 180 days | Hours (Standard) or Minutes (High Priority) |

**Tim's Rule**: Use lifecycle management policies to auto-tier. Never manually manage blob tiers at scale.

[Azure Storage Redundancy](https://learn.microsoft.com/azure/storage/common/storage-redundancy) | [Blob Tiers](https://learn.microsoft.com/azure/storage/blobs/access-tiers-overview)

---

### Card 2.4: Data Integration

| Scenario | Best Solution | Why |
|----------|---------------|-----|
| ETL/ELT from multiple sources | Azure Data Factory | 100+ connectors, visual data flows, scheduling |
| Real-time streaming analytics | Azure Stream Analytics | SQL-like queries on streams, native IoT Hub integration |
| Unified analytics platform | Microsoft Fabric | Lakehouse, data warehouse, real-time analytics in one |
| Big data analytics (existing) | Azure Synapse Analytics | Unified SQL + Spark, serverless or dedicated |
| Data science/ML | Azure Databricks or Synapse Spark | Collaborative notebooks, MLflow integration |
| Simple data movement | AzCopy or Storage Explorer | Manual/scripted bulk transfers |

**Data Factory vs. Synapse Pipelines vs. Fabric Data Factory**:
| Feature | Azure Data Factory | Synapse Pipelines | Fabric Data Factory |
|---------|-------------------|-------------------|---------------------|
| Deployment | Standalone PaaS | Part of Synapse workspace | Part of Fabric |
| Best for | General ETL/ELT | Synapse-centric analytics | Fabric ecosystem |
| Connectors | 100+ | 100+ (same engine) | 100+ (same engine) |
| Future | Fully supported | Fully supported | Strategic direction (SaaS) |

**Tim's 2025 Guidance**:
- **New projects**: Evaluate Microsoft Fabric first for unified analytics
- **Existing ADF/Synapse**: Continue using - no deprecation planned
- **Synapse Pipelines**: Use when destination is Synapse Analytics
- **Data Factory**: Use for everything else, especially hybrid scenarios

[Azure Data Factory](https://learn.microsoft.com/azure/data-factory/introduction) | [Microsoft Fabric](https://learn.microsoft.com/fabric/)

---

## Domain 3: Business Continuity (15-20%)

### Card 3.1: Backup vs. Disaster Recovery

| Objective | Solution | Typical Target |
|-----------|----------|----------------|
| Data protection (accidental deletion, corruption) | Azure Backup | RPO: 24hrs, RTO: hours |
| Business continuity (regional failure) | Azure Site Recovery | RPO: ~30 seconds, RTO: < 1hr |
| Database point-in-time | Built-in PITR + LTR | RPO: 5-10 min, RTO: minutes |

**Tim's Clarification**: Backup = get your data back. DR = keep your business running. You need both.

**Azure Backup Supported Workloads (2025)**:
- Azure VMs (full VM backup, agentless crash-consistent)
- Azure SQL in VM (application-aware)
- Azure Files (share-level, vaulted backup GA)
- Azure Files Premium (vaulted backup GA)
- SAP HANA in VM
- SAP ASE (Sybase) in VM (GA)
- Azure Managed Disks (incremental snapshots)
- Azure Blobs (operational + vaulted backup)
- Azure Database for PostgreSQL Flexible (vaulted backup GA)
- Azure Kubernetes Service (vaulted backup + CRR GA)
- Azure Data Lake Storage (vaulted backup GA)
- On-premises (via MARS agent or MABS)

**Note**: Azure SQL Database PaaS and Cosmos DB use built-in backup (not Azure Backup service).

**New in 2025**:
- Threat detection with Defender for Cloud integration (preview)
- Vaulted backup for Data Lake Storage (GA)
- Agentless multi-disk crash-consistent backups for VMs (GA)

[Azure Backup Overview](https://learn.microsoft.com/azure/backup/backup-overview) | [What's New](https://learn.microsoft.com/azure/backup/whats-new)

---

### Card 3.2: Site Recovery Scenarios

| Source | Target | Use Case |
|--------|--------|----------|
| Azure VM (Region A) | Azure (Region B) | Azure-to-Azure DR |
| Azure VM (Zone 1) | Azure (Zone 2) | Zone-to-zone DR (same region) |
| VMware on-premises | Azure | Datacenter exit DR |
| Hyper-V on-premises | Azure | Hybrid DR |
| Physical servers | Azure | Legacy workload DR |

**Recovery Plan Components**:
1. **Groups**: VMs that fail over together (ordered)
2. **Scripts**: Pre/post actions (Azure Automation runbooks)
3. **Manual Actions**: Human approval gates
4. **Failback**: Return to primary after event

**Tim's RPO/RTO Quick Guide**:
- **RPO (Recovery Point Objective)**: How much data can you lose? (Time between last backup and failure)
- **RTO (Recovery Time Objective)**: How long can you be down? (Time to restore service)

**Site Recovery SLAs (2025)**:
- RTO SLA: Up to 1 hour (with recovery plans)
- RPO: ~30 seconds for continuous replication (Azure VMs, VMware)
- RPO: 30 seconds to 5 minutes for Hyper-V

**Zone-to-Zone DR Benefits**:
- Lower egress costs than region-to-region
- Same SLA as region-to-region
- Faster failover (same region)

[Azure Site Recovery](https://learn.microsoft.com/azure/site-recovery/site-recovery-overview) | [Zone-to-Zone DR](https://learn.microsoft.com/azure/site-recovery/azure-to-azure-how-to-enable-zone-to-zone-disaster-recovery)

---

### Card 3.3: High Availability Patterns

| Layer | Single-Region HA | Multi-Region HA |
|-------|------------------|-----------------|
| Compute (VMs) | Availability Zones + Load Balancer | Front Door + VMs in both regions |
| Compute (PaaS) | Zone-redundant App Service | Front Door + App Service in both regions |
| SQL Database | Zone redundancy (all tiers) | Auto-failover group |
| Cosmos DB | Zone redundancy | Multi-region writes (99.999% SLA) |
| Storage | ZRS | GZRS + manual failover (or RA-GZRS for read) |

**SLA Math (2025)**:
| Configuration | SLA |
|---------------|-----|
| Single VM (Premium SSD) | 99.9% |
| Availability Set | 99.95% |
| Availability Zones | 99.99% |
| Multi-region active-active | 99.99%+ |
| Cosmos DB multi-region multi-write | 99.999% |

**Tim's Rule**: Availability Zones are your default for datacenter-level resilience within a region. Multi-region for regional disaster scenarios.

**Zone-Redundant Services (commonly tested)**:
- Azure SQL Database (all vCore tiers)
- Azure SQL Managed Instance (Business Critical GA, General Purpose preview)
- App Service (Premium v3, Isolated v2)
- Azure Kubernetes Service
- Azure Functions (Premium, Dedicated)
- Azure Firewall (99.99% SLA when zone-redundant)
- Application Gateway v2
- Load Balancer Standard
- VPN Gateway (zone-redundant SKUs)

[Availability Zones](https://learn.microsoft.com/azure/reliability/availability-zones-overview)

---

### Card 3.4: Database HA and DR

| Database | HA Option | DR Option |
|----------|-----------|-----------|
| Azure SQL Database | Zone redundancy (all vCore tiers) | Auto-failover group (readable secondary) |
| Azure SQL Managed Instance | Zone redundancy (BC=GA, GP=preview) | Auto-failover group |
| Cosmos DB | Zone redundancy | Multi-region with automatic failover |
| PostgreSQL Flexible | Zone-redundant HA | Read replicas + manual failover |
| MySQL Flexible | Zone-redundant HA | Read replicas + manual failover |

**Auto-Failover Group Features (2025)**:
1. **Listener endpoints** (connection string doesn't change)
   - Read-write: `<fog-name>.database.windows.net`
   - Read-only: `<fog-name>.secondary.database.windows.net`
2. **Automatic failover** on outage (Microsoft-managed policy)
3. **Readable secondary** for read scale-out
4. **Coordinated failover** of multiple databases
5. **Grace period** configuration (data loss tolerance)
6. **Cross-region support** (any Azure region, not just pairs)
7. **Standby replica pricing** (reduced cost for passive secondary)

**Tim's Failover Group Tips**:
- Use same service tier, compute size, and backup redundancy on secondary
- Configure different maintenance windows for primary/secondary regions
- Read-only listener failover is disabled by default (enable if needed)
- Multiple failover groups per server pair supported for different database groups

[SQL Database Auto-Failover](https://learn.microsoft.com/azure/azure-sql/database/failover-group-sql-db)

---

## Domain 4: Infrastructure Solutions (30-35%)

### Card 4.1: Compute Decision Tree

```
What are you running?
  |
  +-- Legacy Windows app needing OS control --> Azure VMs
  |
  +-- Web app/API
  |     |
  |     +-- Simple, no containers --> App Service
  |     +-- Containers, serverless, scale-to-zero --> Container Apps
  |     +-- Containers, full K8s control --> AKS
  |
  +-- Event-driven code
  |     |
  |     +-- Short-lived (< 10 min) --> Azure Functions
  |     +-- Long-running orchestration --> Durable Functions
  |
  +-- Batch processing --> Azure Batch
  |
  +-- Microservices with Dapr --> Container Apps
  |
  +-- AI/ML workloads --> Azure Machine Learning or AKS
```

**Container Platform Selection (2025)**:
| Scenario | Best Choice | Why |
|----------|-------------|-----|
| Simple containerized apps, scale-to-zero | Container Apps | Serverless, built-in scaling, Dapr integration |
| Full Kubernetes control, custom operators | AKS | Maximum configurability, CNCF ecosystem |
| Quick container run, no orchestration | Container Instances | Single pod, Hyper-V isolated |
| Windows containers | AKS with Windows node pools | Full Windows container support |
| Familiar with App Service, need containers | Web App for Containers | App Service model, simpler than AKS |
| Multiple workloads sharing infrastructure | AKS | Namespace isolation, cost efficiency |

**AKS vs. Container Apps Decision**:
| Factor | AKS | Container Apps |
|--------|-----|----------------|
| Operational overhead | High (you manage cluster) | Low (Microsoft managed) |
| Kubernetes API access | Full access | Abstracted |
| CNCF ecosystem | Full compatibility | Limited |
| Network policies | Yes (deny by default) | No (environment boundary only) |
| Scale-to-zero | Manual configuration | Built-in |
| Dapr integration | Manual setup | Native |
| Cost for small workloads | Higher (always-on nodes) | Lower (consumption) |

**Tim's Container Guidance**: Start with Container Apps unless you need Kubernetes-specific features like custom operators, advanced network policies, or CNCF tooling.

[Compute Decision Tree](https://learn.microsoft.com/azure/architecture/guide/technology-choices/compute-decision-tree) | [Choose Container Service](https://learn.microsoft.com/azure/architecture/guide/choose-azure-container-service)

---

### Card 4.2: Messaging and Events

| Pattern | Best Service | Characteristics |
|---------|--------------|-----------------|
| Event routing (pub/sub, reactive) | Event Grid | Push model, filtering, serverless, at-least-once |
| High-throughput telemetry/streaming | Event Hubs | Pull model, partitions, Kafka compatible, millions/sec |
| Enterprise messaging (transactions, sessions) | Service Bus | Queues, topics, FIFO, exactly-once, dead-letter |
| Simple task queue | Storage Queue | Basic, cheap, at-least-once |

**Event Grid vs. Event Hubs vs. Service Bus (2025)**:
| Feature | Event Grid | Event Hubs | Service Bus |
|---------|------------|------------|-------------|
| **Purpose** | Event distribution | Event streaming | Enterprise messaging |
| **Model** | Push (reactive) | Pull (streaming) | Pull (message broker) |
| **Throughput** | 10M events/sec | Millions/sec | Thousands/sec |
| **Ordering** | No guarantee | Per partition | Sessions (FIFO) |
| **Replay** | No | Yes (retention period) | Dead-letter queue |
| **Latency** | Milliseconds | Low | Variable |
| **Max message size** | 1 MB | 1 MB (Standard), 20 MB (Premium/Dedicated) | 256 KB (Standard), 100 MB (Premium) |
| **Transactions** | No | No | Yes |

**Decision Criteria**:
```
Need Kafka compatibility or millions/sec? --> Event Hubs
Need push-based event routing/webhooks? --> Event Grid
Need message sessions, transactions, ordering? --> Service Bus
Need cheap, simple queue? --> Storage Queue
React to Azure resource changes? --> Event Grid (native integration)
```

**Event Grid 2025 Updates**:
- MQTT support (IoT scenarios)
- Cross-tenant delivery
- Namespace topics for high-throughput
- Network security perimeter support

[Messaging Services Comparison](https://learn.microsoft.com/azure/service-bus-messaging/compare-messaging-services)

---

### Card 4.3: API Management

**APIM Tiers (2025)**:
| Tier | Use Case | Key Features |
|------|----------|--------------|
| **Consumption** | Serverless APIs, low volume | Pay-per-call, auto-scale, no SLA |
| **Developer** | Dev/test | Self-hosted gateway, no SLA |
| **Basic** | Entry production | SLA, limited scale |
| **Standard** | Production | Multi-region (limited), higher scale |
| **Premium** | Enterprise | VNet integration, multi-region, availability zones, workspaces |
| **Basic v2** | Dev/test with SLA | Fast deployment, SLA |
| **Standard v2** | Production (simplified) | VNet integration for backends, fast scaling |
| **Premium v2** | Enterprise (modern) | Full VNet injection, zones, workspaces, up to 30 units |

**v2 Tiers Benefits**:
- Faster deployment (minutes vs. 30-45 min for classic)
- Faster scaling
- Simplified networking options
- SLA on all v2 tiers (including Basic v2)

**Key APIM Policies**:
- **rate-limit-by-key**: Throttle by subscription/IP
- **validate-jwt**: Token validation
- **set-backend-service**: Route to different backends
- **cache-lookup/cache-store**: Response caching
- **rewrite-uri**: URL transformation
- **authentication-managed-identity**: Authenticate to backends

**Tim's APIM Architecture**:
```
Internet --> Front Door (WAF) --> APIM (Premium v2, VNet injected) --> Backend services (Private Link)
```

**Tim's Tier Selection**:
- **New projects**: Start with v2 tiers for faster deployment
- **Enterprise with full isolation**: Premium v2 or Premium classic
- **Serverless APIs**: Consumption tier
- **Workspaces (federated)**: Premium or Premium v2 only

[API Management](https://learn.microsoft.com/azure/api-management/api-management-key-concepts) | [v2 Tiers](https://learn.microsoft.com/azure/api-management/v2-service-tiers-overview)

---

### Card 4.4: Migration Strategy

**Cloud Adoption Framework Migration Phases**:
1. **Assess**: Azure Migrate discovery, dependency mapping, cost estimation
2. **Deploy**: Landing zone setup (identity, networking, governance)
3. **Migrate**: Replicate and cut over workloads
4. **Optimize**: Right-size, implement PaaS, modernize

**Migration Tool Selection**:
| Workload | Tool |
|----------|------|
| VMs (VMware/Hyper-V) | Azure Migrate: Server Migration |
| SQL Server databases | Azure Database Migration Service |
| Web apps | Azure Migrate: Web Apps Migration |
| Data (bulk transfer, offline) | Data Box |
| Data (online, large scale) | AzCopy or Data Factory |

**Migration Strategy (5 Rs)**:
| Strategy | Description | When to Use |
|----------|-------------|-------------|
| Rehost | Lift-and-shift | Quick migration, minimal changes |
| Refactor | Minor modifications | Cloud benefits without rewrite |
| Rearchitect | Significant changes | PaaS adoption, scale requirements |
| Rebuild | Complete rewrite | Legacy replacement, cloud-native |
| Replace | SaaS adoption | Off-the-shelf better than custom |

**Tim's Migration Principle**: Start with Rehost, then optimize. Don't boil the ocean.

[Azure Migrate](https://learn.microsoft.com/azure/migrate/migrate-services-overview)

---

### Card 4.5: Network Connectivity

**Connectivity Options**:
| Scenario | Best Solution | Bandwidth | Latency |
|----------|---------------|-----------|---------|
| Site-to-site VPN | VPN Gateway | Up to 10 Gbps | Variable (internet) |
| Point-to-site VPN | VPN Gateway | Per client | Variable |
| Dedicated private connection | ExpressRoute | Up to 100 Gbps | Predictable, low |
| Branch office connectivity | Virtual WAN | Varies | Varies |
| Global routing | ExpressRoute Global Reach | Circuit speed | Lowest |

**VNet-to-VNet Connectivity**:
| Option | Use Case |
|--------|----------|
| VNet Peering | Same region or cross-region, low latency, non-transitive |
| VPN Gateway | Encrypted tunnel, transit routing |
| Virtual WAN | Large-scale hub-spoke, branch connectivity |

**Tim's Connectivity Rule**: Use ExpressRoute for production workloads with predictable latency requirements. VPN for dev/test or backup path.

**VPN Gateway SKUs (2025)**:
- **Basic**: Retired September 30, 2025 - migrate to VpnGw1 or higher
- **VpnGw1-5**: Production workloads, zone-redundant options available
- **VpnGw1AZ-5AZ**: Zone-redundant for HA

[ExpressRoute](https://learn.microsoft.com/azure/expressroute/expressroute-introduction)

---

### Card 4.6: Network Security

**Private Access to PaaS**:
| Option | Traffic Path | IP Address | On-premises Access |
|--------|--------------|------------|-------------------|
| Private Link | Private endpoint in VNet | Private IP | Yes (via VPN/ER) |
| Service Endpoint | Microsoft backbone | Public IP (secured) | No |

**Tim's Preference**: Always Private Link for production. Service Endpoints are acceptable for dev/test or when Private Link isn't supported.

**Private Link vs. Service Endpoints (2025)**:
| Feature | Private Link | Service Endpoints |
|---------|--------------|-------------------|
| IP Address | Private (your VNet) | Public (Microsoft) |
| On-premises access | Yes | No |
| Data exfiltration protection | Built-in | Requires additional config |
| Cross-region | Yes | No |
| DNS configuration | Required | Not required |
| Cost | Per endpoint + data | Free |

**Security Layers** (defense in depth):
| Layer | Service | Purpose |
|-------|---------|---------|
| Edge | Front Door + WAF | DDoS, OWASP rules, global |
| Network | Azure Firewall | Central egress, FQDN filtering, TLS inspection |
| Subnet | NSG | Port/IP filtering |
| Application | App Gateway WAF | Regional, backend protection |
| Identity | Entra ID + Conditional Access | Zero Trust verification |

**Load Balancer Selection**:
| Requirement | Best Choice |
|-------------|-------------|
| Global HTTP(S), multi-region, WAF, caching | Azure Front Door |
| Regional HTTP(S), WAF, path-based routing | Application Gateway |
| Regional TCP/UDP, ultra-high performance | Load Balancer Standard |
| Global DNS-based routing | Traffic Manager |
| API-specific load balancing | API Management |

**Load Balancer Decision Tree**:
```
Global or Regional?
  |
  +-- Global
  |     |
  |     +-- HTTP(S) traffic --> Front Door
  |     +-- Non-HTTP or DNS-only --> Traffic Manager
  |
  +-- Regional
        |
        +-- HTTP(S) with WAF/path routing --> Application Gateway
        +-- TCP/UDP Layer 4 --> Load Balancer Standard
```

**Important (2025)**: Basic Load Balancer retired September 30, 2025. Migrate to Standard.

[Private Link](https://learn.microsoft.com/azure/private-link/private-link-overview) | [Load Balancing Options](https://learn.microsoft.com/azure/architecture/guide/technology-choices/load-balancing-overview)

---

## Quick Decision Tables

### Storage Quick Reference

| Question | Answer |
|----------|--------|
| Where to store blobs? | Blob Storage |
| Where to store files (SMB)? | Azure Files |
| Where to store files (NFS, high perf)? | NetApp Files |
| Where to store relational data? | Azure SQL Database |
| Where to store JSON documents? | Cosmos DB |
| Where to store key-value? | Table Storage or Cosmos DB Table |
| Where to store streaming data? | Event Hubs or Cosmos DB |

### Security Quick Reference

| Requirement | Service |
|-------------|---------|
| Store secrets | Key Vault |
| Authenticate users | Entra ID |
| Authenticate consumers | Entra External ID |
| Authorize Azure resources | RBAC |
| Encrypt data at rest | Storage encryption (default) |
| Encrypt data in transit | TLS (default) |
| Inspect network traffic | Azure Firewall Premium |
| Protect web apps | WAF (Front Door or App Gateway) |
| Cloud security posture | Defender for Cloud |
| Privileged access | Entra PIM |

### Cost Quick Reference

| To Save Money... | Do This |
|------------------|---------|
| Reserved capacity (1-3 year) | VMs, SQL, Cosmos DB, App Service |
| Spot/Low-priority VMs | Batch processing, dev/test, fault-tolerant workloads |
| Auto-scaling | App Service, AKS, VMSS, Container Apps |
| Storage tiering | Lifecycle policies for cool/cold/archive |
| Right-sizing | Azure Advisor recommendations |
| Scale-to-zero | Container Apps, Functions (Consumption) |
| Standby replicas | SQL failover groups (reduced secondary cost) |
| Azure Hybrid Benefit | Existing Windows Server/SQL licenses |

---

## Exam Day Reminders

1. **Read the scenario carefully** - Requirements drive the answer
2. **Look for keywords**: "minimize cost," "minimal downtime," "maximize availability"
3. **Eliminate wrong answers first** - Usually 2 are clearly wrong
4. **When in doubt**: PaaS over IaaS, managed identity over secrets, Private Link over public
5. **Tim's mantra**: Zero Trust + Managed Identity + Private Link + Bicep

**Service Name Changes to Remember**:
- Azure AD --> Microsoft Entra ID
- Azure AD B2B --> Microsoft Entra External ID (B2B collaboration)
- Azure AD B2C --> Microsoft Entra External ID (for new projects, B2C end-of-sale May 2025)
- Azure AD Connect --> Microsoft Entra Connect Sync (consider Cloud Sync for new deployments)

**Good luck on your exam!**

---

## Additional Resources

- [AZ-305 Study Guide](https://learn.microsoft.com/credentials/certifications/resources/study-guides/az-305)
- [Azure Architecture Center](https://learn.microsoft.com/azure/architecture/)
- [Well-Architected Framework](https://learn.microsoft.com/azure/well-architected/)
- [Cloud Adoption Framework](https://learn.microsoft.com/azure/cloud-adoption-framework/)
- [Microsoft Entra Documentation](https://learn.microsoft.com/entra/)
- [Defender for Cloud Documentation](https://learn.microsoft.com/azure/defender-for-cloud/)
