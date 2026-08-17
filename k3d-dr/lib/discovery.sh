#!/usr/bin/env bash
# discovery.sh - Infrastructure app discovery library
# FR-016: Discover and manage infrastructure apps under ~/projects/infra

set -euo pipefail

# Discovery state
declare DISCOVERY_INFRA_DIR=""
declare DISCOVERY_APPS=()

# Initialize discovery
# Usage: discovery_init <infra_dir>
discovery_init() {
    local infra_dir="${1:-$HOME/projects/infra}"

    DISCOVERY_INFRA_DIR="$infra_dir"
    DISCOVERY_APPS=()
}

# Discover infrastructure apps
# Usage: discovery_find_apps
discovery_find_apps() {
    if [[ ! -d "$DISCOVERY_INFRA_DIR" ]]; then
        log_error "Infrastructure directory not found: $DISCOVERY_INFRA_DIR" "discovery"
        return 1
    fi

    DISCOVERY_APPS=()

    for app_dir in "$DISCOVERY_INFRA_DIR"/*/; do
        [[ -d "$app_dir" ]] || continue

        local app_name
        app_name="$(basename "$app_dir")"

        # Skip hidden directories
        [[ "$app_name" == .* ]] && continue

        DISCOVERY_APPS+=("$app_name")
    done

    log_info "Discovered ${#DISCOVERY_APPS[@]} infrastructure apps" "discovery"
}

# Get discovered apps
# Usage: discovery_get_apps
discovery_get_apps() {
    echo "${DISCOVERY_APPS[@]}"
}

# Get app count
# Usage: discovery_get_count
discovery_get_count() {
    echo "${#DISCOVERY_APPS[@]}"
}

# Get app directory
# Usage: discovery_get_app_dir <app_name>
discovery_get_app_dir() {
    local app_name="$1"

    echo "$DISCOVERY_INFRA_DIR/$app_name"
}

# Check if app has Kubernetes manifests
# Usage: discovery_has_k8s <app_name>
discovery_has_k8s() {
    local app_name="$1"

    local app_dir
    app_dir="$(discovery_get_app_dir "$app_name")"

    [[ -d "$app_dir/k8s" ]]
}

# Check if app has Helm charts
# Usage: discovery_has_helm <app_name>
discovery_has_helm() {
    local app_name="$1"

    local app_dir
    app_dir="$(discovery_get_app_dir "$app_name")"

    [[ -f "$app_dir/helmfile.yaml" ]] || [[ -d "$app_dir/charts" ]]
}

# Get app dependencies
# Usage: discovery_get_dependencies <app_name>
discovery_get_dependencies() {
    local app_name="$1"

    local app_dir
    app_dir="$(discovery_get_app_dir "$app_name")"

    if [[ -f "$app_dir/dependencies.txt" ]]; then
        cat "$app_dir/dependencies.txt"
    fi
}

# Discover apps in dependency order
# Usage: discovery_find_apps_in_order
discovery_find_apps_in_order() {
    discovery_find_apps

    # Simple dependency resolution
    # For now, just return apps in alphabetical order
    # TODO: Implement proper dependency resolution
    IFS=$'\n' sorted_apps=($(sort <<<"${DISCOVERY_APPS[*]}")); unset IFS

    echo "${sorted_apps[@]}"
}

# Get app manifests
# Usage: discovery_get_manifests <app_name>
discovery_get_manifests() {
    local app_name="$1"

    local app_dir
    app_dir="$(discovery_get_app_dir "$app_name")"

    if [[ -d "$app_dir/k8s" ]]; then
        find "$app_dir/k8s" -type f -name "*.yaml" -o -name "*.yml" | sort
    fi
}

# Get app Helm release
# Usage: discovery_get_helm_release <app_name>
discovery_get_helm_release() {
    local app_name="$1"

    local app_dir
    app_dir="$(discovery_get_app_dir "$app_name")"

    if [[ -f "$app_dir/helmfile.yaml" ]]; then
        # Extract release name from helmfile
        grep "name:" "$app_dir/helmfile.yaml" | head -1 | awk '{print $2}'
    fi
}

# Export functions
export -f discovery_init discovery_find_apps discovery_get_apps discovery_get_count discovery_get_app_dir discovery_has_k8s discovery_has_helm discovery_get_dependencies discovery_find_apps_in_order discovery_get_manifests discovery_get_helm_release
export DISCOVERY_INFRA_DIR DISCOVERY_APPS