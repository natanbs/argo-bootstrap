#!/usr/bin/env bash
# vault.sh - HashiCorp Vault operations library
# FR-006: Backup Vault configuration, policies, auth, and Raft snapshots
# FR-030: Auto-unseal using stored unseal key
# FR-031: Protect unseal key with restrictive permissions (0600)

set -euo pipefail

# Vault state
declare VAULT_NAMESPACE="vault"
declare VAULT_UNSEAL_KEY_PATH=""

# Initialize Vault wrapper
# Usage: vault_init <namespace> [unseal_key_path]
vault_init() {
    local namespace="$1"
    local unseal_key_path="${2:-}"

    if ! command -v vault &>/dev/null; then
        error_report "E015" "Vault is not installed" "vault" "Install Vault: https://www.vaultproject.io/docs/installation"
        return 1
    fi

    VAULT_NAMESPACE="$namespace"
    VAULT_UNSEAL_KEY_PATH="$unseal_key_path"
}

# Check if Vault is running and accessible
# Usage: vault_is_running
vault_is_running() {
    vault status -namespace "$VAULT_NAMESPACE" &>/dev/null
}

# Check if Vault is sealed
# Usage: vault_is_sealed
vault_is_sealed() {
    local status
    status="$(vault status -namespace "$VAULT_NAMESPACE" -format=json 2>/dev/null || echo '{"sealed":true}')"
    echo "$status" | jq -r '.sealed'
}

# Get Vault status
# Usage: vault_status
vault_status() {
    vault status -namespace "$VAULT_NAMESPACE" -format=json
}

# Save Vault snapshot
# Usage: vault_save_snapshot <output_path>
vault_save_snapshot() {
    local output_path="$1"

    if ! vault_is_running; then
        error_report "E011" "Vault is not running" "vault" "Start Vault server"
        return 1
    fi

    if [[ "$(vault_is_sealed)" == "true" ]]; then
        error_report "E012" "Vault is sealed" "vault" "Unseal Vault first"
        return 1
    fi

    vault operator raft snapshot save "$output_path" -namespace "$VAULT_NAMESPACE"
}

# Restore Vault from snapshot
# Usage: vault_restore_snapshot <snapshot_path>
vault_restore_snapshot() {
    local snapshot_path="$1"

    if [[ ! -f "$snapshot_path" ]]; then
        error_report "E005" "Snapshot file not found: $snapshot_path" "vault" "Verify snapshot path"
        return 1
    fi

    if ! vault_is_running; then
        error_report "E011" "Vault is not running" "vault" "Start Vault server"
        return 1
    fi

    vault operator raft snapshot restore "$snapshot_path" -namespace "$VAULT_NAMESPACE" -force
}

# Auto-unseal Vault using stored key
# Usage: vault_auto_unseal
vault_auto_unseal() {
    if [[ -z "$VAULT_UNSEAL_KEY_PATH" ]]; then
        error_report "E013" "Vault unseal key path not configured" "vault" "Set vault.unseal_key_path in backup-config.yml"
        return 1
    fi

    if [[ ! -f "$VAULT_UNSEAL_KEY_PATH" ]]; then
        error_report "E013" "Vault unseal key not found: $VAULT_UNSEAL_KEY_PATH" "vault" "Create unseal key file or update vault.unseal_key_path"
        return 1
    fi

    # Check permissions
    local perms
    perms="$(stat -f "%Lp" "$VAULT_UNSEAL_KEY_PATH" 2>/dev/null || stat -c "%a" "$VAULT_UNSEAL_KEY_PATH" 2>/dev/null)"

    if [[ "$perms" != "600" ]]; then
        error_report "E014" "Unseal key has wrong permissions: $perms (expected 600)" "vault" "Fix permissions: chmod 600 $VAULT_UNSEAL_KEY_PATH"
        return 1
    fi

    local unseal_key
    unseal_key="$(cat "$VAULT_UNSEAL_KEY_PATH")"

    vault operator unseal "$unseal_key" -namespace "$VAULT_NAMESPACE"
}

# Save Vault policies
# Usage: vault_save_policies <output_dir>
vault_save_policies() {
    local output_dir="$1"

    mkdir -p "$output_dir"

    local policies
    policies="$(vault policy list -namespace "$VAULT_NAMESPACE" -format=json)"

    echo "$policies" | jq -r '.[]' | while read -r policy; do
        if [[ "$policy" != "default" && "$policy" != "root" ]]; then
            vault policy read "$policy" -namespace "$VAULT_NAMESPACE" > "$output_dir/$policy.hcl"
        fi
    done
}

# Restore Vault policies
# Usage: vault_restore_policies <input_dir>
vault_restore_policies() {
    local input_dir="$1"

    if [[ ! -d "$input_dir" ]]; then
        echo "Warning: Policy directory not found: $input_dir" >&2
        return 0
    fi

    for policy_file in "$input_dir"/*.hcl; do
        [[ -f "$policy_file" ]] || continue

        local policy_name
        policy_name="$(basename "$policy_file" .hcl)"

        vault policy write "$policy_name" "$policy_file" -namespace "$VAULT_NAMESPACE"
    done
}

# Save Vault auth methods
# Usage: vault_save_auth <output_dir>
vault_save_auth() {
    local output_dir="$1"

    mkdir -p "$output_dir"

    local auth
    auth="$(vault auth list -namespace "$VAULT_NAMESPACE" -format=json)"

    echo "$auth" | jq -r 'to_entries[] | select(.key != "token/") | .key' | while read -r mount; do
        local auth_type
        auth_type="$(echo "$auth" | jq -r --arg key "$mount" '.[$key].type')"

        vault read -namespace "$VAULT_NAMESPACE" "sys/auth/$mount" > "$output_dir/$mount.json" 2>/dev/null || true
    done
}

# Restore Vault auth methods
# Usage: vault_restore_auth <input_dir>
vault_restore_auth() {
    local input_dir="$1"

    if [[ ! -d "$input_dir" ]]; then
        echo "Warning: Auth directory not found: $input_dir" >&2
        return 0
    fi

    # Note: Auth method restoration is complex and may require manual intervention
    echo "Warning: Auth method restoration may require manual verification" >&2
}

# Get Vault Kubernetes auth config
# Usage: vault_get_kubernetes_auth
vault_get_kubernetes_auth() {
    vault read -namespace "$VAULT_NAMESPACE" sys/auth/kubernetes/config -format=json 2>/dev/null || echo "{}"
}

# Verify Vault health
# Usage: vault_verify_health
vault_verify_health() {
    if ! vault_is_running; then
        return 1
    fi

    if [[ "$(vault_is_sealed)" == "true" ]]; then
        return 1
    fi

    # Try a simple read operation
    vault token lookup -namespace "$VAULT_NAMESPACE" &>/dev/null
}

# Check Vault connectivity
# Usage: vault_check_connectivity
vault_check_connectivity() {
    if ! command -v vault &>/dev/null; then
        return 1
    fi

    if ! vault_is_running; then
        return 1
    fi

    # Try to get status
    vault status -namespace "$VAULT_NAMESPACE" &>/dev/null
}

# Get Vault version
# Usage: vault_get_version
vault_get_version() {
    vault version 2>/dev/null | head -1
}

# Check if Vault has Raft storage
# Usage: vault_has_raft
vault_has_raft() {
    vault status -namespace "$VAULT_NAMESPACE" -format=json 2>/dev/null | jq -r '.storage_type == "raft"' 2>/dev/null || echo "false"
}

# Export functions
export -f vault_init vault_is_running vault_is_sealed vault_status vault_save_snapshot vault_restore_snapshot vault_auto_unseal vault_save_policies vault_restore_policies vault_save_auth vault_restore_auth vault_get_kubernetes_auth vault_verify_health vault_check_connectivity vault_get_version vault_has_raft
export VAULT_NAMESPACE VAULT_UNSEAL_KEY_PATH