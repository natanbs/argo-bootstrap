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
source "$LIB_DIR/state.sh"
source "$LIB_DIR/registry.sh"
source "$LIB_DIR/snapshots.sh"
source "$LIB_DIR/health.sh"

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
            --interactive)
                INTERACTIVE_MODE=true
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
  --interactive        Interactively select snapshot to restore
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
INTERACTIVE_MODE=false
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

    # Load and validate configuration (exit code 2: config validation failed)
    config_load "$config_file" || {
        log_error "Configuration validation failed" "restore"
        exit 2
    }

    # Validate paths and dependencies (exit code 2: config validation failed)
    validate_all "$config_file" || {
        log_error "Path validation failed" "restore"
        exit 2
    }

    # Apply environment variable overrides
    config_apply_env_overrides

    # Initialize libraries
    _init_libraries

    # Verify Kopia repository integrity before restore (FR-012)
    log_info "Verifying Kopia repository integrity" "restore"
    kopia_verify || {
        log_error "Kopia repository verification failed - aborting restore" "restore"
        exit 3
    }

    # Initialize state tracking (FR-047, FR-050)
    state_init "$SCRIPT_DIR/backup"

    # Handle rollback mode
    if $ROLLBACK_MODE; then
        _rollback_restore
        return
    fi

    # Save pre-restore snapshot ID for targeted rollback (FR-050)
    local pre_restore_snapshot
    pre_restore_snapshot="$(kopia_get_latest_snapshot "$SCRIPT_DIR/backup")"
    if [[ -n "$pre_restore_snapshot" ]]; then
        state_set "pre_restore_snapshot" "$pre_restore_snapshot"
        log_info "Saved pre-restore snapshot ID" "restore" '{"snapshot_id":"'"$pre_restore_snapshot"'"}'
    else
        log_warn "No pre-restore snapshot found - rollback may not work" "restore"
    fi

    # Initialize progress tracking
    local total_steps=11
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

    # Step 3a: Configure Vault Kubernetes auth (FR-024)
    progress_update 4 "Configuring Vault Kubernetes auth"
    _configure_vault_k8s_auth

    # Step 4: Restore PV/PVCs
    progress_update 5 "Restoring persistent volumes"
    _restore_volumes

    # Step 5: Restore application data
    progress_update 6 "Restoring application data"
    _restore_repositories

    # Step 5a: Restore container registry (FR-016)
    progress_update 7 "Restoring container registry"
    _restore_registry

    # Step 5b: Run database restore hooks (FR-016)
    progress_update 8 "Running database restore hooks"
    _restore_database_hooks

    # Step 6: Restore ConfigMaps and configuration
    progress_update 9 "Restoring configuration"
    _restore_configmaps

    # Step 7: Restore application repos
    progress_update 10 "Restoring application repositories"
    _restore_application_repos

    # Step 8: Verify health (FR-016)
    progress_update 11 "Verifying health"
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
        exit 3
    }

    kopia_connect --kdf-argon2id || {
        log_error "Failed to connect to Kopia repository" "restore"
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

# Install infrastructure apps in dependency order (FR-016)
_install_infrastructure() {
    log_info "Installing infrastructure apps" "infra"

    local infra_dir="$HOME/projects/infra"

    if [[ ! -d "$infra_dir" ]]; then
        log_error "Infrastructure directory not found: $infra_dir" "infra"
        return 1
    fi

    # Resolve dependency-ordered install list
    local ordered_apps
    ordered_apps="$(_resolve_infra_order "$infra_dir")"

    if [[ -z "$ordered_apps" ]]; then
        log_warn "No infrastructure apps found to install" "infra"
        return 0
    fi

    # Install infrastructure apps in dependency order
    while IFS= read -r app_name; do
        [[ -z "$app_name" ]] && continue

        local app_dir="$infra_dir/$app_name"

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
    done <<< "$ordered_apps"

    # Rewrite DNS suffix in Ingress resources if configured (FR-026)
    if dns_is_configured; then
        log_info "Rewriting DNS suffix in Ingress resources" "dns"
        local rewritten_dir="/tmp/k3d-dr/rewritten-ingress"
        dns_rewrite_all_ingress "$infra_dir" "$rewritten_dir" || {
            log_warn "DNS rewriting failed" "dns"
        }
    fi
}

# Resolve infrastructure app dependency order via topological sort (FR-016)
# Reads .deps files (one dependency per line) from each app directory
# Bash 3.2 compatible: uses indexed arrays with parallel indexing instead of associative arrays
_resolve_infra_order() {
    local infra_dir="$1"

    # Collect all apps and their dependencies using parallel indexed arrays
    local -a all_apps=()
    local -a all_deps=()

    for app_dir in "$infra_dir"/*/; do
        [[ -d "$app_dir" ]] || continue
        local app_name
        app_name="$(basename "$app_dir")"
        all_apps+=("$app_name")

        # Read dependencies from .deps file if it exists
        local deps_file="$app_dir/.deps"
        local deps=""
        if [[ -f "$deps_file" ]]; then
            while IFS= read -r line; do
                # Skip empty lines and comments
                [[ -z "$line" || "$line" == \#* ]] && continue
                deps+="${deps:+ }$line"
            done < "$deps_file"
        fi
        all_deps+=("$deps")
    done

    local app_count=${#all_apps[@]}

    # Topological sort (Kahn's algorithm)
    local -a sorted=()
    local -a in_degree=()

    # Initialize in-degree to 0 for all apps
    local i
    for i in $(seq 0 $((app_count - 1))); do
        in_degree[$i]=0
    done

    # Calculate in-degrees
    for i in $(seq 0 $((app_count - 1))); do
        local deps="${all_deps[$i]}"
        for dep in $deps; do
            # Only count if dep is actually in our app list
            local j
            for j in $(seq 0 $((app_count - 1))); do
                if [[ "$dep" == "${all_apps[$j]}" ]]; then
                    in_degree[$i]=$(( ${in_degree[$i]} + 1 ))
                    break
                fi
            done
        done
    done

    # Start with apps that have no dependencies
    local -a queue=()
    for i in $(seq 0 $((app_count - 1))); do
        if [[ "${in_degree[$i]}" -eq 0 ]]; then
            queue+=("${all_apps[$i]}")
        fi
    done

    # Process queue
    while [[ ${#queue[@]} -gt 0 ]]; do
        # Shift first element
        local current="${queue[0]}"
        queue=("${queue[@]:1}")

        sorted+=("$current")

        # Find index of current in all_apps
        local current_idx=-1
        for i in $(seq 0 $((app_count - 1))); do
            if [[ "${all_apps[$i]}" == "$current" ]]; then
                current_idx=$i
                break
            fi
        done

        # Reduce in-degree for apps that depend on current
        for i in $(seq 0 $((app_count - 1))); do
            local deps="${all_deps[$i]}"
            for dep in $deps; do
                if [[ "$dep" == "$current" ]]; then
                    in_degree[$i]=$(( ${in_degree[$i]} - 1 ))
                    if [[ "${in_degree[$i]}" -eq 0 ]]; then
                        queue+=("${all_apps[$i]}")
                    fi
                fi
            done
        done
    done

    # Check for circular dependencies
    if [[ ${#sorted[@]} -ne $app_count ]]; then
        log_warn "Circular dependency detected in infrastructure apps, falling back to alphabetical order" "infra"
        printf '%s\n' "${all_apps[@]}" | sort
        return
    fi

    # Output sorted order
    printf '%s\n' "${sorted[@]}"
}

# Restore Vault
_restore_vault() {
    log_info "Restoring Vault" "vault"

    # Wait for Vault to be ready (exit code 4: vault restore error)
    vault_wait_ready 60 || {
        log_error "Vault not ready" "vault"
        return 4
    }

    # Auto-unseal Vault (exit code 4: vault restore error)
    vault_auto_unseal || {
        log_error "Failed to unseal Vault" "vault"
        return 4
    }

    # Restore Vault from snapshot (exit code 4: vault restore error)
    local backup_dir="$SCRIPT_DIR/backup/vault"
    if [[ -f "$backup_dir/raft-snapshot.db" ]]; then
        vault_restore_snapshot "$backup_dir/raft-snapshot.db" || {
            log_error "Failed to restore Vault snapshot" "vault"
            return 4
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

    # Idempotency check: Skip if data already exists (FR-043, FR-005)
    if kubernetes_wait "pvc" "$pvc" 5 2>/dev/null; then
        # Find a pod that mounts this PVC
        local pod_name
        pod_name="$(kubectl get pods -n "$namespace" -o json 2>/dev/null | \
            jq -r --arg pvc "$pvc" '.items[] | select(.spec.volumes[]?.persistentVolumeClaim.claimName == $pvc) | .metadata.name' 2>/dev/null | head -1)"
        
        # If no pod found, fall through to restore (common during initial restore)
        if [[ -n "$pod_name" ]]; then
            if kubectl exec --context "$KUBECTL_CONTEXT" -n "$namespace" "$pod_name" -- ls "$data_dir" &>/dev/null; then
                log_info "Repository already restored, skipping: $name" "restore" '{"repository":"'$name'"}'
                return 0
            fi
        else
            log_debug "No pod mounted on PVC $pvc, proceeding with restore" "restore"
        fi
    fi

    # Resolve snapshot ID (--tag > --snapshot > --interactive > latest) (FR-027)
    local snapshot_id="$SNAPSHOT_ID"
    if [[ -z "$snapshot_id" && -n "$SNAPSHOT_TAG" ]]; then
        snapshots_list_all "$path" "$SNAPSHOT_TAG"
        snapshot_id="$(snapshots_find_by_tag "$SNAPSHOT_TAG" | head -1)"
        if [[ -z "$snapshot_id" ]]; then
            log_warn "No snapshot found for tag: $SNAPSHOT_TAG" "restore" '{"tag":"'"$SNAPSHOT_TAG"'"}'
            snapshot_id="$(kopia_get_latest_snapshot "$path")"
        fi
    elif [[ -z "$snapshot_id" && "$INTERACTIVE_MODE" == "true" ]]; then
        snapshot_id="$(snapshots_interactive_select "$path")"
        if [[ -z "$snapshot_id" ]]; then
            log_warn "No snapshot selected interactively" "restore"
            snapshot_id="$(kopia_get_latest_snapshot "$path")"
        fi
    elif [[ -z "$snapshot_id" ]]; then
        snapshot_id="$(kopia_get_latest_snapshot "$path")"
    fi

    if [[ -z "$snapshot_id" ]]; then
        log_error "No snapshot found for repository: $name" "restore" '{"repository":"'$name'"}'
        return 3
    fi

    # Create temporary restore directory
    local tmp_dir="/tmp/k3d-dr/restore/$name"
    mkdir -p "$tmp_dir"

    # Restore from snapshot (exit code 3: kopia repository error)
    kopia_restore "$snapshot_id" "$tmp_dir" || {
        log_error "Failed to restore repository: $name" "restore" '{"repository":"'$name'","snapshot":"'$snapshot_id'"}'
        return 3
    }

    # Copy to PVC (exit code 5: kubernetes apply error)
    kubernetes_wait "pvc" "$pvc" 30 || {
        log_error "PVC not ready: $pvc" "restore" '{"repository":"'$name'","pvc":"'$pvc'"}'
        return 5
    }

    # Copy data to PVC (exit code 5: kubernetes apply error)
    kubectl cp --context "$KUBECTL_CONTEXT" "$tmp_dir/." "$namespace/$pvc:$data_dir" || {
        log_error "Failed to copy data to PVC" "restore" '{"repository":"'$name'","pvc":"'$pvc'"}'
        return 5
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

# Restore container registry from backup (FR-016)
_restore_registry() {
    log_info "Restoring container registry" "registry"

    local cluster_name
    cluster_name="$(config_get "cluster_name")"
    registry_init "$cluster_name" 5000

    if registry_exists; then
        registry_restore || {
            log_warn "Failed to restore container registry" "registry"
        }
    else
        log_info "Registry does not exist, creating fresh" "registry"
        registry_create
    fi
}

# Run database restore hooks for each repository (FR-016)
_restore_database_hooks() {
    log_info "Running database restore hooks" "hooks"

    local repo_count
    repo_count="$(config_get "repositories.count")"
    local hook_failures=0

    for i in $(seq 0 $((repo_count - 1))); do
        local name db_restore_hook namespace
        name="$(config_get_repository "$i" "name")"
        db_restore_hook="$(config_get_repository "$i" "db_restore_hook")"
        namespace="$(config_get_repository "$i" "namespace")"

        if [[ -n "$db_restore_hook" ]]; then
            log_info "Running db restore hook: $name" "hooks" '{"repository":"'"$name"'","hook":"'"$db_restore_hook"'"}'

            if [[ -f "$db_restore_hook" ]] && [[ -x "$db_restore_hook" ]]; then
                "$db_restore_hook" "$name" "$namespace" || {
                    log_warn "Database restore hook failed for: $name" "hooks" '{"repository":"'"$name"'"}'
                    error_add_partial "hooks" "DB restore hook failed for $name" "Fix hook permissions or content"
                    hook_failures=$((hook_failures + 1))
                }
            else
                log_warn "Database restore hook not executable: $db_restore_hook" "hooks" '{"repository":"'"$name"'"}'
            fi
        fi
    done

    if [[ $hook_failures -gt 0 ]]; then
        log_warn "Some database restore hooks failed ($hook_failures total)" "hooks"
    fi
}

# Configure Vault Kubernetes auth after Vault restore (FR-024)
_configure_vault_k8s_auth() {
    log_info "Configuring Vault Kubernetes auth" "vault"

    # Check if Vault is accessible
    if ! vault_is_running; then
        log_warn "Vault is not running, skipping Kubernetes auth setup" "vault"
        return 0
    fi

    # Get current Kubernetes auth configuration
    local k8s_auth_config
    k8s_auth_config="$(vault_get_kubernetes_auth)"

    # Check if Kubernetes auth is already configured
    local k8s_host
    k8s_host="$(echo "$k8s_auth_config" | jq -r '.data.kubernetes_host // empty' 2>/dev/null)"

    if [[ -n "$k8s_host" ]]; then
        log_info "Vault Kubernetes auth already configured" "vault" '{"kubernetes_host":"'"$k8s_host"'"}'
        return 0
    fi

    # Configure Kubernetes auth
    local k3d_api_host
    k3d_api_host="$(config_get "k3d.api_host" 2>/dev/null || echo "0.0.0.0")"

    local port_offset
    port_offset="$(config_get "port_offset")"
    local k8s_api_port=$((6443 + port_offset))

    # Get Kubernetes CA cert from cluster (FR-003)
    # Since restore runs on the host, we fetch the cert via kubectl
    local kubernetes_ca_cert
    kubernetes_ca_cert="$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[].cluster.certificate-authority-data}' 2>/dev/null | base64 -d 2>/dev/null)"
    
    if [[ -z "$kubernetes_ca_cert" ]]; then
        # Fallback: try to get from cluster-info
        kubernetes_ca_cert="$(kubectl cluster-info 2>/dev/null | grep -oE 'https://[^/]+' | head -1 | xargs -I {} curl -sk {}/ca.crt 2>/dev/null)"
    fi
    
    if [[ -z "$kubernetes_ca_cert" ]]; then
        log_warn "Cannot retrieve Kubernetes CA cert from cluster" "vault"
        return 1
    fi

    vault write -namespace "$VAULT_NAMESPACE" sys/auth/kubernetes/config \
        kubernetes_host="https://${k3d_api_host}:${k8s_api_port}" \
        kubernetes_ca_cert="$kubernetes_ca_cert" \
        disable_local_ca_jwt=true || {
        log_warn "Failed to configure Vault Kubernetes auth" "vault"
        return 0
    }

    log_info "Vault Kubernetes auth configured" "vault"

    # Wait for External Secrets Operator to be ready (FR-024)
    if kubectl get deployment external-secrets -n external-secrets &>/dev/null; then
        log_info "Waiting for External Secrets Operator to be ready" "vault"
        wait_for_deployment "external-secrets" "external-secrets" 60 || {
            log_warn "External Secrets Operator not ready" "vault"
        }
    fi
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

# Rollback restore (FR-050) - use pre-restore snapshot, not latest
_rollback_restore() {
    log_info "Rolling back restore" "rollback"

    # Get pre-restore snapshot from state (FR-050)
    local snapshot_id
    snapshot_id="$(state_get_value "pre_restore_snapshot")"

    if [[ -z "$snapshot_id" ]]; then
        # Fallback: get latest snapshot if pre-restore not found
        log_warn "Pre-restore snapshot not found in state, falling back to latest" "rollback"
        snapshot_id="$(kopia_get_latest_snapshot "$SCRIPT_DIR/backup")"
    fi

    if [[ -z "$snapshot_id" ]]; then
        log_error "No snapshot found for rollback" "rollback"
        return 7
    fi

    log_info "Restoring from pre-restore snapshot" "rollback" '{"snapshot_id":"'"$snapshot_id"'"}'

    # Restore from snapshot (exit code 7: rollback failed)
    kopia_restore "$snapshot_id" "$SCRIPT_DIR/backup" || {
        log_error "Failed to rollback restore" "rollback"
        return 7
    }

    # Clear pre-restore snapshot from state
    state_set "pre_restore_snapshot" ""

    log_info "Rollback completed" "rollback"
}

# Parse arguments and run main
parse_args "$@"
main