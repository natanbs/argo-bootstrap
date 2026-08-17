#!/usr/bin/env bash
# dns.sh - DNS suffix override utility
# FR-026: Configurable DNS suffix override for Ingress resources
# FR-039: DNS suffix format: <original>=<replacement>

set -euo pipefail

# DNS state
declare DNS_ORIGINAL=""
declare DNS_REPLACEMENT=""

# Initialize DNS suffix
# Usage: dns_init <dns_suffix>
dns_init() {
    local dns_suffix="$1"

    if [[ -z "$dns_suffix" ]]; then
        return 0
    fi

    # Parse DNS suffix format: <original>=<replacement>
    if [[ "$dns_suffix" != *"="* ]]; then
        error_report "E024" "DNS suffix format invalid: $dns_suffix (expected original=replacement)" "dns" "Set dns_suffix to format '<original>=<replacement>' (e.g., 'lab=bak')"
        return 1
    fi

    DNS_ORIGINAL="${dns_suffix%%=*}"
    DNS_REPLACEMENT="${dns_suffix#*=}"

    if [[ -z "$DNS_ORIGINAL" || -z "$DNS_REPLACEMENT" ]]; then
        error_report "E024" "DNS suffix parts cannot be empty: $dns_suffix" "dns" "Set both original and replacement values"
        return 1
    fi
}

# Rewrite DNS suffix in string
# Usage: dns_rewrite <input_string>
dns_rewrite() {
    local input="$1"

    if [[ -z "$DNS_ORIGINAL" ]]; then
        echo "$input"
        return 0
    fi

    echo "${input//${DNS_ORIGINAL}/${DNS_REPLACEMENT}}"
}

# Rewrite DNS suffix in Ingress YAML file
# Usage: dns_rewrite_ingress <input_file> <output_file>
dns_rewrite_ingress() {
    local input_file="$1"
    local output_file="$2"

    if [[ ! -f "$input_file" ]]; then
        error_report "E005" "Ingress file not found: $input_file" "dns" "Verify file path"
        return 1
    fi

    if [[ -z "$DNS_ORIGINAL" ]]; then
        # No DNS rewriting needed, copy file
        cp "$input_file" "$output_file"
        return 0
    fi

    # Use sed to rewrite DNS suffix in Ingress resources
    sed "s/${DNS_ORIGINAL}/${DNS_REPLACEMENT}/g" "$input_file" > "$output_file"
}

# Rewrite DNS suffix in all Ingress resources
# Usage: dns_rewrite_all_ingress <input_dir> <output_dir>
dns_rewrite_all_ingress() {
    local input_dir="$1"
    local output_dir="$2"

    if [[ ! -d "$input_dir" ]]; then
        error_report "E005" "Input directory not found: $input_dir" "dns" "Verify directory path"
        return 1
    fi

    mkdir -p "$output_dir"

    for ingress_file in "$input_dir"/*.yaml "$input_dir"/*.yml; do
        [[ -f "$ingress_file" ]] || continue

        local filename
        filename="$(basename "$ingress_file")"
        dns_rewrite_ingress "$ingress_file" "$output_dir/$filename"
    done
}

# Get original DNS suffix
# Usage: dns_get_original
dns_get_original() {
    echo "$DNS_ORIGINAL"
}

# Get replacement DNS suffix
# Usage: dns_get_replacement
dns_get_replacement() {
    echo "$DNS_REPLACEMENT"
}

# Check if DNS rewriting is configured
# Usage: dns_is_configured
dns_is_configured() {
    [[ -n "$DNS_ORIGINAL" ]]
}

# Reset DNS configuration
# Usage: dns_reset
dns_reset() {
    DNS_ORIGINAL=""
    DNS_REPLACEMENT=""
}

# Export functions
export -f dns_init dns_rewrite dns_rewrite_ingress dns_rewrite_all_ingress dns_get_original dns_get_replacement dns_is_configured dns_reset
export DNS_ORIGINAL DNS_REPLACEMENT