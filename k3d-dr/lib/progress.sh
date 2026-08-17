#!/usr/bin/env bash
# progress.sh - Progress reporting library
# FR-044: Backup progress as percentage with phase name
# FR-045: Restore progress as percentage with ETA

set -euo pipefail

# Progress tracking state
declare PROGRESS_TOTAL=0
declare PROGRESS_CURRENT=0
declare PROGRESS_PHASE=""
declare PROGRESS_START_TIME=""
declare PROGRESS_OPERATION=""

# Initialize progress tracking
# Usage: progress_init <total> <operation> <phase>
progress_init() {
    local total="$1"
    local operation="$2"
    local phase="${3:-}"

    PROGRESS_TOTAL="$total"
    PROGRESS_CURRENT=0
    PROGRESS_PHASE="$phase"
    PROGRESS_START_TIME="$(date +%s)"
    PROGRESS_OPERATION="$operation"

    _report_progress
}

# Update progress
# Usage: progress_update <current> <phase>
progress_update() {
    local current="$1"
    local phase="${2:-}"

    PROGRESS_CURRENT="$current"
    [[ -n "$phase" ]] && PROGRESS_PHASE="$phase"

    _report_progress
}

# Increment progress by 1
# Usage: progress_increment <phase>
progress_increment() {
    local phase="${1:-}"

    PROGRESS_CURRENT=$((PROGRESS_CURRENT + 1))
    [[ -n "$phase" ]] && PROGRESS_PHASE="$phase"

    _report_progress
}

# Complete progress
# Usage: progress_complete
progress_complete() {
    PROGRESS_CURRENT="$PROGRESS_TOTAL"
    PROGRESS_PHASE="Completed"

    _report_progress
}

# Calculate ETA based on current progress
_calculate_eta() {
    if [[ $PROGRESS_CURRENT -eq 0 ]]; then
        echo "unknown"
        return
    fi

    local current_time
    current_time="$(date +%s)"
    local elapsed=$((current_time - PROGRESS_START_TIME))

    if [[ $elapsed -eq 0 ]]; then
        echo "unknown"
        return
    fi

    local rate=$(echo "scale=2; $PROGRESS_CURRENT / $elapsed" | bc 2>/dev/null || echo "1")
    local remaining=$((PROGRESS_TOTAL - PROGRESS_CURRENT))
    local eta=$(echo "scale=0; $remaining / $rate" | bc 2>/dev/null || echo "0")

    # Format as minutes:seconds
    local minutes=$((eta / 60))
    local seconds=$((eta % 60))
    printf "%dm%02ds" "$minutes" "$seconds"
}

# Calculate percentage
_calculate_percentage() {
    if [[ $PROGRESS_TOTAL -eq 0 ]]; then
        echo 0
        return
    fi

    echo $(( (PROGRESS_CURRENT * 100) / PROGRESS_TOTAL ))
}

# Report progress
_report_progress() {
    local percentage
    percentage="$(_calculate_percentage)"

    local eta=""
    if [[ "$PROGRESS_CURRENT" -lt "$PROGRESS_TOTAL" ]]; then
        eta=" (ETA: $(_calculate_eta))"
    fi

    # Human-readable progress line
    local progress_line="${PROGRESS_OPERATION}: ${PROGRESS_PHASE} [${percentage}%] (${PROGRESS_CURRENT}/${PROGRESS_TOTAL})${eta}"

    # Machine-readable JSON progress
    local json="{"
    json+="\"timestamp\":\"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\","
    json+="\"operation\":\"${PROGRESS_OPERATION}\","
    json+="\"phase\":\"${PROGRESS_PHASE}\","
    json+="\"percentage\":${percentage},"
    json+="\"current\":${PROGRESS_CURRENT},"
    json+="\"total\":${PROGRESS_TOTAL}"

    if [[ "$PROGRESS_CURRENT" -lt "$PROGRESS_TOTAL" ]]; then
        json+=",\"eta\":\"$(_calculate_eta)\""
    fi

    json+="}"

    # Output to stderr (to not interfere with stdout capture)
    echo "$progress_line" >&2

    # Also log if logging library is available
    if command -v log_info &>/dev/null; then
        log_info "$progress_line" "progress" "$json"
    fi
}

# Create a progress tracker for multiple phases
# Usage: progress_create_tracker <total_phases> <operation>
progress_create_tracker() {
    local total_phases="$1"
    local operation="$2"

    declare PROGRESS_TRACKER_TOTAL="$total_phases"
    declare PROGRESS_TRACKER_CURRENT=0
    declare PROGRESS_TRACKER_OPERATION="$operation"
}

# Update phase progress
# Usage: progress_phase_start <phase_name>
progress_phase_start() {
    local phase_name="$1"

    PROGRESS_TRACKER_CURRENT=$((PROGRESS_TRACKER_CURRENT + 1))
    local percentage=$(( (PROGRESS_TRACKER_CURRENT * 100) / PROGRESS_TRACKER_TOTAL ))

    echo "${PROGRESS_TRACKER_OPERATION}: Phase ${PROGRESS_TRACKER_CURRENT}/${PROGRESS_TRACKER_TOTAL} - ${phase_name} [${percentage}%]" >&2
}

# Export functions
export -f progress_init progress_update progress_increment progress_complete progress_create_tracker progress_phase_start
export PROGRESS_TOTAL PROGRESS_CURRENT PROGRESS_PHASE PROGRESS_START_TIME PROGRESS_OPERATION