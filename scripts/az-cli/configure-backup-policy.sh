#!/bin/bash
#===============================================================================
# SCRIPT: configure-backup-policy.sh
# SYNOPSIS: Create Recovery Services vault and configure backup policies
# DESCRIPTION:
#   This script creates Azure Backup infrastructure including:
#   - Recovery Services vault with geo-redundancy
#   - Custom backup policies for VMs (Enhanced and Standard)
#   - Backup policies for Azure Files
#   - Enable soft delete and security features
#   - Configure backup for sample resources
#
# AZ-305 EXAM OBJECTIVES:
#   - Design data storage solutions: Backup and recovery strategies
#   - Understand RPO/RTO requirements and backup frequency
#   - Compare backup tiers: Snapshot vs Vault-standard
#   - Design for compliance: Retention policies
#   - Implement cross-region restore for disaster recovery
#
# PREREQUISITES:
#   - Azure CLI 2.50+ installed and authenticated
#   - Subscription with Backup Contributor permissions
#   - Microsoft.RecoveryServices provider registered
#
# EXAMPLES:
#   # Create vault and policies with default settings
#   ./configure-backup-policy.sh
#
#   # Create with specific retention settings
#   DAILY_RETENTION=30 WEEKLY_RETENTION=12 ./configure-backup-policy.sh
#
# REFERENCES:
#   - https://learn.microsoft.com/azure/backup/backup-azure-arm-vms-prepare
#   - https://learn.microsoft.com/azure/backup/backup-azure-vms-enhanced-policy
#===============================================================================

set -euo pipefail

#-------------------------------------------------------------------------------
# CONFIGURATION
#-------------------------------------------------------------------------------
LOCATION="${LOCATION:-eastus}"
PREFIX="${PREFIX:-az305}"
RESOURCE_GROUP="${RESOURCE_GROUP:-${PREFIX}-backup-rg}"
VAULT_NAME="${VAULT_NAME:-${PREFIX}-rsv}"

# Retention settings (in days/weeks/months/years)
DAILY_RETENTION="${DAILY_RETENTION:-30}"
WEEKLY_RETENTION="${WEEKLY_RETENTION:-12}"
MONTHLY_RETENTION="${MONTHLY_RETENTION:-12}"
YEARLY_RETENTION="${YEARLY_RETENTION:-3}"

# Storage redundancy: GeoRedundant, LocallyRedundant, ZoneRedundant
STORAGE_REDUNDANCY="${STORAGE_REDUNDANCY:-GeoRedundant}"

#-------------------------------------------------------------------------------
# HELPER FUNCTIONS
#-------------------------------------------------------------------------------
log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

log_success() {
    echo "[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

#-------------------------------------------------------------------------------
# CREATE RESOURCE GROUP
#-------------------------------------------------------------------------------
create_resource_group() {
    log_info "Creating resource group..."

    az group create \
        --name "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --tags "Environment=Development" "Purpose=AZ305-Backup" \
        --output none

    log_success "Resource group created: $RESOURCE_GROUP"
}

#-------------------------------------------------------------------------------
# CREATE RECOVERY SERVICES VAULT
#-------------------------------------------------------------------------------
create_recovery_vault() {
    log_info "Creating Recovery Services vault..."

    # WHY: Recovery Services vault is the central management point for:
    # - Azure VM backup
    # - Azure Files backup
    # - SQL Server in Azure VM backup
    # - SAP HANA backup
    # - Azure Disk backup

    az backup vault create \
        --name "$VAULT_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --output none

    log_success "Recovery Services vault created: $VAULT_NAME"

    # Configure storage redundancy
    # WHY: GeoRedundant provides cross-region protection for disaster recovery
    # LocallyRedundant is cheaper but no cross-region protection
    log_info "Configuring storage redundancy: $STORAGE_REDUNDANCY..."
    az backup vault backup-properties set \
        --name "$VAULT_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --backup-storage-redundancy "$STORAGE_REDUNDANCY" \
        --output none

    # Enable soft delete (on by default, but making explicit)
    # WHY: Soft delete protects against accidental or malicious deletion
    # Deleted backup data is retained for 14 additional days
    log_info "Enabling soft delete..."
    az backup vault backup-properties set \
        --name "$VAULT_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --soft-delete-feature-state Enable \
        --output none

    log_success "Vault configuration complete"
}

#-------------------------------------------------------------------------------
# CREATE ENHANCED VM BACKUP POLICY
#-------------------------------------------------------------------------------
create_enhanced_vm_policy() {
    log_info "Creating Enhanced VM backup policy..."

    POLICY_NAME="${PREFIX}-vm-enhanced-policy"

    # WHY: Enhanced policy provides:
    # - Multiple backups per day (minimum 4-hour RPO)
    # - Longer instant restore retention (up to 30 days)
    # - Support for Trusted Launch VMs
    # - Zone-pinned snapshots

    # Create policy JSON
    cat > /tmp/enhanced-vm-policy.json << EOF
{
    "eTag": null,
    "properties": {
        "backupManagementType": "AzureIaasVM",
        "instantRPDetails": {},
        "schedulePolicy": {
            "schedulePolicyType": "SimpleSchedulePolicyV2",
            "scheduleRunFrequency": "Hourly",
            "hourlySchedule": {
                "interval": 4,
                "scheduleWindowStartTime": "2024-01-01T08:00:00Z",
                "scheduleWindowDuration": 12
            }
        },
        "retentionPolicy": {
            "retentionPolicyType": "LongTermRetentionPolicy",
            "dailySchedule": {
                "retentionTimes": ["2024-01-01T08:00:00Z"],
                "retentionDuration": {
                    "count": $DAILY_RETENTION,
                    "durationType": "Days"
                }
            },
            "weeklySchedule": {
                "daysOfTheWeek": ["Sunday"],
                "retentionTimes": ["2024-01-01T08:00:00Z"],
                "retentionDuration": {
                    "count": $WEEKLY_RETENTION,
                    "durationType": "Weeks"
                }
            },
            "monthlySchedule": {
                "retentionScheduleFormatType": "Weekly",
                "retentionScheduleWeekly": {
                    "daysOfTheWeek": ["Sunday"],
                    "weeksOfTheMonth": ["First"]
                },
                "retentionTimes": ["2024-01-01T08:00:00Z"],
                "retentionDuration": {
                    "count": $MONTHLY_RETENTION,
                    "durationType": "Months"
                }
            },
            "yearlySchedule": {
                "retentionScheduleFormatType": "Weekly",
                "monthsOfYear": ["January"],
                "retentionScheduleWeekly": {
                    "daysOfTheWeek": ["Sunday"],
                    "weeksOfTheMonth": ["First"]
                },
                "retentionTimes": ["2024-01-01T08:00:00Z"],
                "retentionDuration": {
                    "count": $YEARLY_RETENTION,
                    "durationType": "Years"
                }
            }
        },
        "instantRpRetentionRangeInDays": 7,
        "timeZone": "UTC",
        "policyType": "V2"
    }
}
EOF

    # Create the policy
    az backup policy create \
        --vault-name "$VAULT_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --name "$POLICY_NAME" \
        --policy /tmp/enhanced-vm-policy.json \
        --backup-management-type AzureIaasVM \
        --output none 2>/dev/null || log_info "Policy may already exist, continuing..."

    log_success "Enhanced VM backup policy created: $POLICY_NAME"
}

#-------------------------------------------------------------------------------
# CREATE STANDARD VM BACKUP POLICY
#-------------------------------------------------------------------------------
create_standard_vm_policy() {
    log_info "Creating Standard VM backup policy..."

    POLICY_NAME="${PREFIX}-vm-standard-policy"

    # WHY: Standard policy is simpler and more cost-effective
    # - Once per day backup
    # - 2-day instant restore retention
    # - Good for non-critical workloads

    cat > /tmp/standard-vm-policy.json << EOF
{
    "properties": {
        "backupManagementType": "AzureIaasVM",
        "schedulePolicy": {
            "schedulePolicyType": "SimpleSchedulePolicy",
            "scheduleRunFrequency": "Daily",
            "scheduleRunTimes": ["2024-01-01T02:00:00Z"]
        },
        "retentionPolicy": {
            "retentionPolicyType": "LongTermRetentionPolicy",
            "dailySchedule": {
                "retentionTimes": ["2024-01-01T02:00:00Z"],
                "retentionDuration": {
                    "count": $DAILY_RETENTION,
                    "durationType": "Days"
                }
            },
            "weeklySchedule": {
                "daysOfTheWeek": ["Sunday"],
                "retentionTimes": ["2024-01-01T02:00:00Z"],
                "retentionDuration": {
                    "count": $WEEKLY_RETENTION,
                    "durationType": "Weeks"
                }
            }
        },
        "instantRpRetentionRangeInDays": 2,
        "timeZone": "UTC"
    }
}
EOF

    az backup policy create \
        --vault-name "$VAULT_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --name "$POLICY_NAME" \
        --policy /tmp/standard-vm-policy.json \
        --backup-management-type AzureIaasVM \
        --output none 2>/dev/null || log_info "Policy may already exist, continuing..."

    log_success "Standard VM backup policy created: $POLICY_NAME"
}

#-------------------------------------------------------------------------------
# CREATE AZURE FILES BACKUP POLICY
#-------------------------------------------------------------------------------
create_files_backup_policy() {
    log_info "Creating Azure Files backup policy..."

    POLICY_NAME="${PREFIX}-files-policy"

    # WHY: Azure Files backup provides:
    # - Snapshot-based backup (fast restore)
    # - Integration with Recovery Services vault
    # - Support for both snapshot and vault tiers

    cat > /tmp/files-policy.json << EOF
{
    "properties": {
        "backupManagementType": "AzureStorage",
        "workLoadType": "AzureFileShare",
        "schedulePolicy": {
            "schedulePolicyType": "SimpleSchedulePolicy",
            "scheduleRunFrequency": "Daily",
            "scheduleRunTimes": ["2024-01-01T03:00:00Z"]
        },
        "retentionPolicy": {
            "retentionPolicyType": "LongTermRetentionPolicy",
            "dailySchedule": {
                "retentionTimes": ["2024-01-01T03:00:00Z"],
                "retentionDuration": {
                    "count": $DAILY_RETENTION,
                    "durationType": "Days"
                }
            },
            "weeklySchedule": {
                "daysOfTheWeek": ["Sunday"],
                "retentionTimes": ["2024-01-01T03:00:00Z"],
                "retentionDuration": {
                    "count": $WEEKLY_RETENTION,
                    "durationType": "Weeks"
                }
            },
            "monthlySchedule": {
                "retentionScheduleFormatType": "Weekly",
                "retentionScheduleWeekly": {
                    "daysOfTheWeek": ["Sunday"],
                    "weeksOfTheMonth": ["First"]
                },
                "retentionTimes": ["2024-01-01T03:00:00Z"],
                "retentionDuration": {
                    "count": $MONTHLY_RETENTION,
                    "durationType": "Months"
                }
            }
        },
        "timeZone": "UTC"
    }
}
EOF

    az backup policy create \
        --vault-name "$VAULT_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --name "$POLICY_NAME" \
        --policy /tmp/files-policy.json \
        --backup-management-type AzureStorage \
        --workload-type AzureFileShare \
        --output none 2>/dev/null || log_info "Policy may already exist, continuing..."

    log_success "Azure Files backup policy created: $POLICY_NAME"
}

#-------------------------------------------------------------------------------
# CREATE SAMPLE RESOURCES FOR BACKUP DEMO
#-------------------------------------------------------------------------------
create_sample_storage() {
    log_info "Creating sample storage account with file share..."

    STORAGE_NAME="${PREFIX}backupstore$(openssl rand -hex 4)"

    # Create storage account
    az storage account create \
        --name "$STORAGE_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --sku "Standard_LRS" \
        --kind "StorageV2" \
        --output none

    # Create file share
    STORAGE_KEY=$(az storage account keys list \
        --account-name "$STORAGE_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query "[0].value" \
        --output tsv)

    az storage share create \
        --name "backup-demo-share" \
        --account-name "$STORAGE_NAME" \
        --account-key "$STORAGE_KEY" \
        --quota 5 \
        --output none

    log_success "Storage account created: $STORAGE_NAME"
}

#-------------------------------------------------------------------------------
# ENABLE BACKUP FOR STORAGE
#-------------------------------------------------------------------------------
enable_storage_backup() {
    log_info "Enabling backup for Azure Files..."

    # Register storage account with vault
    az backup container register \
        --vault-name "$VAULT_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --backup-management-type AzureStorage \
        --resource-id "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Storage/storageAccounts/$STORAGE_NAME" \
        --output none 2>/dev/null || log_info "Container may already be registered"

    # Enable backup for file share
    az backup protection enable-for-azurefileshare \
        --vault-name "$VAULT_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --storage-account "$STORAGE_NAME" \
        --azure-file-share "backup-demo-share" \
        --policy-name "${PREFIX}-files-policy" \
        --output none 2>/dev/null || log_info "Backup may already be enabled"

    log_success "Backup enabled for Azure Files"
}

#-------------------------------------------------------------------------------
# DISPLAY SUMMARY
#-------------------------------------------------------------------------------
display_summary() {
    echo ""
    echo "==============================================================================="
    echo "                      BACKUP CONFIGURATION SUMMARY"
    echo "==============================================================================="
    echo ""
    echo "Resource Group: $RESOURCE_GROUP"
    echo "Location: $LOCATION"
    echo ""
    echo "RECOVERY SERVICES VAULT:"
    echo "-------------------------------------------------------------------------------"
    echo "Name: $VAULT_NAME"
    echo "Storage Redundancy: $STORAGE_REDUNDANCY"
    echo "Soft Delete: Enabled"
    echo ""

    # Get vault details
    az backup vault show \
        --name "$VAULT_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query "{Name:name, Location:location, ProvisioningState:properties.provisioningState}" \
        --output table
    echo ""

    echo "BACKUP POLICIES:"
    echo "-------------------------------------------------------------------------------"
    az backup policy list \
        --vault-name "$VAULT_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query "[].{Name:name, BackupManagementType:properties.backupManagementType, ScheduleFrequency:properties.schedulePolicy.scheduleRunFrequency}" \
        --output table
    echo ""

    echo "RETENTION SETTINGS:"
    echo "-------------------------------------------------------------------------------"
    echo "Daily Retention: $DAILY_RETENTION days"
    echo "Weekly Retention: $WEEKLY_RETENTION weeks"
    echo "Monthly Retention: $MONTHLY_RETENTION months"
    echo "Yearly Retention: $YEARLY_RETENTION years"
    echo ""

    echo "PROTECTED ITEMS:"
    echo "-------------------------------------------------------------------------------"
    az backup item list \
        --vault-name "$VAULT_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query "[].{Name:name, Type:properties.workloadType, Policy:properties.policyName, Status:properties.protectionStatus}" \
        --output table 2>/dev/null || echo "(No protected items yet)"
    echo ""

    echo "==============================================================================="
    echo "BACKUP BEST PRACTICES (AZ-305 Exam Context):"
    echo "==============================================================================="
    echo ""
    echo "1. RPO/RTO REQUIREMENTS:"
    echo "   - Enhanced policy: 4-hour RPO minimum"
    echo "   - Standard policy: 24-hour RPO"
    echo "   - Instant restore: Minutes RTO"
    echo "   - Vault restore: Hours RTO"
    echo ""
    echo "2. STORAGE REDUNDANCY:"
    echo "   - GRS: Cross-region protection (for DR)"
    echo "   - LRS: Lower cost, single region"
    echo "   - ZRS: Zone redundancy within region"
    echo ""
    echo "3. COMPLIANCE CONSIDERATIONS:"
    echo "   - Enable immutable vaults for regulatory compliance"
    echo "   - Use RBAC to restrict who can disable backup"
    echo "   - Soft delete protects against ransomware"
    echo ""
    echo "4. COST OPTIMIZATION:"
    echo "   - Use appropriate retention periods"
    echo "   - Archive tier for long-term retention"
    echo "   - Monitor backup storage usage"
    echo ""
    echo "==============================================================================="
    echo "USEFUL COMMANDS:"
    echo "==============================================================================="
    echo ""
    echo "# Trigger on-demand backup"
    echo "az backup protection backup-now --vault-name $VAULT_NAME --resource-group $RESOURCE_GROUP --container-name <container> --item-name <item>"
    echo ""
    echo "# List recovery points"
    echo "az backup recoverypoint list --vault-name $VAULT_NAME --resource-group $RESOURCE_GROUP --container-name <container> --item-name <item>"
    echo ""
    echo "# Restore file share"
    echo "az backup restore restore-azurefileshare --vault-name $VAULT_NAME --resource-group $RESOURCE_GROUP --rp-name <recovery-point> --container-name <container> --item-name <share> --restore-mode OriginalLocation"
    echo "==============================================================================="
}

#-------------------------------------------------------------------------------
# MAIN
#-------------------------------------------------------------------------------
main() {
    log_info "Starting backup configuration..."

    create_resource_group
    create_recovery_vault
    create_enhanced_vm_policy
    create_standard_vm_policy
    create_files_backup_policy
    create_sample_storage
    enable_storage_backup
    display_summary

    log_success "Backup configuration completed successfully!"
}

main "$@"
