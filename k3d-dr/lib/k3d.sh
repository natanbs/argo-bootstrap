#!/usr/bin/env bash
# k3d.sh - k3d cluster operations library
# FR-020: Support disaster-recovery test with fresh k3d cluster
# FR-025: Configurable port offset for NodePorts and API server

set -euo pipefail

# k3d state
declare K3D_CLUSTER_NAME=""
declare K3D_PORT_OFFSET="0"
declare K3D_API_PORT="6443"
declare K3D_REGISTRY_PORT="5000"

# Initialize k3d wrapper
# Usage: k3d_init <cluster_name> [port_offset]
k3d_init() {
    local cluster_name="$1"
    local port_offset="${2:-0}"

    if ! command -v k3d &>/dev/null; then
        error_report "E015" "k3d is not installed" "k3d" "Install k3d: https://k3d.io/#installation"
        return 1
    fi

    if ! command -v docker &>/dev/null; then
        error_report "E018" "Docker is not installed" "k3d" "Install Docker: https://docs.docker.com/get-docker/"
        return 1
    fi

    if ! docker info &>/dev/null; then
        error_report "E018" "Docker is not running" "k3d" "Start Docker Desktop or Docker daemon"
        return 1
    fi

    K3D_CLUSTER_NAME="$cluster_name"
    K3D_PORT_OFFSET="$port_offset"
    K3D_API_PORT=$((6443 + port_offset))
    K3D_REGISTRY_PORT=$((5000 + port_offset))
}

# Check if k3d cluster exists
# Usage: k3d_cluster_exists
k3d_cluster_exists() {
    k3d cluster list --format json | jq -e --arg name "$K3D_CLUSTER_NAME" '.[] | select(.name == $name)' &>/dev/null
}

# Get k3d cluster status
# Usage: k3d_cluster_status
k3d_cluster_status() {
    k3d cluster list --format json | jq -r --arg name "$K3D_CLUSTER_NAME" '.[] | select(.name == $name) | .status // "not found"'
}

# Create k3d cluster with port offset
# Usage: k3d_cluster_create [api_port] [registry_port]
k3d_cluster_create() {
    local api_port="${1:-$K3D_API_PORT}"
    local registry_port="${2:-$K3D_REGISTRY_PORT}"

    if k3d_cluster_exists; then
        error_report "E016" "k3d cluster already exists: $K3D_CLUSTER_NAME" "k3d" "Delete existing cluster first: k3d cluster delete $K3D_CLUSTER_NAME"
        return 1
    fi

    local cmd="k3d cluster create $K3D_CLUSTER_NAME"
    cmd+=" --api-port $api_port"
    cmd+=" --registry-use $K3D_CLUSTER_NAME-registry"

    # Add port mappings for NodePort range with offset
    local nodeport_start=$((30000 + K3D_PORT_OFFSET))
    local nodeport_end=$((32767 + K3D_PORT_OFFSET))
    cmd+=" --k3s-arg --service-node-port-range=$nodeport_start-$nodeport_end@server:0"

    # Add volume mappings for host directories
    cmd+=" --volume /tmp/k3d-dr/$K3D_CLUSTER_NAME/server:/var/lib/rancher/k3s/server@server:0"

    if ! $cmd; then
        error_report "E026" "Failed to create k3d cluster" "k3d" "Check k3d logs and Docker status"
        return 1
    fi
}

# Delete k3d cluster
# Usage: k3d_cluster_delete
k3d_cluster_delete() {
    if ! k3d_cluster_exists; then
        return 0
    fi

    if ! k3d cluster delete "$K3D_CLUSTER_NAME"; then
        error_report "E026" "Failed to delete k3d cluster" "k3d" "Check k3d logs and Docker status"
        return 1
    fi
}

# Get k3d cluster kubeconfig
# Usage: k3d_get_kubeconfig
k3d_get_kubeconfig() {
    k3d kubeconfig get "$K3D_CLUSTER_NAME"
}

# Get k3d cluster nodes
# Usage: k3d_get_nodes
k3d_get_nodes() {
    k3d node list --format json | jq -r --arg cluster "$K3D_CLUSTER_NAME" '.[] | select(.cluster == $cluster) | .name'
}

# Get API server URL
# Usage: k3d_get_api_url
k3d_get_api_url() {
    echo "https://127.0.0.1:$K3D_API_PORT"
}

# Get NodePort with offset
# Usage: k3d_get_nodeport <base_port>
k3d_get_nodeport() {
    local base_port="$1"
    echo $((base_port + K3D_PORT_OFFSET))
}

# Check if cluster is ready
# Usage: k3d_cluster_ready
k3d_cluster_ready() {
    if ! k3d_cluster_exists; then
        return 1
    fi

    local status
    status="$(k3d_cluster_status)"
    [[ "$status" == "running" ]]
}

# Wait for cluster to be ready
# Usage: k3d_wait_ready <timeout_seconds>
k3d_wait_ready() {
    local timeout="${1:-120}"

    local start_time
    start_time="$(date +%s)"

    while true; do
        if k3d_cluster_ready; then
            return 0
        fi

        local current_time
        current_time="$(date +%s)"
        local elapsed=$((current_time - start_time))

        if [[ $elapsed -ge $timeout ]]; then
            error_report "E029" "k3d cluster not ready after ${timeout}s" "k3d" "Check k3d logs and Docker status"
            return 1
        fi

        sleep 5
    done
}

# Export functions
export -f k3d_init k3d_cluster_exists k3d_cluster_status k3d_cluster_create k3d_cluster_delete k3d_get_kubeconfig k3d_get_nodes k3d_get_api_url k3d_get_nodeport k3d_cluster_ready k3d_wait_ready
export K3D_CLUSTER_NAME K3D_PORT_OFFSET K3D_API_PORT K3D_REGISTRY_PORT