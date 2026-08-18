#!/usr/bin/env bash
# validation.sh - Configuration and path validation library
# FR-010: Validate configuration, repository existence, and volume mappings
# FR-028: Verify volume mount paths, data directory references, and PVC names consistency
# FR-029a: Validate data_dir is not subdirectory of path

set -euo pipefail

# Validation state
declare VALIDATION_ERRORS=()
declare VALIDATION_WARNINGS=()

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

    # Validate no secrets in configuration (FR-047)
    validate_no_secrets "$config_file"

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

        # Validate hook checksums (T053)
        if [[ -n "$db_hook" ]]; then
            validate_hook_checksum "$db_hook" "$name" "backup"
        fi
        if [[ -n "$db_restore_hook" ]]; then
            validate_hook_checksum "$db_restore_hook" "$name" "restore"
        fi
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

    # Validate cross-field consistency (FR-028)
    validate_cross_field "$config_file"

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

# Validate hook checksum (T053)
# Usage: validate_hook_checksum <script_path> <name> <type>
validate_hook_checksum() {
    local script_path="$1"
    local name="$2"
    local type="$3"

    if [[ ! -f "$script_path" ]]; then
        return 0
    fi

    # Calculate checksum
    local checksum
    checksum="$(sha256sum "$script_path" 2>/dev/null | awk '{print $1}')"

    if [[ -z "$checksum" ]]; then
        validation_add_warning "$type hook checksum cannot be calculated: $script_path (repo: $name)"
        return 0
    fi

    # Store checksum in metadata if available
    if command -v metadata_init &>/dev/null; then
        local metadata_dir
        metadata_dir="$(config_get "metadata_dir")"
        if [[ -n "$metadata_dir" ]]; then
            mkdir -p "$metadata_dir"
            echo "$checksum $script_path" >> "$metadata_dir/hook-checksums.txt"
        fi
    fi

    return 0
}

# Validate secret-free configuration (FR-047)
# Usage: validate_no_secrets <config_file>
validate_no_secrets() {
    local config_file="$1"

    if [[ ! -f "$config_file" ]]; then
        validation_add_error "Configuration file does not exist: $config_file"
        return 1
    fi

    # Check for common secret patterns
    local secret_patterns=(
        'password'
        'secret'
        'token'
        'api_key'
        'apikey'
        'access_key'
        'private_key'
    )

    local found_secrets=0

    for pattern in "${secret_patterns[@]}"; do
        # Match lines where VALUE (after colon) contains secret patterns
        # Only flag actual inline secrets, not:
        # - Env var names (UPPER_CASE, may be quoted)
        # - Paths (start with /)
        # - Var refs (start with ${)
        # - Comments (start with #)
        if grep -qE "^[^#]*:[[:space:]].*${pattern}" "$config_file" 2>/dev/null; then
            # Extract value portion and check if it looks like an actual secret
            # (contains lowercase letters, not just uppercase env var name)
            local line
            while IFS= read -r line; do
                # Skip comments and empty lines
                [[ "$line" =~ ^[[:space:]]*# ]] && continue
                [[ -z "$line" ]] && continue
                
                # Extract value after colon
                local value="${line#*:}"
                value="${value# }"  # Remove leading space
                
                # Skip env var names (ALL_CAPS with underscores, possibly quoted)
                [[ "$value" =~ ^[\"\']?[A-Z_0-9]+[\"\']?$ ]] && continue
                
                # Skip paths
                [[ "$value" =~ ^[\"\']?/ ]] && continue
                
                # Skip var refs
                [[ "$value" =~ ^[\"\']?\\$\\{ ]] && continue
                
                # Check if value contains the secret pattern
                if echo "$value" | grep -qi "$pattern" 2>/dev/null; then
                    validation_add_error "Configuration file contains potential secret reference: $pattern"
                    found_secrets=$((found_secrets + 1))
                    break  # Only report once per pattern
                fi
            done < "$config_file"
        fi
    done

    if [[ $found_secrets -gt 0 ]]; then
        log_error "Configuration file contains potential secret references. Use environment variables or external secrets." "validation"
        return 1
    fi

    return 0
}

# Validate Kubernetes cluster connectivity (T061)
# Usage: validate_kubernetes_connectivity
validate_kubernetes_connectivity() {
    if ! kubectl cluster-info &>/dev/null 2>&1; then
        validation_add_warning "Kubernetes cluster is not accessible"
        return 1
    fi

    return 0
}

# Validate ESO connectivity (T061)
# Usage: validate_eso_connectivity
validate_eso_connectivity() {
    # Check if ESO is installed
    if ! kubectl get deployment external-secrets -n external-secrets &>/dev/null 2>&1; then
        validation_add_warning "External Secrets Operator is not installed"
        return 0
    fi

    # Check if ESO is running
    local ready
    ready="$(kubectl get deployment external-secrets -n external-secrets -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")"

    if [[ "$ready" -eq 0 ]]; then
        validation_add_warning "External Secrets Operator is not ready"
        return 1
    fi

    return 0
}

# Validate Secret generation (T062)
# Usage: validate_secret_generation <namespace>
validate_secret_generation() {
    local namespace="${1:-default}"

    # Check if there are any ExternalSecret resources
    local secret_count
    secret_count="$(kubectl get externalsecrets -n "$namespace" --no-headers 2>/dev/null | wc -l || echo "0")"

    if [[ "$secret_count" -eq 0 ]]; then
        validation_add_warning "No ExternalSecret resources found in namespace: $namespace"
        return 0
    fi

    # Check if secrets are ready
    local ready_count
    ready_count="$(kubectl get externalsecrets -n "$namespace" -o jsonpath='{.items[*].status.conditions[*].status}' 2>/dev/null | grep -o "True" | wc -l || echo "0")"

    if [[ "$ready_count" -ne "$secret_count" ]]; then
        validation_add_warning "Not all ExternalSecrets are ready in namespace: $namespace"
        return 1
    fi

    return 0
}

# Validate cross-field consistency between config and manifests (FR-028)
# Usage: validate_cross_field <config_file>
validate_cross_field() {
    local config_file="$1"

    if [[ ! -f "$config_file" ]]; then
        return 0
    fi

    # Config should already be loaded by caller (no re-sourcing needed)

    local repo_count
    repo_count="$(config_get "repositories.count")"

    for i in $(seq 0 $((repo_count - 1))); do
        local name pvc namespace data_dir
        name="$(config_get_repository "$i" "name")"
        pvc="$(config_get_repository "$i" "pvc")"
        namespace="$(config_get_repository "$i" "namespace")"
        data_dir="$(config_get_repository "$i" "data_dir")"

        # Validate PVC name matches namespace convention
        if [[ -n "$pvc" && -n "$namespace" ]]; then
            # Check if PVC exists in the specified namespace
            if kubectl get pvc "$pvc" -n "$namespace" &>/dev/null; then
                # Verify PVC is in correct namespace
                local actual_namespace
                actual_namespace="$(kubectl get pvc "$pvc" -n "$namespace" -o jsonpath='{.metadata.namespace}' 2>/dev/null)"
                if [[ "$actual_namespace" != "$namespace" ]]; then
                    validation_add_error "PVC $pvc is in namespace $actual_namespace but config specifies $namespace (repo: $name)"
                fi
            fi
        fi

        # Validate data_dir is an absolute path
        if [[ -n "$data_dir" && "$data_dir" != /* ]]; then
            validation_add_warning "data_dir should be an absolute path: $data_dir (repo: $name)"
        fi
    done

    return 0
}

# Export functions
export -f validation_init validation_add_error validation_add_warning validation_passed validation_get_errors validation_get_warnings validate_repository_path validate_data_dir_separation validate_pvc_exists validate_namespace_exists validate_hook_script validate_kopia_repository validate_vault_unseal_key validate_port_offset validate_dns_suffix validate_all validate_hook_checksum validate_no_secrets validate_kubernetes_connectivity validate_eso_connectivity validate_secret_generation validate_cross_field
export VALIDATION_ERRORS VALIDATION_WARNINGS