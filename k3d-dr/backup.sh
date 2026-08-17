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
  -h, --help           Show this help message

Environment Variables:
  KOPIA_PASSWORD       Kopia repository password (required)
  KOPIA_BACKUP_*       Override any config value (e.g., KOPIA_BACKUP_PORT_OFFSET)

Examples:
  ./backup.sh -c backup-config.yml
  KOPIA_PASSWORD=mypassword ./backup.sh
  ./backup.sh --verbose
EOF
}

# Main backup workflow
main() {
    local config_file="${CONFIG_FILE:-backup-config.yml}"

    # Initialize logging
    init_logging

    log_info "Starting backup" "backup"

    # Acquire exclusive lock
    lock_acquire "backup" || {
        log_error "Failed to acquire backup lock" "backup"
        exit 1
    }

    trap 'lock_release "backup"' EXIT

    # Load and validate configuration
    config_load "$config_file" || {
        log_error "Configuration validation failed" "backup"
        exit 1
    }

    # Apply environment variable overrides
    config_apply_env_overrides

    # Initialize libraries
    _init_libraries

    # Initialize progress tracking
    local total_steps=5
    progress_init "$total_steps" "backup"

    # Step 1: Verify cluster and Vault status
    progress_update 1 "Verifying cluster status"
    _verify_cluster_status

    # Step 2: Backup Vault
    progress_update 2 "Backing up Vault"
    _backup_vault

    # Step 3: Backup repositories
    progress_update 3 "Backing up repositories"
    _backup_repositories

    # Step 4: Backup registry
    progress_update 4 "Backing up registry"
    _backup_registry

    # Step 5: Verify and report
    progress_update 5 "Verifying backup"
    _verify_backup

    progress_complete

    log_info "Backup completed successfully" "backup"
}

# Initialize libraries with configuration
_init_libraries() {
    local repo_path
    repo_path="$(config_get "kopia.repository_path")"

    local password_env
    password_env="$(config_get "kopia.password_env")"

    kopia_init "$repo_path" "$password_env" || {
        log_error "Failed to initialize Kopia" "backup"
        exit 1
    }

    kopia_connect || {
        log_error "Failed to connect to Kopia repository" "backup"
        exit 1
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

    # Save Vault snapshot
    log_info "Saving Vault snapshot" "vault"
    vault_save_snapshot "$backup_dir/raft-snapshot.db" || {
        log_error "Failed to save Vault snapshot" "vault"
        return 1
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

    # Backup Vault data with Kopia
    log_info "Backing up Vault data with Kopia" "vault"
    kopia_snapshot "$backup_dir" "vault" || {
        log_error "Failed to backup Vault data" "vault"
        return 1
    }
}

# Backup repositories
_backup_repositories() {
    local repo_count
    repo_count="$(config_get "repositories.count")"

    if [[ "$repo_count" -eq 0 ]]; then
        log_warn "No repositories configured for backup" "backup"
        return 0
    fi

    for i in $(seq 0 $((repo_count - 1))); do
        _backup_repository "$i" || {
            log_error "Failed to backup repository $i" "backup"
            return 1
        }
    done
}

# Backup single repository
_backup_repository() {
    local index="$1"

    local name path
    name="$(config_get_repository "$index" "name")"
    path="$(config_get_repository "$index" "path")"

    log_info "Backing up repository: $name" "backup" '{"repository":"'$name'","path":"'$path'"}'

    # Verify repository exists
    if [[ ! -d "$path" ]]; then
        log_error "Repository path does not exist: $path" "backup" '{"repository":"'$name'"}'
        return 1
    fi

    # Backup repository data
    kopia_snapshot "$path" "$name" || {
        log_error "Failed to backup repository: $name" "backup" '{"repository":"'$name'"}'
        return 1
    }

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
                return 1
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
        return 1
    }

    log_info "Backup verification passed" "backup"
}

# Parse arguments and run main
parse_args "$@"
main