// ============================================================================
// Azure Recovery Services Vault with Backup Policies
// ============================================================================
// Purpose: Deploy Recovery Services Vault for backup and site recovery
// AZ-305 Exam Objectives:
//   - Design a solution for backup and disaster recovery (Objective 3.1)
//   - Design high availability solutions (Objective 3.2)
// Prerequisites:
//   - Resource group must exist
//   - Azure VMs or SQL databases to protect (optional)
// ============================================================================

targetScope = 'resourceGroup'

// ============================================================================
// Parameters
// ============================================================================

@description('Name of the Recovery Services Vault.')
@minLength(2)
@maxLength(50)
param vaultName string

@description('Azure region for the vault.')
param location string = resourceGroup().location

@description('Storage redundancy for the vault.')
@allowed([
  'LocallyRedundant'
  'GeoRedundant'
  'ZoneRedundant'
])
param storageType string = 'GeoRedundant'

@description('Cross region restore setting.')
param enableCrossRegionRestore bool = true

@description('Enable soft delete for backup items.')
param enableSoftDelete bool = true

@description('Soft delete retention period in days.')
@minValue(14)
@maxValue(180)
param softDeleteRetentionDays int = 14

@description('Enable enhanced security (immutability).')
param enableEnhancedSecurity bool = true

@description('Create default VM backup policy.')
param createDefaultVmPolicy bool = true

@description('Create default SQL backup policy.')
param createDefaultSqlPolicy bool = true

@description('Create default File Share backup policy.')
param createDefaultFileSharePolicy bool = true

@description('VM backup schedule time (UTC).')
param vmBackupScheduleTime string = '23:00'

@description('VM backup retention days.')
@minValue(7)
@maxValue(9999)
param vmBackupRetentionDays int = 30

@description('VM weekly backup retention weeks.')
param vmWeeklyRetentionWeeks int = 12

@description('VM monthly backup retention months.')
param vmMonthlyRetentionMonths int = 12

@description('VM yearly backup retention years.')
param vmYearlyRetentionYears int = 3

@description('Tags to apply to resources.')
param tags object = {
  environment: 'production'
  purpose: 'backup-recovery'
  examObjective: 'AZ-305-BusinessContinuity'
}

// ============================================================================
// Variables
// ============================================================================

var recoveryVaultName = 'rsv-${vaultName}-${uniqueString(resourceGroup().id)}'

// ============================================================================
// Resources - Recovery Services Vault
// ============================================================================

@description('Recovery Services Vault')
resource recoveryServicesVault 'Microsoft.RecoveryServices/vaults@2023-06-01' = {
  name: recoveryVaultName
  location: location
  tags: tags
  sku: {
    name: 'RS0'
    tier: 'Standard'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publicNetworkAccess: 'Enabled'
    securitySettings: {
      immutabilitySettings: enableEnhancedSecurity ? {
        state: 'Unlocked'
      } : null
      softDeleteSettings: {
        softDeleteState: enableSoftDelete ? 'Enabled' : 'Disabled'
        softDeleteRetentionPeriodInDays: softDeleteRetentionDays
        enhancedSecurityState: enableEnhancedSecurity ? 'Enabled' : 'Disabled'
      }
    }
  }
}

// ============================================================================
// Resources - Vault Configuration
// ============================================================================

@description('Backup storage configuration')
resource backupStorageConfig 'Microsoft.RecoveryServices/vaults/backupstorageconfig@2023-06-01' = {
  parent: recoveryServicesVault
  name: 'vaultstorageconfig'
  properties: {
    storageType: storageType
    crossRegionRestoreFlag: enableCrossRegionRestore
  }
}

// ============================================================================
// Resources - VM Backup Policy
// ============================================================================

@description('Enhanced VM backup policy with tiered retention')
resource vmBackupPolicy 'Microsoft.RecoveryServices/vaults/backupPolicies@2023-06-01' = if (createDefaultVmPolicy) {
  parent: recoveryServicesVault
  name: 'policy-vm-enhanced'
  properties: {
    backupManagementType: 'AzureIaasVM'
    instantRpRetentionRangeInDays: 5
    schedulePolicy: {
      schedulePolicyType: 'SimpleSchedulePolicy'
      scheduleRunFrequency: 'Daily'
      scheduleRunTimes: [
        '2024-01-01T${vmBackupScheduleTime}:00Z'
      ]
      scheduleWeeklyFrequency: 0
    }
    retentionPolicy: {
      retentionPolicyType: 'LongTermRetentionPolicy'
      dailySchedule: {
        retentionTimes: [
          '2024-01-01T${vmBackupScheduleTime}:00Z'
        ]
        retentionDuration: {
          count: vmBackupRetentionDays
          durationType: 'Days'
        }
      }
      weeklySchedule: {
        daysOfTheWeek: [
          'Sunday'
        ]
        retentionTimes: [
          '2024-01-01T${vmBackupScheduleTime}:00Z'
        ]
        retentionDuration: {
          count: vmWeeklyRetentionWeeks
          durationType: 'Weeks'
        }
      }
      monthlySchedule: {
        retentionScheduleFormatType: 'Weekly'
        retentionScheduleWeekly: {
          daysOfTheWeek: [
            'Sunday'
          ]
          weeksOfTheMonth: [
            'First'
          ]
        }
        retentionTimes: [
          '2024-01-01T${vmBackupScheduleTime}:00Z'
        ]
        retentionDuration: {
          count: vmMonthlyRetentionMonths
          durationType: 'Months'
        }
      }
      yearlySchedule: {
        retentionScheduleFormatType: 'Weekly'
        monthsOfYear: [
          'January'
        ]
        retentionScheduleWeekly: {
          daysOfTheWeek: [
            'Sunday'
          ]
          weeksOfTheMonth: [
            'First'
          ]
        }
        retentionTimes: [
          '2024-01-01T${vmBackupScheduleTime}:00Z'
        ]
        retentionDuration: {
          count: vmYearlyRetentionYears
          durationType: 'Years'
        }
      }
    }
    timeZone: 'UTC'
    tieringPolicy: {
      ArchivedRP: {
        tieringMode: 'TierAfter'
        duration: 3
        durationType: 'Months'
      }
    }
  }
}

// ============================================================================
// Resources - SQL Backup Policy
// ============================================================================

@description('SQL database backup policy')
resource sqlBackupPolicy 'Microsoft.RecoveryServices/vaults/backupPolicies@2023-06-01' = if (createDefaultSqlPolicy) {
  parent: recoveryServicesVault
  name: 'policy-sql-default'
  properties: {
    backupManagementType: 'AzureWorkload'
    workLoadType: 'SQLDataBase'
    settings: {
      timeZone: 'UTC'
      issqlcompression: true
      isCompression: true
    }
    subProtectionPolicy: [
      {
        policyType: 'Full'
        schedulePolicy: {
          schedulePolicyType: 'SimpleSchedulePolicy'
          scheduleRunFrequency: 'Weekly'
          scheduleRunDays: [
            'Sunday'
          ]
          scheduleRunTimes: [
            '2024-01-01T02:00:00Z'
          ]
          scheduleWeeklyFrequency: 0
        }
        retentionPolicy: {
          retentionPolicyType: 'LongTermRetentionPolicy'
          weeklySchedule: {
            daysOfTheWeek: [
              'Sunday'
            ]
            retentionTimes: [
              '2024-01-01T02:00:00Z'
            ]
            retentionDuration: {
              count: 12
              durationType: 'Weeks'
            }
          }
          monthlySchedule: {
            retentionScheduleFormatType: 'Weekly'
            retentionScheduleWeekly: {
              daysOfTheWeek: [
                'Sunday'
              ]
              weeksOfTheMonth: [
                'First'
              ]
            }
            retentionTimes: [
              '2024-01-01T02:00:00Z'
            ]
            retentionDuration: {
              count: 12
              durationType: 'Months'
            }
          }
          yearlySchedule: {
            retentionScheduleFormatType: 'Weekly'
            monthsOfYear: [
              'January'
            ]
            retentionScheduleWeekly: {
              daysOfTheWeek: [
                'Sunday'
              ]
              weeksOfTheMonth: [
                'First'
              ]
            }
            retentionTimes: [
              '2024-01-01T02:00:00Z'
            ]
            retentionDuration: {
              count: 3
              durationType: 'Years'
            }
          }
        }
      }
      {
        policyType: 'Differential'
        schedulePolicy: {
          schedulePolicyType: 'SimpleSchedulePolicy'
          scheduleRunFrequency: 'Weekly'
          scheduleRunDays: [
            'Monday'
            'Tuesday'
            'Wednesday'
            'Thursday'
            'Friday'
            'Saturday'
          ]
          scheduleRunTimes: [
            '2024-01-01T02:00:00Z'
          ]
          scheduleWeeklyFrequency: 0
        }
        retentionPolicy: {
          retentionPolicyType: 'SimpleRetentionPolicy'
          retentionDuration: {
            count: 30
            durationType: 'Days'
          }
        }
      }
      {
        policyType: 'Log'
        schedulePolicy: {
          schedulePolicyType: 'LogSchedulePolicy'
          scheduleFrequencyInMins: 60
        }
        retentionPolicy: {
          retentionPolicyType: 'SimpleRetentionPolicy'
          retentionDuration: {
            count: 15
            durationType: 'Days'
          }
        }
      }
    ]
  }
}

// ============================================================================
// Resources - File Share Backup Policy
// ============================================================================

@description('Azure File Share backup policy')
resource fileShareBackupPolicy 'Microsoft.RecoveryServices/vaults/backupPolicies@2023-06-01' = if (createDefaultFileSharePolicy) {
  parent: recoveryServicesVault
  name: 'policy-fileshare-default'
  properties: {
    backupManagementType: 'AzureStorage'
    workLoadType: 'AzureFileShare'
    schedulePolicy: {
      schedulePolicyType: 'SimpleSchedulePolicy'
      scheduleRunFrequency: 'Daily'
      scheduleRunTimes: [
        '2024-01-01T22:00:00Z'
      ]
      scheduleWeeklyFrequency: 0
    }
    retentionPolicy: {
      retentionPolicyType: 'LongTermRetentionPolicy'
      dailySchedule: {
        retentionTimes: [
          '2024-01-01T22:00:00Z'
        ]
        retentionDuration: {
          count: 30
          durationType: 'Days'
        }
      }
      weeklySchedule: {
        daysOfTheWeek: [
          'Sunday'
        ]
        retentionTimes: [
          '2024-01-01T22:00:00Z'
        ]
        retentionDuration: {
          count: 12
          durationType: 'Weeks'
        }
      }
      monthlySchedule: {
        retentionScheduleFormatType: 'Weekly'
        retentionScheduleWeekly: {
          daysOfTheWeek: [
            'Sunday'
          ]
          weeksOfTheMonth: [
            'First'
          ]
        }
        retentionTimes: [
          '2024-01-01T22:00:00Z'
        ]
        retentionDuration: {
          count: 12
          durationType: 'Months'
        }
      }
    }
    timeZone: 'UTC'
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('Recovery Services Vault name')
output vaultName string = recoveryServicesVault.name

@description('Recovery Services Vault resource ID')
output vaultId string = recoveryServicesVault.id

@description('Recovery Services Vault location')
output vaultLocation string = recoveryServicesVault.location

@description('System-assigned managed identity principal ID')
output identityPrincipalId string = recoveryServicesVault.identity.principalId

@description('VM backup policy ID')
output vmBackupPolicyId string = createDefaultVmPolicy ? vmBackupPolicy.id : ''

@description('VM backup policy name')
output vmBackupPolicyName string = createDefaultVmPolicy ? vmBackupPolicy.name : ''

@description('SQL backup policy ID')
output sqlBackupPolicyId string = createDefaultSqlPolicy ? sqlBackupPolicy.id : ''

@description('SQL backup policy name')
output sqlBackupPolicyName string = createDefaultSqlPolicy ? sqlBackupPolicy.name : ''

@description('File Share backup policy ID')
output fileShareBackupPolicyId string = createDefaultFileSharePolicy ? fileShareBackupPolicy.id : ''

@description('File Share backup policy name')
output fileShareBackupPolicyName string = createDefaultFileSharePolicy ? fileShareBackupPolicy.name : ''

@description('Storage redundancy type')
output storageRedundancy string = storageType

@description('Cross region restore enabled')
output crossRegionRestoreEnabled bool = enableCrossRegionRestore
