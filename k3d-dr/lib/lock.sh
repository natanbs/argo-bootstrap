#!/usr/bin/env bash
# lock.sh - Exclusive lock management library
# FR-048: Prevent concurrent backup operations with exclusive lock

set -euo pipefail

# Lock file paths
LOCK_DIR="${LOCK_DIR:-/tmp/k3d-dr}"
LOCK_FILE_BACKUP="${LOCK_DIR}/backup.lock"
LOCK_FILE_RESTORE="${LOCK_DIR}/restore.lock"

# Lock file descriptor
declare -g LOCK_FD=""

# Initialize lock directory
_init_lock_dir() {
    mkdir -p "$LOCK_DIR"
}

# Acquire exclusive lock
# Usage: lock_acquire <lock_type> <timeout_seconds>
# Returns: 0 on success, 1 on timeout or failure
lock_acquire() {
    local lock_type="$1"
    local timeout="${2:-30}"

    local lock_file
    case "$lock_type" in
        backup)
            lock_file="$LOCK_FILE_BACKUP"
            ;;
        restore)
            lock_file="$LOCK_FILE_RESTORE"
            ;;
        *)
            echo "Error: Invalid lock type: $lock_type" >&2
            return 1
            ;;
    esac

    _init_lock_dir

    # Check if lock file exists and if the process is still running
    if [[ -f "$lock_file" ]]; then
        local pid
        pid="$(cat "$lock_file" 2>/dev/null || echo "")"

        if [[ -n "$pid" ]]; then
            # Check if process is still running
            if kill -0 "$pid" 2>/dev/null; then
                echo "Error: Another $lock_type operation is running (PID: $pid)" >&2
                echo "Lock file: $lock_file" >&2
                echo "Use 'rm -f $lock_file' to force remove the lock if the process is no longer running" >&2
                return 1
            else
                # Process is dead, remove stale lock
                rm -f "$lock_file"
            fi
        else
            # Lock file exists but is empty, remove it
            rm -f "$lock_file"
        fi
    fi

    # Try to acquire lock with timeout
    local start_time
    start_time="$(date +%s)"

    while true; do
        # Use mkdir for atomic lock creation
        if mkdir "$lock_file.lock" 2>/dev/null; then
            # Write PID to lock file
            echo "$$" > "$lock_file"
            LOCK_FD="$lock_file"
            return 0
        fi

        # Check timeout
        local current_time
        current_time="$(date +%s)"
        local elapsed=$((current_time - start_time))

        if [[ $elapsed -ge $timeout ]]; then
            echo "Error: Timeout waiting for lock after ${timeout}s" >&2
            echo "Lock file: $lock_file" >&2
            return 1
        fi

        # Wait before retrying
        sleep 1
    done
}

# Release exclusive lock
# Usage: lock_release <lock_type>
lock_release() {
    local lock_type="$1"

    local lock_file
    case "$lock_type" in
        backup)
            lock_file="$LOCK_FILE_BACKUP"
            ;;
        restore)
            lock_file="$LOCK_FILE_RESTORE"
            ;;
        *)
            echo "Error: Invalid lock type: $lock_type" >&2
            return 1
            ;;
    esac

    # Remove lock directory and file
    rm -rf "$lock_file.lock" 2>/dev/null || true
    rm -f "$lock_file" 2>/dev/null || true
}

# Check if lock is held
# Usage: lock_is_held <lock_type>
# Returns: 0 if lock is held, 1 if not
lock_is_held() {
    local lock_type="$1"

    local lock_file
    case "$lock_type" in
        backup)
            lock_file="$LOCK_FILE_BACKUP"
            ;;
        restore)
            lock_file="$LOCK_FILE_RESTORE"
            ;;
        *)
            return 1
            ;;
    esac

    if [[ -f "$lock_file" ]]; then
        local pid
        pid="$(cat "$lock_file" 2>/dev/null || echo "")"

        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
    fi

    return 1
}

# Get lock holder PID
# Usage: lock_get_holder <lock_type>
# Returns: PID or empty string
lock_get_holder() {
    local lock_type="$1"

    local lock_file
    case "$lock_type" in
        backup)
            lock_file="$LOCK_FILE_BACKUP"
            ;;
        restore)
            lock_file="$LOCK_FILE_RESTORE"
            ;;
        *)
            echo ""
            return 1
            ;;
    esac

    if [[ -f "$lock_file" ]]; then
        cat "$lock_file" 2>/dev/null || echo ""
    else
        echo ""
    fi
}

# Force remove lock (use with caution)
# Usage: lock_force_remove <lock_type>
lock_force_remove() {
    local lock_type="$1"

    local lock_file
    case "$lock_type" in
        backup)
            lock_file="$LOCK_FILE_BACKUP"
            ;;
        restore)
            lock_file="$LOCK_FILE_RESTORE"
            ;;
        *)
            echo "Error: Invalid lock type: $lock_type" >&2
            return 1
            ;;
    esac

    local pid
    pid="$(lock_get_holder "$lock_type")"

    if [[ -n "$pid" ]]; then
        echo "Warning: Force removing lock held by PID: $pid" >&2
        echo "Killing process $pid..." >&2
        kill -9 "$pid" 2>/dev/null || true
    fi

    rm -rf "$lock_file.lock" 2>/dev/null || true
    rm -f "$lock_file" 2>/dev/null || true
}

# Export functions
export -f lock_acquire lock_release lock_is_held lock_get_holder lock_force_remove
export LOCK_DIR LOCK_FILE_BACKUP LOCK_FILE_RESTORE