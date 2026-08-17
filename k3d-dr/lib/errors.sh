#!/usr/bin/env bash
# errors.sh - Machine-readable error format library
# FR-051: Error format with fields: error_code, message, component, suggested_remediation

set -euo pipefail

# Error codes
_get_error_message() {
    local code="$1"
    case "$code" in
        E001) echo "Configuration file not found" ;;
        E002) echo "Configuration file is not readable" ;;
        E003) echo "Invalid YAML syntax in configuration" ;;
        E004) echo "Configuration validation failed" ;;
        E005) echo "Repository not found" ;;
        E006) echo "Repository path does not exist" ;;
        E007) echo "Repository is not readable" ;;
        E008) echo "Kopia repository not initialized" ;;
        E009) echo "Kopia password not set" ;;
        E010) echo "Kopia repository corrupted" ;;
        E011) echo "Vault is not running" ;;
        E012) echo "Vault is sealed" ;;
        E013) echo "Vault unseal key not found" ;;
        E014) echo "Vault unseal key has wrong permissions" ;;
        E015) echo "k3d is not installed" ;;
        E016) echo "k3d cluster already exists" ;;
        E017) echo "k3d cluster does not exist" ;;
        E018) echo "Docker is not running" ;;
        E019) echo "Lock acquisition failed" ;;
        E020) echo "Lock is already held" ;;
        E021) echo "Database hook failed" ;;
        E022) echo "Database hook timed out" ;;
        E023) echo "Port offset out of range" ;;
        E024) echo "DNS suffix format invalid" ;;
        E025) echo "Backup state file corrupted" ;;
        E026) echo "Restore failed" ;;
        E027) echo "Backup failed" ;;
        E028) echo "Health check failed" ;;
        E029) echo "Component not ready" ;;
        E030) echo "Permission denied" ;;
        *) echo "Unknown error" ;;
    esac
}

# Error state
declare LAST_ERROR_CODE=""
declare LAST_ERROR_MESSAGE=""
declare LAST_ERROR_COMPONENT=""
declare LAST_ERROR_REMEDIATION=""

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
    for code in E001 E002 E003 E004 E005 E006 E007 E008 E009 E010 E011 E012 E013 E014 E015 E016 E017 E018 E019 E020 E021 E022 E023 E024 E025 E026 E027 E028 E029 E030; do
        if [[ "$(_get_error_message "$code")" == "$message" ]]; then
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
    for code in E001 E002 E003 E004 E005 E006 E007 E008 E009 E010 E011 E012 E013 E014 E015 E016 E017 E018 E019 E020 E021 E022 E023 E024 E025 E026 E027 E028 E029 E030; do
        if [[ "$(_get_error_message "$code")" == "$message" ]]; then
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
export -f error_create error_report error_get_last error_clear error_is error_report_auto error_report_with_remediation _get_error_message
export LAST_ERROR_CODE LAST_ERROR_MESSAGE LAST_ERROR_COMPONENT LAST_ERROR_REMEDIATION

# Partial failure tracking (FR-049)
declare PARTIAL_FAILURES=()
declare PARTIAL_FAILURE_COUNT=0

# Add partial failure
# Usage: error_add_partial <component> <message> [remediation]
error_add_partial() {
    local component="$1"
    local message="$2"
    local remediation="${3:-}"

    PARTIAL_FAILURES+=("$(error_create "E021" "$message" "$component" "$remediation")")
    PARTIAL_FAILURE_COUNT=$((PARTIAL_FAILURE_COUNT + 1))
}

# Get partial failures count
# Usage: error_get_partial_count
error_get_partial_count() {
    echo "$PARTIAL_FAILURE_COUNT"
}

# Get partial failures
# Usage: error_get_partials
error_get_partials() {
    for failure in "${PARTIAL_FAILURES[@]}"; do
        echo "$failure"
    done
}

# Check if there are partial failures
# Usage: error_has_partials
error_has_partials() {
    [[ $PARTIAL_FAILURE_COUNT -gt 0 ]]
}

# Clear partial failures
# Usage: error_clear_partials
error_clear_partials() {
    PARTIAL_FAILURES=()
    PARTIAL_FAILURE_COUNT=0
}

# Create partial failure summary
# Usage: error_partial_summary
error_partial_summary() {
    if [[ $PARTIAL_FAILURE_COUNT -eq 0 ]]; then
        echo '{"partial_failures":0}'
        return
    fi

    local json='{"partial_failures":'$PARTIAL_FAILURE_COUNT',"failures":['
    local first=true

    for failure in "${PARTIAL_FAILURES[@]}"; do
        if $first; then
            first=false
        else
            json+=","
        fi
        json+="$failure"
    done

    json+=']}'
    echo "$json"
}

# Export partial failure functions
export -f error_add_partial error_get_partial_count error_get_partials error_has_partials error_clear_partials error_partial_summary
export PARTIAL_FAILURES PARTIAL_FAILURE_COUNT