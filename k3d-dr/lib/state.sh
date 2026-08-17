#!/usr/bin/env bash
# state.sh - Backup state tracking library
# FR-047: Backup resume capability by tracking completed phases

set -euo pipefail

# State file path
declare STATE_FILE=""
declare STATE_DIR=""

# Initialize state tracking
# Usage: state_init <backup_dir>
state_init() {
    local backup_dir="$1"

    STATE_DIR="$backup_dir/.state"
    mkdir -p "$STATE_DIR"

    STATE_FILE="$STATE_DIR/backup_state.json"
}

# Get current state
# Usage: state_get
state_get() {
    if [[ -f "$STATE_FILE" ]]; then
        cat "$STATE_FILE"
    else
        echo "{}"
    fi
}

# Set state
# Usage: state_set <key> <value>
state_set() {
    local key="$1"
    local value="$2"

    local current_state
    current_state="$(state_get)"

    local new_state
    new_state="$(echo "$current_state" | jq --arg key "$key" --arg value "$value" '.[$key] = $value')"

    echo "$new_state" > "$STATE_FILE"
}

# Get state value
# Usage: state_get_value <key>
state_get_value() {
    local key="$1"

    local current_state
    current_state="$(state_get)"

    echo "$current_state" | jq -r --arg key "$key" '.[$key] // empty'
}

# Check if phase is completed
# Usage: state_is_completed <phase>
state_is_completed() {
    local phase="$1"

    local value
    value="$(state_get_value "$phase")"

    [[ "$value" == "completed" ]]
}

# Mark phase as completed
# Usage: state_mark_completed <phase>
state_mark_completed() {
    local phase="$1"

    state_set "$phase" "completed"
}

# Mark phase as in progress
# Usage: state_mark_in_progress <phase>
state_mark_in_progress() {
    local phase="$1"

    state_set "$phase" "in_progress"
}

# Mark phase as failed
# Usage: state_mark_failed <phase> <error_message>
state_mark_failed() {
    local phase="$1"
    local error_message="$2"

    state_set "$phase" "failed:$error_message"
}

# Get failed phase message
# Usage: state_get_failure <phase>
state_get_failure() {
    local phase="$1"

    local value
    value="$(state_get_value "$phase")"

    if [[ "$value" == failed:* ]]; then
        echo "${value#failed:}"
    fi
}

# Clear state
# Usage: state_clear
state_clear() {
    rm -f "$STATE_FILE"
}

# Get all completed phases
# Usage: state_get_completed
state_get_completed() {
    local current_state
    current_state="$(state_get)"

    echo "$current_state" | jq -r 'to_entries[] | select(.value == "completed") | .key'
}

# Get all failed phases
# Usage: state_get_failed
state_get_failed() {
    local current_state
    current_state="$(state_get)"

    echo "$current_state" | jq -r 'to_entries[] | select(.value | startswith("failed:")) | .key'
}

# Export functions
export -f state_init state_get state_set state_get_value state_is_completed state_mark_completed state_mark_in_progress state_mark_failed state_get_failure state_clear state_get_completed state_get_failed
export STATE_FILE STATE_DIR