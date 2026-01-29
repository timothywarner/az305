#!/usr/bin/env bash
# ============================================================================
# TITLE:    AZ-305 Domain 3: Business Continuity & Disaster Recovery
# DOMAIN:   Domain 3 - Design Business Continuity Solutions (15-20%)
# DESCRIPTION:
#   Teaching examples covering Azure Backup, Azure Site Recovery, SQL geo-
#   replication, storage redundancy, Cosmos DB multi-region writes, point-in-
#   time restore, and availability design patterns. Code-review examples for
#   AZ-305 classroom use.
# AUTHOR:   Tim Warner
# DATE:     January 2026
# NOTES:    Not intended for direct execution. Illustrates correct syntax and
#           architectural decision-making for AZ-305 exam preparation.
# ============================================================================

set -euo pipefail

SUBSCRIPTION_ID="00000000-0000-0000-0000-000000000000"
RESOURCE_GROUP="az305-rg"
LOCATION="eastus"
DR_LOCATION="westus2"
PREFIX="az305"

# ============================================================================
# SECTION 1: Azure Backup Vault + VM Backup Policy
# ============================================================================

# EXAM TIP: Azure Backup is the primary backup service. Know the two vault types:
#   Recovery Services vault -> VMs, SQL on VM, SAP HANA, Azure Files, on-prem
#   Backup vault           -> Azure Disks, Azure Blobs, Azure Database for PostgreSQL
# The exam tests: vault type selection, backup frequency, retention, RPO/RTO impact.
#
# KEY CONCEPTS:
#   RPO (Recovery Point Objective) = Maximum acceptable data loss (time between backups)
#   RTO (Recovery Time Objective)  = Maximum acceptable downtime (time to restore)
#   Example: RPO of 1 hour means you backup at least every hour.
#            RTO of 4 hours means you must restore within 4 hours.

# WHEN TO USE:
#   Azure Backup -> Application-consistent backups, long-term retention, compliance
#   Snapshots    -> Fast, short-term recovery (minutes), no cross-region
#   ASR          -> Full VM replication for DR (see Section 2)
#   Choose based on RPO/RTO: Snapshots (minutes RPO) vs Backup (hours RPO) vs ASR (seconds RPO)

# Create a Recovery Services vault for VM backups
az backup vault create \
    --name "${PREFIX}-rsv" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --storage-redundancy "GeoRedundant"  # GRS for cross-region backup protection

# EXAM TIP: Storage redundancy for the vault determines where backup data is stored:
#   LRS -> Single region, 3 copies (lowest cost, no regional DR)
#   ZRS -> Single region, across zones (zone-level protection)
#   GRS -> Cross-region, 6 copies (recommended for production)

# Create a backup policy with Enhanced policy tier (multi-day backup)
# Enhanced policy supports: multiple backups/day (RPO as low as 4 hours),
# zone-level protection, and instant restore from snapshot tier.
az backup policy set \
    --resource-group "$RESOURCE_GROUP" \
    --vault-name "${PREFIX}-rsv" \
    --name "production-vm-policy" \
    --policy '{
        "policyType": "V2",
        "instantRPDetails": {
            "azureBackupRGNamePrefix": "az305-restore-",
            "azureBackupRGNameSuffix": ""
        },
        "schedulePolicy": {
            "schedulePolicyType": "SimpleSchedulePolicyV2",
            "scheduleRunFrequency": "Hourly",
            "hourlySchedule": {
                "interval": 4,
                "scheduleWindowStartTime": "2026-01-01T06:00:00Z",
                "scheduleWindowDuration": 16
            }
        },
        "retentionPolicy": {
            "retentionPolicyType": "LongTermRetentionPolicy",
            "dailySchedule": {
                "retentionDuration": {"count": 30, "durationType": "Days"}
            },
            "weeklySchedule": {
                "retentionDuration": {"count": 12, "durationType": "Weeks"},
                "daysOfTheWeek": ["Sunday"]
            },
            "monthlySchedule": {
                "retentionDuration": {"count": 12, "durationType": "Months"},
                "retentionScheduleFormatType": "Weekly",
                "retentionScheduleWeekly": {
                    "daysOfTheWeek": ["Sunday"],
                    "weeksOfTheMonth": ["First"]
                }
            },
            "yearlySchedule": {
                "retentionDuration": {"count": 3, "durationType": "Years"},
                "retentionScheduleFormatType": "Weekly",
                "monthsOfYear": ["January"],
                "retentionScheduleWeekly": {
                    "daysOfTheWeek": ["Sunday"],
                    "weeksOfTheMonth": ["First"]
                }
            }
        }
    }'

# Enable backup for a VM
az backup protection enable-for-vm \
    --resource-group "$RESOURCE_GROUP" \
    --vault-name "${PREFIX}-rsv" \
    --vm "${PREFIX}-vm" \
    --policy-name "production-vm-policy"

# ============================================================================
# SECTION 2: Azure Site Recovery (Cross-Region DR)
# ============================================================================

# EXAM TIP: Azure Site Recovery (ASR) provides FULL VM REPLICATION for disaster
# recovery. It continuously replicates VMs to a secondary region with RPO as
# low as 30 seconds. Know the difference:
#   Backup = Point-in-time restore (RPO hours, RTO hours)
#   ASR    = Near-real-time replication (RPO seconds, RTO minutes)

# WHEN TO USE: ASR when RTO < 1 hour and RPO < 5 minutes.
# ASR supports: Azure-to-Azure, VMware-to-Azure, Hyper-V-to-Azure, physical servers.
# For Azure VMs, ASR replicates managed disks to the target region.

# Create the target (DR) resource group
az group create \
    --name "${RESOURCE_GROUP}-dr" \
    --location "$DR_LOCATION"

# Create a Recovery Services vault in the DR region for ASR
az backup vault create \
    --name "${PREFIX}-rsv-dr" \
    --resource-group "${RESOURCE_GROUP}-dr" \
    --location "$DR_LOCATION" \
    --storage-redundancy "LocallyRedundant"  # LRS in DR region (source is already GRS)

# EXAM TIP: ASR configuration for Azure-to-Azure includes:
# 1. Source and target regions (paired regions recommended for best SLA)
# 2. Replication policy (RPO threshold, recovery point retention, app-consistent frequency)
# 3. Target network and subnet mapping
# 4. Managed identity for ASR permissions
#
# The full ASR setup involves multiple steps best done in portal or Bicep.
# Conceptual CLI flow:
# az site-recovery policy create ...
# az site-recovery protection-container create ...
# az site-recovery replication-protected-item create ...

# Key replication policy parameters:
# - Recovery point retention: 24 hours (how many hours of recovery points to keep)
# - App-consistent snapshot frequency: 4 hours (for database-consistent recovery)
# - Multi-VM consistency: Enabled (ensures related VMs recover together)

# DR failover test (non-disruptive) -- run periodically to validate DR readiness
# az site-recovery replication-protected-item test-failover ...

# EXAM TIP: Always perform DR drills. The exam asks about DR testing strategies:
#   Test failover     -> Non-disruptive, creates isolated test VMs in DR region
#   Planned failover  -> Graceful, no data loss, requires source VM shutdown
#   Unplanned failover -> Emergency, minimal data loss (up to RPO), source may be down

# ============================================================================
# SECTION 3: SQL Database Geo-Replication and Auto-Failover Groups
# ============================================================================

# EXAM TIP: Two approaches to SQL Database DR:
#   Active geo-replication -> Manual failover, up to 4 readable secondaries
#   Auto-failover groups   -> Automatic failover, DNS-based endpoint redirection
# The exam STRONGLY prefers auto-failover groups for production scenarios because
# they provide automatic failover without application connection string changes.

# WHEN TO USE:
#   Auto-failover groups -> Production apps requiring automatic DR with zero app changes
#   Active geo-replication -> Read scale-out, manual failover control, >4 replicas
#   Geo-restore from backup -> Lowest cost DR (RPO up to 1 hour, RTO up to 12 hours)

# Create a failover group across two regions
az sql failover-group create \
    --name "${PREFIX}-fog" \
    --partner-server "${PREFIX}-sql-dr" \
    --resource-group "$RESOURCE_GROUP" \
    --server "${PREFIX}-sql" \
    --partner-resource-group "${RESOURCE_GROUP}-dr" \
    --failover-policy "Automatic" \
    --grace-period 1 \
    --add-db "${PREFIX}-db-production"

# EXAM TIP: The failover group provides TWO DNS endpoints:
#   Read-write: <fog-name>.database.windows.net (points to primary)
#   Read-only:  <fog-name>.secondary.database.windows.net (points to secondary)
# After failover, DNS automatically redirects. Applications using these endpoints
# require ZERO code changes for DR. This is a key exam concept.

# Grace period = minutes to wait before automatic failover (prevents false positives)
# Set to 0 for immediate failover; 1 hour is common for production.

# ============================================================================
# SECTION 4: Storage Account Redundancy Options (Decision Guide)
# ============================================================================

# EXAM TIP: Storage redundancy is a HEAVILY tested topic. Know ALL six options:
#
# +----------+--------+-------+------+------------------------------------------+
# | Option   | Copies | Zones | Regions | Use Case                              |
# +----------+--------+-------+---------+---------------------------------------+
# | LRS      | 3      | 1     | 1       | Dev/test, non-critical, lowest cost   |
# | ZRS      | 3      | 3     | 1       | HA within region, zone failure         |
# | GRS      | 6      | 1     | 2       | DR across regions, read after failover|
# | GZRS     | 6      | 3     | 2       | Best: zone HA + cross-region DR       |
# | RA-GRS   | 6      | 1     | 2       | GRS + read access to secondary always |
# | RA-GZRS  | 6      | 3     | 2       | GZRS + read access to secondary always|
# +----------+--------+-------+---------+---------------------------------------+
#
# Decision flow:
#   Need cross-region DR?
#     No  -> Need zone redundancy? Yes=ZRS, No=LRS
#     Yes -> Need read access to secondary? Yes=RA-GRS/RA-GZRS, No=GRS/GZRS
#            Need zone redundancy? Yes=GZRS/RA-GZRS, No=GRS/RA-GRS

# WHEN TO USE RA-GRS/RA-GZRS: When you need read access to data even during a
# regional outage (e.g., static content serving, reporting workloads).
# The secondary endpoint is: <account>-secondary.blob.core.windows.net

# Create storage accounts demonstrating different redundancy levels
az storage account create \
    --name "${PREFIX}stordev" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --sku "Standard_LRS" \
    --kind "StorageV2" \
    --min-tls-version "TLS1_2"
    # LRS: Dev/test only -- single datacenter, no zone/region protection

az storage account create \
    --name "${PREFIX}storprod" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --sku "Standard_RAGZRS" \
    --kind "StorageV2" \
    --min-tls-version "TLS1_2"
    # RA-GZRS: Production -- zone-redundant + cross-region + read secondary

# ============================================================================
# SECTION 5: Cosmos DB Multi-Region Writes
# ============================================================================

# EXAM TIP: Cosmos DB supports multi-region writes (active-active) where ANY
# region can accept writes. This provides the lowest write latency for globally
# distributed apps. Conflict resolution is handled via:
#   Last-Writer-Wins (LWW) -> Default, uses _ts timestamp
#   Custom conflict resolution -> Stored procedure or merge function
# Multi-region writes INCREASE RU cost (roughly 2x per additional write region).

# WHEN TO USE multi-region writes:
#   Active-active (multi-write) -> Global apps needing low write latency everywhere
#   Active-passive (single-write) -> Most apps; read replicas sufficient
#   Single region -> Dev/test, regional-only apps, cost-sensitive workloads

# Enable multi-region writes on an existing Cosmos DB account
az cosmosdb update \
    --name "${PREFIX}-cosmos" \
    --resource-group "$RESOURCE_GROUP" \
    --enable-multiple-write-locations true

# Add a write region (each region can now accept writes)
az cosmosdb update \
    --name "${PREFIX}-cosmos" \
    --resource-group "$RESOURCE_GROUP" \
    --locations regionName=eastus failoverPriority=0 isZoneRedundant=true \
    --locations regionName=westus2 failoverPriority=1 isZoneRedundant=true \
    --locations regionName=northeurope failoverPriority=2 isZoneRedundant=true

# Configure automatic failover (if a write region goes down, next priority takes over)
az cosmosdb update \
    --name "${PREFIX}-cosmos" \
    --resource-group "$RESOURCE_GROUP" \
    --enable-automatic-failover true

# ============================================================================
# SECTION 6: Point-in-Time Restore for SQL and Blob
# ============================================================================

# EXAM TIP: Point-in-time restore (PITR) recovers data to a specific moment.
# It is the PRIMARY defense against accidental data deletion/corruption.
# Different services have different PITR capabilities:
#   SQL Database  -> 1-35 days retention (configurable), 5-10 min granularity
#   SQL Managed Instance -> 1-35 days, same as SQL Database
#   Blob Storage  -> Requires versioning + soft delete, or PITR feature (preview)
#   Cosmos DB     -> Continuous backup mode: 7 or 30 day retention

# WHEN TO USE PITR vs full backup restore:
#   PITR         -> Accidental deletion, corruption, "undo" within retention window
#   Full restore -> Complete database recovery, migration, cloning for dev/test

# --- SQL Database Point-in-Time Restore ---
# Restore to a specific timestamp (e.g., 2 hours ago before accidental DELETE)
RESTORE_TIME=$(date -u -d '2 hours ago' '+%Y-%m-%dT%H:%M:%SZ')

az sql db restore \
    --resource-group "$RESOURCE_GROUP" \
    --server "${PREFIX}-sql" \
    --name "${PREFIX}-db-production" \
    --dest-name "${PREFIX}-db-restored" \
    --time "$RESTORE_TIME"

# EXAM TIP: PITR creates a NEW database -- it does NOT overwrite the existing one.
# After validation, you can rename the restored DB and drop the corrupted one.
# Long-term retention (LTR) extends backup retention beyond 35 days (weekly/monthly/yearly).

# Configure long-term retention for compliance
az sql db ltr-policy set \
    --resource-group "$RESOURCE_GROUP" \
    --server "${PREFIX}-sql" \
    --database "${PREFIX}-db-production" \
    --weekly-retention "P4W" \
    --monthly-retention "P12M" \
    --yearly-retention "P3Y" \
    --week-of-year 1

# --- Blob Storage Point-in-Time Restore ---
# Requires blob versioning, change feed, and soft delete to be enabled
az storage account blob-service-properties update \
    --account-name "${PREFIX}storage" \
    --resource-group "$RESOURCE_GROUP" \
    --enable-versioning true \
    --enable-change-feed true \
    --enable-delete-retention true \
    --delete-retention-days 30 \
    --enable-restore-policy true \
    --restore-days 14

# ============================================================================
# SECTION 7: Availability Sets vs Zones vs VMSS Decision Guide
# ============================================================================

# EXAM TIP: This is a CRITICAL decision tree for the exam:
#
# +---------------------+------------------+--------+---------+------------------+
# | Feature             | Availability Set | Avail. | VMSS    | Single VM        |
# |                     |                  | Zones  |         |                  |
# +---------------------+------------------+--------+---------+------------------+
# | Protects against    | Rack/host failure| Zone   | Zone +  | None             |
# |                     |                  | failure| scaling |                  |
# | SLA (with 2+ VMs)  | 99.95%           | 99.99% | 99.95%+ | 99.9% (prem SSD)|
# | Auto-scaling        | No               | No     | Yes     | No               |
# | Max instances       | 200 (3 FDs)      | 3 zones| 1000    | 1                |
# | Best for            | Legacy lift-shift| Prod   | Web tier| Dev/test         |
# +---------------------+------------------+--------+---------+------------------+
#
# Decision flow:
#   Need auto-scaling?
#     Yes -> VMSS (can span availability zones for 99.99%)
#     No  -> Need highest SLA?
#              Yes -> Availability Zones (99.99%)
#              No  -> Availability Sets (99.95%) or single VM (99.9% with premium SSD)

# WHEN TO USE:
#   Availability Zones -> Production workloads needing zone-level fault tolerance
#   Availability Sets  -> Legacy apps that cannot span zones (older regions)
#   VMSS               -> Stateless workloads needing auto-scale (web frontends)
#   Single VM with Premium SSD -> Dev/test, or when 99.9% SLA is acceptable

# Create a VM in a specific availability zone
az vm create \
    --resource-group "$RESOURCE_GROUP" \
    --name "${PREFIX}-vm-zone1" \
    --location "$LOCATION" \
    --zone 1 \
    --image "MicrosoftWindowsServer:WindowsServer:2022-datacenter-g2:latest" \
    --size "Standard_D4s_v5" \
    --admin-username "azureadmin" \
    --admin-password "REPLACE-WITH-KEYVAULT-SECRET" \
    --os-disk-type "Premium_LRS" \
    --nsg "${PREFIX}-nsg"

# Create VMs across ALL three zones for highest availability
for ZONE in 1 2 3; do
    az vm create \
        --resource-group "$RESOURCE_GROUP" \
        --name "${PREFIX}-vm-zone${ZONE}" \
        --location "$LOCATION" \
        --zone "$ZONE" \
        --image "MicrosoftWindowsServer:WindowsServer:2022-datacenter-g2:latest" \
        --size "Standard_D4s_v5" \
        --admin-username "azureadmin" \
        --admin-password "REPLACE-WITH-KEYVAULT-SECRET" \
        --os-disk-type "Premium_LRS" \
        --nsg "${PREFIX}-nsg" \
        --no-wait  # Deploy in parallel for speed
done

echo "Business continuity configuration examples complete."
echo "Recovery Services Vault: ${PREFIX}-rsv"
echo "Failover Group: ${PREFIX}-fog"
