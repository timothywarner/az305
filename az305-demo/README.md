# AZ-305 Demo Environment

**Instructor:** Tim Warner | **Platform:** O'Reilly Live Learning
**Resource Group:** `az305-rg` | **Region:** East US 2
**Last Updated:** 2026-01-28

A fully provisioned Azure environment for teaching the AZ-305 (Designing Microsoft Azure Infrastructure Solutions) exam objectives. Every resource maps to one or more exam domains, giving learners hands-on visibility into the services they will encounter on the exam.

---

## Exam Domain Mapping

The AZ-305 exam covers four weighted domains. This environment includes live resources for each.

| Domain | Weight | Demo Resources |
|--------|--------|----------------|
| **1 - Identity, Governance, and Monitoring** | 25-30% | Key Vault, Log Analytics, Application Insights, Diagnostic Settings |
| **2 - Data Storage** | 20-25% | SQL Database, Cosmos DB, Storage Account, Data Factory |
| **3 - Business Continuity** | 15-20% | Recovery Services Vaults (Backup + ASR), Storage redundancy, SQL auto-pause |
| **4 - Infrastructure** | 30-35% | VNets, Peering, NSGs, App Gateway + WAF, Traffic Manager, VMs, AKS, Functions, Logic Apps, Service Bus, APIM |

---

## Quick Start: Demo Walkthrough by Domain

### Domain 1 -- Identity, Governance, and Monitoring

**Key Vault (secrets and key management)**

```bash
# Show vault configuration (RBAC mode, purge protection)
az keyvault show --name kv-az305-tw --query "{name:name, sku:properties.sku.name, enableRbacAuthorization:properties.enableRbacAuthorization, enablePurgeProtection:properties.enablePurgeProtection}" -o table

# List secrets (does NOT reveal values)
az keyvault secret list --vault-name kv-az305-tw -o table

# Retrieve the demo secret
az keyvault secret show --vault-name kv-az305-tw --name demo-api-key --query value -o tsv

# Show the encryption key
az keyvault key show --vault-name kv-az305-tw --name demo-encrypt-key --query "{name:name, keyType:key.kty, keySize:key.n}" -o table
```

**Teaching point:** Compare RBAC mode vs. access-policy mode. Discuss managed identities eliminating the need for stored credentials.

**Log Analytics and Application Insights**

```bash
# Show workspace config (retention, pricing tier)
az monitor log-analytics workspace show --workspace-name law-az305 --resource-group az305-rg -o table

# List all diagnostic settings sending to this workspace
az monitor diagnostic-settings list --resource "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/az305-rg/providers/Microsoft.Compute/virtualMachines/vm-win01" -o table

# Query recent heartbeat data (proves agents are reporting)
az monitor log-analytics query --workspace law-az305 --analytics-query "Heartbeat | summarize LastHeartbeat=max(TimeGenerated) by Computer | order by LastHeartbeat desc" -o table

# Show Application Insights overview
az monitor app-insights component show --app appi-az305 --resource-group az305-rg -o table
```

**Teaching point:** All resources in the environment send diagnostics to `law-az305`. This is the single-pane-of-glass pattern recommended for the exam.

---

### Domain 2 -- Data Storage

**Azure SQL Database (serverless relational)**

```bash
# Show server and database tier
az sql db show --server sql-az305-tw --name sqldb-az305-demo --resource-group az305-rg --query "{name:name, sku:currentSku, autoPauseDelay:autoPauseDelay, minCapacity:minCapacity, maxSizeBytes:maxSizeBytes}" -o table

# Query sample data (requires sqlcmd or Azure Data Studio)
sqlcmd -S sql-az305-tw.database.windows.net -d sqldb-az305-demo -U tim -P 'REDACTED_SQL_PASSWORD' -Q "SELECT TOP 5 * FROM Products"
sqlcmd -S sql-az305-tw.database.windows.net -d sqldb-az305-demo -U tim -P 'REDACTED_SQL_PASSWORD' -Q "SELECT TOP 5 * FROM Orders"
```

**Teaching point:** Serverless auto-pauses after 60 minutes of inactivity. Show the cost difference vs. provisioned. Discuss when to use DTU vs. vCore models.

**Cosmos DB (serverless NoSQL)**

```bash
# Show account configuration
az cosmosdb show --name cosmos-az305-tw --resource-group az305-rg --query "{name:name, kind:kind, consistencyPolicy:consistencyPolicy.defaultConsistencyLevel, enableFreeTier:enableFreeTier}" -o table

# List databases and containers
az cosmosdb sql database list --account-name cosmos-az305-tw --resource-group az305-rg -o table
az cosmosdb sql container list --account-name cosmos-az305-tw --resource-group az305-rg --database-name SensorData -o table

# Show partition key
az cosmosdb sql container show --account-name cosmos-az305-tw --resource-group az305-rg --database-name SensorData --name readings --query "{partitionKey:resource.partitionKey, indexingPolicy:resource.indexingPolicy.indexingMode}" -o table
```

**Teaching point:** Partition key choice (`/deviceId`) is the most critical Cosmos DB design decision. Discuss consistency levels and when serverless vs. provisioned throughput applies.

**Storage Account (lifecycle management)**

```bash
# Show account properties
az storage account show --name staz305demo --resource-group az305-rg --query "{name:name, sku:sku.name, accessTier:accessTier, blobVersioning:isBlobVersioningEnabled}" -o table

# List containers
az storage container list --account-name staz305demo --auth-mode login -o table

# Show lifecycle management policy
az storage account management-policy show --account-name staz305demo --resource-group az305-rg -o jsonc

# List blobs in raw-data
az storage blob list --account-name staz305demo --container-name raw-data --auth-mode login -o table
```

**Teaching point:** Walk through the lifecycle policy tiers (Hot -> Cool@30d -> Archive@90d -> Delete@365d). Discuss versioning + soft delete as data protection.

**Data Factory (ETL pipeline)**

```bash
# List pipelines
az datafactory pipeline list --factory-name adf-az305-tw --resource-group az305-rg -o table

# Trigger the blob-to-sql pipeline
az datafactory pipeline create-run --factory-name adf-az305-tw --resource-group az305-rg --name pipeline-blob-to-sql

# Check run status (use the run ID from previous command)
az datafactory pipeline-run show --factory-name adf-az305-tw --resource-group az305-rg --run-id <RUN_ID> -o table
```

**Teaching point:** Show the Copy Activity pattern: blob CSV source -> SQL SalesImport sink. Discuss integration runtimes and when to use Data Factory vs. Synapse pipelines.

---

### Domain 3 -- Business Continuity

**Azure Backup**

```bash
# Show vault and backup items
az backup vault show --name rsv-backup-az305 --resource-group az305-rg -o table
az backup item list --vault-name rsv-backup-az305 --resource-group az305-rg --backup-management-type AzureIaasVM -o table

# Show backup policy
az backup policy list --vault-name rsv-backup-az305 --resource-group az305-rg -o table
```

**Teaching point:** Discuss RTO/RPO targets. The DefaultPolicy provides daily backups. Compare application-consistent vs. crash-consistent snapshots.

**Azure Site Recovery**

```bash
# Show ASR vault and replication policy
az backup vault show --name rsv-asr-az305 --resource-group az305-rg -o table

# List replication policies (use the portal for visual walkthrough)
# ASR config: 24-hour RPO, 4-hour app-consistent snapshot frequency
```

**Teaching point:** ASR enables cross-region DR for VMs. Walk through the fabric -> container -> policy -> protected item hierarchy. Discuss failover testing best practices.

---

### Domain 4 -- Infrastructure

**Networking (VNets, Peering, NSGs)**

```bash
# Show VNet topology
az network vnet list --resource-group az305-rg -o table
az network vnet show --name vnet-win --resource-group az305-rg --query "{addressSpace:addressSpace.addressPrefixes, subnets:subnets[].{name:name,prefix:addressPrefix}}" -o jsonc
az network vnet show --name vnet-linux --resource-group az305-rg --query "{addressSpace:addressSpace.addressPrefixes, subnets:subnets[].{name:name,prefix:addressPrefix}}" -o jsonc

# Verify bidirectional peering
az network vnet peering list --vnet-name vnet-win --resource-group az305-rg -o table
az network vnet peering list --vnet-name vnet-linux --resource-group az305-rg -o table

# Show NSG rules
az network nsg rule list --nsg-name nsg-win --resource-group az305-rg -o table
az network nsg rule list --nsg-name nsg-linux --resource-group az305-rg -o table
```

**Teaching point:** Two VNets with non-overlapping address spaces peered bidirectionally. This is the hub-spoke foundation. Discuss when to use peering vs. VPN Gateway vs. Virtual WAN.

**Application Gateway + WAF**

```bash
# Show App Gateway config
az network application-gateway show --name appgw-az305 --resource-group az305-rg --query "{sku:sku, wafConfiguration:webApplicationFirewallConfiguration}" -o jsonc

# Show WAF policy (OWASP 3.2 ruleset)
az network application-gateway waf-policy show --name wafpol-az305 --resource-group az305-rg -o jsonc

# Test the App Gateway endpoint
curl -s http://23.102.120.230 | head -20
```

**Teaching point:** WAF_v2 SKU with OWASP 3.2 in Detection mode. Discuss Detection vs. Prevention mode trade-offs and custom WAF rules.

**Traffic Manager**

```bash
# Show Traffic Manager profile
az network traffic-manager profile show --name tm-az305-tw --resource-group az305-rg -o table

# List endpoints
az network traffic-manager endpoint list --profile-name tm-az305-tw --resource-group az305-rg --type azureEndpoints -o table
```

**Teaching point:** Performance routing method sends users to the lowest-latency endpoint. Compare Traffic Manager (DNS) vs. Front Door (HTTP) vs. Load Balancer (L4) vs. App Gateway (L7).

**Virtual Machines**

```bash
# Show both VMs
az vm list --resource-group az305-rg -o table
az vm show --name vm-win01 --resource-group az305-rg --query "{name:name, size:hardwareProfile.vmSize, os:storageProfile.osDisk.osType, privateIp:privateIps}" -o table
az vm show --name vm-linux01 --resource-group az305-rg --query "{name:name, size:hardwareProfile.vmSize, os:storageProfile.osDisk.osType}" -o table

# Browse the IIS page on vm-win01 (through App Gateway)
# http://23.102.120.230
```

**Teaching point:** B2s is the smallest production-capable SKU. Discuss VM sizing, availability sets vs. zones, and when to use VMs vs. containers vs. serverless.

**AKS (Kubernetes)**

```bash
# Show cluster config
az aks show --name aks-az305 --resource-group az305-rg --query "{name:name, kubernetesVersion:kubernetesVersion, networkPlugin:networkProfile.networkPlugin, serviceCidr:networkProfile.serviceCidr, agentPoolProfiles:agentPoolProfiles[0].{count:count,vmSize:vmSize}}" -o jsonc

# Get credentials and explore (if kubectl installed)
az aks get-credentials --name aks-az305 --resource-group az305-rg
kubectl get nodes
kubectl get pods --all-namespaces
```

**Teaching point:** Azure CNI gives pods real VNet IPs (vs. kubenet overlay). Service CIDR 10.3.0.0/16 is separate from VNet ranges. Discuss when AKS vs. Container Apps vs. ACI.

**Serverless Compute**

```bash
# List Function Apps
az functionapp list --resource-group az305-rg -o table

# Show .NET Function App config
az functionapp show --name func-az305-tw --resource-group az305-rg --query "{name:name, runtime:siteConfig.linuxFxVersion, state:state}" -o table

# Test the Service Bus sender Function App
curl "https://func-sb-az305-tw.azurewebsites.net/api/sendorder?message=AZ305-Demo-Order"

# Show Logic App
az logic workflow show --name logic-az305-tw --resource-group az305-rg -o table
```

**Teaching point:** Consumption plan = pay-per-execution (ideal for sporadic workloads). Compare Functions (code-first) vs. Logic Apps (designer-first) for integration scenarios.

**Service Bus (messaging)**

```bash
# Show namespace and queue
az servicebus namespace show --name sb-az305-tw --resource-group az305-rg --query "{name:name, sku:sku.name}" -o table
az servicebus queue show --namespace-name sb-az305-tw --resource-group az305-rg --name orders-queue --query "{name:name, maxSizeInMegabytes:maxSizeInMegabytes, defaultMessageTimeToLive:defaultMessageTimeToLive, lockDuration:lockDuration}" -o table

# Check message count
az servicebus queue show --namespace-name sb-az305-tw --resource-group az305-rg --name orders-queue --query "{activeMessageCount:countDetails.activeMessageCount}" -o table
```

**Teaching point:** Basic SKU supports queues only (no topics/subscriptions). Discuss Service Bus vs. Queue Storage vs. Event Grid vs. Event Hubs decision matrix.

**API Management**

```bash
# Show APIM instance (in warnerco RG)
az apim show --name warnerco-apim --resource-group warnerco -o table

# List APIs
az apim api list --service-name warnerco-apim --resource-group warnerco -o table

# Test an API call (requires subscription key)
curl -H "Ocp-Apim-Subscription-Key: REDACTED_APIM_KEY" https://warnerco-apim.azure-api.net/api/robots
```

**Teaching point:** APIM sits in front of the Container App backend. The backend ingress is restricted to the APIM IP only. Discuss API gateway patterns, rate limiting, and developer portal.

---

## Full Resource Inventory

### Networking

| Resource | Type | Details |
|----------|------|---------|
| `vnet-win` | Virtual Network | 10.1.0.0/16 |
| -- `snet-win-default` | Subnet | 10.1.1.0/24 |
| -- `snet-aks` | Subnet | 10.1.4.0/22 |
| -- `snet-appgw` | Subnet | 10.1.8.0/24 |
| `vnet-linux` | Virtual Network | 10.2.0.0/16 |
| -- `snet-linux-default` | Subnet | 10.2.1.0/24 |
| `peer-win-to-linux` | VNet Peering | vnet-win -> vnet-linux |
| `peer-linux-to-win` | VNet Peering | vnet-linux -> vnet-win |
| `nsg-win` | NSG | Allows RDP |
| `nsg-linux` | NSG | Allows SSH |
| `tm-az305-tw` | Traffic Manager | Performance routing |
| `appgw-az305` | Application Gateway | WAF_v2, capacity 1 |
| `wafpol-az305` | WAF Policy | OWASP 3.2, Detection mode |

### Compute

| Resource | Type | Details |
|----------|------|---------|
| `vm-win01` | Virtual Machine | Windows Server 2022, B2s, 10.1.1.4 |
| `vm-linux01` | Virtual Machine | Ubuntu 22.04, B2s, 10.2.1.4 |
| `aks-az305` | AKS Cluster | 1 node B2s, Azure CNI, service CIDR 10.3.0.0/16 |
| `func-az305-tw` | Function App | .NET 8 isolated, Consumption |
| `func-sb-az305-tw` | Function App | Node.js 20, Consumption |
| `logic-az305-tw` | Logic App | Consumption, HTTP trigger |

### Data Storage

| Resource | Type | Details |
|----------|------|---------|
| `sql-az305-tw` | SQL Server | Logical server |
| `sqldb-az305-demo` | SQL Database | Serverless Gen5, 0.5-2 vCores, auto-pause 60min |
| `cosmos-az305-tw` | Cosmos DB | Serverless, NoSQL API |
| `staz305demo` | Storage Account | Standard_LRS, Hot, versioning + soft delete |
| `adf-az305-tw` | Data Factory | pipeline-blob-to-sql |

### Messaging

| Resource | Type | Details |
|----------|------|---------|
| `sb-az305-tw` | Service Bus | Basic SKU |
| -- `orders-queue` | Queue | 1 GB, 14d TTL, 30s lock, 4 sample messages |

### Security and Identity

| Resource | Type | Details |
|----------|------|---------|
| `kv-az305-tw` | Key Vault | Standard, RBAC mode, purge protection |

### Monitoring

| Resource | Type | Details |
|----------|------|---------|
| `law-az305` | Log Analytics | PerGB2018, 30-day retention |
| `appi-az305` | Application Insights | Linked to law-az305 |

### BCDR

| Resource | Type | Details |
|----------|------|---------|
| `rsv-backup-az305` | Recovery Services Vault | VM backup (vm-win01, DefaultPolicy) |
| `rsv-asr-az305` | Recovery Services Vault | ASR (24hr RPO, 4hr app-consistent) |

### API Management (RG: warnerco)

| Resource | Type | Details |
|----------|------|---------|
| `warnerco-apim` | API Management | WARNERCO Robotics Schematica API (15 ops) |
| `warnerco-schematica-classroom` | Container App | Backend, ingress restricted to APIM IP |

---

## Connection Details and Credentials

| Resource | Connection | Credentials |
|----------|------------|-------------|
| SQL Server | `sql-az305-tw.database.windows.net` | User: `tim` / Password: `REDACTED_SQL_PASSWORD` |
| SQL Database | `sqldb-az305-demo` | Same as SQL Server |
| Key Vault | `kv-az305-tw.vault.azure.net` | Azure RBAC (your identity) |
| APIM Gateway | `https://warnerco-apim.azure-api.net` | Subscription Key: `REDACTED_APIM_KEY` |
| App Gateway | `http://23.102.120.230` | No auth (public IIS page) |
| Traffic Manager | `http://tm-az305-tw.trafficmanager.net` | No auth |
| Service Bus Sender | `https://func-sb-az305-tw.azurewebsites.net/api/sendorder?message=Hello` | No auth (anonymous trigger) |
| Cosmos DB | `cosmos-az305-tw.documents.azure.com` | Azure RBAC or keys via portal |

### SQL Database Tables

**Products** (5 rows):

| Column | Type |
|--------|------|
| ProductId | int (PK) |
| ProductName | nvarchar |
| Category | nvarchar |
| Price | decimal |

**Orders** (5 rows):

| Column | Type |
|--------|------|
| OrderId | int (PK) |
| ProductId | int (FK) |
| Quantity | int |
| OrderDate | datetime |

**SalesImport** (ADF sink target):

| Column | Type |
|--------|------|
| (populated by Data Factory pipeline) | |

### Cosmos DB Sample Document

```json
{
  "id": "reading-001",
  "deviceId": "sensor-alpha",
  "temperature": 72.4,
  "humidity": 45.2,
  "timestamp": "2026-01-15T10:30:00Z"
}
```

### Storage Account Containers

| Container | Contents |
|-----------|----------|
| `raw-data` | Sales CSVs, sensor JSON |
| `processed-data` | (pipeline output) |
| `archive-data` | (lifecycle policy target) |

**Lifecycle Policy:**

| Condition | Action |
|-----------|--------|
| Last modified > 30 days | Move to Cool tier |
| Last modified > 90 days | Move to Archive tier |
| Last modified > 365 days | Delete blob |
| Snapshot age > 90 days | Delete snapshot |

---

## Architecture Overview

```
                         Internet
                            |
              +-------------+-------------+
              |                           |
     Traffic Manager              App Gateway (WAF_v2)
     (DNS / Performance)          http://23.102.120.230
              |                           |
              v                           v
    +-------------------+       +-------------------+
    | vm-win01 (IIS)    |       | vm-win01 (IIS)    |
    | 10.1.1.4          |       | 10.1.1.4          |
    | vnet-win          |       | snet-appgw        |
    +-------------------+       +-------------------+
              |
        VNet Peering
        (bidirectional)
              |
    +-------------------+
    | vm-linux01        |
    | 10.2.1.4          |
    | vnet-linux        |
    +-------------------+

    +-------------------+       +-------------------+
    | aks-az305         |       | Service Bus       |
    | snet-aks          |  <--  | orders-queue      |
    | 10.1.4.0/22       |       | func-sb-az305-tw  |
    +-------------------+       +-------------------+

    +-------------------+       +-------------------+
    | APIM              |  -->  | Container App     |
    | warnerco-apim     |       | (ingress locked)  |
    +-------------------+       +-------------------+

    +-------------------+       +-------------------+       +-------------------+
    | SQL Database      |  <--  | Data Factory      |  <--  | Blob Storage      |
    | sqldb-az305-demo  |       | adf-az305-tw      |       | staz305demo       |
    +-------------------+       +-------------------+       +-------------------+

    +-------------------+       +-------------------+       +-------------------+
    | Cosmos DB         |       | Key Vault         |       | Log Analytics     |
    | SensorData        |       | kv-az305-tw       |       | law-az305         |
    | /deviceId         |       | (RBAC mode)       |       | (all diagnostics) |
    +-------------------+       +-------------------+       +-------------------+

    +-------------------+       +-------------------+
    | RSV Backup        |       | RSV ASR           |
    | vm-win01 daily    |       | 24hr RPO          |
    +-------------------+       +-------------------+
```

For detailed Mermaid diagrams, see `../docs/diagrams/`.

---

## Cost Management Tips

This environment uses cost-conscious SKUs, but Azure charges accrue even when idle. Follow these practices between sessions.

### Deallocate VMs when not demoing

```bash
# Stop and deallocate both VMs (stops compute billing)
az vm deallocate --name vm-win01 --resource-group az305-rg --no-wait
az vm deallocate --name vm-linux01 --resource-group az305-rg --no-wait

# Restart before the next session
az vm start --name vm-win01 --resource-group az305-rg --no-wait
az vm start --name vm-linux01 --resource-group az305-rg --no-wait
```

### SQL auto-pause

The SQL database is configured with a 60-minute auto-pause delay. No action needed -- it will pause automatically when idle. First query after pause takes ~60 seconds to resume.

### Cosmos DB serverless

Serverless Cosmos DB charges only for consumed RUs. No baseline cost when idle.

### Function Apps on Consumption plan

Both Function Apps use the Consumption plan. No cost when not executing.

### AKS single-node cluster

The AKS cluster runs a single B2s node. To stop the cluster entirely:

```bash
# Stop the AKS cluster (stops node VM billing)
az aks stop --name aks-az305 --resource-group az305-rg

# Restart before the next session
az aks start --name aks-az305 --resource-group az305-rg
```

### Cost watchlist (highest to lowest)

1. **Application Gateway WAF_v2** -- fixed hourly cost even when idle (consider stopping if not needed between sessions)
2. **VMs** -- deallocate when not in use
3. **AKS node** -- stop cluster when not in use
4. **Recovery Services Vaults** -- storage charges for backup data
5. **Log Analytics** -- PerGB ingestion charges
6. **Everything else** -- minimal or zero idle cost

---

## Cleanup Instructions

When the demo environment is no longer needed, delete all resources.

```bash
# Delete the primary resource group (all resources except APIM)
az group delete --name az305-rg --yes --no-wait

# If also cleaning up the APIM resources
az group delete --name warnerco --yes --no-wait

# Verify deletion
az group list -o table
```

**Warning:** This is irreversible. Recovery Services Vaults may require manual removal of backup items before the resource group can be deleted.

```bash
# If vault deletion fails, disable soft delete and remove backup items first
az backup vault backup-properties set --name rsv-backup-az305 --resource-group az305-rg --soft-delete-feature-state Disable
az backup protection disable --container-name <CONTAINER> --item-name vm-win01 --vault-name rsv-backup-az305 --resource-group az305-rg --delete-backup-data true --yes
```

---

## Pre-Session Checklist

Run these commands 15 minutes before the live session to verify everything is running.

```bash
# 1. Start VMs
az vm start --name vm-win01 --resource-group az305-rg --no-wait
az vm start --name vm-linux01 --resource-group az305-rg --no-wait

# 2. Start AKS
az aks start --name aks-az305 --resource-group az305-rg

# 3. Verify SQL is responsive (will wake from auto-pause)
sqlcmd -S sql-az305-tw.database.windows.net -d sqldb-az305-demo -U tim -P 'REDACTED_SQL_PASSWORD' -Q "SELECT 1 AS alive"

# 4. Verify App Gateway is serving
curl -s -o /dev/null -w "%{http_code}" http://23.102.120.230

# 5. Verify Function App is responding
curl -s -o /dev/null -w "%{http_code}" "https://func-sb-az305-tw.azurewebsites.net/api/sendorder?message=healthcheck"

# 6. Verify APIM is responding
curl -s -o /dev/null -w "%{http_code}" -H "Ocp-Apim-Subscription-Key: REDACTED_APIM_KEY" https://warnerco-apim.azure-api.net/api/robots

# 7. Quick resource count
az resource list --resource-group az305-rg --query "length(@)" -o tsv
```

---

## Post-Session Checklist

Run after the live session to minimize costs.

```bash
# 1. Deallocate VMs
az vm deallocate --name vm-win01 --resource-group az305-rg --no-wait
az vm deallocate --name vm-linux01 --resource-group az305-rg --no-wait

# 2. Stop AKS
az aks stop --name aks-az305 --resource-group az305-rg

# 3. SQL will auto-pause on its own (60 min idle)
# No action needed
```

---

## Related Files

| File | Description |
|------|-------------|
| `../az305-objective-domain.md` | Complete AZ-305 exam objective domain study guide |
| `../docs/diagrams/` | Architecture diagrams (Mermaid) |
| `../instructor/` | Instructor slide decks and notes |

---

## Attribution

**Instructor:** Tim Warner
**Platform:** O'Reilly Live Learning
**Course:** AZ-305: Designing Microsoft Azure Infrastructure Solutions -- Exam Prep

*This demo environment is designed for educational purposes. All resources use cost-optimized SKUs suitable for demonstration, not production workloads.*
