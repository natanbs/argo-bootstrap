#!/usr/bin/env bash
# logging.sh - Structured JSON logging library
# FR-046: Structured JSON logs with fields: timestamp, level, message, component, metadata

set -euo pipefail

# Log levels
LOG_LEVEL_DEBUG="debug"
LOG_LEVEL_INFO="info"
LOG_LEVEL_WARN="warn"
LOG_LEVEL_ERROR="error"

# Default log level (can be overridden via environment variable)
LOG_LEVEL="${LOG_LEVEL:-$LOG_LEVEL_INFO}"

# Log format: "json" for structured JSON output, "text" for plain text (FR-046)
LOG_FORMAT="${LOG_FORMAT:-text}"

# Log file path (can be overridden via environment variable)
LOG_FILE="${LOG_FILE:-}"

# Color codes for terminal output
_get_color() {
    local level="$1"
    case "$level" in
        debug) echo "\033[36m" ;;   # Cyan
        info) echo "\033[32m" ;;    # Green
        warn) echo "\033[33m" ;;    # Yellow
        error) echo "\033[31m" ;;   # Red
        *) echo "" ;;
    esac
}
COLOR_RESET="\033[0m"

# Check if a log level should be emitted
_should_log() {
    local level="$1"
    local levels=("$LOG_LEVEL_DEBUG" "$LOG_LEVEL_INFO" "$LOG_LEVEL_WARN" "$LOG_LEVEL_ERROR")
    local current_idx=0
    local target_idx=0

    for i in "${!levels[@]}"; do
        if [[ "${levels[$i]}" == "$LOG_LEVEL" ]]; then
            current_idx=$i
        fi
        if [[ "${levels[$i]}" == "$level" ]]; then
            target_idx=$i
        fi
    done

    [[ $target_idx -ge $current_idx ]]
}

# Escape string for JSON
_json_escape() {
    local str="$1"
    str="${str//\\/\\\\}"
    str="${str//\"/\\\"}"
    str="${str//$'\n'/\\n}"
    str="${str//$'\t'/\\t}"
    str="${str//$'\r'/}"
    echo -n "$str"
}

# Format log entry for output (FR-007)
# Usage: _format_log_entry <format> <timestamp> <level> <message> [component] [metadata]
_format_log_entry() {
    local format="$1"
    local timestamp="$2"
    local level="$3"
    local message="$4"
    local component="${5:-}"
    local metadata="${6:-}"

    if [[ "$format" == "json" ]]; then
        local json="{"
        json+="\"timestamp\":\"${timestamp}\","
        json+="\"level\":\"${level}\","
        json+="\"message\":\"$(_json_escape "$message")\""

        if [[ -n "$component" ]]; then
            json+=",\"component\":\"$(_json_escape "$component")\""
        fi

        if [[ -n "$metadata" ]]; then
            json+=",\"metadata\":${metadata}"
        fi

        json+="}"
        echo "$json"
    else
        local entry=""
        if [[ -n "$component" ]]; then
            entry="[$timestamp] $level [$component] $message"
        else
            entry="[$timestamp] $level $message"
        fi
        echo "$entry"
    fi
}

# Core logging function
_log() {
    local level="$1"
    local message="$2"
    local component="${3:-}"
    local metadata="${4:-}"

    if ! _should_log "$level"; then
        return 0
    fi

    local timestamp
    timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

    # Uppercase level for contract compliance
    local upper_level
    upper_level="$(echo "$level" | tr '[:lower:]' '[:upper:]')"

    # Format entry using helper (FR-007)
    local entry
    entry="$(_format_log_entry "$LOG_FORMAT" "$timestamp" "$upper_level" "$message" "$component" "$metadata")"

    if [[ "$LOG_FORMAT" == "json" ]]; then
        echo "$entry"
    else
        # Plain text output with optional color
        local color=""
        if [[ -t 1 ]]; then
            color="$(_get_color "$level")"
        fi

        if [[ -n "$color" ]]; then
            echo -e "${color}${entry}${COLOR_RESET}"
        else
            echo "$entry"
        fi
    fi

    # Append to log file if configured
    if [[ -n "$LOG_FILE" ]]; then
        local file_entry
        file_entry="$(_format_log_entry "$LOG_FORMAT" "$timestamp" "$upper_level" "$message" "$component" "$metadata")"
        echo "$file_entry" >> "$LOG_FILE"
    fi
}

# Public logging functions
log_debug() {
    _log "$LOG_LEVEL_DEBUG" "$1" "${2:-}" "${3:-}"
}

log_info() {
    _log "$LOG_LEVEL_INFO" "$1" "${2:-}" "${3:-}"
}

log_warn() {
    _log "$LOG_LEVEL_WARN" "$1" "${2:-}" "${3:-}"
}

log_error() {
    _log "$LOG_LEVEL_ERROR" "$1" "${2:-}" "${3:-}"
}

# Log with metadata as key-value pairs
# Usage: log_info "message" "component" '{"key":"value"}'
log_with_metadata() {
    local level="$1"
    local message="$2"
    local component="$3"
    shift 3

    local metadata="{"
    local first=true
    while [[ $# -gt 0 ]]; do
        if $first; then
            first=false
        else
            metadata+=","
        fi
        metadata+="\"$(_json_escape "$1")\":\"$(_json_escape "$2")\""
        shift 2
    done
    metadata+="}"

    _log "$level" "$message" "$component" "$metadata"
}

# Set log level
set_log_level() {
    local level="$1"
    LOG_LEVEL="$level"
}

# Set log file
set_log_file() {
    LOG_FILE="$1"
    mkdir -p "$(dirname "$LOG_FILE")"
}

# Initialize logging from environment
init_logging() {
    LOG_LEVEL="${LOG_LEVEL:-$LOG_LEVEL_INFO}"
    LOG_FORMAT="${LOG_FORMAT:-text}"
    LOG_FILE="${LOG_FILE:-}"

    if [[ -n "$LOG_FILE" ]]; then
        set_log_file "$LOG_FILE"
    fi
}

# Export functions
export -f log_debug log_info log_warn log_error log_with_metadata set_log_level set_log_file init_logging
export LOG_LEVEL LOG_FORMAT LOG_FILE