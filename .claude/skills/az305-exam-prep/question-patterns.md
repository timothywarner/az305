# AZ-305 Question Pattern Templates

These patterns mirror the question archetypes found on the actual Microsoft AZ-305 exam. Rotate through patterns to ensure variety across a quiz session.

## Pattern 1: Service Selection

**Template:**
```
[Company] is developing [workload type]. You need to [business requirement].
The solution must [constraint 1] and [constraint 2].
What should you use?
```

**Example trigger topics:**
- Choosing between Azure SQL Database, SQL Managed Instance, and SQL Server on VMs
- Selecting the right messaging service (Event Grid, Event Hubs, Service Bus, Queue Storage)
- Picking a compute platform (App Service, AKS, Container Apps, Functions)

---

## Pattern 2: Configuration Decision

**Template:**
```
You have [existing infrastructure description]. You need to [new requirement]
while [maintaining constraint]. What should you configure?
```

**Example trigger topics:**
- Configuring replication for Azure Storage accounts
- Setting up Cosmos DB consistency levels
- Configuring Azure Front Door routing rules vs Application Gateway

---

## Pattern 3: Architecture Migration

**Template:**
```
[Company] is migrating [workload type] from [source environment] to Azure.
The migration must [requirement 1] with [SLA/compliance need].
You need to minimize [cost/downtime/complexity].
What should you recommend?
```

**Example trigger topics:**
- SQL Server to Azure SQL migration strategy
- On-premises VM workloads to Azure (rehost vs refactor vs rearchitect)
- Legacy app modernization paths

---

## Pattern 4: Cost Optimization

**Template:**
```
[Company] needs to [capability]. The solution must [non-negotiable requirement].
You need to minimize costs. What should you implement?
```

**Example trigger topics:**
- Reserved Instances vs Savings Plans vs Spot VMs
- Storage tier selection (Hot, Cool, Cold, Archive)
- Right-sizing compute resources
- Choosing between PaaS and IaaS for cost

---

## Pattern 5: Security and Compliance

**Template:**
```
Your organization must comply with [compliance standard/regulation].
You need to [capability] for [workload type].
The solution must [security constraint].
What should you recommend?
```

**Example trigger topics:**
- Data residency and sovereignty requirements
- Encryption at rest and in transit strategies
- Network isolation with Private Link vs Service Endpoints
- Identity protection and Conditional Access

---

## Pattern 6: High Availability and Disaster Recovery

**Template:**
```
[Company] has a [workload description] with an SLA requirement of [percentage].
You need to ensure [availability/recovery requirement].
The solution must [constraint about RPO/RTO].
What should you recommend?
```

**Example trigger topics:**
- Multi-region deployment strategies
- Azure Site Recovery configuration
- Database geo-replication and failover groups
- Availability Zones vs Availability Sets

---

## Pattern 7: Integration and Hybrid

**Template:**
```
[Company] has [on-premises resource]. You need to [integrate/extend]
this resource with Azure while [maintaining constraint].
Users must be able to [access requirement].
What should you recommend?
```

**Example trigger topics:**
- Hybrid identity with Microsoft Entra Connect
- ExpressRoute vs VPN Gateway selection
- Azure Arc for hybrid management
- Hybrid DNS resolution

---

## Pattern 8: Monitoring and Governance

**Template:**
```
[Company] has [number] subscriptions across [number] departments.
You need to [governance/monitoring requirement].
The solution must [constraint about scope/automation].
What should you implement?
```

**Example trigger topics:**
- Azure Policy vs RBAC for governance
- Management group hierarchy design
- Azure Monitor, Log Analytics, and Application Insights
- Cost Management and budgets

---

## Distractor Design Guidelines

When creating incorrect options, use these distractor strategies:

1. **Partial solution:** Addresses some but not all requirements
2. **Wrong scope:** Right service, wrong tier/SKU/configuration
3. **Deprecated/legacy:** Older approach that's been superseded
4. **Overkill:** Valid but unnecessarily complex or expensive
5. **Wrong category:** Solves a different problem entirely
6. **Common confusion:** Services frequently mixed up (e.g., B2B vs B2C, Event Grid vs Event Hubs)
7. **Missing constraint:** Would work if a stated constraint didn't exist
