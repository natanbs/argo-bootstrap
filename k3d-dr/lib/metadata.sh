#!/usr/bin/env bash
# metadata.sh - Cluster metadata collection library
# FR-011: Collect and record cluster bootstrap metadata

set -euo pipefail

# Metadata state
declare -g METADATA_FILE=""
declare -g METADATA_DIR=""

# Initialize metadata collection
# Usage: metadata_init <backup_dir>
metadata_init() {
    local backup_dir="$1"

    METADATA_DIR="$backup_dir/.metadata"
    mkdir -p "$METADATA_DIR"

    METADATA_FILE="$METADATA_DIR/cluster-metadata.json"
}

# Collect cluster metadata
# Usage: metadata_collect
metadata_collect() {
    log_info "Collecting cluster metadata" "metadata"

    local metadata="{}"

    # Collect k3d version
    local k3d_version
    k3d_version="$(k3d version 2>/dev/null | head -1 || echo "unknown")"
    metadata="$(echo "$metadata" | jq --arg v "$k3d_version" '.k3d_version = $v')"

    # Collect Kubernetes version
    local k8s_version
    k8s_version="$(kubectl version --short 2>/dev/null | grep Server | awk '{print $3}' || echo "unknown")"
    metadata="$(echo "$metadata" | jq --arg v "$k8s_version" '.kubernetes_version = $v')"

    # Collect Docker version
    local docker_version
    docker_version="$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo "unknown")"
    metadata="$(echo "$metadata" | jq --arg v "$docker_version" '.docker_version = $v')"

    # Collect Vault version
    local vault_version
    vault_version="$(vault version 2>/dev/null | head -1 || echo "unknown")"
    metadata="$(echo "$metadata" | jq --arg v "$vault_version" '.vault_version = $v')"

    # Collect ESO version (if installed)
    local eso_version
    eso_version="$(kubectl get deployment external-secrets -n external-secrets -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo "not installed")"
    metadata="$(echo "$metadata" | jq --arg v "$eso_version" '.eso_version = $v')"

    # Collect Helm version
    local helm_version
    helm_version="$(helm version --short 2>/dev/null || echo "unknown")"
    metadata="$(echo "$metadata" | jq --arg v "$helm_version" '.helm_version = $v')"

    # Collect repository list
    local repo_count
    repo_count="$(config_get "repositories.count")"
    local repos="[]"
    for i in $(seq 0 $((repo_count - 1))); do
        local name
        name="$(config_get_repository "$i" "name")"
        repos="$(echo "$repos" | jq --arg r "$name" '. += [$r]')"
    done
    metadata="$(echo "$metadata" | jq --argjson r "$repos" '.repositories = $r')"

    # Collect Kopia snapshot IDs
    local snapshot_ids="[]"
    for i in $(seq 0 $((repo_count - 1))); do
        local name path
        name="$(config_get_repository "$i" "name")"
        path="$(config_get_repository "$i" "path")"

        local snapshot_id
        snapshot_id="$(kopia_get_latest_snapshot "$path" 2>/dev/null || echo "")"
        if [[ -n "$snapshot_id" ]]; then
            snapshot_ids="$(echo "$snapshot_ids" | jq --arg n "$name" --arg s "$snapshot_id" '. += [{"name": $n, "snapshot_id": $s}]')"
        fi
    done
    metadata="$(echo "$metadata" | jq --argjson s "$snapshot_ids" '.kopia_snapshots = $s')"

    # Collect collection timestamp
    local timestamp
    timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    metadata="$(echo "$metadata" | jq --arg t "$timestamp" '.collected_at = $t')"

    # Save metadata
    echo "$metadata" > "$METADATA_FILE"

    log_info "Cluster metadata collected" "metadata" '{"file":"'$METADATA_FILE'"}'
}

# Get metadata value
# Usage: metadata_get <key>
metadata_get() {
    local key="$1"

    if [[ -f "$METADATA_FILE" ]]; then
        jq -r --arg key "$key" '.[$key] // empty' "$METADATA_FILE"
    fi
}

# Get all metadata
# Usage: metadata_get_all
metadata_get_all() {
    if [[ -f "$METADATA_FILE" ]]; then
        cat "$METADATA_FILE"
    else
        echo "{}"
    fi
}

# Verify metadata matches current cluster
# Usage: metadata_verify
metadata_verify() {
    if [[ ! -f "$METADATA_FILE" ]]; then
        log_error "No metadata file found" "metadata"
        return 1
    fi

    log_info "Verifying cluster metadata" "metadata"

    local current_metadata
    current_metadata="$(metadata_collect_to_string)"

    local saved_metadata
    saved_metadata="$(cat "$METADATA_FILE")"

    # Compare versions
    local k3d_match k8s_match docker_match
    k3d_match="$(echo "$current_metadata" "$saved_metadata" | jq -s '.[0].k3d_version == .[1].k3d_version')"
    k8s_match="$(echo "$current_metadata" "$saved_metadata" | jq -s '.[0].kubernetes_version == .[1].kubernetes_version')"
    docker_match="$(echo "$current_metadata" "$saved_metadata" | jq -s '.[0].docker_version == .[1].docker_version')"

    if [[ "$k3d_match" == "true" && "$k8s_match" == "true" && "$docker_match" == "true" ]]; then
        log_info "Metadata verification passed" "metadata"
        return 0
    else
        log_warn "Metadata verification failed - versions mismatch" "metadata" '{"k3d_match":'$k3d_match',"k8s_match":'$k8s_match',"docker_match":'$docker_match'}'
        return 1
    fi
}

# Collect metadata to string (without saving)
# Usage: metadata_collect_to_string
metadata_collect_to_string() {
    local metadata="{}"

    # Collect k3d version
    local k3d_version
    k3d_version="$(k3d version 2>/dev/null | head -1 || echo "unknown")"
    metadata="$(echo "$metadata" | jq --arg v "$k3d_version" '.k3d_version = $v')"

    # Collect Kubernetes version
    local k8s_version
    k8s_version="$(kubectl version --short 2>/dev/null | grep Server | awk '{print $3}' || echo "unknown")"
    metadata="$(echo "$metadata" | jq --arg v "$k8s_version" '.kubernetes_version = $v')"

    # Collect Docker version
    local docker_version
    docker_version="$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo "unknown")"
    metadata="$(echo "$metadata" | jq --arg v "$docker_version" '.docker_version = $v')"

    echo "$metadata"
}

# Export functions
export -f metadata_init metadata_collect metadata_get metadata_get_all metadata_verify metadata_collect_to_string
export METADATA_FILE METADATA_DIR