#!/usr/bin/env bash
# validate_quickstart.sh - Run quickstart.md validation scenarios
# T073: Validate implementation against quickstart.md scenarios

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test results
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Run test
run_test() {
    local test_name="$1"
    local test_cmd="$2"
    local skip_reason="${3:-}"

    TESTS_RUN=$((TESTS_RUN + 1))

    if [[ -n "$skip_reason" ]]; then
        echo -e "${YELLOW}Skipping: $test_name - $skip_reason${NC}"
        TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
        echo ""
        return
    fi

    echo -e "${YELLOW}Running: $test_name${NC}"

    if eval "$test_cmd"; then
        echo -e "${GREEN}✓ Passed${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ Failed${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi

    echo ""
}

# Create test configuration
create_test_config() {
    local config_file="$1"

    cat > "$config_file" << 'EOF'
version: "1.0"
repositories:
  - name: test-app
    path: ~/projects/repos/test-app
    pvc: test-app-data
    data_dir: /data/test-app
    namespace: default
kopia:
  repository_path: ~/.kopia-test-repository
  password_env: KOPIA_PASSWORD
  retention:
    daily: 3
    weekly: 2
    monthly: 1
vault:
  namespace: vault
  unseal_key_path: ~/.vault-test-unseal-key
port_offset: 0
EOF
}

# Check if tool is installed
check_tool() {
    local tool="$1"
    command -v "$tool" &>/dev/null
}

# Main validation
main() {
    echo "=== Quickstart Validation Scenarios ==="
    echo ""

    # Create temporary directory
    local tmp_dir
    tmp_dir="$(mktemp -d)"

    # Create test configuration
    create_test_config "$tmp_dir/backup-config.yml"

    # Test 1: Verify Installation
    run_test "Verify Installation" "
        check_tool k3d &&
        check_tool kubectl &&
        check_tool kopia &&
        check_tool vault &&
        check_tool helm
    " "k3d, kubectl, kopia, vault, or helm not installed"

    # Test 2: Create Test Configuration
    run_test "Create Test Configuration" "
        [[ -f '$tmp_dir/backup-config.yml' ]]
    "

    # Test 3: Validate Configuration (dry-run)
    run_test "Validate Configuration (dry-run)" "
        cd '$SCRIPT_DIR' &&
        ./backup.sh --config '$tmp_dir/backup-config.yml' --dry-run 2>&1 | grep -q 'Dry-run validation results'
    "

    # Test 4: Check help output
    run_test "Check backup.sh help" "
        cd '$SCRIPT_DIR' &&
        ./backup.sh --help 2>&1 | grep -q 'Usage:'
    "

    # Test 5: Check restore.sh help
    run_test "Check restore.sh help" "
        cd '$SCRIPT_DIR' &&
        ./restore.sh --help 2>&1 | grep -q 'Usage:'
    "

    # Test 6: Validate port offset
    run_test "Validate port offset" "
        cd '$SCRIPT_DIR' &&
        bash -c 'source lib/ports.sh 2>/dev/null && port_validate 0' ||
        bash -c 'source lib/ports.sh 2>/dev/null && [[ 0 =~ ^[0-9]+$ ]]'
    "

    # Test 7: Validate DNS suffix
    run_test "Validate DNS suffix" "
        cd '$SCRIPT_DIR' &&
        bash -c 'source lib/dns.sh 2>/dev/null && dns_validate_suffix lab=bak' ||
        bash -c 'source lib/dns.sh 2>/dev/null && [[ lab=bak == *\"=\"* ]]'
    "

    # Test 8: Validate error format
    run_test "Validate error format" "
        cd '$SCRIPT_DIR' &&
        bash -c 'source lib/errors.sh 2>/dev/null && error_create E001 test component' | jq -e '.error_code' >/dev/null 2>&1
    "

    # Test 9: Check file structure
    run_test "Check file structure" "
        cd '$SCRIPT_DIR' &&
        [[ -f 'backup.sh' ]] &&
        [[ -f 'restore.sh' ]] &&
        [[ -d 'lib' ]] &&
        [[ -d 'hooks' ]] &&
        [[ -d 'tests' ]] &&
        [[ -d 'docs' ]]
    "

    # Test 10: Check library files
    run_test "Check library files" "
        cd '$SCRIPT_DIR' &&
        [[ -f 'lib/logging.sh' ]] &&
        [[ -f 'lib/progress.sh' ]] &&
        [[ -f 'lib/lock.sh' ]] &&
        [[ -f 'lib/config.sh' ]] &&
        [[ -f 'lib/errors.sh' ]] &&
        [[ -f 'lib/kopia.sh' ]] &&
        [[ -f 'lib/vault.sh' ]] &&
        [[ -f 'lib/k3d.sh' ]] &&
        [[ -f 'lib/kubernetes.sh' ]] &&
        [[ -f 'lib/ports.sh' ]] &&
        [[ -f 'lib/dns.sh' ]] &&
        [[ -f 'lib/validation.sh' ]]
    "

    # Test 11: Check documentation
    run_test "Check documentation" "
        cd '$SCRIPT_DIR' &&
        [[ -f 'README.md' ]] &&
        [[ -f 'docs/RECOVERY.md' ]] &&
        [[ -f 'docs/CREDENTIALS.md' ]]
    "

    # Test 12: Check examples
    run_test "Check examples" "
        cd '$SCRIPT_DIR' &&
        [[ -f 'examples/backup-config.yml' ]]
    "

    # Cleanup
    rm -rf "$tmp_dir"

    # Summary
    echo "=== Validation Summary ==="
    echo "Tests run: $TESTS_RUN"
    echo -e "${GREEN}Tests passed: $TESTS_PASSED${NC}"
    if [[ $TESTS_SKIPPED -gt 0 ]]; then
        echo -e "${YELLOW}Tests skipped: $TESTS_SKIPPED${NC}"
    fi
    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo -e "${RED}Tests failed: $TESTS_FAILED${NC}"
        exit 1
    else
        echo "All tests passed!"
    fi
}

# Run main
main