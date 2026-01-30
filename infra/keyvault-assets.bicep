// ============================================================================
// Azure Key Vault Assets: Secrets, Keys, and Certificates
// ============================================================================
// Purpose: Deploy demo secrets, cryptographic keys, and certificates into an
//          EXISTING Key Vault to showcase the three asset types AZ-305
//          candidates must understand.
//
// AZ-305 Exam Objectives:
//   - Design a solution for managing secrets, keys, and certificates (2.4)
//   - Design authentication and authorization solutions (1.1)
//   - Design data encryption solutions (2.3)
//
// Deployment:
//   az deployment group create \
//     --resource-group <rg-name> \
//     --template-file keyvault-assets.bicep \
//     --parameters keyvault-assets.parameters.json
//
// Prerequisites:
//   - Key Vault must already exist (deploy keyvault-with-private-link.bicep first)
//   - Deploying principal needs "Key Vault Administrator" role on the vault
//   - Key Vault must use Azure RBAC authorization (not access policies)
//
// ============================================================================
// KEY VAULT ASSET TYPES - AZ-305 Teaching Notes
// ============================================================================
//
// SECRETS:
//   - Store arbitrary string values (connection strings, API keys, passwords)
//   - Maximum 25 KB per secret value
//   - Versioned: each update creates a new version
//   - RBAC role: "Key Vault Secrets User" (read) or "Key Vault Secrets Officer" (manage)
//   - Use case: App Service/Functions reference via @Microsoft.KeyVault() syntax
//   - Rotation: Use Event Grid + Azure Functions for automated rotation
//   - EXAM TIP: Secrets are the MOST COMMON asset type on AZ-305 scenarios
//
// KEYS:
//   - Cryptographic keys (RSA, EC) managed by Key Vault
//   - Key material NEVER leaves Key Vault boundary (operations happen server-side)
//   - Supports encrypt/decrypt, sign/verify, wrapKey/unwrapKey operations
//   - RBAC role: "Key Vault Crypto User" (use) or "Key Vault Crypto Officer" (manage)
//   - Use case: Azure Disk Encryption, TDE (SQL), Storage Service Encryption (CMK)
//   - Premium SKU required for HSM-backed keys (RSA-HSM, EC-HSM)
//   - EXAM TIP: Know the difference between software-protected vs HSM-protected keys
//
// CERTIFICATES:
//   - X.509 certificates with lifecycle management
//   - Internally stored as a KEY (public) + SECRET (private key + cert)
//   - Supports auto-renewal with integrated CAs (DigiCert, GlobalSign)
//   - Self-signed certificates available for dev/test
//   - RBAC role: "Key Vault Certificates Officer" (manage)
//   - Use case: TLS/SSL for App Service, API Management, Application Gateway
//   - EXAM TIP: Certificates combine keys + secrets; understand the relationship
//
// ============================================================================
// MANAGED IDENTITY ACCESS PATTERN
// ============================================================================
//
// How managed identities access Key Vault assets:
//
//   1. Enable system-assigned or user-assigned managed identity on the resource
//   2. Assign the appropriate Key Vault RBAC role to the identity's principal ID
//   3. Reference the vault URI in your application configuration
//   4. The Azure SDK (DefaultAzureCredential) handles token acquisition automatically
//
// Example for App Service:
//   - Enable system-assigned identity on the App Service
//   - Assign "Key Vault Secrets User" role to the App Service identity
//   - Use @Microsoft.KeyVault(VaultName=myvault;SecretName=mysecret) in app settings
//
// ============================================================================
// SOFT DELETE AND PURGE PROTECTION
// ============================================================================
//
// Soft delete (enabled by default, cannot be disabled on new vaults):
//   - Deleted assets are recoverable for the retention period (7-90 days)
//   - Deleted vault names are reserved during retention period
//   - EXAM TIP: You cannot reuse a vault name until the soft-deleted vault is purged
//
// Purge protection (recommended for production):
//   - Prevents permanent deletion during the retention period
//   - CANNOT be disabled once enabled
//   - Required for: Azure Disk Encryption, TDE with CMK, Always Encrypted
//   - EXAM TIP: Once purge protection is on, it stays on forever
//
// ============================================================================

targetScope = 'resourceGroup'

// ============================================================================
// Parameters
// ============================================================================

@description('Name of the EXISTING Key Vault to add assets to.')
@minLength(3)
@maxLength(24)
param keyVaultName string

// ---------------------------------------------------------------------------
// Secret Parameters
// ---------------------------------------------------------------------------

@description('Database connection string value. Use a secure parameter or Key Vault reference in production.')
@secure()
param databaseConnectionString string

@description('External API key value. Use a secure parameter or Key Vault reference in production.')
@secure()
param externalApiKey string

@description('Storage account key value. Use a secure parameter or Key Vault reference in production.')
@secure()
param storageAccountKey string

@description('Enable or disable secrets (demonstrates secret rotation by disabling old versions).')
param enableSecrets bool = true

@description('Number of days from now until secrets expire. Used to calculate expiration timestamps.')
@minValue(30)
@maxValue(730)
param secretExpiryDays int = 365

// ---------------------------------------------------------------------------
// Key Parameters
// ---------------------------------------------------------------------------

@description('Enable or disable the data encryption key.')
param enableDataEncryptionKey bool = true

@description('Enable or disable the signing key.')
param enableSigningKey bool = true

// ---------------------------------------------------------------------------
// Certificate Parameters
// ---------------------------------------------------------------------------

@description('Subject name for the TLS certificate (e.g., CN=contoso-app.azurewebsites.net).')
param certificateSubjectName string = 'CN=contoso-app.azurewebsites.net'

@description('Certificate validity in months.')
@minValue(1)
@maxValue(36)
param certificateValidityMonths int = 12

@description('Percentage of certificate lifetime at which to trigger auto-renewal (1-99).')
@minValue(1)
@maxValue(99)
param certificateRenewalPercentage int = 80

// ---------------------------------------------------------------------------
// Common Parameters
// ---------------------------------------------------------------------------

@description('Tags to apply to all Key Vault assets.')
param tags object = {
  environment: 'demo'
  purpose: 'az305-keyvault-assets'
  examObjective: 'AZ-305-Objective-2.4'
}

// ============================================================================
// Variables
// ============================================================================

// Calculate Unix timestamps for secret activation and expiration
// Note: dateTimeToEpoch requires a valid ISO 8601 string
param now int = dateTimeToEpoch(utcNow())
var secretActivationTime = now
var secretExpirationTime = now + (secretExpiryDays * 86400) // 86400 seconds per day

// Key expiration: 2 years from now
var keyExpirationTime = now + (730 * 86400)
var keyActivationTime = now

// ============================================================================
// Reference Existing Key Vault
// ============================================================================

@description('Reference to the existing Key Vault')
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

// ============================================================================
// SECRETS
// ============================================================================
// Secrets store sensitive string values like connection strings, API keys,
// and passwords. Applications retrieve them at runtime using the Key Vault
// SDK or App Service Key Vault references.
//
// Secret Rotation Patterns:
//   1. Manual: Update secret value, create new version, update app config
//   2. Semi-automated: Event Grid fires on SecretNearExpiry, triggers Function
//   3. Fully automated: Azure Function rotates secret on schedule + updates
//      the consuming service (e.g., regenerate Storage key, update secret)
//
// The enable/disable toggle below demonstrates how to implement rotation:
//   - Deploy new secret version (enabled)
//   - Disable the old version (applications fail over to new version)
//   - Old version remains for audit trail
// ============================================================================

@description('Database connection string secret - demonstrates storing structured credentials')
resource secretDatabaseConnectionString 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'app-database-connection-string'
  tags: union(tags, {
    assetType: 'secret'
    rotationSchedule: '90-days'
    rbacRole: 'Key Vault Secrets User'
  })
  properties: {
    contentType: 'application/x-connection-string'
    value: databaseConnectionString
    attributes: {
      enabled: enableSecrets
      nbf: secretActivationTime
      exp: secretExpirationTime
    }
  }
}

@description('External API key secret - demonstrates storing third-party credentials')
resource secretExternalApiKey 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'external-api-key'
  tags: union(tags, {
    assetType: 'secret'
    rotationSchedule: '180-days'
    rbacRole: 'Key Vault Secrets User'
  })
  properties: {
    contentType: 'text/plain'
    value: externalApiKey
    attributes: {
      enabled: enableSecrets
      nbf: secretActivationTime
      exp: secretExpirationTime
    }
  }
}

@description('Storage account key secret - demonstrates storing Azure service credentials')
resource secretStorageAccountKey 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'storage-account-key'
  tags: union(tags, {
    assetType: 'secret'
    rotationSchedule: '60-days'
    rbacRole: 'Key Vault Secrets User'
  })
  properties: {
    // TEACHING NOTE: In production, prefer managed identity over storing
    // storage account keys. This demo shows the pattern for services that
    // still require key-based authentication.
    contentType: 'text/plain'
    value: storageAccountKey
    attributes: {
      enabled: enableSecrets
      nbf: secretActivationTime
      exp: secretExpirationTime
    }
  }
}

// ============================================================================
// KEYS
// ============================================================================
// Cryptographic keys are used for encryption, decryption, signing, and
// verification. The key material never leaves Key Vault; all cryptographic
// operations are performed server-side.
//
// Key Types:
//   - RSA: Asymmetric encryption, key wrapping. Sizes: 2048, 3072, 4096 bits.
//   - EC: Elliptic curve for digital signatures. Curves: P-256, P-256K, P-384, P-521.
//   - RSA-HSM / EC-HSM: Hardware Security Module backed (Premium SKU only).
//
// Common AZ-305 Exam Scenarios:
//   - Customer-Managed Keys (CMK) for Storage Service Encryption -> RSA key
//   - Transparent Data Encryption (TDE) for Azure SQL -> RSA key
//   - Azure Disk Encryption -> RSA key
//   - Application-level digital signatures -> EC key
//   - Key wrapping for envelope encryption -> RSA key with wrapKey/unwrapKey
//
// Key Rotation Policy (available since API 2023-02-01):
//   - Automatic rotation based on time triggers
//   - Event Grid notification before expiry
//   - Works with CMK scenarios (Storage, SQL automatically pick up new version)
// ============================================================================

@description('RSA 2048-bit key for data encryption and key wrapping (envelope encryption pattern)')
resource keyDataEncryption 'Microsoft.KeyVault/vaults/keys@2023-07-01' = {
  parent: keyVault
  name: 'data-encryption-key'
  tags: union(tags, {
    assetType: 'key'
    keyType: 'RSA-2048'
    purpose: 'data-encryption'
    rbacRole: 'Key Vault Crypto User'
  })
  properties: {
    kty: 'RSA'
    keySize: 2048
    keyOps: [
      'encrypt'
      'decrypt'
      'wrapKey'
      'unwrapKey'
    ]
    attributes: {
      enabled: enableDataEncryptionKey
      nbf: keyActivationTime
      exp: keyExpirationTime
    }
    // Rotation policy: auto-rotate 2 months before expiry, notify 30 days before
    rotationPolicy: {
      attributes: {
        expiryTime: 'P2Y' // Key versions expire after 2 years
      }
      lifetimeActions: [
        {
          action: {
            type: 'rotate'
          }
          trigger: {
            timeBeforeExpiry: 'P2M' // Rotate 2 months before expiry
          }
        }
        {
          action: {
            type: 'notify'
          }
          trigger: {
            timeBeforeExpiry: 'P30D' // Notify 30 days before expiry
          }
        }
      ]
    }
  }
}

@description('EC P-256 key for digital signatures (compact, fast, ideal for JWT/token signing)')
resource keySigningKey 'Microsoft.KeyVault/vaults/keys@2023-07-01' = {
  parent: keyVault
  name: 'signing-key'
  tags: union(tags, {
    assetType: 'key'
    keyType: 'EC-P256'
    purpose: 'digital-signatures'
    rbacRole: 'Key Vault Crypto User'
  })
  properties: {
    kty: 'EC'
    curveName: 'P-256'
    keyOps: [
      'sign'
      'verify'
    ]
    attributes: {
      enabled: enableSigningKey
      nbf: keyActivationTime
      exp: keyExpirationTime
    }
    // TEACHING NOTE: EC keys use different rotation considerations than RSA.
    // EC P-256 provides ~128-bit security equivalent with much smaller key sizes
    // and faster operations than RSA 2048 (which provides ~112-bit security).
    rotationPolicy: {
      attributes: {
        expiryTime: 'P1Y' // Signing keys often have shorter lifetimes
      }
      lifetimeActions: [
        {
          action: {
            type: 'rotate'
          }
          trigger: {
            timeBeforeExpiry: 'P30D' // Rotate 30 days before expiry
          }
        }
        {
          action: {
            type: 'notify'
          }
          trigger: {
            timeBeforeExpiry: 'P14D' // Notify 14 days before expiry
          }
        }
      ]
    }
  }
}

// ============================================================================
// CERTIFICATES
// ============================================================================
// Certificates in Key Vault combine the lifecycle management of X.509
// certificates with the security of Key Vault storage. Internally, a
// certificate is stored as:
//   - A KEY resource (public key portion)
//   - A SECRET resource (private key + certificate chain in PFX/PEM format)
//
// This dual storage means:
//   - You can use the KEY for cryptographic operations (sign, verify)
//   - You can retrieve the SECRET to get the full certificate with private key
//   - RBAC for keys and secrets applies to the underlying key/secret
//
// Certificate Issuers:
//   - Self: Self-signed (dev/test only, not trusted by browsers)
//   - DigiCert: Integrated CA (auto-renewal with production certs)
//   - GlobalSign: Integrated CA (auto-renewal with production certs)
//   - Unknown: Manual enrollment (you complete CSR externally)
//
// Auto-Renewal:
//   - Configure lifetime action at X% of validity period
//   - Integrated CAs (DigiCert/GlobalSign) renew automatically
//   - Self-signed and "Unknown" issuers generate Event Grid events
//   - Use Event Grid + Logic Apps/Functions for custom renewal workflows
//
// AZ-305 Exam Scenarios:
//   - TLS for App Service custom domains -> certificate from Key Vault
//   - TLS termination at Application Gateway -> certificate from Key Vault
//   - Mutual TLS (mTLS) for API Management -> client certificate from Key Vault
//   - Code signing -> certificate with signing key usage
// ============================================================================

@description('Self-signed TLS certificate for demo (shows certificate lifecycle management)')
resource certificateAppTls 'Microsoft.KeyVault/vaults/certificates@2023-07-01' = {
  parent: keyVault
  name: 'app-tls-certificate'
  tags: union(tags, {
    assetType: 'certificate'
    purpose: 'tls-termination'
    issuerType: 'Self'
    rbacRole: 'Key Vault Certificates Officer'
  })
  properties: {
    certificatePolicy: {
      issuerParameters: {
        // "Self" = self-signed certificate (dev/test only)
        // For production, use "DigiCert" or "GlobalSign" for auto-renewal
        // Use "Unknown" for manual enrollment with an external CA
        name: 'Self'
      }
      keyProperties: {
        // RSA 2048 is the minimum recommended for TLS certificates
        keyType: 'RSA'
        keySize: 2048
        exportable: true // Must be true for App Service / Application Gateway
        reuseKey: false  // Generate new key pair on renewal for better security
      }
      secretProperties: {
        // PFX format includes private key (required for most Azure services)
        // PEM format is an alternative for Linux-based services
        contentType: 'application/x-pkcs12'
      }
      x509CertificateProperties: {
        subject: certificateSubjectName
        subjectAlternativeNames: {
          dnsNames: [
            // Add SANs (Subject Alternative Names) for additional hostnames
            replace(replace(certificateSubjectName, 'CN=', ''), 'cn=', '')
          ]
        }
        keyUsage: [
          'digitalSignature'
          'keyEncipherment'
        ]
        extendedKeyUsage: [
          '1.3.6.1.5.5.7.3.1' // TLS Web Server Authentication (serverAuth)
        ]
        validityInMonths: certificateValidityMonths
      }
      lifetimeActions: [
        {
          // Auto-renew when certificate reaches 80% of its lifetime
          // For a 12-month cert, this triggers renewal at ~9.6 months
          trigger: {
            lifetimePercentage: certificateRenewalPercentage
          }
          action: {
            // "AutoRenew" for Self and integrated CAs
            // "EmailContacts" for Unknown issuer (manual process)
            actionType: 'AutoRenew'
          }
        }
      ]
    }
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('Key Vault name (for reference in subsequent deployments)')
output keyVaultName string = keyVault.name

@description('Key Vault URI (applications use this to connect)')
output keyVaultUri string = keyVault.properties.vaultUri

// Secret outputs (URIs only, never output secret VALUES)
@description('Database connection string secret URI (use this in app configuration)')
output databaseConnectionStringSecretUri string = secretDatabaseConnectionString.properties.secretUri

@description('External API key secret URI')
output externalApiKeySecretUri string = secretExternalApiKey.properties.secretUri

@description('Storage account key secret URI')
output storageAccountKeySecretUri string = secretStorageAccountKey.properties.secretUri

// Key outputs
@description('Data encryption key URI (use this for CMK configuration)')
output dataEncryptionKeyUri string = keyDataEncryption.properties.keyUri

@description('Data encryption key ID (includes version, for explicit version pinning)')
output dataEncryptionKeyUriWithVersion string = keyDataEncryption.properties.keyUriWithVersion

@description('Signing key URI')
output signingKeyUri string = keySigningKey.properties.keyUri

// Certificate output
@description('TLS certificate secret ID (use this to bind certificate to App Service or Application Gateway)')
output tlsCertificateSecretId string = certificateAppTls.properties.secretId

// ---------------------------------------------------------------------------
// App Service Key Vault Reference Format (for teaching)
// ---------------------------------------------------------------------------
// Use these formats in App Service / Azure Functions application settings:
//
// Latest version (auto-rotates):
//   @Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=app-database-connection-string)
//
// Specific version (pinned, does NOT auto-rotate):
//   @Microsoft.KeyVault(SecretUri=https://${keyVaultName}.vault.azure.net/secrets/app-database-connection-string/<version>)
//
// ---------------------------------------------------------------------------

@description('App Service Key Vault reference format for the database connection string (latest version)')
output appServiceSecretReference string = '@Microsoft.KeyVault(VaultName=${keyVault.name};SecretName=app-database-connection-string)'

// ---------------------------------------------------------------------------
// RBAC Role Summary (for teaching)
// ---------------------------------------------------------------------------
// Role Name                          | ID                                   | Scope
// -----------------------------------|--------------------------------------|------------------
// Key Vault Administrator            | 00482a5a-887f-4fb3-b363-3b7fe8e74483 | Full control
// Key Vault Secrets User             | 4633458b-17de-408a-b874-0445c86b69e6 | Read secrets
// Key Vault Secrets Officer          | b86a8fe4-44ce-4948-aee5-eccb2c155cd7 | Manage secrets
// Key Vault Crypto User              | 12338af0-0e69-4776-bea7-57ae8d297424 | Use keys
// Key Vault Crypto Officer           | 14b46e9e-c2b7-41b4-b07b-48a6ebf60603 | Manage keys
// Key Vault Certificates Officer     | a4417e6f-fecd-4de8-b567-7b0420556985 | Manage certs
// Key Vault Crypto Service Enc User  | e147488a-f6f5-4113-8e2d-b22465e65bf6 | CMK encryption
// ---------------------------------------------------------------------------
