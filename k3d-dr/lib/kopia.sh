#!/usr/bin/env bash
# kopia.sh - Kopia backup engine wrapper library
# FR-003: Kopia as sole backup engine with encrypted local repository
# FR-012: Kopia repository integrity verification
# FR-013: Configurable retention policies

set -euo pipefail

# Kopia state
declare KOPIA_REPO_PATH=""
declare KOPIA_PASSWORD=""

# Initialize Kopia wrapper
# Usage: kopia_init <repo_path> <password_env>
kopia_init() {
    local repo_path="$1"
    local password_env="$2"

    if ! command -v kopia &>/dev/null; then
        error_report "E015" "Kopia is not installed" "kopia" "Install Kopia: https://kopia.io/docs/installation/"
        return 1
    fi

    KOPIA_REPO_PATH="$repo_path"
    KOPIA_PASSWORD="${!password_env:-}"

    if [[ -z "$KOPIA_PASSWORD" ]]; then
        error_report "E009" "Kopia password not set" "kopia" "Set environment variable: export $password_env='your-password'"
        return 1
    fi

    export KOPIA_PASSWORD
}

# Create or connect to Kopia repository
# Usage: kopia_connect
kopia_connect() {
    if [[ ! -d "$KOPIA_REPO_PATH" ]]; then
        # Create new repository
        kopia repository create filesystem --path "$KOPIA_REPO_PATH" --password "$KOPIA_PASSWORD"
    else
        # Connect to existing repository
        kopia repository connect filesystem --path "$KOPIA_REPO_PATH" --password "$KOPIA_PASSWORD" 2>/dev/null || {
            # If connection fails, try creating
            kopia repository create filesystem --path "$KOPIA_REPO_PATH" --password "$KOPIA_PASSWORD"
        }
    fi
}

# Create snapshot of directory
# Usage: kopia_snapshot <source_path> [tag]
kopia_snapshot() {
    local source_path="$1"
    local tag="${2:-}"

    if [[ ! -d "$source_path" ]]; then
        error_report "E006" "Repository path does not exist: $source_path" "kopia" "Create directory: mkdir -p $source_path"
        return 1
    fi

    local cmd="kopia snapshot create $source_path"
    [[ -n "$tag" ]] && cmd+=" --tag $tag"

    if ! $cmd; then
        error_report "E027" "Backup failed for $source_path" "kopia" "Check Kopia logs and repository permissions"
        return 1
    fi
}

# Restore snapshot to directory
# Usage: kopia_restore <snapshot_id> <destination_path>
kopia_restore() {
    local snapshot_id="$1"
    local destination_path="$2"

    mkdir -p "$destination_path"

    if ! kopia snapshot restore "$snapshot_id" --output "$destination_path"; then
        error_report "E026" "Restore failed for snapshot $snapshot_id" "kopia" "Check snapshot ID and destination permissions"
        return 1
    fi
}

# List snapshots with optional filtering
# Usage: kopia_list_snapshots [path] [tag]
kopia_list_snapshots() {
    local path="${1:-}"
    local tag="${2:-}"

    local cmd="kopia snapshot list"
    [[ -n "$path" ]] && cmd+=" --path $path"
    [[ -n "$tag" ]] && cmd+=" --tag $tag"

    $cmd
}

# Get latest snapshot ID for path
# Usage: kopia_get_latest_snapshot <path>
kopia_get_latest_snapshot() {
    local path="$1"

    kopia snapshot list --path "$path" --latest 1 --json | jq -r '.[0].id // empty'
}

# Get snapshot by timestamp
# Usage: kopia_get_snapshot_by_timestamp <path> <timestamp>
kopia_get_snapshot_by_timestamp() {
    local path="$1"
    local timestamp="$2"

    kopia snapshot list --path "$path" --json | jq -r --arg ts "$timestamp" '.[] | select(.startTime == $ts) | .id'
}

# Get snapshots by tag
# Usage: kopia_get_snapshots_by_tag <tag>
kopia_get_snapshots_by_tag() {
    local tag="$1"

    kopia snapshot list --tag "$tag" --json
}

# Verify repository integrity
# Usage: kopia_verify
kopia_verify() {
    if ! kopia repository verify --password "$KOPIA_PASSWORD"; then
        error_report "E010" "Kopia repository verification failed" "kopia" "Repository may be corrupted. Consider re-initializing."
        return 1
    fi
}

# Apply retention policy
# Usage: kopia_retention <daily> <weekly> <monthly>
kopia_retention() {
    local daily="$1"
    local weekly="$2"
    local monthly="$3"

    kopia policy set --keep-latest "$daily" --keep-daily "$daily" --keep-weekly "$weekly" --keep-monthly "$monthly"
}

# Delete old snapshots based on retention
# Usage: kopia_delete_old_snapshots
kopia_delete_old_snapshots() {
    kopia snapshot delete --delete-all --confirm
}

# Get repository information
# Usage: kopia_info
kopia_info() {
    kopia repository status
}

# Get snapshot count
# Usage: kopia_snapshot_count [path]
kopia_snapshot_count() {
    local path="${1:-}"

    local cmd="kopia snapshot list"
    [[ -n "$path" ]] && cmd+=" --path $path"

    $cmd | wc -l
}

# Check if repository is accessible
# Usage: kopia_check_access
kopia_check_access() {
    if [[ ! -d "$KOPIA_REPO_PATH" ]]; then
        return 1
    fi

    if [[ ! -r "$KOPIA_REPO_PATH" ]]; then
        return 1
    fi

    # Try to connect to repository
    kopia repository connect filesystem --path "$KOPIA_REPO_PATH" --password "$KOPIA_PASSWORD" &>/dev/null
}

# Get repository status
# Usage: kopia_status
kopia_status() {
    kopia repository status 2>/dev/null || echo "disconnected"
}

# Check if repository is initialized
# Usage: kopia_is_initialized
kopia_is_initialized() {
    [[ -f "$KOPIA_REPO_PATH/kopia.config" ]]
}

# Export functions
export -f kopia_init kopia_connect kopia_snapshot kopia_restore kopia_list_snapshots kopia_get_latest_snapshot kopia_get_snapshot_by_timestamp kopia_get_snapshots_by_tag kopia_verify kopia_retention kopia_delete_old_snapshots kopia_info kopia_snapshot_count kopia_check_access kopia_status kopia_is_initialized
export KOPIA_REPO_PATH KOPIA_PASSWORD