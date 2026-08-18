# Quickstart: Fix Code Review Bugs

**Feature**: 007-fix-code-review-bugs
**Date**: 2026-08-18

## Prerequisites

- bash 3.2+ (macOS/Linux)
- kopia installed
- kubectl configured
- k3d cluster running (for integration testing)

## Validation Scenarios

### Scenario 1: Secret Validation (FR-001)

**Setup**: Create a test config file with legitimate key names

```bash
cat > /tmp/test-config.yaml << 'EOF'
kopia:
  repository_path: /tmp/kopia-repo
  password_env: KOPIA_PASSWORD
vault:
  unseal_key_path: /tmp/unseal-key
EOF
```

**Test**:
```bash
source k3d-dr/lib/validation.sh
validate_no_secrets /tmp/test-config.yaml
echo "Exit code: $?"
```

**Expected**: Exit code 0 (validation passes)

### Scenario 2: Secret Detection (FR-001)

**Setup**: Create a config with inline secret

```bash
cat > /tmp/test-secret.yaml << 'EOF'
kopia:
  password: my-super-secret-password
EOF
```

**Test**:
```bash
source k3d-dr/lib/validation.sh
validate_no_secrets /tmp/test-secret.yaml
echo "Exit code: $?"
```

**Expected**: Exit code 1 (validation fails)

### Scenario 3: Env Override (FR-002)

**Setup**: Set environment variable

```bash
export KOPIA_PASSWORD_ENV=MY_PASSWORD
```

**Test**:
```bash
source k3d-dr/lib/config.sh
config_load /tmp/test-config.yaml
config_get "kopia.password_env"
```

**Expected**: Output is `MY_PASSWORD` (not the YAML value)

### Scenario 4: Vault CA Cert (FR-003)

**Setup**: Running k3d cluster with Vault

**Test**:
```bash
source k3d-dr/restore.sh
# Run the Vault K8s auth setup
_configure_vault_k8s_auth
```

**Expected**: Command completes without hanging

### Scenario 5: Retention Flags (FR-004)

**Setup**: Config with different daily and latest values

```bash
cat > /tmp/test-retention.yaml << 'EOF'
kopia:
  retention:
    daily: 7
    latest: 30
EOF
```

**Test**:
```bash
source k3d-dr/lib/kopia.sh
kopia_retention 7 4 12 30  # daily weekly monthly latest
```

**Expected**: Kopia policy set with `--keep-latest 30 --keep-daily 7`

### Scenario 6: Idempotency Check (FR-005)

**Setup**: PVC exists but no pod mounted

**Test**:
```bash
source k3d-dr/restore.sh
# Run idempotency check against PVC with no pods
_restore_repository 0
```

**Expected**: Falls through to restore (no error)

### Scenario 7: Bash Syntax Validation (SC-006)

**Test**:
```bash
bash -n k3d-dr/backup.sh
bash -n k3d-dr/restore.sh
bash -n k3d-dr/lib/config.sh
bash -n k3d-dr/lib/validation.sh
bash -n k3d-dr/lib/kopia.sh
bash -n k3d-dr/lib/logging.sh
```

**Expected**: All pass (exit code 0)

### Scenario 8: Unit Tests (SC-007)

**Test**:
```bash
cd k3d-dr/tests
bats unit/
```

**Expected**: All previously passing tests still pass
