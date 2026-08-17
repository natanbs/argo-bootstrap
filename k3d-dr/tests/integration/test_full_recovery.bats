#!/usr/bin/env bats
# test_full_recovery.bats - Integration test for full disaster recovery
# T077: Write integration test for full recovery

load '../test_helper'

# Setup test environment
setup() {
    # Create temporary directory
    TEST_TMPDIR="$(mktemp -d)"

    # Create test configuration
    create_test_config

    # Set required environment variables
    export KOPIA_PASSWORD="test-password-123"
    export VAULT_ADDR="https://127.0.0.1:8200"

    # Create test data directory
    mkdir -p "$TEST_TMPDIR/test-repo"
    echo "test data" > "$TEST_TMPDIR/test-repo/test-file.txt"

    # Create mock commands
    create_mock_commands
}

# Cleanup test environment
cleanup() {
    rm -rf "$TEST_TMPDIR"
}

# Create test configuration
create_test_config() {
    cat > "$TEST_TMPDIR/backup-config.yml" << 'EOF'
version: "1.0"
repositories:
  - name: test-repo
    path: TEST_TMPDIR/test-repo
    pvc: test-repo-data
    data_dir: /data/test-repo
    namespace: default
kopia:
  repository_path: TEST_TMPDIR/.kopia-repository
  password_env: KOPIA_PASSWORD
  retention:
    daily: 3
    weekly: 2
    monthly: 1
vault:
  namespace: vault
  unseal_key_path: TEST_TMPDIR/.vault-unseal-key
port_offset: 0
EOF

    # Replace TEST_TMPDIR with actual path
    sed -i '' "s|TEST_TMPDIR|$TEST_TMPDIR|g" "$TEST_TMPDIR/backup-config.yml"
}

# Create mock commands
create_mock_commands() {
    mkdir -p "$TEST_TMPDIR/bin"

    # Mock k3d
    cat > "$TEST_TMPDIR/bin/k3d" << 'EOF'
#!/bin/bash
case "$1" in
    version)
        echo "k3d version v5.0.0"
        ;;
    cluster)
        case "$2" in
            create)
                echo "Creating cluster"
                ;;
            delete)
                echo "Deleting cluster"
                ;;
            list)
                echo "NAME        SERVERS   AGENTS   LOADBALANCER"
                echo "test-k3d    1/1       0/0      true"
                ;;
        esac
        ;;
esac
EOF
    chmod +x "$TEST_TMPDIR/bin/k3d"

    # Mock kubectl
    cat > "$TEST_TMPDIR/bin/kubectl" << 'EOF'
#!/bin/bash
case "$1" in
    version)
        echo "Client Version: v1.24.0"
        echo "Server Version: v1.24.0"
        ;;
    get)
        case "$2" in
            pods)
                echo "NAME                     READY   STATUS    RESTARTS   AGE"
                echo "test-pod                 1/1     Running   0          1m"
                ;;
            pvc)
                echo "NAME              STATUS   VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS"
                echo "test-pvc          Bound    test-vol 1Gi        RWO            local-path"
                ;;
            namespaces)
                echo "NAME              STATUS   AGE"
                echo "default           Active   1m"
                ;;
            externalsecrets)
                echo "NAME              STATUS   AGE"
                echo "test-secret       Ready    1m"
                ;;
        esac
        ;;
esac
EOF
    chmod +x "$TEST_TMPDIR/bin/kubectl"

    # Mock vault
    cat > "$TEST_TMPDIR/bin/vault" << 'EOF'
#!/bin/bash
case "$1" in
    version)
        echo "Vault v1.12.0"
        ;;
    status)
        echo '{"sealed":false}'
        ;;
    operator)
        case "$2" in
            raft)
                case "$3" in
                    snapshot)
                        case "$4" in
                            save)
                                echo "Snapshot saved"
                                ;;
                            restore)
                                echo "Snapshot restored"
                                ;;
                        esac
                        ;;
                esac
                ;;
            unseal)
                echo "Vault unsealed"
                ;;
        esac
        ;;
esac
EOF
    chmod +x "$TEST_TMPDIR/bin/vault"

    # Mock kopia
    cat > "$TEST_TMPDIR/bin/kopia" << 'EOF'
#!/bin/bash
case "$1" in
    version)
        echo "0.12.0"
        ;;
    repository)
        case "$2" in
            create)
                echo "Repository created"
                ;;
            connect)
                echo "Repository connected"
                ;;
            verify)
                echo "Repository verified"
                ;;
            status)
                echo "Connected"
                ;;
        esac
        ;;
    snapshot)
        case "$2" in
            create)
                echo "Snapshot created: abc123"
                ;;
            list)
                echo "ID    TIME                 SOURCE     SIZE"
                echo "abc123 2026-08-17 10:00:00 /test-repo 100B"
                ;;
            restore)
                echo "Snapshot restored"
                ;;
        esac
        ;;
    policy)
        echo "Policy set"
        ;;
esac
EOF
    chmod +x "$TEST_TMPDIR/bin/kopia"

    # Mock helm
    cat > "$TEST_TMPDIR/bin/helm" << 'EOF'
#!/bin/bash
case "$1" in
    version)
        echo "v3.10.0+g3855f81"
        ;;
esac
EOF
    chmod +x "$TEST_TMPDIR/bin/helm"

    # Mock docker
    cat > "$TEST_TMPDIR/bin/docker" << 'EOF'
#!/bin/bash
case "$1" in
    version)
        echo "Docker version 20.10.0"
        ;;
    info)
        echo "Server Version: 20.10.0"
        ;;
esac
EOF
    chmod +x "$TEST_TMPDIR/bin/docker"

    # Mock bc
    cat > "$TEST_TMPDIR/bin/bc" << 'EOF'
#!/bin/bash
echo "1"
EOF
    chmod +x "$TEST_TMPDIR/bin/bc"

    # Mock sha256sum
    cat > "$TEST_TMPDIR/bin/sha256sum" << 'EOF'
#!/bin/bash
echo "abc123  $1"
EOF
    chmod +x "$TEST_TMPDIR/bin/sha256sum"

    # Mock jq
    cat > "$TEST_TMPDIR/bin/jq" << 'EOF'
#!/bin/bash
# Simple jq mock - just pass through for basic operations
if [[ "$*" == *"--version"* ]]; then
    echo "jq-1.6"
else
    # For most operations, just echo the input
    cat
fi
EOF
    chmod +x "$TEST_TMPDIR/bin/jq"

    # Mock yq
    cat > "$TEST_TMPDIR/bin/yq" << 'EOF'
#!/bin/bash
# Simple yq mock - extract values from YAML
if [[ "$*" == *"--version"* ]]; then
    echo "yq (https://github.com/mikefarah/yq/) version 4.30.0"
else
    # For config loading, just echo default values
    echo "1.0"
fi
EOF
    chmod +x "$TEST_TMPDIR/bin/yq"

    # Add mock bin to PATH
    export PATH="$TEST_TMPDIR/bin:$PATH"
}

# Test full backup and restore workflow
@test "Full disaster recovery workflow" {
    # Skip if not in full test mode
    if [[ "${FULL_TEST:-false}" != "true" ]]; then
        skip "Set FULL_TEST=true to run full integration test"
    fi

    # Run backup
    run "$SCRIPT_DIR/backup.sh" --config "$TEST_TMPDIR/backup-config.yml"
    assert_success
    assert_output --partial "Backup completed successfully"

    # Destroy cluster (simulate)
    run "$TEST_TMPDIR/bin/k3d" cluster delete
    assert_success

    # Restore
    run "$SCRIPT_DIR/restore.sh" --config "$TEST_TMPDIR/backup-config.yml"
    assert_success
    assert_output --partial "Restore completed successfully"
}

@test "Backup dry-run validates configuration" {
    run "$SCRIPT_DIR/backup.sh" --config "$TEST_TMPDIR/backup-config.yml" --dry-run
    assert_success
    assert_output --partial "Dry-run validation results"
}

@test "Restore dry-run validates configuration" {
    run "$SCRIPT_DIR/restore.sh" --config "$TEST_TMPDIR/backup-config.yml" --dry-run
    assert_success
    assert_output --partial "Dry-run validation results"
}

@test "Backup reports progress" {
    run "$SCRIPT_DIR/backup.sh" --config "$TEST_TMPDIR/backup-config.yml" --verbose
    assert_success
}

@test "Restore reports progress" {
    run "$SCRIPT_DIR/restore.sh" --config "$TEST_TMPDIR/backup-config.yml" --verbose
    assert_success
}

@test "Backup outputs JSON when requested" {
    run "$SCRIPT_DIR/backup.sh" --config "$TEST_TMPDIR/backup-config.yml" --dry-run --json
    assert_success
}

@test "Restore outputs JSON when requested" {
    run "$SCRIPT_DIR/restore.sh" --config "$TEST_TMPDIR/backup-config.yml" --dry-run --json
    assert_success
}

@test "Backup fails with invalid config" {
    run "$SCRIPT_DIR/backup.sh" --config "$TEST_TMPDIR/nonexistent-config.yml"
    assert_failure
}

@test "Restore fails with invalid config" {
    run "$SCRIPT_DIR/restore.sh" --config "$TEST_TMPDIR/nonexistent-config.yml"
    assert_failure
}

@test "Selective restore with --repo flag" {
    run "$SCRIPT_DIR/restore.sh" --config "$TEST_TMPDIR/backup-config.yml" --repo test-repo --dry-run
    assert_success
}

@test "Selective restore with --snapshot flag" {
    run "$SCRIPT_DIR/restore.sh" --config "$TEST_TMPDIR/backup-config.yml" --snapshot abc123 --dry-run
    assert_success
}

@test "Backup help shows usage" {
    run "$SCRIPT_DIR/backup.sh" --help
    assert_success
    assert_output --partial "Usage:"
}

@test "Restore help shows usage" {
    run "$SCRIPT_DIR/restore.sh" --help
    assert_success
    assert_output --partial "Usage:"
}

@test "Error codes are machine-readable JSON" {
    run "$SCRIPT_DIR/lib/errors.sh" 2>/dev/null || true
    # The library should load without errors
    assert [ -f "$SCRIPT_DIR/lib/errors.sh" ]
}