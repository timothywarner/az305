# AZ-305 Designing Azure Infrastructure Solutions - Course Flow

**Instructor:** Tim Warner | **Platform:** O'Reilly Live Learning
**Duration:** 5 x 50-minute segments with 10-minute breaks
**Exam Version:** Skills measured as of October 18, 2024

---

## Schedule Overview

| Time | Activity |
|------|----------|
| 9:00 AM | Segment 1 - Foundations: Identity, Governance & Monitoring |
| 9:50 AM | Break (10 min) |
| 10:00 AM | Segment 2 - Data Storage Solutions |
| 10:50 AM | Break (10 min) |
| 11:00 AM | Segment 3 - Business Continuity & High Availability |
| 11:50 AM | Break (10 min) |
| 12:00 PM | Segment 4 - Infrastructure: Compute & Application Architecture |
| 12:50 PM | Break (10 min) |
| 1:00 PM | Segment 5 - Infrastructure: Networking & Migrations |
| 1:50 PM | Course Complete |

---

## Exam Objective Distribution

| Domain | Weight | Primary Segment | Secondary Coverage |
|--------|--------|-----------------|-------------------|
| Identity, Governance & Monitoring | 25-30% | Segment 1 | Woven throughout |
| Data Storage Solutions | 20-25% | Segment 2 | Segment 3 (HA) |
| Business Continuity Solutions | 15-20% | Segment 3 | All segments |
| Infrastructure Solutions | 30-35% | Segments 4-5 | Segment 1 (monitoring) |

---

## Segment 1 (9:00-9:50) - Foundations: Identity, Governance & Monitoring

**Theme: "Identity is the Control Plane - Everything Else Follows"**

### Why This Comes First
Identity and governance form the foundation of every Azure deployment. You cannot design secure compute, storage, or networking without first understanding authentication, authorization, and organizational hierarchy. This segment establishes the mental model for all subsequent design decisions.

### Learning Objectives (Exam Domain: 25-30%)

**Design Solutions for Logging and Monitoring**
- Recommend a logging solution (Log Analytics workspace topology, retention tiers)
- Recommend a solution for routing logs (diagnostic settings, Azure Monitor Agent)
- Recommend a monitoring solution (Azure Monitor, Application Insights, alerts)

**Design Authentication and Authorization Solutions**
- Recommend an authentication solution (Entra ID, B2B, B2C, federation)
- Recommend an identity management solution (Entra ID vs. hybrid)
- Recommend a solution for authorizing access to Azure resources (RBAC, custom roles)
- Recommend a solution for authorizing access to on-premises resources (Entra Connect, pass-through auth)
- Recommend a solution to manage secrets, certificates, and keys (Key Vault)

**Design Governance**
- Recommend a structure for management groups, subscriptions, and resource groups
- Recommend a strategy for resource tagging
- Recommend a solution for managing compliance (Azure Policy, Deployment Stacks; Blueprints deprecated July 2026)
- Recommend a solution for identity governance (PIM, access reviews, entitlement management)

### Key Topics to Cover

| Topic | Time | Focus |
|-------|------|-------|
| Azure Monitor ecosystem | 8 min | Log Analytics workspace design patterns (centralized vs. distributed) |
| Entra ID architecture | 10 min | B2B vs. B2C decision tree, hybrid identity patterns |
| RBAC deep dive | 8 min | Built-in vs. custom roles, deny assignments, scope inheritance |
| Management hierarchy | 8 min | Management groups, subscriptions, RGs - when to split |
| Azure Policy | 8 min | Policy effects, initiatives, exemptions, compliance remediation |
| Key Vault patterns | 8 min | Soft delete, purge protection, RBAC vs. access policies |

### Live Demo Flow (4-5 demos)

1. **Log Analytics Workspace Topology** (8 min)
   - Create workspace with data collection rules
   - Configure diagnostic settings for multiple resource types
   - Show workspace-based retention vs. archive tiers
   - Query with KQL: resource-specific tables

2. **Entra ID B2B Guest Configuration** (8 min)
   - Invite external user with redemption flow
   - Configure cross-tenant access settings
   - Show conditional access policy for guests
   - Demonstrate access package with entitlement management

3. **Custom RBAC Role Creation** (8 min)
   - Create custom role via Azure CLI
   - Assign at subscription scope
   - Test with "What If" in portal
   - Show NotActions vs. deny assignments

4. **Azure Policy Initiative Deployment** (8 min)
   - Deploy built-in initiative (CIS benchmark)
   - Create custom policy definition
   - Configure remediation task
   - Review compliance dashboard

5. **Key Vault with Managed Identity** (8 min)
   - Create Key Vault with RBAC permission model
   - Enable soft delete and purge protection
   - Configure managed identity access
   - Demonstrate secret rotation pattern

### Exam Tips for Segment 1

- **RBAC scope matters**: If a question mentions "multiple subscriptions" - think management group scope
- **Log Analytics retention**: Default 30 days free, max 730 days, archive tier for cold data
- **Key Vault question keywords**: "compliance" = purge protection, "rotation" = Event Grid integration
- **Entra B2B vs B2C**: B2B = partner organizations, B2C = customer/consumer identities
- **Policy vs. Initiative**: Single requirement = policy, compliance framework = initiative
- **PIM vs. Access Reviews**: PIM = just-in-time elevation, Access Reviews = periodic attestation

---

## Segment 2 (10:00-10:50) - Data Storage Solutions

**Theme: "Right Data, Right Service, Right Tier"**

### Why This Comes Second
With identity and governance established, we now tackle data - the heart of most Azure solutions. Understanding storage patterns is prerequisite to business continuity (Segment 3) and application architecture (Segment 4).

### Learning Objectives (Exam Domain: 20-25%)

**Design Data Storage Solutions for Relational Data**
- Recommend a solution for storing relational data (SQL Database, SQL MI, PostgreSQL, MySQL)
- Recommend a database service tier and compute tier (DTU vs. vCore, serverless vs. provisioned)
- Recommend a solution for database scalability (read replicas, sharding, elastic pools)
- Recommend a solution for data protection (TDE, Always Encrypted, dynamic data masking)

**Design Data Storage Solutions for Semi-Structured and Unstructured Data**
- Recommend a solution for storing semi-structured data (Cosmos DB, Table Storage)
- Recommend a solution for storing unstructured data (Blob Storage, Data Lake Storage Gen2)
- Recommend a data storage solution to balance features, performance, and costs
- Recommend a data solution for protection and durability

**Design Data Integration**
- Recommend a solution for data integration (Data Factory, Synapse pipelines)
- Recommend a solution for data analysis (Synapse Analytics, Databricks, Power BI)

### Key Topics to Cover

| Topic | Time | Focus |
|-------|------|-------|
| SQL Database decision tree | 8 min | When SQL DB vs. SQL MI vs. SQL on VM |
| Service tier selection | 8 min | DTU vs. vCore, serverless vs. provisioned breakpoints |
| Cosmos DB partition strategy | 10 min | Partition key selection, RU estimation, global distribution |
| Storage account architecture | 8 min | Performance tiers, access tiers, lifecycle management |
| Data Lake design patterns | 8 min | Hierarchical namespace, bronze/silver/gold zones |
| Data integration patterns | 8 min | Data Factory vs. Synapse pipelines, when to use each |

### Live Demo Flow (4-5 demos)

1. **SQL Database Elastic Pool Configuration** (10 min)
   - Create elastic pool with vCore model
   - Add databases with different workload profiles
   - Show eDTU/vCore sharing and limits
   - Configure auto-pause for dev/test databases
   - Demonstrate read replica for reporting workload

2. **Cosmos DB Multi-Region with Partition Strategy** (10 min)
   - Create account with multiple write regions
   - Design partition key for e-commerce scenario
   - Show cross-partition query cost
   - Configure consistency level tradeoffs
   - Enable analytical store for HTAP

3. **Storage Account Lifecycle Management** (8 min)
   - Create storage account with Data Lake Gen2
   - Configure lifecycle policy (hot -> cool -> archive)
   - Set up immutable storage with legal hold
   - Show soft delete and versioning recovery
   - Configure private endpoint

4. **Data Factory Pipeline with Managed Identity** (10 min)
   - Create linked services with managed identity auth
   - Build copy pipeline with incremental load pattern
   - Configure integration runtime for hybrid scenarios
   - Show monitoring and alerting
   - Demonstrate parameterized datasets

5. **Synapse Analytics Quick Tour** (8 min)
   - Serverless SQL pool query over Data Lake
   - Dedicated pool for warehouse workloads
   - Spark pool for transformation
   - Show unified monitoring dashboard

### Exam Tips for Segment 2

- **SQL MI vs. SQL Database**: MI = near 100% SQL Server compatibility, requires VNet
- **DTU vs. vCore decision**: vCore when you need reserved capacity, hybrid benefit, or resource governance
- **Cosmos DB consistency**: Strong = highest latency/cost, Eventual = lowest, Session = default sweet spot
- **Storage redundancy keywords**: "regional outage" = GRS/GZRS, "zone failure" = ZRS, "cost sensitive" = LRS
- **Partition key rules**: High cardinality, even distribution, included in most queries
- **Data Factory vs. Synapse pipelines**: Same engine - Synapse for unified analytics, ADF for pure ETL

---

## Segment 3 (11:00-11:50) - Business Continuity & High Availability

**Theme: "Design for Failure - Because It Will Happen"**

### Why This Comes Third
Business continuity concepts (RTO/RPO, backup, DR) apply to everything we have learned so far (identity, data) and everything that follows (compute, networking). This segment teaches the resilience patterns that must inform all architectural decisions.

### Learning Objectives (Exam Domain: 15-20%)

**Design Solutions for Backup and Disaster Recovery**
- Recommend a recovery solution for Azure and hybrid workloads that meets recovery objectives
- Recommend a backup and recovery solution for compute
- Recommend a backup and recovery solution for databases
- Recommend a backup and recovery solution for unstructured data

**Design for High Availability**
- Recommend a high availability solution for compute
- Recommend a high availability solution for relational data
- Recommend a high availability solution for semi-structured and unstructured data

### Key Topics to Cover

| Topic | Time | Focus |
|-------|------|-------|
| RTO/RPO fundamentals | 6 min | Business requirements to technical design |
| Azure Backup architecture | 10 min | Vault types, MARS agent, backup policies |
| Azure Site Recovery | 10 min | DR for VMs, replication, recovery plans |
| Compute HA patterns | 8 min | Availability sets vs. zones vs. VMSS |
| Database HA options | 8 min | SQL Always On, Cosmos DB multi-region, failover groups |
| Storage HA patterns | 8 min | Redundancy options, RA-GRS failover |

### Key Topics to Cover (Continued)

**RTO/RPO Decision Matrix**

| Requirement | Solution Pattern |
|-------------|-----------------|
| RPO = 0 (no data loss) | Synchronous replication (Availability Zones, Always On sync) |
| RPO < 1 hour | Continuous replication (ASR, geo-replication) |
| RPO < 24 hours | Daily backups with transaction log backup |
| RTO < 1 hour | Hot standby, auto-failover groups |
| RTO < 4 hours | Warm standby, Azure Site Recovery |
| RTO < 24 hours | Cold standby, backup restore |

### Live Demo Flow (4-5 demos)

1. **Recovery Services Vault Configuration** (10 min)
   - Create vault with geo-redundancy
   - Configure backup policy for VMs (daily, weekly, monthly retention)
   - Enable cross-region restore
   - Show instant restore from snapshot tier
   - Configure backup alerts and reports

2. **Azure Site Recovery for VM DR** (12 min)
   - Enable replication for VM to paired region
   - Configure replication policy (RPO target)
   - Run test failover without impacting production
   - Show recovery plan with pre/post scripts
   - Demonstrate failback process

3. **SQL Database Auto-Failover Groups** (10 min)
   - Create failover group across regions
   - Configure read-write and read-only endpoints
   - Initiate manual failover
   - Show grace period for data loss
   - Demonstrate application connection string pattern

4. **Availability Zone Deployment** (10 min)
   - Deploy VM across zones using Azure CLI
   - Configure zone-redundant load balancer
   - Show zone health and failover behavior
   - Compare to availability sets
   - Calculate composite SLA

5. **Storage Account Failover** (8 min)
   - Configure RA-GRS storage
   - Initiate customer-managed failover
   - Show data consistency implications
   - Configure blob soft delete for accidental deletion
   - Point-in-time restore demonstration

### Exam Tips for Segment 3

- **RPO vs. RTO confusion**: RPO = acceptable data loss (time), RTO = acceptable downtime (time)
- **Availability Sets vs. Zones**: Sets = rack/power fault domains, Zones = datacenter-level isolation
- **VM SLA math**: Single VM Premium SSD = 99.9%, Availability Set = 99.95%, Availability Zones = 99.99%
- **Backup vault vs. ASR vault**: Both use Recovery Services vault, but different purposes
- **SQL failover group endpoints**: Always use `.database.windows.net` listener, not server name
- **GRS failover keywords**: "customer-managed" = you initiate, "Microsoft-managed" = regional disaster

---

## Segment 4 (12:00-12:50) - Infrastructure: Compute & Application Architecture

**Theme: "From VMs to Serverless - Pick the Right Abstraction"**

### Why This Comes Fourth
With data storage and business continuity patterns established, we now design the compute layer and application architecture that processes that data. This segment covers half of the largest exam domain (30-35%).

### Learning Objectives (Exam Domain: ~17% of Infrastructure)

**Design Compute Solutions**
- Specify components of a compute solution based on workload requirements
- Recommend a virtual machine-based solution
- Recommend a container-based solution
- Recommend a serverless-based solution
- Recommend a compute solution for batch processing

**Design an Application Architecture**
- Recommend a messaging architecture
- Recommend an event-driven architecture
- Recommend a solution for API integration
- Recommend a caching solution for applications
- Recommend an application configuration management solution
- Recommend an automated deployment solution for applications

### Key Topics to Cover

| Topic | Time | Focus |
|-------|------|-------|
| Compute decision tree | 8 min | VM -> Container Apps -> Functions decision criteria |
| VM-based patterns | 6 min | VMSS, proximity placement, dedicated hosts |
| Container options | 8 min | ACI vs. Container Apps vs. AKS decision matrix |
| Serverless patterns | 8 min | Functions consumption vs. premium vs. dedicated |
| Messaging architecture | 10 min | Service Bus vs. Event Hubs vs. Event Grid |
| App architecture patterns | 10 min | APIM, Redis Cache, App Configuration |

### Compute Decision Matrix

| Requirement | Recommended Service |
|-------------|-------------------|
| Lift-and-shift, full OS control | Virtual Machines + VMSS |
| Microservices, some orchestration | Azure Container Apps |
| Complex orchestration, Kubernetes expertise | Azure Kubernetes Service |
| Simple container workloads, batch | Azure Container Instances |
| Event-driven, short-lived, cost sensitive | Azure Functions Consumption |
| Event-driven, VNet, longer execution | Azure Functions Premium |
| HPC, batch rendering, parallel compute | Azure Batch |

### Messaging Decision Matrix

| Pattern | Service | Use Case |
|---------|---------|----------|
| Point-to-point commands | Service Bus Queues | Order processing, task dispatch |
| Pub/sub with filtering | Service Bus Topics | Multi-subscriber notifications |
| High-throughput streaming | Event Hubs | Telemetry, log aggregation |
| Reactive event routing | Event Grid | Resource events, webhooks |
| Legacy integration | Logic Apps | B2B, EDI, workflow orchestration |

### Live Demo Flow (4-5 demos)

1. **Container Apps with Auto-Scale** (10 min)
   - Deploy containerized API to Container Apps
   - Configure HTTP scale rule
   - Enable Dapr for service discovery
   - Show managed identity integration
   - Blue-green deployment with revisions

2. **Azure Functions with Service Bus Trigger** (10 min)
   - Create Function App with Premium plan (VNet integration)
   - Configure Service Bus trigger binding
   - Show dead-letter queue handling
   - Demonstrate managed identity for queue access
   - Configure Application Insights integration

3. **Event Grid Custom Topics** (8 min)
   - Create custom topic with schema validation
   - Configure webhook subscription with filters
   - Show CloudEvents schema
   - Dead-letter destination configuration
   - Event delivery retry policy

4. **API Management with OAuth 2.0** (12 min)
   - Create APIM instance (consumption tier for demo)
   - Import OpenAPI spec
   - Configure JWT validation policy
   - Set up rate limiting and quota
   - Show developer portal customization

5. **Azure Cache for Redis Pattern** (8 min)
   - Create Redis cache with clustering
   - Implement cache-aside pattern in code
   - Configure geo-replication for DR
   - Show connection resiliency patterns
   - Demonstrate data persistence options

### Exam Tips for Segment 4

- **Container Apps vs. AKS**: Container Apps for simplicity + Dapr, AKS for full Kubernetes control
- **Functions plan selection**: Consumption = auto-scale to zero, Premium = VNet + no cold start, Dedicated = predictable cost
- **Service Bus vs. Event Grid**: Service Bus = commands/transactions, Event Grid = events/notifications
- **Event Hubs partitions**: Cannot increase after creation, plan for peak throughput
- **APIM tier selection**: Consumption = serverless, Developer = dev/test, Standard/Premium = production
- **Redis clustering**: Required for >53GB, enables horizontal scaling

---

## Segment 5 (1:00-1:50) - Infrastructure: Networking & Migrations

**Theme: "Zero Trust Networking and Cloud Adoption Framework"**

### Why This Comes Last
Networking ties everything together - compute, storage, and identity all require network connectivity. Migrations leverage all prior knowledge. Ending here provides a comprehensive view of how all components integrate.

### Learning Objectives (Exam Domain: ~18% of Infrastructure)

**Design Network Solutions**
- Recommend a connectivity solution that connects Azure resources to the internet
- Recommend a connectivity solution that connects Azure resources to on-premises networks
- Recommend a solution to optimize network performance
- Recommend a solution to optimize network security
- Recommend a load-balancing and routing solution

**Design Migrations**
- Evaluate a migration solution that leverages the Microsoft Cloud Adoption Framework for Azure
- Evaluate on-premises servers, data, and applications for migration
- Recommend a solution for migrating workloads to infrastructure as a service (IaaS) and platform as a service (PaaS)
- Recommend a solution for migrating databases
- Recommend a solution for migrating unstructured data

### Key Topics to Cover

| Topic | Time | Focus |
|-------|------|-------|
| Network topology patterns | 8 min | Hub-spoke vs. Virtual WAN decision tree |
| Hybrid connectivity | 8 min | VPN Gateway vs. ExpressRoute vs. both |
| Network security | 10 min | NSG vs. ASG vs. Azure Firewall vs. NVA |
| Load balancing decision | 8 min | Load Balancer vs. App Gateway vs. Front Door vs. Traffic Manager |
| CAF migration phases | 8 min | Assess, migrate, optimize, secure |
| Migration tooling | 8 min | Azure Migrate, DMS, Data Box |

### Network Security Decision Matrix

| Requirement | Solution |
|-------------|----------|
| L4 stateful filtering | Network Security Groups |
| Application-aware L7 filtering | Azure Firewall Premium |
| Web application protection (OWASP) | Application Gateway WAF / Front Door WAF |
| Third-party appliance required | Network Virtual Appliance |
| Microsegmentation | Application Security Groups |
| DNS-based filtering | Azure Firewall DNS Proxy |

### Load Balancing Decision Matrix

| Traffic Type | Scope | Solution |
|--------------|-------|----------|
| HTTP/HTTPS | Global | Azure Front Door |
| HTTP/HTTPS | Regional | Application Gateway |
| Non-HTTP | Global | Traffic Manager + LB/App GW |
| Non-HTTP | Regional | Azure Load Balancer |
| Any | Cross-premises | Traffic Manager |

### Live Demo Flow (4-5 demos)

1. **Hub-Spoke Network Topology** (12 min)
   - Deploy hub VNet with Azure Firewall
   - Create spoke VNets with peering
   - Configure UDR for forced tunneling
   - Enable Azure Firewall policy rules
   - Show network flow logging

2. **Private Link Service Setup** (10 min)
   - Create Private Endpoint for SQL Database
   - Configure private DNS zone integration
   - Disable public network access
   - Show DNS resolution flow
   - Compare to Service Endpoints

3. **Application Gateway with WAF** (10 min)
   - Deploy App Gateway v2 with WAF policy
   - Configure backend pool with VMs
   - Enable OWASP rule set
   - Set up custom WAF rules
   - Show WAF logs in Log Analytics

4. **Azure Migrate Assessment** (10 min)
   - Set up Azure Migrate project
   - Run discovery with appliance
   - Show assessment report (sizing, cost, readiness)
   - Demonstrate dependency visualization
   - Create migration wave groups

5. **Database Migration Service** (8 min)
   - Create DMS instance in VNet
   - Configure source (SQL Server) and target (SQL MI)
   - Run online migration with minimal downtime
   - Show cutover process
   - Validate migration completion

### Exam Tips for Segment 5

- **Hub-spoke vs. Virtual WAN**: Virtual WAN for >10 spokes or SD-WAN integration
- **ExpressRoute vs. VPN**: ExpressRoute = private connection, VPN = over internet
- **Private Link vs. Service Endpoints**: Private Link = private IP in your VNet, Service Endpoints = optimized route to public IP
- **Azure Firewall vs. NSG**: Firewall = centralized, stateful, FQDN filtering; NSG = distributed, L3/L4 only
- **Front Door vs. Traffic Manager**: Front Door = CDN + WAF + acceleration, Traffic Manager = DNS-based only
- **CAF phases keyword**: "Assess" = discovery, "Migrate" = replicate, "Optimize" = right-size, "Secure" = governance

---

## Cross-Cutting Themes (Reinforce Throughout)

### Well-Architected Framework Pillars
Reference these pillars in every segment discussion:

| Pillar | Key Questions |
|--------|--------------|
| **Reliability** | What is the SLA? What happens when this fails? |
| **Security** | Who can access this? How are secrets managed? |
| **Cost Optimization** | What is the cost model? Can we right-size? |
| **Operational Excellence** | How do we monitor? How do we deploy? |
| **Performance Efficiency** | Can it scale? What are the limits? |

### Zero Trust Architecture
Reinforce in every demo:
- Verify explicitly (authentication everywhere)
- Use least privilege access (scoped RBAC)
- Assume breach (network segmentation, encryption)

### Managed Identity Pattern
Every demo should use managed identity where possible:
- Key Vault access
- Storage account access
- SQL Database access
- Service Bus access

---

## Required Tools and Setup

### Instructor Workstation
- VS Code with Azure Tools extension pack
- Azure CLI 2.x (latest)
- PowerShell 7.x with Az module
- Bicep CLI
- Docker Desktop (for container demos)

### Azure Environment
- Demonstration subscription with Contributor access
- Pre-created resource groups for each segment
- Service principals and managed identities pre-configured
- Sample data loaded in databases

### Portal Bookmarks
- Azure Portal (portal.azure.com)
- Entra Admin Center (entra.microsoft.com)
- Microsoft Learn AZ-305 Study Guide (learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/az-305)
- Azure Architecture Center (learn.microsoft.com/en-us/azure/architecture/)

---

## Post-Course Resources

Share these links at course completion:

1. **Practice Assessment**: https://learn.microsoft.com/en-us/credentials/certifications/exams/az-305/practice/assessment?assessment-type=practice&assessmentId=15
2. **Exam Sandbox**: https://aka.ms/examdemo
3. **Azure Architecture Center**: https://learn.microsoft.com/en-us/azure/architecture/
4. **Well-Architected Framework**: https://learn.microsoft.com/en-us/azure/well-architected/
5. **Cloud Adoption Framework**: https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/

---

## Recommended Next Steps

1. **[IMMEDIATE]** Review this document and adjust demo timing based on environment setup time
2. **[SHORT-TERM]** Pre-provision Azure resources for demos to minimize live creation time
3. **[LONG-TERM]** Create Bicep templates for demo environment reproducibility across deliveries
