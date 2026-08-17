#!/usr/bin/env bash
# validation.sh - Configuration and path validation library
# FR-010: Validate configuration, repository existence, and volume mappings
# FR-028: Verify volume mount paths, data directory references, and PVC names consistency
# FR-029a: Validate data_dir is not subdirectory of path

set -euo pipefail

# Validation state
declare -g VALIDATION_ERRORS=()
declare -g VALIDATION_WARNINGS=()

# Initialize validation
validation_init() {
    VALIDATION_ERRORS=()
    VALIDATION_WARNINGS=()
}

# Add validation error
# Usage: validation_add_error <message>
validation_add_error() {
    local message="$1"
    VALIDATION_ERRORS+=("$message")
}

# Add validation warning
# Usage: validation_add_warning <message>
validation_add_warning() {
    local message="$1"
    VALIDATION_WARNINGS+=("$message")
}

# Check if validation passed
# Usage: validation_passed
validation_passed() {
    [[ ${#VALIDATION_ERRORS[@]} -eq 0 ]]
}

# Get validation errors
# Usage: validation_get_errors
validation_get_errors() {
    for error in "${VALIDATION_ERRORS[@]}"; do
        echo "$error"
    done
}

# Get validation warnings
# Usage: validation_get_warnings
validation_get_warnings() {
    for warning in "${VALIDATION_WARNINGS[@]}"; do
        echo "$warning"
    done
}

# Validate repository path exists
# Usage: validate_repository_path <path> <name>
validate_repository_path() {
    local path="$1"
    local name="$2"

    if [[ ! -d "$path" ]]; then
        validation_add_error "Repository path does not exist: $path (repo: $name)"
        return 1
    fi

    if [[ ! -r "$path" ]]; then
        validation_add_error "Repository path is not readable: $path (repo: $name)"
        return 1
    fi

    return 0
}

# Validate data_dir is not subdirectory of path (FR-029a)
# Usage: validate_data_dir_separation <path> <data_dir> <name>
validate_data_dir_separation() {
    local path="$1"
    local data_dir="$2"
    local name="$3"

    if [[ "$data_dir" == "$path"* ]]; then
        validation_add_error "data_dir must not be a subdirectory of path (FR-029a): $data_dir is inside $path (repo: $name)"
        return 1
    fi

    return 0
}

# Validate PVC exists in namespace
# Usage: validate_pvc_exists <pvc> <namespace>
validate_pvc_exists() {
    local pvc="$1"
    local namespace="$2"

    if ! kubectl get pvc "$pvc" -n "$namespace" &>/dev/null; then
        validation_add_warning "PVC does not exist: $pvc in namespace $namespace (will be created during restore)"
        return 0
    fi

    return 0
}

# Validate Kubernetes namespace exists
# Usage: validate_namespace_exists <namespace>
validate_namespace_exists() {
    local namespace="$1"

    if ! kubectl get namespace "$namespace" &>/dev/null; then
        validation_add_warning "Namespace does not exist: $namespace (will be created during restore)"
        return 0
    fi

    return 0
}

# Validate hook script exists and is executable
# Usage: validate_hook_script <script_path> <name> <type>
validate_hook_script() {
    local script_path="$1"
    local name="$2"
    local type="$3"

    if [[ -z "$script_path" ]]; then
        return 0
    fi

    if [[ ! -f "$script_path" ]]; then
        validation_add_error "$type hook script does not exist: $script_path (repo: $name)"
        return 1
    fi

    if [[ ! -x "$script_path" ]]; then
        validation_add_warning "$type hook script is not executable: $script_path (repo: $name)"
        return 0
    fi

    return 0
}

# Validate Kopia repository
# Usage: validate_kopia_repository <repo_path>
validate_kopia_repository() {
    local repo_path="$1"

    if [[ ! -d "$repo_path" ]]; then
        validation_add_warning "Kopia repository directory does not exist: $repo_path (will be created)"
        return 0
    fi

    # Check if repository is initialized
    if [[ ! -f "$repo_path/kopia.config" ]]; then
        validation_add_warning "Kopia repository is not initialized: $repo_path (will be initialized)"
        return 0
    fi

    return 0
}

# Validate Vault unseal key
# Usage: validate_vault_unseal_key <key_path>
validate_vault_unseal_key() {
    local key_path="$1"

    if [[ -z "$key_path" ]]; then
        return 0
    fi

    if [[ ! -f "$key_path" ]]; then
        validation_add_error "Vault unseal key does not exist: $key_path"
        return 1
    fi

    # Check permissions
    local perms
    perms="$(stat -f "%Lp" "$key_path" 2>/dev/null || stat -c "%a" "$key_path" 2>/dev/null || echo "000")"

    if [[ "$perms" != "600" ]]; then
        validation_add_warning "Vault unseal key has wrong permissions: $perms (expected 600)"
    fi

    return 0
}

# Validate port offset
# Usage: validate_port_offset <offset>
validate_port_offset() {
    local offset="$1"

    if ! [[ "$offset" =~ ^[0-9]+$ ]]; then
        validation_add_error "Port offset must be a non-negative integer: $offset"
        return 1
    fi

    if [[ "$offset" -gt 65000 ]]; then
        validation_add_error "Port offset out of range: $offset (max 65000)"
        return 1
    fi

    return 0
}

# Validate DNS suffix format
# Usage: validate_dns_suffix <suffix>
validate_dns_suffix() {
    local suffix="$1"

    if [[ -z "$suffix" ]]; then
        return 0
    fi

    if [[ "$suffix" != *"="* ]]; then
        validation_add_error "DNS suffix format invalid: $suffix (expected original=replacement)"
        return 1
    fi

    local original="${suffix%%=*}"
    local replacement="${suffix#*=}"

    if [[ -z "$original" || -z "$replacement" ]]; then
        validation_add_error "DNS suffix parts cannot be empty: $suffix"
        return 1
    fi

    return 0
}

# Validate all configuration
# Usage: validate_all <config_file>
validate_all() {
    local config_file="$1"

    validation_init

    # Validate configuration file exists
    if [[ ! -f "$config_file" ]]; then
        validation_add_error "Configuration file does not exist: $config_file"
        return 1
    fi

    # Source config library if not already loaded
    if ! command -v config_get &>/dev/null; then
        source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
        config_load "$config_file"
    fi

    # Validate repositories
    local repo_count
    repo_count="$(config_get "repositories.count")"

    for i in $(seq 0 $((repo_count - 1))); do
        local name path data_dir pvc namespace db_hook db_restore_hook
        name="$(config_get_repository "$i" "name")"
        path="$(config_get_repository "$i" "path")"
        data_dir="$(config_get_repository "$i" "data_dir")"
        pvc="$(config_get_repository "$i" "pvc")"
        namespace="$(config_get_repository "$i" "namespace")"
        db_hook="$(config_get_repository "$i" "db_hook")"
        db_restore_hook="$(config_get_repository "$i" "db_restore_hook")"

        validate_repository_path "$path" "$name"
        validate_data_dir_separation "$path" "$data_dir" "$name"
        validate_namespace_exists "$namespace"
        validate_pvc_exists "$pvc" "$namespace"
        validate_hook_script "$db_hook" "$name" "backup"
        validate_hook_script "$db_restore_hook" "$name" "restore"
    done

    # Validate Kopia
    local kopia_repo_path
    kopia_repo_path="$(config_get "kopia.repository_path")"
    validate_kopia_repository "$kopia_repo_path"

    # Validate Vault unseal key
    local vault_unseal_key
    vault_unseal_key="$(config_get "vault.unseal_key_path")"
    validate_vault_unseal_key "$vault_unseal_key"

    # Validate port offset
    local port_offset
    port_offset="$(config_get "port_offset")"
    validate_port_offset "$port_offset"

    # Validate DNS suffix
    local dns_suffix
    dns_suffix="$(config_get "dns_suffix")"
    validate_dns_suffix "$dns_suffix"

    # Report results
    if ! validation_passed; then
        echo "Validation failed with ${#VALIDATION_ERRORS[@]} errors:" >&2
        validation_get_errors >&2
        return 1
    fi

    if [[ ${#VALIDATION_WARNINGS[@]} -gt 0 ]]; then
        echo "Validation warnings:" >&2
        validation_get_warnings >&2
    fi

    return 0
}

# Export functions
export -f validation_init validation_add_error validation_add_warning validation_passed validation_get_errors validation_get_warnings validate_repository_path validate_data_dir_separation validate_pvc_exists validate_namespace_exists validate_hook_script validate_kopia_repository validate_vault_unseal_key validate_port_offset validate_dns_suffix validate_all
export VALIDATION_ERRORS VALIDATION_WARNINGS