#!/bin/bash
#===============================================================================
# SCRIPT: create-rbac-assignments.sh
# SYNOPSIS: Create custom RBAC role definitions and assignments
# DESCRIPTION:
#   This script demonstrates Azure RBAC concepts including:
#   - Creating custom role definitions with specific permissions
#   - Assigning built-in and custom roles at different scopes
#   - Following least-privilege principle
#   - Understanding Actions, NotActions, DataActions, and NotDataActions
#
# AZ-305 EXAM OBJECTIVES:
#   - Design identity, governance, and monitoring solutions
#   - Implement Azure RBAC for resource access control
#   - Understand built-in vs custom roles
#   - Apply least-privilege principle
#   - Configure role assignments at different scopes
#
# PREREQUISITES:
#   - Azure CLI 2.50+ installed and authenticated
#   - User Access Administrator or Owner role at target scope
#   - Microsoft.Authorization resource provider registered
#
# EXAMPLES:
#   # Create custom roles and assignments
#   ./create-rbac-assignments.sh
#
#   # Create with specific scope
#   SCOPE_RESOURCE_GROUP="my-rg" ./create-rbac-assignments.sh
#
# REFERENCES:
#   - https://learn.microsoft.com/azure/role-based-access-control/custom-roles
#   - https://learn.microsoft.com/azure/role-based-access-control/role-assignments-cli
#===============================================================================

set -euo pipefail

#-------------------------------------------------------------------------------
# CONFIGURATION
#-------------------------------------------------------------------------------
LOCATION="${LOCATION:-eastus}"
PREFIX="${PREFIX:-az305}"
RESOURCE_GROUP="${RESOURCE_GROUP:-${PREFIX}-rbac-rg}"
SCOPE_RESOURCE_GROUP="${SCOPE_RESOURCE_GROUP:-$RESOURCE_GROUP}"

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
# SETUP
#-------------------------------------------------------------------------------
setup_environment() {
    log_info "Setting up environment..."

    # Create resource group for demonstration
    az group create \
        --name "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --tags "Environment=Development" "Purpose=AZ305-RBAC" \
        --output none

    # Get subscription ID
    SUBSCRIPTION_ID=$(az account show --query id --output tsv)

    log_success "Environment setup complete"
}

#-------------------------------------------------------------------------------
# CREATE CUSTOM ROLE: VM OPERATOR
#-------------------------------------------------------------------------------
create_vm_operator_role() {
    log_info "Creating custom role: VM Operator..."

    # WHY: This role allows starting/stopping VMs without full Contributor access
    # This follows the principle of least privilege
    # - Actions: What the role CAN do
    # - NotActions: Exceptions to Actions (cannot do)
    # - DataActions: Data plane operations (e.g., blob access)
    # - AssignableScopes: Where this role can be assigned

    role_name="VM Operator - ${PREFIX}"

    # Check if role already exists
    existing_role=$(az role definition list \
        --name "$role_name" \
        --query "[0].name" \
        --output tsv 2>/dev/null || echo "")

    if [ -z "$existing_role" ]; then
        # Create the role definition JSON
        cat > /tmp/vm-operator-role.json << EOF
{
    "Name": "$role_name",
    "Description": "Can start, stop, and restart virtual machines. Cannot create, delete, or modify VM configuration.",
    "Actions": [
        "Microsoft.Compute/virtualMachines/start/action",
        "Microsoft.Compute/virtualMachines/powerOff/action",
        "Microsoft.Compute/virtualMachines/restart/action",
        "Microsoft.Compute/virtualMachines/read",
        "Microsoft.Compute/virtualMachines/instanceView/read",
        "Microsoft.Network/networkInterfaces/read",
        "Microsoft.Network/publicIPAddresses/read",
        "Microsoft.Resources/subscriptions/resourceGroups/read"
    ],
    "NotActions": [],
    "DataActions": [],
    "NotDataActions": [],
    "AssignableScopes": [
        "/subscriptions/$SUBSCRIPTION_ID"
    ]
}
EOF

        az role definition create \
            --role-definition /tmp/vm-operator-role.json \
            --output none

        log_success "Custom role 'VM Operator' created"
    else
        log_info "Custom role 'VM Operator' already exists"
    fi
}

#-------------------------------------------------------------------------------
# CREATE CUSTOM ROLE: STORAGE BLOB READER (NO DELETE)
#-------------------------------------------------------------------------------
create_storage_reader_role() {
    log_info "Creating custom role: Storage Blob Reader (No Delete)..."

    # WHY: Allow reading blobs but prevent deletion
    # Uses NotDataActions to explicitly deny delete operations
    # DataActions are used for data plane operations on storage

    role_name="Storage Blob Reader No Delete - ${PREFIX}"

    existing_role=$(az role definition list \
        --name "$role_name" \
        --query "[0].name" \
        --output tsv 2>/dev/null || echo "")

    if [ -z "$existing_role" ]; then
        cat > /tmp/storage-reader-role.json << EOF
{
    "Name": "$role_name",
    "Description": "Can read storage blobs but cannot delete them. Useful for audit scenarios.",
    "Actions": [
        "Microsoft.Storage/storageAccounts/blobServices/containers/read",
        "Microsoft.Storage/storageAccounts/blobServices/read",
        "Microsoft.Storage/storageAccounts/read"
    ],
    "NotActions": [],
    "DataActions": [
        "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read"
    ],
    "NotDataActions": [
        "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/delete",
        "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/write"
    ],
    "AssignableScopes": [
        "/subscriptions/$SUBSCRIPTION_ID"
    ]
}
EOF

        az role definition create \
            --role-definition /tmp/storage-reader-role.json \
            --output none

        log_success "Custom role 'Storage Blob Reader (No Delete)' created"
    else
        log_info "Custom role 'Storage Blob Reader (No Delete)' already exists"
    fi
}

#-------------------------------------------------------------------------------
# CREATE CUSTOM ROLE: COST VIEWER
#-------------------------------------------------------------------------------
create_cost_viewer_role() {
    log_info "Creating custom role: Cost Viewer..."

    # WHY: Allow viewing cost data without access to modify resources
    # Useful for finance teams who need to monitor cloud spending

    role_name="Cost Viewer - ${PREFIX}"

    existing_role=$(az role definition list \
        --name "$role_name" \
        --query "[0].name" \
        --output tsv 2>/dev/null || echo "")

    if [ -z "$existing_role" ]; then
        cat > /tmp/cost-viewer-role.json << EOF
{
    "Name": "$role_name",
    "Description": "Can view cost and usage data. Cannot modify any resources.",
    "Actions": [
        "Microsoft.Consumption/*/read",
        "Microsoft.CostManagement/*/read",
        "Microsoft.Billing/billingPeriods/read",
        "Microsoft.Resources/subscriptions/read",
        "Microsoft.Resources/subscriptions/resourceGroups/read",
        "Microsoft.Support/*"
    ],
    "NotActions": [],
    "DataActions": [],
    "NotDataActions": [],
    "AssignableScopes": [
        "/subscriptions/$SUBSCRIPTION_ID"
    ]
}
EOF

        az role definition create \
            --role-definition /tmp/cost-viewer-role.json \
            --output none

        log_success "Custom role 'Cost Viewer' created"
    else
        log_info "Custom role 'Cost Viewer' already exists"
    fi
}

#-------------------------------------------------------------------------------
# CREATE CUSTOM ROLE: KEY VAULT SECRETS USER
#-------------------------------------------------------------------------------
create_keyvault_secrets_role() {
    log_info "Creating custom role: Key Vault Secrets User..."

    # WHY: Allow reading secrets without management plane access
    # This separates operational access from administrative access

    role_name="Key Vault Secrets User - ${PREFIX}"

    existing_role=$(az role definition list \
        --name "$role_name" \
        --query "[0].name" \
        --output tsv 2>/dev/null || echo "")

    if [ -z "$existing_role" ]; then
        cat > /tmp/kv-secrets-role.json << EOF
{
    "Name": "$role_name",
    "Description": "Can read, list, and get secrets from Key Vault. Cannot create, update, or delete secrets.",
    "Actions": [
        "Microsoft.KeyVault/vaults/read",
        "Microsoft.KeyVault/vaults/secrets/read"
    ],
    "NotActions": [],
    "DataActions": [
        "Microsoft.KeyVault/vaults/secrets/getSecret/action",
        "Microsoft.KeyVault/vaults/secrets/readMetadata/action"
    ],
    "NotDataActions": [
        "Microsoft.KeyVault/vaults/secrets/setSecret/action",
        "Microsoft.KeyVault/vaults/secrets/delete"
    ],
    "AssignableScopes": [
        "/subscriptions/$SUBSCRIPTION_ID"
    ]
}
EOF

        az role definition create \
            --role-definition /tmp/kv-secrets-role.json \
            --output none

        log_success "Custom role 'Key Vault Secrets User' created"
    else
        log_info "Custom role 'Key Vault Secrets User' already exists"
    fi
}

#-------------------------------------------------------------------------------
# CREATE SAMPLE RESOURCES FOR ROLE ASSIGNMENT DEMONSTRATION
#-------------------------------------------------------------------------------
create_sample_resources() {
    log_info "Creating sample resources for role assignment demonstration..."

    # Create a storage account
    STORAGE_NAME="${PREFIX}rbacstore$(openssl rand -hex 4)"
    az storage account create \
        --name "$STORAGE_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --sku "Standard_LRS" \
        --kind "StorageV2" \
        --output none

    # Create a Key Vault
    KV_NAME="${PREFIX}-rbac-kv-$(openssl rand -hex 4)"
    az keyvault create \
        --name "$KV_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --enable-rbac-authorization true \
        --output none

    log_success "Sample resources created"
}

#-------------------------------------------------------------------------------
# DEMONSTRATE ROLE ASSIGNMENTS
#-------------------------------------------------------------------------------
demonstrate_role_assignments() {
    log_info "Demonstrating role assignments at different scopes..."

    # Get current user's object ID
    CURRENT_USER_ID=$(az ad signed-in-user show --query id --output tsv 2>/dev/null || echo "")

    if [ -z "$CURRENT_USER_ID" ]; then
        log_info "Could not get current user ID. Skipping user-based assignments."
        log_info "In production, you would assign roles to specific users, groups, or service principals."
    else
        # Demonstrate built-in role assignment at resource group scope
        log_info "Assigning 'Reader' role at resource group scope..."

        # Check if assignment already exists to make idempotent
        existing_assignment=$(az role assignment list \
            --assignee "$CURRENT_USER_ID" \
            --role "Reader" \
            --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP" \
            --query "[0].id" \
            --output tsv 2>/dev/null || echo "")

        if [ -z "$existing_assignment" ]; then
            az role assignment create \
                --assignee "$CURRENT_USER_ID" \
                --role "Reader" \
                --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP" \
                --output none
            log_success "Reader role assigned at resource group scope"
        else
            log_info "Reader role assignment already exists"
        fi
    fi

    # Display role assignment examples (without actually creating them)
    echo ""
    log_info "Role Assignment Examples (not executed - for reference):"
    echo ""
    echo "# Assign role to a user at subscription scope"
    echo "az role assignment create \\"
    echo "    --assignee \"user@example.com\" \\"
    echo "    --role \"Contributor\" \\"
    echo "    --scope \"/subscriptions/\$SUBSCRIPTION_ID\""
    echo ""
    echo "# Assign role to a group at resource group scope"
    echo "az role assignment create \\"
    echo "    --assignee \"<group-object-id>\" \\"
    echo "    --role \"Storage Blob Data Reader\" \\"
    echo "    --scope \"/subscriptions/\$SUBSCRIPTION_ID/resourceGroups/\$RESOURCE_GROUP\""
    echo ""
    echo "# Assign role to a service principal at resource scope"
    echo "az role assignment create \\"
    echo "    --assignee \"<service-principal-app-id>\" \\"
    echo "    --role \"Key Vault Secrets Officer\" \\"
    echo "    --scope \"/subscriptions/\$SUBSCRIPTION_ID/resourceGroups/\$RESOURCE_GROUP/providers/Microsoft.KeyVault/vaults/\$KV_NAME\""
    echo ""
    echo "# Assign custom role"
    echo "az role assignment create \\"
    echo "    --assignee \"<principal-id>\" \\"
    echo "    --role \"VM Operator - ${PREFIX}\" \\"
    echo "    --scope \"/subscriptions/\$SUBSCRIPTION_ID/resourceGroups/\$RESOURCE_GROUP\""
}

#-------------------------------------------------------------------------------
# DISPLAY SUMMARY
#-------------------------------------------------------------------------------
display_summary() {
    echo ""
    echo "==============================================================================="
    echo "                       RBAC CONFIGURATION SUMMARY"
    echo "==============================================================================="
    echo ""
    echo "Subscription ID: $SUBSCRIPTION_ID"
    echo "Resource Group: $RESOURCE_GROUP"
    echo ""
    echo "CUSTOM ROLES CREATED:"
    echo "-------------------------------------------------------------------------------"
    echo ""
    az role definition list \
        --custom-role-only true \
        --query "[?contains(roleName, '$PREFIX')].{Name:roleName, Description:description}" \
        --output table
    echo ""
    echo "ROLE DEFINITION DETAILS:"
    echo "-------------------------------------------------------------------------------"

    for role_name in "VM Operator - ${PREFIX}" "Storage Blob Reader No Delete - ${PREFIX}" "Cost Viewer - ${PREFIX}" "Key Vault Secrets User - ${PREFIX}"; do
        echo ""
        echo "Role: $role_name"
        az role definition list \
            --name "$role_name" \
            --query "[0].{Actions:permissions[0].actions, NotActions:permissions[0].notActions, DataActions:permissions[0].dataActions, NotDataActions:permissions[0].notDataActions}" \
            --output yaml 2>/dev/null || echo "  (Role not found)"
    done

    echo ""
    echo "EXISTING ROLE ASSIGNMENTS IN RESOURCE GROUP:"
    echo "-------------------------------------------------------------------------------"
    az role assignment list \
        --resource-group "$RESOURCE_GROUP" \
        --query "[].{Principal:principalName, Role:roleDefinitionName, Scope:scope}" \
        --output table
    echo ""
    echo "==============================================================================="
    echo "RBAC BEST PRACTICES:"
    echo "==============================================================================="
    echo ""
    echo "1. LEAST PRIVILEGE: Grant only the minimum permissions needed"
    echo "   - Use built-in roles when possible"
    echo "   - Create custom roles for specific scenarios"
    echo ""
    echo "2. SCOPE APPROPRIATELY:"
    echo "   - Assign at the narrowest scope possible"
    echo "   - Management Group > Subscription > Resource Group > Resource"
    echo ""
    echo "3. USE GROUPS OVER INDIVIDUALS:"
    echo "   - Assign roles to Azure AD groups"
    echo "   - Manage group membership separately"
    echo ""
    echo "4. REGULAR REVIEW:"
    echo "   - Use Access Reviews for periodic attestation"
    echo "   - Remove unused role assignments"
    echo ""
    echo "5. CONDITIONAL ACCESS:"
    echo "   - Combine RBAC with Conditional Access policies"
    echo "   - Require MFA for privileged roles"
    echo ""
    echo "6. PIM FOR PRIVILEGED ROLES:"
    echo "   - Use Privileged Identity Management for elevated roles"
    echo "   - Just-in-time activation reduces standing access"
    echo "==============================================================================="
}

#-------------------------------------------------------------------------------
# CLEANUP FUNCTION
#-------------------------------------------------------------------------------
cleanup_roles() {
    log_info "Cleaning up custom roles..."

    for role_name in "VM Operator - ${PREFIX}" "Storage Blob Reader No Delete - ${PREFIX}" "Cost Viewer - ${PREFIX}" "Key Vault Secrets User - ${PREFIX}"; do
        az role definition delete --name "$role_name" --output none 2>/dev/null || true
    done

    log_success "Custom roles cleaned up"
}

#-------------------------------------------------------------------------------
# MAIN
#-------------------------------------------------------------------------------
main() {
    log_info "Starting RBAC configuration..."

    # Parse arguments
    if [ "${1:-}" == "--cleanup" ]; then
        cleanup_roles
        exit 0
    fi

    setup_environment
    create_vm_operator_role
    create_storage_reader_role
    create_cost_viewer_role
    create_keyvault_secrets_role
    create_sample_resources
    demonstrate_role_assignments
    display_summary

    log_success "RBAC configuration completed successfully!"
    echo ""
    echo "To clean up custom roles, run: $0 --cleanup"
}

main "$@"
