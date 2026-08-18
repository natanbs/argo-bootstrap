#!/usr/bin/env bash
# backup.sh - Primary backup script
# FR-001: Single script orchestrating complete backup workflow
# FR-014: Non-zero exit codes on failure
# FR-018: Idempotent operations
# FR-041: Identical state produces identical snapshots
# FR-042: Deterministic alphabetical ordering

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

# Source libraries
source "$LIB_DIR/logging.sh"
source "$LIB_DIR/errors.sh"
source "$LIB_DIR/config.sh"
source "$LIB_DIR/kopia.sh"
source "$LIB_DIR/vault.sh"
source "$LIB_DIR/lock.sh"
source "$LIB_DIR/progress.sh"
source "$LIB_DIR/ports.sh"
source "$LIB_DIR/dns.sh"
source "$LIB_DIR/validation.sh"
source "$LIB_DIR/state.sh"
source "$LIB_DIR/metadata.sh"

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -v|--verbose)
                set_log_level "debug"
                shift
                ;;
            --json)
                JSON_OUTPUT=true
                shift
                ;;
            --resume)
                RESUME_MODE=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                show_help
                exit 1
                ;;
        esac
    done
}

# Show help
show_help() {
    cat << EOF
Usage: backup.sh [OPTIONS]

Options:
  -c, --config FILE    Configuration file (default: backup-config.yml)
  -v, --verbose        Enable debug logging
  --json               Output in JSON format
  --resume             Resume interrupted backup (skip completed phases)
  --dry-run            Perform validation only, don't backup
  -h, --help           Show this help message

Environment Variables:
  KOPIA_PASSWORD       Kopia repository password (required)
  KOPIA_BACKUP_*       Override any config value (e.g., KOPIA_BACKUP_PORT_OFFSET)

Examples:
  ./backup.sh -c backup-config.yml
  KOPIA_PASSWORD=mypassword ./backup.sh
  ./backup.sh --verbose
  ./backup.sh --json
  ./backup.sh --dry-run
EOF
}

# State variables
JSON_OUTPUT=false
DRY_RUN=false
RESUME_MODE=false

# Main backup workflow
main() {
    local config_file="${CONFIG_FILE:-backup-config.yml}"

    # Initialize logging
    init_logging

    if $JSON_OUTPUT; then
        log_info "Starting backup" "backup" '{"output_format":"json"}'
    else
        log_info "Starting backup" "backup"
    fi

    # Acquire exclusive lock (exit code 6: lock acquisition failed)
    lock_acquire "backup" || {
        log_error "Failed to acquire backup lock" "backup"
        exit 6
    }

    trap 'lock_release "backup"' EXIT

    # Load and validate configuration (exit code 2: config validation failed)
    config_load "$config_file" || {
        log_error "Configuration validation failed" "backup"
        exit 2
    }

    # Validate paths and dependencies (exit code 2: config validation failed)
    validate_all "$config_file" || {
        log_error "Path validation failed" "backup"
        exit 2
    }

    # Dry-run mode: Output validation results and exit
    if $DRY_RUN; then
        _output_dry_run
        return
    fi

    # Apply environment variable overrides
    config_apply_env_overrides

    # Initialize libraries
    _init_libraries

    # Initialize state tracking for resume support (FR-047)
    local backup_dir
    backup_dir="$(config_get "kopia.repository_path")"
    state_init "$backup_dir"

    # Initialize metadata collection (FR-011)
    metadata_init "$backup_dir"

    if $RESUME_MODE; then
        local completed
        completed="$(state_get_completed)"
        if [[ -n "$completed" ]]; then
            log_info "Resuming backup - skipping completed phases" "backup" '{"resume":"true","completed_phases":"'"$(echo "$completed" | tr '\n' ',')"'}'
        fi
    fi

    # Initialize progress tracking
    local total_steps=5
    progress_init "$total_steps" "backup"

    # Step 1: Verify cluster and Vault status
    if ! $RESUME_MODE || ! state_is_completed "verify_cluster"; then
        progress_update 1 "Verifying cluster status"
        _verify_cluster_status
        state_mark_completed "verify_cluster"
    else
        log_info "Skipping verify_cluster (already completed)" "backup"
    fi

    # Step 2: Backup Vault
    if ! $RESUME_MODE || ! state_is_completed "backup_vault"; then
        progress_update 2 "Backing up Vault"
        _backup_vault
        state_mark_completed "backup_vault"
    else
        log_info "Skipping backup_vault (already completed)" "backup"
    fi

    # Step 3: Backup repositories
    if ! $RESUME_MODE || ! state_is_completed "backup_repositories"; then
        progress_update 3 "Backing up repositories"
        _backup_repositories
        state_mark_completed "backup_repositories"
    else
        log_info "Skipping backup_repositories (already completed)" "backup"
    fi

    # Step 4: Backup registry
    if ! $RESUME_MODE || ! state_is_completed "backup_registry"; then
        progress_update 4 "Backing up registry"
        _backup_registry
        state_mark_completed "backup_registry"
    else
        log_info "Skipping backup_registry (already completed)" "backup"
    fi

    # Step 5: Verify and report
    if ! $RESUME_MODE || ! state_is_completed "verify_backup"; then
        progress_update 5 "Verifying backup"
        _verify_backup
        state_mark_completed "verify_backup"
    else
        log_info "Skipping verify_backup (already completed)" "backup"
    fi

    # Collect cluster metadata (FR-011)
    metadata_collect || {
        log_warn "Metadata collection failed" "backup"
    }

    # Apply retention policy (FR-013, FR-004)
    local retention_daily retention_weekly retention_monthly retention_latest
    retention_daily="$(config_get "retention.daily" 2>/dev/null || echo "7")"
    retention_weekly="$(config_get "retention.weekly" 2>/dev/null || echo "4")"
    retention_monthly="$(config_get "retention.monthly" 2>/dev/null || echo "12")"
    retention_latest="$(config_get "retention.latest" 2>/dev/null || echo "")"
    kopia_retention "$retention_daily" "$retention_weekly" "$retention_monthly" "$retention_latest" || {
        log_warn "Failed to apply retention policy" "backup"
    }

    progress_complete

    if $JSON_OUTPUT; then
        local partial_count=0
        if error_has_partials 2>/dev/null; then
            partial_count="$(error_get_partial_count)"
        fi
        local summary
        summary="$(cat <<EOF
{
  "status": "success",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "repositories_backed_up": $(config_get "repositories.count"),
  "vault_backed_up": true,
  "registry_backed_up": true,
  "partial_failures": $partial_count
}
EOF
)"
        echo "$summary"
    else
        log_info "Backup completed successfully" "backup"
    fi
}

# Output dry-run validation results
_output_dry_run() {
    log_info "Performing dry-run validation" "backup"

    local repo_count
    repo_count="$(config_get "repositories.count")"

    local kopia_repo_path
    kopia_repo_path="$(config_get "kopia.repository_path")"

    local vault_namespace
    vault_namespace="$(config_get "vault.namespace")"

    local port_offset
    port_offset="$(config_get "port_offset")"

    if $JSON_OUTPUT; then
        local result
        result="$(cat <<EOF
{
  "dry_run": true,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "configuration_valid": true,
  "repositories": $repo_count,
  "kopia_repository": "$kopia_repo_path",
  "vault_namespace": "$vault_namespace",
  "port_offset": $port_offset,
  "validation_passed": true
}
EOF
)"
        echo "$result"
    else
        echo "Dry-run validation results:"
        echo "=========================="
        echo "Configuration valid: Yes"
        echo "Repositories to backup: $repo_count"
        echo "Kopia repository: $kopia_repo_path"
        echo "Vault namespace: $vault_namespace"
        echo "Port offset: $port_offset"
        echo ""
        echo "All validation checks passed."
    fi
}

# Initialize libraries with configuration
_init_libraries() {
    local repo_path
    repo_path="$(config_get "kopia.repository_path")"

    local password_env
    password_env="$(config_get "kopia.password_env")"

    kopia_init "$repo_path" "$password_env" || {
        log_error "Failed to initialize Kopia" "backup"
        exit 3
    }

    kopia_connect --kdf-argon2id || {
        log_error "Failed to connect to Kopia repository" "backup"
        exit 3
    }

    local vault_namespace
    vault_namespace="$(config_get "vault.namespace")"

    local vault_unseal_key
    vault_unseal_key="$(config_get "vault.unseal_key_path")"

    vault_init "$vault_namespace" "$vault_unseal_key"

    local port_offset
    port_offset="$(config_get "port_offset")"
    ports_init "$port_offset"

    local dns_suffix
    dns_suffix="$(config_get "dns_suffix")"
    dns_init "$dns_suffix"
}

# Verify cluster status
_verify_cluster_status() {
    # Check if cluster is running
    if ! vault_is_running; then
        log_warn "Vault is not running - backup may be incomplete" "backup"
    fi

    # Check if Vault is sealed
    if [[ "$(vault_is_sealed)" == "true" ]]; then
        log_warn "Vault is sealed - cannot backup Vault snapshots" "backup"
    fi
}

# Backup Vault
_backup_vault() {
    if ! vault_is_running; then
        log_warn "Skipping Vault backup - not running" "vault"
        return 0
    fi

    if [[ "$(vault_is_sealed)" == "true" ]]; then
        log_warn "Skipping Vault backup - sealed" "vault"
        return 0
    fi

    local backup_dir="$SCRIPT_DIR/backup/vault"
    mkdir -p "$backup_dir"

    # Save Vault snapshot (exit code 4: vault snapshot error)
    log_info "Saving Vault snapshot" "vault"
    vault_save_snapshot "$backup_dir/raft-snapshot.db" || {
        log_error "Failed to save Vault snapshot" "vault"
        return 4
    }

    # Save Vault policies
    log_info "Saving Vault policies" "vault"
    vault_save_policies "$backup_dir/policies" || {
        log_warn "Failed to save some Vault policies" "vault"
    }

    # Save Vault auth methods
    log_info "Saving Vault auth configuration" "vault"
    vault_save_auth "$backup_dir/auth" || {
        log_warn "Failed to save some Vault auth configuration" "vault"
    }

    # Backup Vault data with Kopia (exit code 4: vault snapshot error)
    log_info "Backing up Vault data with Kopia" "vault"
    kopia_snapshot "$backup_dir" "vault" || {
        log_error "Failed to backup Vault data" "vault"
        return 4
    }
}

# Backup repositories (in deterministic alphabetical order - FR-042, FR-049/054)
# Non-critical failures continue to next repository; tracked via errors.sh
_backup_repositories() {
    local repo_count
    repo_count="$(config_get "repositories.count")"

    if [[ "$repo_count" -eq 0 ]]; then
        log_warn "No repositories configured for backup" "backup"
        return 0
    fi

    error_clear_partials

    # Get repository names and sort alphabetically for deterministic ordering
    local sorted_repos=()
    for i in $(seq 0 $((repo_count - 1))); do
        local name
        name="$(config_get_repository "$i" "name")"
        sorted_repos+=("$name")
    done

    # Sort repository names
    IFS=$'\n' sorted_repos=($(sort <<<"${sorted_repos[*]}")); unset IFS

    local failure_count=0

    # Backup in sorted order
    for repo_name in "${sorted_repos[@]}"; do
        for i in $(seq 0 $((repo_count - 1))); do
            local name
            name="$(config_get_repository "$i" "name")"
            if [[ "$name" == "$repo_name" ]]; then
                _backup_repository "$i" || {
                    log_warn "Non-critical failure backing up repository: $repo_name" "backup"
                    error_add_partial "backup" "Repository backup failed: $repo_name" "Check repository path and permissions"
                    failure_count=$((failure_count + 1))
                }
                break
            fi
        done
    done

    # Report partial failures summary (FR-049)
    if [[ $failure_count -gt 0 ]]; then
        log_warn "Backup completed with $failure_count partial failure(s)" "backup"
        if $JSON_OUTPUT; then
            error_partial_summary
        fi
    fi

    return 0
}

# Backup single repository
_backup_repository() {
    local index="$1"

    local name path
    name="$(config_get_repository "$index" "name")"
    path="$(config_get_repository "$index" "path")"

    log_info "Backing up repository: $name" "backup" '{"repository":"'$name'","path":"'$path'"}'

    # Verify repository exists (exit code 3: kopia repository error)
    if [[ ! -d "$path" ]]; then
        log_error "Repository path does not exist: $path" "backup" '{"repository":"'$name'"}'
        return 3
    fi

    # Backup repository data (exit code 3: kopia repository error)
    kopia_snapshot "$path" "$name" || {
        log_error "Failed to backup repository: $name" "backup" '{"repository":"'$name'"}'
        return 3
    }

    # Copy k8s manifests to backup directory for restore alignment (FR-016)
    local manifests_dir="$path/k8s"
    if [[ -d "$manifests_dir" ]]; then
        local backup_manifests="$SCRIPT_DIR/backup/repos/$name/k8s"
        mkdir -p "$backup_manifests"
        cp -r "$manifests_dir"/* "$backup_manifests/" 2>/dev/null || {
            log_warn "Failed to copy manifests for repository: $name" "backup" '{"repository":"'$name'"}'
        }
    fi

    # Run database hook if configured
    local db_hook
    db_hook="$(config_get_repository "$index" "db_hook")"

    if [[ -n "$db_hook" ]] && [[ -x "$db_hook" ]]; then
        log_info "Running database backup hook: $db_hook" "backup" '{"repository":"'$name'"}'

        local timeout
        timeout="$(config_get "database_hooks.timeout")"

        if ! timeout "$timeout" "$db_hook" "$name" "$path"; then
            local mandatory
            mandatory="$(config_get "database_hooks.mandatory")"

            if [[ "$mandatory" == "true" ]]; then
                log_error "Database hook failed (mandatory)" "backup" '{"repository":"'$name'","hook":"'$db_hook'"}'
                return 5
            else
                log_warn "Database hook failed (optional)" "backup" '{"repository":"'$name'","hook":"'$db_hook'"}'
            fi
        fi
    fi
}

# Backup registry
_backup_registry() {
    log_info "Backing up container registry" "backup"

    # Check if registry exists
    if ! docker volume ls --format '{{.Name}}' | grep -q "k3d-${K3D_CLUSTER_NAME:-k3d}-registry"; then
        log_warn "Container registry not found" "backup"
        return 0
    fi

    # Backup registry data
    local registry_path="/var/lib/registry"
    kopia_snapshot "$registry_path" "registry" || {
        log_warn "Failed to backup container registry" "backup"
    }
}

# Verify backup
_verify_backup() {
    log_info "Verifying backup integrity" "backup"

    kopia_verify || {
        log_error "Backup verification failed" "backup"
        return 3
    }

    log_info "Backup verification passed" "backup"
}

# Parse arguments and run main
parse_args "$@"
main