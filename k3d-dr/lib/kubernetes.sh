#!/usr/bin/env bash
# kubernetes.sh - Kubernetes operations library
# FR-016: Complete infrastructure recovery order

set -euo pipefail

# Kubernetes state
declare -g KUBECTL_NAMESPACE=""
declare -g KUBECTL_CONTEXT=""

# Initialize Kubernetes wrapper
# Usage: kubernetes_init <context> [namespace]
kubernetes_init() {
    local context="$1"
    local namespace="${2:-}"

    if ! command -v kubectl &>/dev/null; then
        error_report "E015" "kubectl is not installed" "kubernetes" "Install kubectl: https://kubernetes.io/docs/tasks/tools/"
        return 1
    fi

    KUBECTL_CONTEXT="$context"
    KUBECTL_NAMESPACE="$namespace"
}

# Apply Kubernetes resources from file or directory
# Usage: kubernetes_apply <path>
kubernetes_apply() {
    local path="$1"

    if [[ ! -e "$path" ]]; then
        error_report "E005" "Path not found: $path" "kubernetes" "Verify path exists"
        return 1
    fi

    local cmd="kubectl apply --context $KUBECTL_CONTEXT -f $path"
    [[ -n "$KUBECTL_NAMESPACE" ]] && cmd+=" -n $KUBECTL_NAMESPACE"

    if ! $cmd; then
        error_report "E026" "Failed to apply resources from $path" "kubernetes" "Check kubectl logs and cluster connectivity"
        return 1
    fi
}

# Delete Kubernetes resources
# Usage: kubernetes_delete <path>
kubernetes_delete() {
    local path="$1"

    if [[ ! -e "$path" ]]; then
        return 0
    fi

    local cmd="kubectl delete --context $KUBECTL_CONTEXT -f $path"
    [[ -n "$KUBECTL_NAMESPACE" ]] && cmd+=" -n $KUBECTL_NAMESPACE"

    $cmd 2>/dev/null || true
}

# Wait for resources to be ready
# Usage: kubernetes_wait <resource> <name> <timeout_seconds>
kubernetes_wait() {
    local resource="$1"
    local name="$2"
    local timeout="${3:-120}"

    local cmd="kubectl wait --context $KUBECTL_CONTEXT --for=condition=Ready $resource/$name"
    [[ -n "$KUBECTL_NAMESPACE" ]] && cmd+=" -n $KUBECTL_NAMESPACE"
    cmd+=" --timeout=${timeout}s"

    if ! $cmd; then
        error_report "E029" "Resource $resource/$name not ready after ${timeout}s" "kubernetes" "Check resource status and events"
        return 1
    fi
}

# Wait for deployment to be ready
# Usage: kubernetes_wait_deployment <name> <namespace> <timeout_seconds>
kubernetes_wait_deployment() {
    local name="$1"
    local namespace="${2:-$KUBECTL_NAMESPACE}"
    local timeout="${3:-120}"

    kubectl wait --context "$KUBECTL_CONTEXT" --for=condition=Available deployment/"$name" -n "$namespace" --timeout="${timeout}s"
}

# Wait for pod to be ready
# Usage: kubernetes_wait_pod <label> <namespace> <timeout_seconds>
kubernetes_wait_pod() {
    local label="$1"
    local namespace="${2:-$KUBECTL_NAMESPACE}"
    local timeout="${3:-120}"

    local start_time
    start_time="$(date +%s)"

    while true; do
        local ready
        ready="$(kubectl get pods --context "$KUBECTL_CONTEXT" -n "$namespace" -l "$label" -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")"

        if [[ "$ready" == *"True"* ]]; then
            return 0
        fi

        local current_time
        current_time="$(date +%s)"
        local elapsed=$((current_time - start_time))

        if [[ $elapsed -ge $timeout ]]; then
            error_report "E029" "Pod with label $label not ready after ${timeout}s" "kubernetes" "Check pod status and events"
            return 1
        fi

        sleep 5
    done
}

# Get Kubernetes resources
# Usage: kubernetes_get <resource> [namespace]
kubernetes_get() {
    local resource="$1"
    local namespace="${2:-$KUBECTL_NAMESPACE}"

    local cmd="kubectl get --context $KUBECTL_CONTEXT $resource -o json"
    [[ -n "$namespace" ]] && cmd+=" -n $namespace"

    $cmd
}

# Get pod logs
# Usage: kubernetes_logs <pod_name> <namespace> [container]
kubernetes_logs() {
    local pod_name="$1"
    local namespace="${2:-$KUBECTL_NAMESPACE}"
    local container="${3:-}"

    local cmd="kubectl logs --context $KUBECTL_CONTEXT $pod_name -n $namespace"
    [[ -n "$container" ]] && cmd+=" -c $container"

    $cmd
}

# Check if namespace exists
# Usage: kubernetes_namespace_exists <namespace>
kubernetes_namespace_exists() {
    local namespace="$1"

    kubectl get namespace --context "$KUBECTL_CONTEXT" "$namespace" &>/dev/null
}

# Create namespace if not exists
# Usage: kubernetes_create_namespace <namespace>
kubernetes_create_namespace() {
    local namespace="$1"

    if ! kubernetes_namespace_exists "$namespace"; then
        kubectl create namespace --context "$KUBECTL_CONTEXT" "$namespace"
    fi
}

# Export functions
export -f kubernetes_init kubernetes_apply kubernetes_delete kubernetes_wait kubernetes_wait_deployment kubernetes_wait_pod kubernetes_get kubernetes_logs kubernetes_namespace_exists kubernetes_create_namespace
export KUBECTL_NAMESPACE KUBECTL_CONTEXT