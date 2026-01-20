# AZ-305 Reference Architectures

**Last Updated**: January 2025 | **Exam Version**: October 18, 2024 Update

Key architectures mapped directly to exam objectives. Each architecture includes Tim's opinionated recommendations and implementation guidance.

---

## Domain 1: Identity, Governance & Monitoring (25-30%)

### Architecture 1.1: Enterprise Logging and Monitoring

**Exam Objective**: Recommend logging and monitoring solutions

```
                                    +------------------+
                                    |   SIEM (Splunk)  |
                                    +--------^---------+
                                             |
+---------------+    Diagnostic    +---------+---------+
| Azure         |    Settings      |    Event Hub      |
| Resources     +----------------->+   (real-time)     |
| (VMs, SQL,    |                  +-------------------+
| App Service)  |
|               +----------------->+-------------------+
+---------------+    Diagnostic    | Log Analytics     |<--+ Azure Monitor
                     Settings      | Workspace         |   | Alerts
                                   | (centralized)     +---+
                +----------------->+-------------------+
                     Diagnostic
                     Settings      +-------------------+
                                   | Storage Account   |
                +----------------->| (archive 7+ yrs)  |
                                   +-------------------+
```

**Key Decisions**:
| Decision | Tim's Recommendation |
|----------|---------------------|
| Workspace topology | Single centralized workspace with resource-context RBAC |
| Retention strategy | 90 days in Log Analytics, 7+ years in Storage |
| SIEM integration | Event Hub for real-time streaming |
| Cost control | Enable sampling in App Insights, basic logs for verbose data |

**Implementation Checklist**:
- [ ] Deploy Log Analytics workspace with resource-context access mode
- [ ] Configure diagnostic settings for all resources (Activity Log, metrics, logs)
- [ ] Set up Event Hub namespace for SIEM integration
- [ ] Create action groups for critical alerts
- [ ] Deploy Azure Monitor Agent for VM telemetry

[Azure Monitor Architecture](https://learn.microsoft.com/azure/azure-monitor/best-practices-logs)

---

### Architecture 1.2: Zero Trust Identity

**Exam Objective**: Design authentication and authorization solutions

```
+-------------------+     +----------------------+     +------------------+
|   External Users  |     |  Microsoft Entra ID  |     |  Azure Resources |
|   (B2B Partners)  +---->+                      +---->+                  |
+-------------------+     |  - Conditional Access|     |  - Key Vault     |
                          |  - PIM               |     |  - SQL Database  |
+-------------------+     |  - Access Reviews    |     |  - Storage       |
|   Internal Users  +---->+                      |     |                  |
|   (Employees)     |     +----------+-----------+     +--------^---------+
+-------------------+                |                          |
                                     |                          |
+-------------------+                v                          |
|   Applications    |     +----------------------+              |
|   (App Service,   +---->+   Managed Identity   +--------------+
|   Container Apps) |     |   (User-Assigned)    |   RBAC/Data Plane
+-------------------+     +----------------------+   Access
```

**Key Decisions**:
| Decision | Tim's Recommendation |
|----------|---------------------|
| External collaboration | B2B with access packages (not B2C for partners) |
| App authentication | Managed identity (user-assigned for portability) |
| Privileged access | PIM with JIT activation, MFA required |
| Secrets management | Key Vault Premium with Private Link |

**Conditional Access Policy Matrix**:
| User Type | MFA | Device Compliance | Location | Session |
|-----------|-----|-------------------|----------|---------|
| Admins | Always | Required | Named locations only | 1hr max |
| Employees | Risk-based | Required | Any | 8hr max |
| B2B Guests | Always | Not enforced | Named locations only | 4hr max |

[Zero Trust Architecture](https://learn.microsoft.com/azure/security/fundamentals/zero-trust)

---

### Architecture 1.3: Governance Hierarchy

**Exam Objective**: Design governance structures and compliance

```
                    +---------------------------+
                    |    Root Management Group  |
                    |    (Tenant Root)          |
                    +-------------+-------------+
                                  |
                    +-------------+-------------+
                    |   Policy: Deny public IPs |
                    |   Policy: Require tags    |
                    |   Policy: Allowed regions |
                    +-------------+-------------+
                                  |
        +------------+------------+------------+------------+
        |            |            |            |            |
+-------v------+ +---v---+ +-----v-----+ +----v----+ +-----v-----+
|   Platform   | |Sandbox| |Landing    | |Decomm-  | |Connectivity|
|              | |       | |Zones      | |issioned | |            |
+--------------+ +-------+ +-----+-----+ +---------+ +------------+
                               |
              +----------------+----------------+
              |                |                |
        +-----v-----+    +-----v-----+    +-----v-----+
        |    Corp   |    |   Online  |    |    SAP    |
        | (internal)|    | (external)|    | (special) |
        +-----------+    +-----------+    +-----------+
              |
    +---------+---------+
    |         |         |
+---v---+ +---v---+ +---v---+
|  Dev  | | Test  | | Prod  |
+-------+ +-------+ +-------+
```

**Policy Assignment Strategy**:
| Level | Policies | Effect |
|-------|----------|--------|
| Root | Security baselines (deny public access, required tags) | Deny |
| Platform | Platform-specific (networking, monitoring) | DeployIfNotExists |
| Landing Zone | Application-specific (allowed SKUs) | Audit then Deny |
| Subscription | Environment-specific (allowed regions) | Deny |

**Tim's Governance Rules**:
1. Security policies at root with Deny effect = non-negotiable guardrails
2. Use Azure Policy initiatives (not individual policies) for manageability
3. Tag inheritance from resource group using Modify effect
4. Exempt sandbox subscriptions from cost policies (but not security)

[Cloud Adoption Framework Landing Zones](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/)

---

## Domain 2: Data Storage Solutions (20-25%)

### Architecture 2.1: Enterprise Data Platform

**Exam Objective**: Design data storage and integration solutions

```
+----------------+     +-----------------+     +-------------------+
| On-Premises    |     |   Azure Data    |     |  Azure Synapse    |
| SQL Server     +---->+   Factory       +---->+  Analytics        |
+----------------+  IR |  (orchestration)|     |  (warehouse)      |
                       +--------+--------+     +---------+---------+
+----------------+              |                        |
| SaaS Apps      +------------->+              +---------v---------+
| (Salesforce)   |              |              |   Power BI        |
+----------------+              |              |   (visualization) |
                                v              +-------------------+
                       +--------+--------+
                       |  ADLS Gen2      |
                       |  (data lake)    |
                       +-----------------+
```

**Storage Layer Decisions**:
| Data Type | Storage | Tier | Why |
|-----------|---------|------|-----|
| Raw ingestion | ADLS Gen2 | Hot | Hierarchical namespace for organization |
| Curated data | ADLS Gen2 | Cool | Processed, less frequent access |
| Archive | Blob Storage | Archive | Compliance retention |
| Operational DB | Azure SQL | N/A | Transactional workloads |
| Analytics DB | Synapse dedicated pool | N/A | Complex queries, star schema |

**Tim's Data Platform Principles**:
1. Bronze/Silver/Gold medallion architecture in ADLS
2. Data Factory for orchestration, Synapse for transformation
3. Private endpoints for all data services
4. Managed identity for all pipeline authentication

[Modern Data Warehouse](https://learn.microsoft.com/azure/architecture/solution-ideas/articles/modern-data-warehouse)

---

### Architecture 2.2: Multi-Region Database

**Exam Objective**: Design for database scalability and protection

```
                     +------------------+
                     |   Application    |
                     |   (connection to |
                     |   listener)      |
                     +--------+---------+
                              |
                              v
                     +--------+---------+
                     |  Failover Group  |
                     |  Listener        |
                     |  (auto-failover) |
                     +--------+---------+
                              |
            +-----------------+-----------------+
            |                                   |
+-----------v-----------+         +-------------v-----------+
|   Primary (East US)   |         |   Secondary (West US)   |
|   Azure SQL Database  |  Async  |   Azure SQL Database    |
|   Business Critical   +-------->+   Business Critical     |
|   Zone Redundant      |  Repl   |   Zone Redundant        |
|                       |         |   (Readable)            |
+-----------------------+         +-------------------------+
            |
            v
+---------------------------+
|   Read Replica            |
|   (Built-in, same region) |
|   For reporting queries   |
+---------------------------+
```

**Configuration Decisions**:
| Setting | Value | Why |
|---------|-------|-----|
| Service tier | Business Critical | Built-in read replica, zone redundancy |
| Failover mode | Automatic | Minimize RTO |
| Grace period | 1 hour | Balance between false positives and RTO |
| Read-intent routing | Enabled | Offload reporting to secondary |

**Tim's Database HA/DR Pattern**:
- Zone redundancy = HA within region (datacenter failure)
- Auto-failover group = DR across regions (regional failure)
- Both are needed for comprehensive resilience

[SQL Database Auto-Failover Groups](https://learn.microsoft.com/azure/azure-sql/database/auto-failover-group-overview)

---

### Architecture 2.3: Globally Distributed NoSQL

**Exam Objective**: Design semi-structured data solutions

```
                    +----------------------+
                    |   Cosmos DB Account  |
                    |   (API: NoSQL)       |
                    +----------+-----------+
                               |
        +----------------------+----------------------+
        |                      |                      |
+-------v-------+      +-------v-------+      +-------v-------+
|   East US     |      |   West Europe |      |   Southeast   |
|   (Write)     |<---->|   (Write)     |<---->|   Asia        |
|   Primary     | Sync |   Primary     | Sync |   (Write)     |
+---------------+      +---------------+      +---------------+
        |
        v
+---------------------------+
|   Partition Strategy      |
|   Key: /tenantId          |
|   Distributes data evenly |
+---------------------------+
```

**Configuration Decisions**:
| Setting | Value | Why |
|---------|-------|-----|
| API | NoSQL (Core) | Most flexible, widest feature set |
| Consistency | Session | Best balance of consistency and performance |
| Multi-region writes | Enabled | <10ms writes globally |
| Partition key | High cardinality field | Even data distribution |
| Conflict resolution | Last-Writer-Wins | Simple, suitable for most cases |

**Tim's Cosmos DB Rules**:
1. Partition key selection is permanent and critical - choose wisely
2. Session consistency unless you need stronger guarantees
3. Multi-region writes only if you need <10ms latency globally (cost impact)
4. Use serverless for dev/test, provisioned for production

[Cosmos DB Global Distribution](https://learn.microsoft.com/azure/cosmos-db/distribute-data-globally)

---

## Domain 3: Business Continuity (15-20%)

### Architecture 3.1: Enterprise Backup

**Exam Objective**: Design backup and recovery solutions

```
+------------------+
|  Recovery        |
|  Services Vault  |
|  (Central Mgmt)  |
+--------+---------+
         |
    +----+----+----+----+----+
    |         |         |         |
+---v---+ +---v---+ +---v---+ +---v---+
|Azure  | |Azure  | |Azure  | |SAP    |
|VMs    | |SQL in | |Files  | |HANA   |
|       | |VM     | |       | |       |
+-------+ +-------+ +-------+ +-------+

Policy Assignment:
- Daily backup at 2 AM
- 30-day instant recovery
- Weekly/Monthly/Yearly for LTR
- Soft delete enabled (14 days)
- RBAC: Backup Operators role
```

**Backup Policy Design**:
| Workload | Frequency | Instant Recovery | LTR |
|----------|-----------|------------------|-----|
| Production VMs | Daily | 30 days | 1 year monthly |
| SQL databases | Every 4 hours | 7 days | 7 years weekly |
| File shares | Daily | 30 days | 90 days |
| Dev/Test | Weekly | 7 days | None |

**Tim's Backup Non-Negotiables**:
1. Soft delete always enabled (ransomware protection)
2. Cross-region restore for critical workloads
3. RBAC separation: Backup Contributor vs. Backup Operator
4. Alert on backup failures (don't assume success)

[Azure Backup Architecture](https://learn.microsoft.com/azure/backup/backup-architecture)

---

### Architecture 3.2: Disaster Recovery

**Exam Objective**: Design DR solutions meeting recovery objectives

```
+------------------------+                    +------------------------+
|   Primary Region       |                    |   Secondary Region     |
|   (East US)            |                    |   (West US)            |
+------------------------+                    +------------------------+
|                        |                    |                        |
|  +------------------+  |   Continuous       |  +------------------+  |
|  |   Web Tier       |  |   Replication      |  |   Web Tier       |  |
|  |   (App Service)  +------------------------>+   (App Service)  |  |
|  +------------------+  |                    |  +------------------+  |
|                        |                    |                        |
|  +------------------+  |   ASR              |  +------------------+  |
|  |   App Tier       +------------------------>+   App Tier       |  |
|  |   (VMs)          |  |   Replication      |  |   (VMs-stopped)  |  |
|  +------------------+  |                    |  +------------------+  |
|                        |                    |                        |
|  +------------------+  |   Auto-Failover    |  +------------------+  |
|  |   SQL Database   +------------------------>+   SQL Database   |  |
|  |   (Primary)      |  |   Group            |  |   (Secondary)    |  |
|  +------------------+  |                    |  +------------------+  |
|                        |                    |                        |
+------------------------+                    +------------------------+
            |                                              |
            |              +------------------+            |
            +------------->+   Azure Front    +<-----------+
                           |   Door           |
                           |   (Global LB)    |
                           +------------------+
```

**Recovery Objectives**:
| Tier | RPO | RTO | Solution |
|------|-----|-----|----------|
| Web (PaaS) | 0 | <5 min | Active-active, Front Door routing |
| App (VMs) | <15 min | <1 hr | Azure Site Recovery |
| Database | <5 min | <30 min | Auto-failover group |
| Overall | <15 min | <1 hr | Recovery plan orchestration |

**Tim's DR Testing Schedule**:
| Test Type | Frequency | Scope |
|-----------|-----------|-------|
| Backup verification | Weekly | Random restore tests |
| ASR test failover | Monthly | Non-production environment |
| Full DR drill | Quarterly | Complete failover (planned) |

[Azure Site Recovery Planning](https://learn.microsoft.com/azure/site-recovery/site-recovery-overview)

---

### Architecture 3.3: High Availability Patterns

**Exam Objective**: Design HA solutions for compute and data

```
Region: East US
+------------------------------------------------------------------+
|                                                                  |
|   Zone 1              Zone 2              Zone 3                 |
|   +------------+      +------------+      +------------+         |
|   |    VM      |      |    VM      |      |    VM      |         |
|   +-----+------+      +-----+------+      +-----+------+         |
|         |                   |                   |                |
|   +-----v-------------------v-------------------v-----+          |
|   |        Azure Load Balancer (Zone-Redundant)      |          |
|   +----------------------------+---------------------+          |
|                                |                                 |
|   +----------------------------v---------------------+          |
|   |        Azure SQL Database (Zone-Redundant)       |          |
|   +--------------------------------------------------+          |
|                                                                  |
+------------------------------------------------------------------+
                                |
                                v
                    +-----------+-----------+
                    |    Azure Front Door   |
                    |    (Global entry)     |
                    +-----------------------+
```

**SLA Calculations**:
| Configuration | Compute SLA | Database SLA | Composite |
|---------------|-------------|--------------|-----------|
| Single VM | 99.9% | 99.99% | 99.89% |
| Availability Set | 99.95% | 99.99% | 99.94% |
| Availability Zones | 99.99% | 99.99% | 99.98% |
| Multi-region active | 99.99%+ | 99.995% | 99.99%+ |

**Tim's HA Decision Matrix**:
| Failure Scope | Solution |
|---------------|----------|
| Single VM/instance | Availability Set (rack/update domains) |
| Datacenter | Availability Zones |
| Region | Multi-region with Front Door/Traffic Manager |

[Availability Zones Overview](https://learn.microsoft.com/azure/availability-zones/az-overview)

---

## Domain 4: Infrastructure Solutions (30-35%)

### Architecture 4.1: Modern Application Platform

**Exam Objective**: Design compute and application architecture

```
                    +------------------+
                    |   Azure Front    |
                    |   Door + WAF     |
                    +--------+---------+
                             |
                    +--------v---------+
                    |   API Management |
                    |   (Premium, VNet)|
                    +--------+---------+
                             |
         +-------------------+-------------------+
         |                   |                   |
+--------v--------+ +--------v--------+ +--------v--------+
| Container Apps  | | Container Apps  | | Container Apps  |
| (Order Service) | | (Inventory Svc) | | (Payment Svc)   |
| + Dapr state    | | + Dapr pubsub   | | + Dapr secrets  |
+-----------------+ +-----------------+ +-----------------+
         |                   |                   |
         +-------------------+-------------------+
                             |
                    +--------v---------+
                    |  Azure Service   |
                    |  Bus (messaging) |
                    +--------+---------+
                             |
         +-------------------+-------------------+
         |                   |                   |
+--------v--------+ +--------v--------+ +--------v--------+
| Azure SQL DB    | | Cosmos DB       | | Azure Cache     |
| (transactions)  | | (catalog)       | | for Redis       |
+-----------------+ +-----------------+ +-----------------+

All resources connected via Private Endpoints
Managed Identity for all service-to-service auth
```

**Compute Selection**:
| Workload Type | Best Choice | Why |
|---------------|-------------|-----|
| HTTP microservices | Container Apps | Dapr, KEDA, scale-to-zero |
| Kubernetes-native apps | AKS | Full K8s control, operators |
| Event-driven functions | Azure Functions | Consumption billing |
| Legacy Windows apps | App Service or VMs | .NET Framework support |
| Batch processing | Azure Batch | Low-priority VMs, job scheduling |

**Tim's Container Apps Recommendation**: Start here for new microservices. Only move to AKS if you need custom operators, Windows containers, or specific networking requirements.

[Container Apps Overview](https://learn.microsoft.com/azure/container-apps/overview)

---

### Architecture 4.2: Hub-Spoke Network

**Exam Objective**: Design network connectivity and security

```
                              +-------------------+
                              |   On-Premises     |
                              |   Datacenter      |
                              +--------+----------+
                                       |
                              +--------v----------+
                              |   ExpressRoute    |
                              |   Circuit         |
                              +--------+----------+
                                       |
+------------------------------------------------------------------------------+
|                              Hub VNet (10.0.0.0/16)                          |
|                                                                              |
|  +----------------+  +----------------+  +----------------+                  |
|  | GatewaySubnet  |  | AzureFirewall  |  | AzureBastion   |                  |
|  | (ExpressRoute) |  | Subnet         |  | Subnet         |                  |
|  +----------------+  +-------+--------+  +----------------+                  |
|                              |                                               |
+------------------------------------------------------------------------------+
                               |
        +----------------------+----------------------+
        |                      |                      |
+-------v-------+      +-------v-------+      +-------v-------+
| Spoke: Prod   |      | Spoke: Dev    |      | Spoke: Shared |
| 10.1.0.0/16   |      | 10.2.0.0/16   |      | 10.3.0.0/16   |
|               |      |               |      |               |
| - App Service |      | - VMs         |      | - Key Vault   |
| - SQL (PE)    |      | - AKS         |      | - ACR         |
| - Storage (PE)|      |               |      | - Log Analytics|
+---------------+      +---------------+      +---------------+
```

**Network Security Layers**:
| Layer | Service | Purpose |
|-------|---------|---------|
| Perimeter | Azure Firewall Premium | Centralized egress, TLS inspection |
| Edge (web) | Front Door WAF | DDoS, OWASP protection |
| Subnet | NSG | Port/IP filtering |
| Service | Private Endpoints | Private PaaS access |

**Routing Configuration**:
| Traffic Flow | Route |
|--------------|-------|
| Spoke-to-spoke | Via Azure Firewall (forced tunnel) |
| Spoke-to-internet | Via Azure Firewall (default route) |
| Spoke-to-on-premises | Via ExpressRoute gateway |

**Tim's Networking Principle**: All egress through Azure Firewall. All PaaS access via Private Link. No exceptions for production.

[Hub-Spoke Reference Architecture](https://learn.microsoft.com/azure/architecture/reference-architectures/hybrid-networking/hub-spoke)

---

### Architecture 4.3: Virtual WAN

**Exam Objective**: Design connectivity for branch offices

```
                    +----------------------+
                    |   Virtual WAN        |
                    |   (Microsoft-managed)|
                    +----------+-----------+
                               |
        +----------------------+----------------------+
        |                      |                      |
+-------v-------+      +-------v-------+      +-------v-------+
| Hub: East US  |      | Hub: West EU  |      | Hub: SE Asia  |
| (Secured)     |      | (Secured)     |      | (Secured)     |
+-------+-------+      +-------+-------+      +-------+-------+
        |                      |                      |
  +-----+-----+          +-----+-----+          +-----+-----+
  |     |     |          |     |     |          |     |     |
  v     v     v          v     v     v          v     v     v
Branch Branch VNet    Branch Branch VNet    Branch Branch VNet
 1      2    Spoke     3      4    Spoke     5      6    Spoke

Connections:
- S2S VPN (branches)
- ExpressRoute (datacenters)
- VNet peering (Azure workloads)
- SD-WAN integration (Cisco, VMware, etc.)
```

**When to Use Virtual WAN vs. Hub-Spoke**:
| Factor | Virtual WAN | Traditional Hub-Spoke |
|--------|-------------|----------------------|
| Branch count | Many (20+) | Few (<10) |
| Management | Microsoft-managed | Customer-managed |
| SD-WAN integration | Native partners | Manual NVA |
| Routing complexity | Automatic | Manual UDRs |
| Cost | Higher | Lower |

**Tim's Virtual WAN Guidance**: Use when you have 10+ branches OR need SD-WAN integration. Otherwise, traditional hub-spoke is more cost-effective.

[Virtual WAN Overview](https://learn.microsoft.com/azure/virtual-wan/virtual-wan-about)

---

### Architecture 4.4: Migration Landing Zone

**Exam Objective**: Design migrations using Cloud Adoption Framework

```
Phase 1: Assess                    Phase 2: Deploy Landing Zone
+------------------+               +------------------------+
| Azure Migrate    |               | Management Groups      |
| - Discovery      |               | Azure Policy           |
| - Dependencies   |               | Hub-Spoke Network      |
| - Assessment     |               | Identity (Entra ID)    |
| - Cost estimate  |               | Logging (Log Analytics)|
+------------------+               +------------------------+
         |                                    |
         v                                    v
Phase 3: Migrate                   Phase 4: Optimize
+------------------+               +------------------------+
| Azure Migrate    |               | Azure Advisor          |
| - Server Migr    |               | Right-sizing           |
| - Database Migr  |               | Reserved Instances     |
| - Web App Migr   |               | PaaS modernization     |
+------------------+               +------------------------+
```

**Migration Wave Planning**:
| Wave | Workloads | Strategy | Timeline |
|------|-----------|----------|----------|
| 0 | Infrastructure (AD, DNS) | Extend/Replicate | Week 1-2 |
| 1 | Low-risk apps (dev/test) | Rehost | Week 3-4 |
| 2 | Standard workloads | Rehost | Week 5-8 |
| 3 | Complex workloads | Refactor | Week 9-12 |
| 4 | Critical apps | Rearchitect | Week 13+ |

**Tim's Migration Principles**:
1. Assess EVERYTHING before migrating ANYTHING
2. Landing zone must be ready before first workload moves
3. Start with rehost, optimize later (don't boil the ocean)
4. Parallel track for database migrations (DMS)

[Azure Migrate Overview](https://learn.microsoft.com/azure/migrate/migrate-services-overview)

---

## Quick Architecture Decision Reference

### By Scenario

| Scenario | Architecture Pattern |
|----------|---------------------|
| Global web app | Front Door + App Service (multi-region) |
| Enterprise API | APIM + Container Apps/AKS + Service Bus |
| Data platform | ADLS + Data Factory + Synapse |
| Hybrid connectivity | ExpressRoute + Hub-Spoke |
| Branch offices | Virtual WAN |
| IoT telemetry | IoT Hub + Event Hubs + Stream Analytics |
| Microservices | Container Apps with Dapr |

### By Exam Domain

| Domain | Key Architectures |
|--------|-------------------|
| Identity/Governance | Zero Trust, Landing Zone hierarchy |
| Data Storage | Modern Data Warehouse, Multi-region DB |
| Business Continuity | DR with ASR, Enterprise Backup |
| Infrastructure | Hub-Spoke, Container Platform, Virtual WAN |

---

## Implementation Resources

**Bicep Samples**:
- [Azure Verified Modules](https://azure.github.io/Azure-Verified-Modules/)
- [Bicep Registry](https://github.com/Azure/bicep-registry-modules)

**Reference Architectures**:
- [Azure Architecture Center](https://learn.microsoft.com/azure/architecture/)
- [Well-Architected Framework](https://learn.microsoft.com/azure/well-architected/)
- [Landing Zone Accelerators](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/)

**Hands-on Labs**:
- [AZ-305 Microsoft Learning Labs](https://github.com/MicrosoftLearning/AZ-305-DesigningMicrosoftAzureInfrastructureSolutions)
- [Azure Citadel](https://azurecitadel.com/)

---

## Attribution

All architecture patterns align with Microsoft Azure Well-Architected Framework and Cloud Adoption Framework best practices. Diagrams are conceptual representations for educational purposes.
