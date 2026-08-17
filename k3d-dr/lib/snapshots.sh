#!/usr/bin/env bash
# snapshots.sh - Snapshot listing and interactive selection library
# FR-027: Support multiple snapshot selection methods

set -euo pipefail

# Snapshot selection state
declare SNAPSHOT_LIST=""
declare SNAPSHOT_COUNT="0"

# List all snapshots
# Usage: snapshots_list_all [path] [tag]
snapshots_list_all() {
    local path="${1:-}"
    local tag="${2:-}"

    local cmd="kopia snapshot list --json"
    [[ -n "$path" ]] && cmd+=" --path $path"
    [[ -n "$tag" ]] && cmd+=" --tag $tag"

    SNAPSHOT_LIST="$($cmd 2>/dev/null || echo "[]")"
    SNAPSHOT_COUNT="$(echo "$SNAPSHOT_LIST" | jq length)"
}

# Get snapshot count
# Usage: snapshots_count
snapshots_count() {
    echo "$SNAPSHOT_COUNT"
}

# Get snapshot by index
# Usage: snapshots_get <index>
snapshots_get() {
    local index="$1"

    echo "$SNAPSHOT_LIST" | jq -r ".[$index]"
}

# Get snapshot ID by index
# Usage: snapshots_get_id <index>
snapshots_get_id() {
    local index="$1"

    echo "$SNAPSHOT_LIST" | jq -r ".[$index].id"
}

# Get snapshot timestamp by index
# Usage: snapshots_get_timestamp <index>
snapshots_get_timestamp() {
    local index="$1"

    echo "$SNAPSHOT_LIST" | jq -r ".[$index].startTime"
}

# Get snapshot size by index
# Usage: snapshots_get_size <index>
snapshots_get_size() {
    local index="$1"

    echo "$SNAPSHOT_LIST" | jq -r ".[$index].size // 0"
}

# List snapshots in human-readable format
# Usage: snapshots_list_human [path] [tag]
snapshots_list_human() {
    local path="${1:-}"
    local tag="${2:-}"

    snapshots_list_all "$path" "$tag"

    if [[ "$SNAPSHOT_COUNT" -eq 0 ]]; then
        echo "No snapshots found"
        return 0
    fi

    echo "Available snapshots:"
    echo "-------------------"

    for i in $(seq 0 $((SNAPSHOT_COUNT - 1))); do
        local id timestamp size
        id="$(snapshots_get_id "$i")"
        timestamp="$(snapshots_get_timestamp "$i")"
        size="$(snapshots_get_size "$i")"

        printf "[%d] %s - %s (%s bytes)\n" "$i" "$id" "$timestamp" "$size"
    done
}

# Interactive snapshot selection
# Usage: snapshots_interactive_select [path] [tag]
# Returns: selected snapshot ID
snapshots_interactive_select() {
    local path="${1:-}"
    local tag="${2:-}"

    snapshots_list_all "$path" "$tag"

    if [[ "$SNAPSHOT_COUNT" -eq 0 ]]; then
        echo "No snapshots found" >&2
        return 1
    fi

    # Display snapshots
    snapshots_list_human "$path" "$tag"

    # Prompt for selection
    echo ""
    read -r -p "Enter snapshot number [0-$((SNAPSHOT_COUNT - 1))] (default: 0): " selection

    # Default to 0 if empty
    selection="${selection:-0}"

    # Validate selection
    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [[ "$selection" -ge "$SNAPSHOT_COUNT" ]]; then
        echo "Invalid selection" >&2
        return 1
    fi

    snapshots_get_id "$selection"
}

# Find snapshot by timestamp
# Usage: snapshots_find_by_timestamp <timestamp>
snapshots_find_by_timestamp() {
    local timestamp="$1"

    echo "$SNAPSHOT_LIST" | jq -r --arg ts "$timestamp" '.[] | select(.startTime == $ts) | .id'
}

# Find snapshots by tag
# Usage: snapshots_find_by_tag <tag>
snapshots_find_by_tag() {
    local tag="$1"

    echo "$SNAPSHOT_LIST" | jq -r --arg tag "$tag" '.[] | select(.tags[]? == $tag) | .id'
}

# Export functions
export -f snapshots_list_all snapshots_count snapshots_get snapshots_get_id snapshots_get_timestamp snapshots_get_size snapshots_list_human snapshots_interactive_select snapshots_find_by_timestamp snapshots_find_by_tag
export SNAPSHOT_LIST SNAPSHOT_COUNT