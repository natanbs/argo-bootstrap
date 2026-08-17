#!/usr/bin/env bash
# health.sh - Health check verification library
# FR-034: Verify health of each infrastructure component before proceeding
# FR-035: Wait for Vault to be unsealed and responsive

set -euo pipefail

# Health check state
declare HEALTH_CHECK_TIMEOUT="120"
declare HEALTH_CHECK_INTERVAL="5"

# Initialize health check
# Usage: health_init <timeout_seconds> [interval_seconds]
health_init() {
    local timeout="${1:-120}"
    local interval="${2:-5}"

    HEALTH_CHECK_TIMEOUT="$timeout"
    HEALTH_CHECK_INTERVAL="$interval"
}

# Wait for Vault to be ready
# Usage: vault_wait_ready <timeout_seconds>
vault_wait_ready() {
    local timeout="${1:-$HEALTH_CHECK_TIMEOUT}"

    local start_time
    start_time="$(date +%s)"

    while true; do
        # Check if Vault is running
        if vault_is_running; then
            # Check if Vault is unsealed
            if [[ "$(vault_is_sealed)" == "false" ]]; then
                return 0
            fi
        fi

        local current_time
        current_time="$(date +%s)"
        local elapsed=$((current_time - start_time))

        if [[ $elapsed -ge $timeout ]]; then
            error_report "E029" "Vault not ready after ${timeout}s" "health" "Check Vault logs and status"
            return 1
        fi

        sleep "$HEALTH_CHECK_INTERVAL"
    done
}

# Wait for deployment to be ready
# Usage: wait_for_deployment <name> <namespace> <timeout_seconds>
wait_for_deployment() {
    local name="$1"
    local namespace="${2:-default}"
    local timeout="${3:-$HEALTH_CHECK_TIMEOUT}"

    local start_time
    start_time="$(date +%s)"

    while true; do
        # Get deployment status
        local status
        status="$(kubectl get deployment "$name" -n "$namespace" -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null || echo "False")"

        if [[ "$status" == "True" ]]; then
            return 0
        fi

        local current_time
        current_time="$(date +%s)"
        local elapsed=$((current_time - start_time))

        if [[ $elapsed -ge $timeout ]]; then
            error_report "E029" "Deployment $name not ready after ${timeout}s" "health" "Check deployment status and events"
            return 1
        fi

        sleep "$HEALTH_CHECK_INTERVAL"
    done
}

# Wait for pod to be ready
# Usage: wait_for_pod <label> <namespace> <timeout_seconds>
wait_for_pod() {
    local label="$1"
    local namespace="${2:-default}"
    local timeout="${3:-$HEALTH_CHECK_TIMEOUT}"

    local start_time
    start_time="$(date +%s)"

    while true; do
        # Get pod status
        local ready
        ready="$(kubectl get pods -n "$namespace" -l "$label" -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")"

        if [[ "$ready" == *"True"* ]]; then
            return 0
        fi

        local current_time
        current_time="$(date +%s)"
        local elapsed=$((current_time - start_time))

        if [[ $elapsed -ge $timeout ]]; then
            error_report "E029" "Pod with label $label not ready after ${timeout}s" "health" "Check pod status and events"
            return 1
        fi

        sleep "$HEALTH_CHECK_INTERVAL"
    done
}

# Wait for service to be ready
# Usage: wait_for_service <name> <namespace> <timeout_seconds>
wait_for_service() {
    local name="$1"
    local namespace="${2:-default}"
    local timeout="${3:-$HEALTH_CHECK_TIMEOUT}"

    local start_time
    start_time="$(date +%s)"

    while true; do
        # Get service endpoints
        local endpoints
        endpoints="$(kubectl get endpoints "$name" -n "$namespace" -o jsonpath='{.subsets[*].addresses}' 2>/dev/null || echo "")"

        if [[ -n "$endpoints" ]]; then
            return 0
        fi

        local current_time
        current_time="$(date +%s)"
        local elapsed=$((current_time - start_time))

        if [[ $elapsed -ge $timeout ]]; then
            error_report "E029" "Service $name not ready after ${timeout}s" "health" "Check service status and endpoints"
            return 1
        fi

        sleep "$HEALTH_CHECK_INTERVAL"
    done
}

# Verify component health
# Usage: verify_component_health <component_type> <name> <namespace> <timeout_seconds>
verify_component_health() {
    local component_type="$1"
    local name="$2"
    local namespace="${3:-default}"
    local timeout="${4:-$HEALTH_CHECK_TIMEOUT}"

    case "$component_type" in
        vault)
            vault_wait_ready "$timeout"
            ;;
        deployment)
            wait_for_deployment "$name" "$namespace" "$timeout"
            ;;
        pod)
            wait_for_pod "$name" "$namespace" "$timeout"
            ;;
        service)
            wait_for_service "$name" "$namespace" "$timeout"
            ;;
        *)
            error_report "E999" "Unknown component type: $component_type" "health"
            return 1
            ;;
    esac
}

# Export functions
export -f health_init vault_wait_ready wait_for_deployment wait_for_pod wait_for_service verify_component_health
export HEALTH_CHECK_TIMEOUT HEALTH_CHECK_INTERVAL