#!/usr/bin/env bash
# registry.sh - Registry persistence library
# FR-009: Persist k3d local container registry to host directory

set -euo pipefail

# Registry state
declare REGISTRY_NAME=""
declare REGISTRY_PORT="5000"
declare REGISTRY_HOST_DIR=""

# Initialize registry
# Usage: registry_init <cluster_name> <port>
registry_init() {
    local cluster_name="$1"
    local port="${2:-5000}"

    REGISTRY_NAME="${cluster_name}-registry"
    REGISTRY_PORT="$port"
    REGISTRY_HOST_DIR="/tmp/k3d-dr/$cluster_name/registry"
}

# Check if registry exists
# Usage: registry_exists
registry_exists() {
    docker volume ls --format '{{.Name}}' | grep -q "^${REGISTRY_NAME}$"
}

# Create registry
# Usage: registry_create
registry_create() {
    if registry_exists; then
        return 0
    fi

    mkdir -p "$REGISTRY_HOST_DIR"

    docker volume create "$REGISTRY_NAME" || {
        error_report "E026" "Failed to create registry volume" "registry"
        return 1
    }
}

# Delete registry
# Usage: registry_delete
registry_delete() {
    if ! registry_exists; then
        return 0
    fi

    docker volume rm "$REGISTRY_NAME" || {
        error_report "E026" "Failed to delete registry volume" "registry"
        return 1
    }
}

# Backup registry data
# Usage: registry_backup
registry_backup() {
    if ! registry_exists; then
        return 0
    fi

    log_info "Backing up container registry" "registry"

    # Create temporary directory for registry data
    local tmp_dir="/tmp/k3d-dr/registry-backup"
    mkdir -p "$tmp_dir"

    # Run registry container and copy data
    docker run --rm \
        -v "$REGISTRY_NAME:/var/lib/registry:ro" \
        -v "$tmp_dir:/backup" \
        alpine tar -czf /backup/registry-data.tar.gz -C /var/lib/registry .

    # Backup with Kopia
    kopia_snapshot "$tmp_dir" "registry" || {
        error_report "E027" "Failed to backup registry data" "registry"
        return 1
    }

    # Clean up
    rm -rf "$tmp_dir"
}

# Restore registry data
# Usage: registry_restore
registry_restore() {
    if ! registry_exists; then
        return 0
    fi

    log_info "Restoring container registry" "registry"

    # Get latest snapshot
    local snapshot_id
    snapshot_id="$(kopia_get_latest_snapshot "/tmp/k3d-dr/registry-backup")"

    if [[ -z "$snapshot_id" ]]; then
        log_warn "No registry backup found" "registry"
        return 0
    fi

    # Create temporary directory
    local tmp_dir="/tmp/k3d-dr/registry-restore"
    mkdir -p "$tmp_dir"

    # Restore from snapshot
    kopia_restore "$snapshot_id" "$tmp_dir" || {
        error_report "E026" "Failed to restore registry data" "registry"
        return 1
    }

    # Run registry container and restore data
    docker run --rm \
        -v "$REGISTRY_NAME:/var/lib/registry" \
        -v "$tmp_dir:/backup" \
        alpine sh -c "cd /var/lib/registry && tar -xzf /backup/registry-data.tar.gz"

    # Clean up
    rm -rf "$tmp_dir"
}

# Export functions
export -f registry_init registry_exists registry_create registry_delete registry_backup registry_restore
export REGISTRY_NAME REGISTRY_PORT REGISTRY_HOST_DIR