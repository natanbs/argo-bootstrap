#!/usr/bin/env bash
# ports.sh - Port offset utility
# FR-025: Configurable port offset for NodePorts and API server
# FR-038: Port offset as integer 0-65000, default 0

set -euo pipefail

# Port configuration
declare PORT_OFFSET="0"
declare PORT_API_BASE="6443"
declare PORT_NODEPORT_START="30000"
declare PORT_NODEPORT_END="32767"

# Initialize port offset
# Usage: ports_init <offset>
ports_init() {
    local offset="$1"

    if ! [[ "$offset" =~ ^[0-9]+$ ]]; then
        error_report "E023" "Port offset must be a non-negative integer (got '$offset')" "ports" "Set port_offset to a value between 0 and 65000"
        return 1
    fi

    if [[ "$offset" -gt 65000 ]]; then
        error_report "E023" "Port offset out of range: $offset (max 65000)" "ports" "Set port_offset to a value between 0 and 65000"
        return 1
    fi

    PORT_OFFSET="$offset"
}

# Get API server port with offset
# Usage: ports_get_api_port
ports_get_api_port() {
    echo $((PORT_API_BASE + PORT_OFFSET))
}

# Get NodePort with offset
# Usage: ports_get_nodeport <base_port>
ports_get_nodeport() {
    local base_port="$1"

    if [[ "$base_port" -lt "$PORT_NODEPORT_START" || "$base_port" -gt "$PORT_NODEPORT_END" ]]; then
        error_report "E023" "Base port must be in NodePort range ($PORT_NODEPORT_START-$PORT_NODEPORT_END)" "ports" "Use a valid NodePort"
        return 1
    fi

    local offset_port=$((base_port + PORT_OFFSET))

    if [[ "$offset_port" -gt 65535 ]]; then
        error_report "E023" "Offset port exceeds maximum: $offset_port (max 65535)" "ports" "Reduce port offset"
        return 1
    fi

    echo "$offset_port"
}

# Get all NodePort range with offset
# Usage: ports_get_nodeport_range
ports_get_nodeport_range() {
    local start=$((PORT_NODEPORT_START + PORT_OFFSET))
    local end=$((PORT_NODEPORT_END + PORT_OFFSET))

    if [[ "$end" -gt 65535 ]]; then
        end=65535
    fi

    echo "$start-$end"
}

# Validate port is available
# Usage: ports_validate_available <port>
ports_validate_available() {
    local port="$1"

    # Check if port is in use
    if command -v lsof &>/dev/null; then
        if lsof -i :"$port" &>/dev/null; then
            return 1
        fi
    elif command -v netstat &>/dev/null; then
        if netstat -tuln | grep -q ":$port "; then
            return 1
        fi
    fi

    return 0
}

# Get port offset
# Usage: ports_get_offset
ports_get_offset() {
    echo "$PORT_OFFSET"
}

# Reset port offset to default
# Usage: ports_reset
ports_reset() {
    PORT_OFFSET="0"
}

# Export functions
export -f ports_init ports_get_api_port ports_get_nodeport ports_get_nodeport_range ports_validate_available ports_get_offset ports_reset
export PORT_OFFSET PORT_API_BASE PORT_NODEPORT_START PORT_NODEPORT_END