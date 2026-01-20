# AZ-305 Architecture Diagrams

This directory contains Mermaid architecture diagrams covering key scenarios for the **AZ-305: Designing Microsoft Azure Infrastructure Solutions** exam. Each diagram is aligned with official Microsoft documentation and the Azure Well-Architected Framework.

## How to Use These Diagrams

### Viewing Diagrams
1. **VS Code**: Install the "Mermaid Preview" extension
2. **GitHub**: Mermaid diagrams render automatically in `.md` files
3. **Online**: Use [Mermaid Live Editor](https://mermaid.live)
4. **Command Line**: Use `mmdc` (Mermaid CLI) to export to SVG/PNG

### Rendering to SVG
```bash
# Install Mermaid CLI
npm install -g @mermaid-js/mermaid-cli

# Convert to SVG
mmdc -i governance-hierarchy.mmd -o governance-hierarchy.svg
```

---

## Domain 1: Design Identity, Governance, and Monitoring Solutions

### 1. Governance Hierarchy
**File:** `governance-hierarchy.mmd`

**AZ-305 Objectives Covered:**
- Design a governance hierarchy (management groups, subscriptions, resource groups)
- Design for policy inheritance and exemptions
- Design for resource organization aligned to CAF

**Key Architectural Decisions:**
- Root management group establishes enterprise-wide policies
- Platform and Landing Zones separation follows CAF enterprise-scale
- Policy inheritance flows down the hierarchy - child scopes cannot override
- Sandbox environments have relaxed policies but no connectivity to production
- Decommissioned MG uses "Deny All" for resources pending deletion

**Microsoft Learn References:**
- [Management groups overview](https://learn.microsoft.com/azure/governance/management-groups/overview)
- [Azure landing zone architecture](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/)

---

### 2. Zero Trust Identity
**File:** `zero-trust-identity.mmd`

**AZ-305 Objectives Covered:**
- Design authentication and authorization solutions
- Design Conditional Access policies
- Design for Privileged Identity Management (PIM)
- Design identity protection and risk policies

**Key Architectural Decisions:**
- Conditional Access is the Zero Trust policy engine - evaluates signals to make decisions
- MFA should be required for all users, with phishing-resistant methods for admins
- Device compliance integrates with Intune for managed device requirements
- PIM provides just-in-time access with approval workflows for privileged roles
- Identity Protection detects and remediates user and sign-in risks automatically

**Microsoft Learn References:**
- [Zero Trust identity deployment](https://learn.microsoft.com/security/zero-trust/deploy/identity)
- [Conditional Access overview](https://learn.microsoft.com/entra/identity/conditional-access/overview)

---

### 3. Logging Architecture
**File:** `logging-architecture.mmd`

**AZ-305 Objectives Covered:**
- Design a Log Analytics workspace architecture
- Design data collection and routing strategies
- Design monitoring and alerting solutions
- Design for cost optimization in logging

**Key Architectural Decisions:**
- Data Collection Rules (DCRs) enable transformation at ingestion to reduce costs
- Basic Logs tier costs ~60% less but has limited query capabilities (8-day retention)
- Event Hub enables real-time streaming to external SIEM systems
- Archive tier provides long-term retention (up to 12 years) at lower cost
- Diagnostic settings route platform logs to multiple destinations simultaneously

**Microsoft Learn References:**
- [Azure Monitor overview](https://learn.microsoft.com/azure/azure-monitor/overview)
- [Log Analytics workspace design](https://learn.microsoft.com/azure/azure-monitor/logs/workspace-design)

---

## Domain 2: Design Data Storage Solutions

### 4. Enterprise Data Platform
**File:** `data-platform.mmd`

**AZ-305 Objectives Covered:**
- Design a data storage solution for relational and non-relational data
- Design data integration solutions
- Design a data analytics solution using Synapse Analytics

**Key Architectural Decisions:**
- Medallion Architecture (Bronze/Silver/Gold) enables incremental data refinement
- Delta Lake provides ACID transactions on data lake storage
- Serverless SQL pools are pay-per-query, ideal for exploration and ad-hoc analysis
- Dedicated SQL pools use MPP architecture for large-scale analytics
- Microsoft Purview provides unified data governance and cataloging

**Microsoft Learn References:**
- [Azure Synapse Analytics](https://learn.microsoft.com/azure/synapse-analytics/overview-what-is)
- [Lakehouse architecture](https://learn.microsoft.com/azure/architecture/example-scenario/data/real-time-lakehouse-data-processing)

---

### 5. Cosmos DB Global Distribution
**File:** `cosmosdb-global.mmd`

**AZ-305 Objectives Covered:**
- Design for multi-region data solutions
- Design for data consistency requirements
- Design for high availability and disaster recovery

**Key Architectural Decisions:**
- Strong consistency requires single write region and increases latency
- Session consistency is the default and most common for web applications
- Multi-region writes cannot use Strong consistency - use Bounded Staleness instead
- 99.999% SLA requires multi-region configuration
- Service-managed failover provides automatic failover with 10-15 minute RTO

**Microsoft Learn References:**
- [Cosmos DB global distribution](https://learn.microsoft.com/azure/cosmos-db/distribute-data-globally)
- [Consistency levels](https://learn.microsoft.com/azure/cosmos-db/consistency-levels)

---

### 6. Azure SQL HA/DR
**File:** `sql-ha-dr.mmd`

**AZ-305 Objectives Covered:**
- Design high availability for Azure SQL solutions
- Design disaster recovery strategies
- Design for RTO and RPO requirements

**Key Architectural Decisions:**
- Zone redundant deployment requires Premium or Business Critical tier
- Failover Groups provide automatic failover with listener endpoints - no app changes needed
- Active Geo-Replication provides cross-region readable secondaries
- Scale secondary first when scaling up, primary first when scaling down
- Auto-failover groups have ~1 hour RTO, ~5 second RPO

**Microsoft Learn References:**
- [Azure SQL HA/DR checklist](https://learn.microsoft.com/azure/azure-sql/database/high-availability-disaster-recovery-checklist)
- [Failover groups](https://learn.microsoft.com/azure/azure-sql/database/failover-group-sql-db)

---

## Domain 3: Design Business Continuity Solutions

### 7. Azure Backup Architecture
**File:** `backup-architecture.mmd`

**AZ-305 Objectives Covered:**
- Design backup and recovery solutions
- Design for vault redundancy and cross-region restore
- Design backup policies and retention

**Key Architectural Decisions:**
- GRS (Geo-Redundant Storage) is required for Cross-Region Restore
- Soft delete protects against accidental deletion with 14 days free retention
- Immutable vault cannot be disabled once locked - use for compliance requirements
- Recovery Services vault vs Backup vault depends on workload type
- Instant restore from snapshots provides RTO in minutes

**Microsoft Learn References:**
- [Azure Backup architecture](https://learn.microsoft.com/azure/backup/backup-architecture)
- [Recovery Services vault](https://learn.microsoft.com/azure/backup/backup-azure-recovery-services-vault-overview)

---

### 8. Site Recovery DR
**File:** `site-recovery-dr.mmd`

**AZ-305 Objectives Covered:**
- Design disaster recovery solutions using Azure Site Recovery
- Design recovery plans for multi-tier applications
- Design for RTO/RPO requirements

**Key Architectural Decisions:**
- Test failover uses isolated network - no impact to production replication
- Recovery plans enable ordered failover with pre/post scripts for multi-tier apps
- RPO depends on replication frequency and network bandwidth
- Failback requires reprotection first to establish reverse replication
- Cache storage account in source region is required for Azure-to-Azure DR

**Microsoft Learn References:**
- [Azure Site Recovery architecture](https://learn.microsoft.com/azure/site-recovery/azure-to-azure-architecture)
- [Recovery plans](https://learn.microsoft.com/azure/site-recovery/recovery-plan-overview)

---

### 9. High Availability Patterns
**File:** `high-availability-patterns.mmd`

**AZ-305 Objectives Covered:**
- Design solutions using availability sets and availability zones
- Design load balancing solutions
- Design for SLA requirements

**Key Architectural Decisions:**
- Availability Zones provide 99.99% SLA vs 99.95% for Availability Sets
- Standard Load Balancer required for Availability Zones (Basic is zonal only)
- Traffic Manager is DNS-based (no inline traffic) - use Front Door for L7 global LB
- Composite SLA = multiply individual SLAs - add redundancy to improve
- Zone-redundant services automatically survive single zone failures

**Microsoft Learn References:**
- [Availability Zones overview](https://learn.microsoft.com/azure/reliability/availability-zones-overview)
- [Azure Load Balancer](https://learn.microsoft.com/azure/load-balancer/load-balancer-overview)

---

## Domain 4: Design Infrastructure Solutions

### 10. Hub-Spoke Network
**File:** `hub-spoke-network.mmd`

**AZ-305 Objectives Covered:**
- Design network topology (hub-spoke)
- Design for hybrid connectivity (ExpressRoute, VPN)
- Design network security with Azure Firewall

**Key Architectural Decisions:**
- VNet peering is non-transitive - spokes cannot communicate directly without Firewall or NVA
- Use Gateway Transit on hub peering to share ExpressRoute/VPN with spokes
- Azure Firewall needs dedicated /26 subnet minimum named 'AzureFirewallSubnet'
- UDRs required to force traffic through Firewall (0.0.0.0/0 -> Firewall)
- Azure Bastion provides secure RDP/SSH without public IPs on VMs

**Microsoft Learn References:**
- [Hub-spoke topology](https://learn.microsoft.com/azure/architecture/networking/architecture/hub-spoke)
- [Azure Firewall](https://learn.microsoft.com/azure/firewall/overview)

---

### 11. Container Apps Microservices
**File:** `container-apps-microservices.mmd`

**AZ-305 Objectives Covered:**
- Design containerized application solutions
- Design for event-driven architectures
- Design microservices patterns

**Key Architectural Decisions:**
- Dapr provides service mesh capabilities without Kubernetes complexity
- KEDA enables scale-to-zero for cost optimization on event triggers
- Container Apps abstracts Kubernetes - no direct K8s API access
- Use revisions for blue-green and canary deployments with traffic splitting
- Dapr building blocks: service invocation, pub/sub, state, bindings, secrets

**Microsoft Learn References:**
- [Azure Container Apps](https://learn.microsoft.com/azure/container-apps/overview)
- [Microservices with Dapr](https://learn.microsoft.com/azure/architecture/example-scenario/serverless/microservices-with-container-apps-dapr)

---

### 12. API Architecture
**File:** `api-architecture.mmd`

**AZ-305 Objectives Covered:**
- Design API Management solutions
- Design for global API distribution
- Design API security and governance

**Key Architectural Decisions:**
- Use Front Door for global distribution + APIM for API management policies
- Internal VNet mode requires App Gateway for public access to APIM
- APIM policies execute in order: Inbound -> Backend -> Outbound -> On-Error
- Self-hosted gateway enables hybrid/multi-cloud API management
- Products and subscriptions control API access with rate limiting

**Microsoft Learn References:**
- [API Management overview](https://learn.microsoft.com/azure/api-management/api-management-key-concepts)
- [Front Door with APIM](https://learn.microsoft.com/azure/api-management/front-door-api-management)

---

### 13. Azure Landing Zone
**File:** `migration-landing-zone.mmd`

**AZ-305 Objectives Covered:**
- Design for Azure landing zones
- Design resource organization and governance
- Design for workload migration and modernization

**Key Architectural Decisions:**
- Platform subscriptions host shared services managed by central platform team
- Application landing zones are workload-specific with inherited governance
- Subscription vending automates consistent landing zone provisioning
- Policy inheritance flows down the MG hierarchy - child scopes cannot override
- Corp vs Online landing zones have different network and security requirements

**Microsoft Learn References:**
- [Azure landing zone](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/)
- [CAF enterprise-scale](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/enterprise-scale/)

---

### 14. Private Link Topology
**File:** `private-link-topology.mmd`

**AZ-305 Objectives Covered:**
- Design Private Link and Private Endpoint solutions
- Design DNS resolution for private endpoints
- Design secure PaaS connectivity

**Key Architectural Decisions:**
- Private Endpoints require dedicated subnet with network policies disabled
- DNS resolution is critical - Private DNS zones must be linked to all consuming VNets
- On-premises access requires conditional DNS forwarding to Azure DNS resolver
- Disable public access on PaaS services after configuring private endpoints
- Private Link vs Service Endpoints: PE provides private IP, SE keeps traffic on backbone

**Microsoft Learn References:**
- [Private Link overview](https://learn.microsoft.com/azure/private-link/private-link-overview)
- [Private endpoint DNS](https://learn.microsoft.com/azure/private-link/private-endpoint-dns)

---

## Exam Tips Summary

### Identity & Governance
- Conditional Access evaluates signals in real-time to make access decisions
- PIM provides just-in-time privileged access with approval workflows
- Policy inheritance flows down - use exemptions for exceptions

### Data Storage
- Medallion Architecture (Bronze -> Silver -> Gold) enables incremental refinement
- Session consistency is default for Cosmos DB and suitable for most web apps
- Failover Groups provide automatic failover with listener endpoints

### Business Continuity
- GRS required for Cross-Region Restore
- Test failover is non-disruptive and uses isolated network
- Composite SLA = Product of individual SLAs

### Infrastructure
- VNet peering is non-transitive
- Standard Load Balancer required for Availability Zones
- Private DNS zones must be linked to all consuming VNets

---

## Contributing

To update these diagrams:
1. Edit the `.mmd` source files
2. Test rendering in Mermaid Live Editor
3. Update this README with any new exam tips or references
4. Export to SVG for static image requirements

## License

These diagrams are provided for educational purposes in preparation for the AZ-305 exam.
