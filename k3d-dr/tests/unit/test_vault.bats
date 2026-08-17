#!/usr/bin/env bats
# test_vault.bats - Unit tests for vault.sh

load '../test_helper'

@test "vault_init sets namespace" {
    # Mock vault command
    export PATH="$TEST_TMPDIR:$PATH"
    echo '#!/bin/bash' > "$TEST_TMPDIR/vault"
    chmod +x "$TEST_TMPDIR/vault"
    
    run vault_init "vault" "/tmp/unseal-key"
    assert_success
    assert_equal "vault" "$VAULT_NAMESPACE"
    assert_equal "/tmp/unseal-key" "$VAULT_UNSEAL_KEY_PATH"
}

@test "vault_is_running checks vault status" {
    # Mock vault command that succeeds
    export PATH="$TEST_TMPDIR:$PATH"
    cat > "$TEST_TMPDIR/vault" << 'EOF'
#!/bin/bash
if [[ "$*" == *"status"* ]]; then
    exit 0
fi
exit 1
EOF
    chmod +x "$TEST_TMPDIR/vault"
    
    VAULT_NAMESPACE="vault"
    run vault_is_running
    assert_success
}

@test "vault_is_sealed returns sealed status" {
    # Mock vault command
    export PATH="$TEST_TMPDIR:$PATH"
    cat > "$TEST_TMPDIR/vault" << 'EOF'
#!/bin/bash
echo '{"sealed":true}'
EOF
    chmod +x "$TEST_TMPDIR/vault"
    
    VAULT_NAMESPACE="vault"
    run vault_is_sealed
    assert_success
    assert_equal "true" "$output"
}

@test "vault_save_snapshot creates snapshot" {
    # Mock vault command
    export PATH="$TEST_TMPDIR:$PATH"
    cat > "$TEST_TMPDIR/vault" << 'EOF'
#!/bin/bash
if [[ "$*" == *"status"* ]]; then
    echo '{"sealed":false}'
    exit 0
fi
if [[ "$*" == *"snapshot save"* ]]; then
    echo "snapshot saved"
    exit 0
fi
exit 1
EOF
    chmod +x "$TEST_TMPDIR/vault"
    
    VAULT_NAMESPACE="vault"
    run vault_save_snapshot "$TEST_TMPDIR/snapshot.db"
    assert_success
}

@test "vault_auto_unseal fails without key path" {
    VAULT_NAMESPACE="vault"
    VAULT_UNSEAL_KEY_PATH=""
    
    run vault_auto_unseal
    assert_failure
}

@test "vault_auto_unseal fails with nonexistent key" {
    VAULT_NAMESPACE="vault"
    VAULT_UNSEAL_KEY_PATH="/nonexistent/key"
    
    run vault_auto_unseal
    assert_failure
}

@test "vault_save_policies saves policies" {
    # Create temporary directory
    mkdir -p "$TEST_TMPDIR/policies"
    
    # Mock vault command
    export PATH="$TEST_TMPDIR:$PATH"
    cat > "$TEST_TMPDIR/vault" << 'EOF'
#!/bin/bash
if [[ "$*" == *"policy list"* ]]; then
    echo '["default","root","my-policy"]'
    exit 0
fi
if [[ "$*" == *"policy read"* ]]; then
    echo 'path "secret/*" { capabilities = ["read"] }'
    exit 0
fi
exit 1
EOF
    chmod +x "$TEST_TMPDIR/vault"
    
    VAULT_NAMESPACE="vault"
    run vault_save_policies "$TEST_TMPDIR/policies"
    assert_success
    [[ -f "$TEST_TMPDIR/policies/my-policy.hcl" ]]
}