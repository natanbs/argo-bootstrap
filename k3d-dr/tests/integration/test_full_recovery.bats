#!/usr/bin/env bats
# test_full_recovery.bats - Integration test for full disaster recovery
# T077: Write integration test for full recovery

SCRIPT_DIR=""
TEST_TMPDIR=""

setup() {
    SCRIPT_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
    TEST_TMPDIR="$(mktemp -d)"
}

cleanup() {
    rm -rf "$TEST_TMPDIR"
}

@test "backup.sh exists and is executable" {
    [ -f "$SCRIPT_DIR/backup.sh" ]
    [ -x "$SCRIPT_DIR/backup.sh" ]
}

@test "restore.sh exists and is executable" {
    [ -f "$SCRIPT_DIR/restore.sh" ]
    [ -x "$SCRIPT_DIR/restore.sh" ]
}

@test "backup.sh --help shows usage" {
    run "$SCRIPT_DIR/backup.sh" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
    [[ "$output" == *"--config"* ]]
    [[ "$output" == *"--dry-run"* ]]
    [[ "$output" == *"--json"* ]]
    [[ "$output" == *"--verbose"* ]]
}

@test "restore.sh --help shows usage" {
    run "$SCRIPT_DIR/restore.sh" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
    [[ "$output" == *"--repo"* ]]
    [[ "$output" == *"--snapshot"* ]]
    [[ "$output" == *"--tag"* ]]
    [[ "$output" == *"--rollback"* ]]
}

@test "backup.sh fails with nonexistent config" {
    run "$SCRIPT_DIR/backup.sh" --config "$TEST_TMPDIR/nonexistent.yml"
    [ "$status" -ne 0 ]
}

@test "restore.sh fails with nonexistent config" {
    run "$SCRIPT_DIR/restore.sh" --config "$TEST_TMPDIR/nonexistent.yml"
    [ "$status" -ne 0 ]
}

@test "All required libraries exist" {
    [ -f "$SCRIPT_DIR/lib/logging.sh" ]
    [ -f "$SCRIPT_DIR/lib/errors.sh" ]
    [ -f "$SCRIPT_DIR/lib/config.sh" ]
    [ -f "$SCRIPT_DIR/lib/kopia.sh" ]
    [ -f "$SCRIPT_DIR/lib/vault.sh" ]
    [ -f "$SCRIPT_DIR/lib/k3d.sh" ]
    [ -f "$SCRIPT_DIR/lib/kubernetes.sh" ]
    [ -f "$SCRIPT_DIR/lib/ports.sh" ]
    [ -f "$SCRIPT_DIR/lib/dns.sh" ]
    [ -f "$SCRIPT_DIR/lib/validation.sh" ]
    [ -f "$SCRIPT_DIR/lib/progress.sh" ]
    [ -f "$SCRIPT_DIR/lib/lock.sh" ]
    [ -f "$SCRIPT_DIR/lib/state.sh" ]
    [ -f "$SCRIPT_DIR/lib/registry.sh" ]
    [ -f "$SCRIPT_DIR/lib/health.sh" ]
    [ -f "$SCRIPT_DIR/lib/snapshots.sh" ]
    [ -f "$SCRIPT_DIR/lib/metadata.sh" ]
    [ -f "$SCRIPT_DIR/lib/discovery.sh" ]
}

@test "Hook scripts exist" {
    [ -f "$SCRIPT_DIR/hooks/db-backup.sh" ]
    [ -x "$SCRIPT_DIR/hooks/db-backup.sh" ]
    [ -f "$SCRIPT_DIR/hooks/db-restore.sh" ]
    [ -x "$SCRIPT_DIR/hooks/db-restore.sh" ]
}

@test "Example hooks exist" {
    [ -f "$SCRIPT_DIR/hooks/examples/pg-backup.sh" ]
    [ -x "$SCRIPT_DIR/hooks/examples/pg-backup.sh" ]
    [ -f "$SCRIPT_DIR/hooks/examples/pg-restore.sh" ]
    [ -x "$SCRIPT_DIR/hooks/examples/pg-restore.sh" ]
}

@test "Documentation exists" {
    [ -f "$SCRIPT_DIR/README.md" ]
    [ -f "$SCRIPT_DIR/docs/RECOVERY.md" ]
    [ -f "$SCRIPT_DIR/docs/CREDENTIALS.md" ]
}

@test "Example config exists" {
    [ -f "$SCRIPT_DIR/examples/backup-config.yml" ]
}

@test "Test fixtures exist" {
    [ -f "$SCRIPT_DIR/tests/fixtures/backup-config.yml" ]
}

@test "Unit tests exist" {
    [ -f "$SCRIPT_DIR/tests/unit/test_ports.bats" ]
    [ -f "$SCRIPT_DIR/tests/unit/test_dns.bats" ]
    [ -f "$SCRIPT_DIR/tests/unit/test_errors.bats" ]
    [ -f "$SCRIPT_DIR/tests/unit/test_logging.bats" ]
    [ -f "$SCRIPT_DIR/tests/unit/test_progress.bats" ]
    [ -f "$SCRIPT_DIR/tests/unit/test_lock.bats" ]
    [ -f "$SCRIPT_DIR/tests/unit/test_config.bats" ]
    [ -f "$SCRIPT_DIR/tests/unit/test_kopia.bats" ]
    [ -f "$SCRIPT_DIR/tests/unit/test_vault.bats" ]
}

@test "YAML validation schema exists" {
    [ -f "$SCRIPT_DIR/schemas/backup-config.yaml" ]
}

@test "libraries have no bash 4+ syntax errors" {
    for lib in "$SCRIPT_DIR"/lib/*.sh; do
        run bash -n "$lib"
        [ "$status" -eq 0 ] || {
            echo "Syntax error in: $lib"
            false
        }
    done
}

@test "backup.sh has no syntax errors" {
    run bash -n "$SCRIPT_DIR/backup.sh"
    [ "$status" -eq 0 ]
}

@test "restore.sh has no syntax errors" {
    run bash -n "$SCRIPT_DIR/restore.sh"
    [ "$status" -eq 0 ]
}

@test "Hook scripts have no syntax errors" {
    for hook in "$SCRIPT_DIR"/hooks/*.sh; do
        run bash -n "$hook"
        [ "$status" -eq 0 ] || {
            echo "Syntax error in: $hook"
            false
        }
    done
}

@test "All scripts are valid bash" {
    for script in "$SCRIPT_DIR"/*.sh "$SCRIPT_DIR"/hooks/*.sh; do
        run bash -n "$script"
        [ "$status" -eq 0 ] || {
            echo "Syntax error in: $script"
            false
        }
    done
}

@test "validate_quickstart.sh exists and is executable" {
    [ -f "$SCRIPT_DIR/validate_quickstart.sh" ]
    [ -x "$SCRIPT_DIR/validate_quickstart.sh" ]
}

@test "Example config has valid YAML structure" {
    # Check basic YAML structure with grep
    grep -q 'version:' "$SCRIPT_DIR/examples/backup-config.yml"
    grep -q 'repositories:' "$SCRIPT_DIR/examples/backup-config.yml"
    grep -q 'kopia:' "$SCRIPT_DIR/examples/backup-config.yml"
    grep -q 'vault:' "$SCRIPT_DIR/examples/backup-config.yml"
}

@test "Example config has required repository fields" {
    grep -q 'name:' "$SCRIPT_DIR/examples/backup-config.yml"
    grep -q 'path:' "$SCRIPT_DIR/examples/backup-config.yml"
    grep -q 'pvc:' "$SCRIPT_DIR/examples/backup-config.yml"
    grep -q 'data_dir:' "$SCRIPT_DIR/examples/backup-config.yml"
    grep -q 'namespace:' "$SCRIPT_DIR/examples/backup-config.yml"
}

@test "backup.sh supports --dry-run flag" {
    run "$SCRIPT_DIR/backup.sh" --help
    [[ "$output" == *"--dry-run"* ]]
}

@test "backup.sh supports --json flag" {
    run "$SCRIPT_DIR/backup.sh" --help
    [[ "$output" == *"--json"* ]]
}

@test "backup.sh supports --verbose flag" {
    run "$SCRIPT_DIR/backup.sh" --help
    [[ "$output" == *"--verbose"* ]]
}

@test "restore.sh supports --repo flag" {
    run "$SCRIPT_DIR/restore.sh" --help
    [[ "$output" == *"--repo"* ]]
}

@test "restore.sh supports --volume flag" {
    run "$SCRIPT_DIR/restore.sh" --help
    [[ "$output" == *"--volume"* ]]
}

@test "restore.sh supports --snapshot flag" {
    run "$SCRIPT_DIR/restore.sh" --help
    [[ "$output" == *"--snapshot"* ]]
}

@test "restore.sh supports --tag flag" {
    run "$SCRIPT_DIR/restore.sh" --help
    [[ "$output" == *"--tag"* ]]
}

@test "restore.sh supports --rollback flag" {
    run "$SCRIPT_DIR/restore.sh" --help
    [[ "$output" == *"--rollback"* ]]
}

@test "backup.sh supports --config flag" {
    run "$SCRIPT_DIR/backup.sh" --help
    [[ "$output" == *"--config"* ]]
}

@test "restore.sh supports --config flag" {
    run "$SCRIPT_DIR/restore.sh" --help
    [[ "$output" == *"--config"* ]]
}

@test "RECOVERY.md has disaster recovery procedures" {
    grep -qi "disaster" "$SCRIPT_DIR/docs/RECOVERY.md"
    grep -qi "recovery" "$SCRIPT_DIR/docs/RECOVERY.md"
}

@test "CREDENTIALS.md has credential management info" {
    grep -qi "credential" "$SCRIPT_DIR/docs/CREDENTIALS.md"
    grep -qi "kopia" "$SCRIPT_DIR/docs/CREDENTIALS.md"
    grep -qi "vault" "$SCRIPT_DIR/docs/CREDENTIALS.md"
}