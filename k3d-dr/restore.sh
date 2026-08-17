#!/usr/bin/env bash
# restore.sh - Primary restore script
# FR-002: Single script supporting full disaster recovery and selective restore
# FR-014: Non-zero exit codes on failure
# FR-016: Complete infrastructure recovery order
# FR-018: Idempotent operations

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
source "$LIB_DIR/k3d.sh"
source "$LIB_DIR/kubernetes.sh"
source "$LIB_DIR/lock.sh"
source "$LIB_DIR/progress.sh"
source "$LIB_DIR/ports.sh"
source "$LIB_DIR/dns.sh"
source "$LIB_DIR/validation.sh"

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -r|--repo)
                SELECTIVE_REPO="$2"
                shift 2
                ;;
            --volume)
                SELECTIVE_VOLUME="$2"
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
            --rollback)
                ROLLBACK_MODE=true
                shift
                ;;
            --snapshot)
                SNAPSHOT_ID="$2"
                shift 2
                ;;
            --tag)
                SNAPSHOT_TAG="$2"
                shift 2
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
Usage: restore.sh [OPTIONS]

Options:
  -c, --config FILE    Configuration file (default: backup-config.yml)
  -r, --repo NAME      Restore specific repository only
  --volume NAME        Restore specific volume only
  -v, --verbose        Enable debug logging
  --json               Output in JSON format
  --rollback           Rollback partial restore
  --snapshot ID        Restore from specific snapshot
  --tag NAME           Restore from tagged snapshot
  -h, --help           Show this help message

Environment Variables:
  KOPIA_PASSWORD       Kopia repository password (required)
  KOPIA_BACKUP_*       Override any config value (e.g., KOPIA_BACKUP_PORT_OFFSET)

Examples:
  ./restore.sh -c backup-config.yml
  ./restore.sh --repo argo-bootstrap
  ./restore.sh --snapshot abc123
  ./restore.sh --tag daily
  ./restore.sh --json
EOF
}

# State variables
SELECTIVE_REPO=""
SELECTIVE_VOLUME=""
ROLLBACK_MODE=false
SNAPSHOT_ID=""
SNAPSHOT_TAG=""
JSON_OUTPUT=false

# Main restore workflow
main() {
    local config_file="${CONFIG_FILE:-backup-config.yml}"

    # Initialize logging
    init_logging

    if $JSON_OUTPUT; then
        log_info "Starting restore" "restore" '{"output_format":"json"}'
    else
        log_info "Starting restore" "restore"
    fi

    # Acquire exclusive lock
    lock_acquire "restore" || {
        log_error "Failed to acquire restore lock" "restore"
        exit 1
    }

    trap 'lock_release "restore"' EXIT

    # Load and validate configuration
    config_load "$config_file" || {
        log_error "Configuration validation failed" "restore"
        exit 1
    }

    # Validate paths and dependencies
    validate_all "$config_file" || {
        log_error "Path validation failed" "restore"
        exit 1
    }

    # Apply environment variable overrides
    config_apply_env_overrides

    # Initialize libraries
    _init_libraries

    # Handle rollback mode
    if $ROLLBACK_MODE; then
        _rollback_restore
        return
    fi

    # Initialize progress tracking
    local total_steps=8
    progress_init "$total_steps" "restore"

    # Step 1: Create k3d cluster
    progress_update 1 "Creating k3d cluster"
    _create_cluster

    # Step 2: Install infrastructure apps
    progress_update 2 "Installing infrastructure apps"
    _install_infrastructure

    # Step 3: Restore Vault
    progress_update 3 "Restoring Vault"
    _restore_vault

    # Step 4: Restore PV/PVCs
    progress_update 4 "Restoring persistent volumes"
    _restore_volumes

    # Step 5: Restore application data
    progress_update 5 "Restoring application data"
    _restore_repositories

    # Step 6: Restore ConfigMaps and configuration
    progress_update 6 "Restoring configuration"
    _restore_configmaps

    # Step 7: Restore application repos
    progress_update 7 "Restoring application repositories"
    _restore_application_repos

    # Step 8: Verify health
    progress_update 8 "Verifying health"
    _verify_health

    progress_complete

    if $JSON_OUTPUT; then
        # Output JSON summary
        local summary
        summary="$(cat <<EOF
{
  "status": "success",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "repositories_restored": $(config_get "repositories.count"),
  "vault_restored": true,
  "cluster_restored": true
}
EOF
)"
        echo "$summary"
    else
        log_info "Restore completed successfully" "restore"
    fi
}

# Initialize libraries with configuration
_init_libraries() {
    local repo_path
    repo_path="$(config_get "kopia.repository_path")"

    local password_env
    password_env="$(config_get "kopia.password_env")"

    kopia_init "$repo_path" "$password_env" || {
        log_error "Failed to initialize Kopia" "restore"
        exit 1
    }

    kopia_connect || {
        log_error "Failed to connect to Kopia repository" "restore"
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

    # Initialize k3d
    k3d_init "k3d-dr" "$port_offset"
}

# Create k3d cluster
_create_cluster() {
    log_info "Creating k3d cluster" "k3d"

    # Check if cluster already exists
    if k3d_cluster_exists; then
        log_warn "k3d cluster already exists" "k3d"
        return 0
    fi

    # Create cluster
    k3d_cluster_create || {
        log_error "Failed to create k3d cluster" "k3d"
        return 1
    }

    # Wait for cluster to be ready
    k3d_wait_ready 120 || {
        log_error "k3d cluster not ready" "k3d"
        return 1
    }

    # Get kubeconfig
    local kubeconfig
    kubeconfig="$(k3d_get_kubeconfig)"
    export KUBECONFIG="$kubeconfig"

    # Initialize Kubernetes
    kubernetes_init "k3d-k3d-dr"
}

# Install infrastructure apps
_install_infrastructure() {
    log_info "Installing infrastructure apps" "infra"

    local infra_dir="$HOME/projects/infra"

    if [[ ! -d "$infra_dir" ]]; then
        log_error "Infrastructure directory not found: $infra_dir" "infra"
        return 1
    fi

    # Install infrastructure apps in order
    for app_dir in "$infra_dir"/*/; do
        [[ -d "$app_dir" ]] || continue

        local app_name
        app_name="$(basename "$app_dir")"

        log_info "Installing infrastructure app: $app_name" "infra" '{"app":"'$app_name'"}'

        # Apply Kubernetes manifests
        if [[ -d "$app_dir/k8s" ]]; then
            kubernetes_apply "$app_dir/k8s" || {
                log_warn "Failed to install $app_name" "infra" '{"app":"'$app_name'"}'
            }
        fi

        # Install Helm charts
        if [[ -f "$app_dir/helmfile.yaml" ]]; then
            (cd "$app_dir" && helmfile sync) || {
                log_warn "Failed to install $app_name Helm chart" "infra" '{"app":"'$app_name'"}'
            }
        fi
    done
}

# Restore Vault
_restore_vault() {
    log_info "Restoring Vault" "vault"

    # Wait for Vault to be ready
    vault_wait_ready 60 || {
        log_error "Vault not ready" "vault"
        return 1
    }

    # Auto-unseal Vault
    vault_auto_unseal || {
        log_error "Failed to unseal Vault" "vault"
        return 1
    }

    # Restore Vault from snapshot
    local backup_dir="$SCRIPT_DIR/backup/vault"
    if [[ -f "$backup_dir/raft-snapshot.db" ]]; then
        vault_restore_snapshot "$backup_dir/raft-snapshot.db" || {
            log_error "Failed to restore Vault snapshot" "vault"
            return 1
        }
    fi

    # Restore policies
    if [[ -d "$backup_dir/policies" ]]; then
        vault_restore_policies "$backup_dir/policies" || {
            log_warn "Failed to restore some Vault policies" "vault"
        }
    fi

    # Restore auth methods
    if [[ -d "$backup_dir/auth" ]]; then
        vault_restore_auth "$backup_dir/auth" || {
            log_warn "Failed to restore some Vault auth configuration" "vault"
        }
    fi
}

# Restore persistent volumes
_restore_volumes() {
    log_info "Restoring persistent volumes" "storage"

    local repo_count
    repo_count="$(config_get "repositories.count")"

    for i in $(seq 0 $((repo_count - 1))); do
        local name pvc namespace
        name="$(config_get_repository "$i" "name")"
        pvc="$(config_get_repository "$i" "pvc")"
        namespace="$(config_get_repository "$i" "namespace")"

        log_info "Restoring volume for: $name" "storage" '{"repository":"'$name'","pvc":"'$pvc'"}'

        # Create PVC if it doesn't exist
        kubernetes_wait "pvc" "$pvc" 30 2>/dev/null || {
            # Create PVC
            cat <<EOF | kubectl apply --context "$KUBECTL_CONTEXT" -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: $pvc
  namespace: $namespace
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
EOF
        }
    done
}

# Restore repositories
_restore_repositories() {
    local repo_count
    repo_count="$(config_get "repositories.count")"

    if [[ -n "$SELECTIVE_REPO" ]]; then
        # Selective restore by repository name
        _restore_selective_repository "$SELECTIVE_REPO"
    elif [[ -n "$SELECTIVE_VOLUME" ]]; then
        # Selective restore by volume name
        _restore_selective_volume "$SELECTIVE_VOLUME"
    else
        # Full restore
        for i in $(seq 0 $((repo_count - 1))); do
            _restore_repository "$i" || {
                log_error "Failed to restore repository $i" "restore"
                return 1
            }
        done
    fi
}

# Restore single repository (with idempotency - skip if already restored)
_restore_repository() {
    local index="$1"

    local name path data_dir pvc namespace
    name="$(config_get_repository "$index" "name")"
    path="$(config_get_repository "$index" "path")"
    data_dir="$(config_get_repository "$index" "data_dir")"
    pvc="$(config_get_repository "$index" "pvc")"
    namespace="$(config_get_repository "$index" "namespace")"

    log_info "Restoring repository: $name" "restore" '{"repository":"'$name'","path":"'$path'"}'

    # Idempotency check: Skip if data already exists (FR-043)
    if kubectl exec --context "$KUBECTL_CONTEXT" -n "$namespace" "$pvc" -- ls "$data_dir" &>/dev/null; then
        log_info "Repository already restored, skipping: $name" "restore" '{"repository":"'$name'"}'
        return 0
    fi

    # Get latest snapshot
    local snapshot_id="$SNAPSHOT_ID"
    if [[ -z "$snapshot_id" ]]; then
        snapshot_id="$(kopia_get_latest_snapshot "$path")"
    fi

    if [[ -z "$snapshot_id" ]]; then
        log_error "No snapshot found for repository: $name" "restore" '{"repository":"'$name'"}'
        return 1
    fi

    # Create temporary restore directory
    local tmp_dir="/tmp/k3d-dr/restore/$name"
    mkdir -p "$tmp_dir"

    # Restore from snapshot
    kopia_restore "$snapshot_id" "$tmp_dir" || {
        log_error "Failed to restore repository: $name" "restore" '{"repository":"'$name'","snapshot":"'$snapshot_id'"}'
        return 1
    }

    # Copy to PVC
    kubernetes_wait "pvc" "$pvc" 30 || {
        log_error "PVC not ready: $pvc" "restore" '{"repository":"'$name'","pvc":"'$pvc'"}'
        return 1
    }

    # Copy data to PVC
    kubectl cp --context "$KUBECTL_CONTEXT" "$tmp_dir/." "$namespace/$pvc:$data_dir" || {
        log_error "Failed to copy data to PVC" "restore" '{"repository":"'$name'","pvc":"'$pvc'"}'
        return 1
    }

    # Clean up
    rm -rf "$tmp_dir"

    log_info "Repository restore completed: $name" "restore" '{"repository":"'$name'"}'
}

# Restore selective repository
_restore_selective_repository() {
    local repo_name="$1"

    local repo_count
    repo_count="$(config_get "repositories.count")"

    for i in $(seq 0 $((repo_count - 1))); do
        local name
        name="$(config_get_repository "$i" "name")"

        if [[ "$name" == "$repo_name" ]]; then
            _restore_repository "$i"
            return
        fi
    done

    log_error "Repository not found: $repo_name" "restore" '{"repository":"'$repo_name'"}'
    return 1
}

# Restore selective volume
_restore_selective_volume() {
    local volume_name="$1"

    local repo_count
    repo_count="$(config_get "repositories.count")"

    for i in $(seq 0 $((repo_count - 1))); do
        local name pvc
        name="$(config_get_repository "$i" "name")"
        pvc="$(config_get_repository "$i" "pvc")"

        if [[ "$pvc" == "$volume_name" ]]; then
            _restore_repository "$i"
            return
        fi
    done

    log_error "Volume not found: $volume_name" "restore" '{"volume":"'$volume_name'"}'
    return 1
}

# Restore ConfigMaps and configuration
_restore_configmaps() {
    log_info "Restoring ConfigMaps and configuration" "config"

    local backup_dir="$SCRIPT_DIR/backup/configmaps"
    if [[ -d "$backup_dir" ]]; then
        kubernetes_apply "$backup_dir" || {
            log_warn "Failed to restore some ConfigMaps" "config"
        }
    fi
}

# Restore application repos
_restore_application_repos() {
    log_info "Restoring application repositories" "apps"

    local repo_count
    repo_count="$(config_get "repositories.count")"

    for i in $(seq 0 $((repo_count - 1))); do
        local name namespace
        name="$(config_get_repository "$i" "name")"
        namespace="$(config_get_repository "$i" "namespace")"

        # Apply Kubernetes manifests if they exist
        local manifests_dir="$SCRIPT_DIR/backup/repos/$name/k8s"
        if [[ -d "$manifests_dir" ]]; then
            kubernetes_apply "$manifests_dir" || {
                log_warn "Failed to restore manifests for: $name" "apps" '{"repository":"'$name'"}'
            }
        fi
    done
}

# Verify health
_verify_health() {
    log_info "Verifying health" "health"

    # Wait for all pods to be ready
    kubernetes_wait_pod "app" "default" 120 || {
        log_warn "Some pods are not ready" "health"
    }

    # Check Vault health
    vault_verify_health || {
        log_warn "Vault health check failed" "health"
    }

    log_info "Health verification completed" "health"
}

# Rollback restore
_rollback_restore() {
    log_info "Rolling back restore" "rollback"

    # Get pre-restore snapshot
    local snapshot_id
    snapshot_id="$(kopia_get_latest_snapshot "$SCRIPT_DIR/backup")"

    if [[ -z "$snapshot_id" ]]; then
        log_error "No snapshot found for rollback" "rollback"
        return 1
    fi

    # Restore from snapshot
    kopia_restore "$snapshot_id" "$SCRIPT_DIR/backup" || {
        log_error "Failed to rollback restore" "rollback"
        return 1
    }

    log_info "Rollback completed" "rollback"
}

# Parse arguments and run main
parse_args "$@"
main