#!/usr/bin/env bats
# test_kopia.bats - Unit tests for kopia.sh

load '../test_helper'

@test "kopia_init sets repository path" {
    # Mock kopia command
    export PATH="$TEST_TMPDIR:$PATH"
    echo '#!/bin/bash' > "$TEST_TMPDIR/kopia"
    chmod +x "$TEST_TMPDIR/kopia"
    
    export KOPIA_TEST_PASSWORD="test-password"
    
    run kopia_init "/tmp/test-repo" "KOPIA_TEST_PASSWORD"
    assert_success
    assert_equal "/tmp/test-repo" "$KOPIA_REPO_PATH"
    assert_equal "test-password" "$KOPIA_PASSWORD"
}

@test "kopia_init fails when password not set" {
    unset KOPIA_TEST_PASSWORD
    
    run kopia_init "/tmp/test-repo" "KOPIA_TEST_PASSWORD"
    assert_failure
}

@test "kopia_snapshot creates snapshot" {
    # Mock kopia command
    export PATH="$TEST_TMPDIR:$PATH"
    echo '#!/bin/bash' > "$TEST_TMPDIR/kopia"
    chmod +x "$TEST_TMPDIR/kopia"
    
    mkdir -p "$TEST_TMPDIR/source"
    
    run kopia_snapshot "$TEST_TMPDIR/source" "test-tag"
    assert_success
}

@test "kopia_snapshot fails for nonexistent path" {
    run kopia_snapshot "/nonexistent/path" "test-tag"
    assert_failure
}

@test "kopia_verify checks repository" {
    # Mock kopia command
    export PATH="$TEST_TMPDIR:$PATH"
    echo '#!/bin/bash' > "$TEST_TMPDIR/kopia"
    chmod +x "$TEST_TMPDIR/kopia"
    
    export KOPIA_PASSWORD="test-password"
    
    run kopia_verify
    assert_success
}

@test "kopia_list_snapshots lists snapshots" {
    # Mock kopia command
    export PATH="$TEST_TMPDIR:$PATH"
    cat > "$TEST_TMPDIR/kopia" << 'EOF'
#!/bin/bash
echo "snapshot1"
echo "snapshot2"
EOF
    chmod +x "$TEST_TMPDIR/kopia"
    
    run kopia_list_snapshots "/tmp/test"
    assert_success
    assert_contains "$output" "snapshot1"
    assert_contains "$output" "snapshot2"
}