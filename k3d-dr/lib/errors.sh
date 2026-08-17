#!/usr/bin/env bash
# errors.sh - Machine-readable error format library
# FR-051: Error format with fields: error_code, message, component, suggested_remediation

set -euo pipefail

# Error codes
declare -A ERROR_CODES=(
    ["E001"]="Configuration file not found"
    ["E002"]="Configuration file is not readable"
    ["E003"]="Invalid YAML syntax in configuration"
    ["E004"]="Configuration validation failed"
    ["E005"]="Repository not found"
    ["E006"]="Repository path does not exist"
    ["E007"]="Repository is not readable"
    ["E008"]="Kopia repository not initialized"
    ["E009"]="Kopia password not set"
    ["E010"]="Kopia repository corrupted"
    ["E011"]="Vault is not running"
    ["E012"]="Vault is sealed"
    ["E013"]="Vault unseal key not found"
    ["E014"]="Vault unseal key has wrong permissions"
    ["E015"]="k3d is not installed"
    ["E016"]="k3d cluster already exists"
    ["E017"]="k3d cluster does not exist"
    ["E018"]="Docker is not running"
    ["E019"]="Lock acquisition failed"
    ["E020"]="Lock is already held"
    ["E021"]="Database hook failed"
    ["E022"]="Database hook timed out"
    ["E023"]="Port offset out of range"
    ["E024"]="DNS suffix format invalid"
    ["E025"]="Backup state file corrupted"
    ["E026"]="Restore failed"
    ["E027"]="Backup failed"
    ["E028"]="Health check failed"
    ["E029"]="Component not ready"
    ["E030"]="Permission denied"
)

# Error state
declare -g LAST_ERROR_CODE=""
declare -g LAST_ERROR_MESSAGE=""
declare -g LAST_ERROR_COMPONENT=""
declare -g LAST_ERROR_REMEDIATION=""

# Create machine-readable error
# Usage: error_create <error_code> <message> <component> [remediation]
error_create() {
    local error_code="$1"
    local message="$2"
    local component="$3"
    local remediation="${4:-}"

    # Store last error
    LAST_ERROR_CODE="$error_code"
    LAST_ERROR_MESSAGE="$message"
    LAST_ERROR_COMPONENT="$component"
    LAST_ERROR_REMEDIATION="$remediation"

    # Build JSON error
    local json="{"
    json+="\"timestamp\":\"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\","
    json+="\"error_code\":\"${error_code}\","
    json+="\"message\":\"$(_json_escape "$message")\","
    json+="\"component\":\"$(_json_escape "$component")\""

    if [[ -n "$remediation" ]]; then
        json+=",\"suggested_remediation\":\"$(_json_escape "$remediation")\""
    fi

    json+="}"

    echo "$json"
}

# Report error to stderr
# Usage: error_report <error_code> <message> <component> [remediation]
error_report() {
    local error_code="$1"
    local message="$2"
    local component="$3"
    local remediation="${4:-}"

    local json
    json="$(error_create "$error_code" "$message" "$component" "$remediation")"

    # Output to stderr
    echo "ERROR: $json" >&2

    # Also log if logging library is available
    if command -v log_error &>/dev/null; then
        log_error "$message" "$component" "$json"
    fi
}

# Get last error details
# Usage: error_get_last
error_get_last() {
    echo "code=$LAST_ERROR_CODE"
    echo "message=$LAST_ERROR_MESSAGE"
    echo "component=$LAST_ERROR_COMPONENT"
    echo "remediation=$LAST_ERROR_REMEDIATION"
}

# Clear last error
# Usage: error_clear
error_clear() {
    LAST_ERROR_CODE=""
    LAST_ERROR_MESSAGE=""
    LAST_ERROR_COMPONENT=""
    LAST_ERROR_REMEDIATION=""
}

# Check if last error matches code
# Usage: error_is <error_code>
error_is() {
    local error_code="$1"
    [[ "$LAST_ERROR_CODE" == "$error_code" ]]
}

# Create error with automatic code lookup
# Usage: error_report_auto <component> <message>
error_report_auto() {
    local component="$1"
    local message="$2"

    # Try to find matching error code
    local error_code="E999"
    for code in "${!ERROR_CODES[@]}"; do
        if [[ "${ERROR_CODES[$code]}" == "$message" ]]; then
            error_code="$code"
            break
        fi
    done

    error_report "$error_code" "$message" "$component"
}

# Create error with remediation
# Usage: error_report_with_remediation <component> <message> <remediation>
error_report_with_remediation() {
    local component="$1"
    local message="$2"
    local remediation="$3"

    local error_code="E999"
    for code in "${!ERROR_CODES[@]}"; do
        if [[ "${ERROR_CODES[$code]}" == "$message" ]]; then
            error_code="$code"
            break
        fi
    done

    error_report "$error_code" "$message" "$component" "$remediation"
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

# Export functions
export -f error_create error_report error_get_last error_clear error_is error_report_auto error_report_with_remediation
export ERROR_CODES LAST_ERROR_CODE LAST_ERROR_MESSAGE LAST_ERROR_COMPONENT LAST_ERROR_REMEDIATION