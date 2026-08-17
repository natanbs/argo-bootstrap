#!/usr/bin/env bash
# test_helper.bash - bats-core test helper functions

# Get the directory of this script
BATS_TEST_DIRNAME="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$BATS_TEST_DIRNAME/../lib" && pwd)"

# Source all libraries
setup() {
    TEST_TMPDIR="$(mktemp -d)"
    source "$LIB_DIR/logging.sh"
    source "$LIB_DIR/errors.sh"
    source "$LIB_DIR/progress.sh"
    source "$LIB_DIR/lock.sh"
    source "$LIB_DIR/ports.sh"
    source "$LIB_DIR/dns.sh"
}

# Cleanup temporary directory
cleanup_tmpdir() {
    [[ -d "${TEST_TMPDIR:-}" ]] && rm -rf "$TEST_TMPDIR"
}

# Create test configuration file
create_test_config() {
    local config_file="${1:-$TEST_TMPDIR/backup-config.yml}"

    cat > "$config_file" << EOF
version: "1.0"
repositories:
  - name: test-repo
    path: /tmp/test-repo
    pvc: test-pvc
    data_dir: /data
    namespace: default
kopia:
  repository_path: /tmp/kopia-repo
  password_env: KOPIA_TEST_PASSWORD
  retention:
    daily: 7
    weekly: 4
    monthly: 12
vault:
  namespace: vault
database_hooks:
  timeout: 300
  mandatory: true
port_offset: 0
dns_suffix: lab=bak
EOF
    echo "$config_file"
}

# Assert functions - handle unset vars safely
assert_equal() {
    local expected="${1:-}"
    local actual="${2:-}"
    local message="${3:-}"

    if [[ "$expected" != "$actual" ]]; then
        [[ -n "$message" ]] && echo "Assertion failed: $message"
        echo "Expected: $expected"
        echo "Actual: $actual"
        return 1
    fi
}

assert_contains() {
    local haystack="${1:-}"
    local needle="${2:-}"
    local message="${3:-}"

    if [[ "$haystack" != *"$needle"* ]]; then
        [[ -n "$message" ]] && echo "Assertion failed: $message"
        echo "Expected to contain: $needle"
        echo "Actual: $haystack"
        return 1
    fi
}

assert_success() {
    local status="${1:-}"
    local message="${2:-}"

    if [[ -z "$status" ]] || [[ "$status" -ne 0 ]]; then
        [[ -n "$message" ]] && echo "Assertion failed: $message"
        echo "Expected success (exit code 0)"
        echo "Actual exit code: ${status:-<empty>}"
        return 1
    fi
}

assert_failure() {
    local status="${1:-}"
    local message="${2:-}"

    if [[ -z "$status" ]]; then
        return 0
    fi
    if [[ "$status" -eq 0 ]]; then
        [[ -n "$message" ]] && echo "Assertion failed: $message"
        echo "Expected failure (exit code non-zero)"
        echo "Actual exit code: $status"
        return 1
    fi
}

# Export helper functions
export -f create_test_config assert_equal assert_contains assert_success assert_failure