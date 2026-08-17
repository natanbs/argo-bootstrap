# Quickstart: Local k3d Disaster Recovery

**Date**: 2026-08-17
**Feature**: 006-k3d-disaster-recovery
**Status**: Complete

## Overview

This document provides runnable validation scenarios for the k3d disaster recovery system. Follow these steps to verify the implementation works correctly.

## Prerequisites

- macOS or Linux with Docker installed
- k3d CLI installed
- kubectl CLI installed
- Kopia CLI installed
- HashiCorp Vault CLI installed
- Helm CLI installed
- A running k3d cluster with applications deployed

## Quick Validation (5 minutes)

### 1. Verify Installation

```bash
# Check required tools
k3d version
kubectl version --client
kopia version
vault version
helm version
```

**Expected**: All tools report version numbers without errors.

### 2. Create Test Configuration

```bash
# Create backup-config.yml
cat > backup-config.yml << 'EOF'
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

# Set Kopia password
export KOPIA_PASSWORD="test-password-123"
```

**Expected**: Configuration file created without errors.

### 3. Validate Configuration

```bash
# Run backup in dry-run mode
./backup.sh --config backup-config.yml --dry-run
```

**Expected**: Validation passes, reports what would be backed up.

### 4. Run Backup

```bash
# Perform backup
./backup.sh --config backup-config.yml
```

**Expected**: Backup completes successfully, reports snapshot ID.

### 5. Verify Backup

```bash
# List Kopia snapshots
kopia snapshot list

# Check backup metadata
cat ~/.kopia-test-repository/cluster-metadata.json
```

**Expected**: Snapshot listed, metadata contains version information.

### 6. Destroy Cluster

```bash
# Delete k3d cluster completely
k3d cluster delete

# Verify deletion
k3d cluster list
```

**Expected**: Cluster removed, no containers or volumes remain.

### 7. Restore from Backup

```bash
# Restore environment
./restore.sh --config backup-config.yml
```

**Expected**: Restore completes successfully, cluster recreated with all data.

### 8. Verify Restoration

```bash
# Check cluster status
kubectl get pods --all-namespaces

# Verify Vault is unsealed
vault status

# Check application data
kubectl exec -it <pod-name> -- ls /data
```

**Expected**: All pods running, Vault unsealed, data intact.

## Full Validation (30 minutes)

### Complete Disaster Recovery Test

```bash
# 1. Setup
export KOPIA_PASSWORD="test-password-123"
export VAULT_ADDR="https://127.0.0.1:8200"

# 2. Backup
./backup.sh --config backup-config.yml --json > backup-result.json

# 3. Capture state
kubectl get all --all-namespaces > pre-destroy-state.txt
kubectl get pvc --all-namespaces >> pre-destroy-state.txt

# 4. Destroy
k3d cluster delete
docker volume prune -f

# 5. Restore
./restore.sh --config backup-config.yml --json > restore-result.json

# 6. Verify
kubectl get all --all-namespaces > post-restore-state.txt
kubectl get pvc --all-namespaces >> post-restore-state.txt

# 7. Compare
diff pre-destroy-state.txt post-restore-state.txt
```

**Expected**: No differences in pod/PVC state.

## Selective Restore Test

### Restore Single Repository

```bash
# Backup all
./backup.sh --config backup-config.yml

# Restore only test-app
./restore.sh --config backup-config.yml --repo test-app
```

**Expected**: Only test-app data restored, other apps unaffected.

### Restore Single Volume

```bash
# Backup all
./backup.sh --config backup-config.yml

# Restore only test-app-data volume
./restore.sh --config backup-config.yml --volume test-app-data
```

**Expected**: Only specified volume restored.

## Error Handling Tests

### Configuration Validation

```bash
# Create invalid config
cat > invalid-config.yml << 'EOF'
version: "1.0"
repositories: []
kopia:
  repository_path: "/nonexistent/path"
  password_env: "NONEXISTENT_VAR"
EOF

# Run validation
./backup.sh --config invalid-config.yml --dry-run
```

**Expected**: Validation fails with clear error messages.

### Concurrent Backup Prevention

```bash
# Start backup in background
./backup.sh --config backup-config.yml &
BACKUP_PID=$!

# Try second backup
./backup.sh --config backup-config.yml
echo "Exit code: $?"

# Wait for first backup
wait $BACKUP_PID
```

**Expected**: Second backup fails with lock error.

## Rollback Test

```bash
# Backup
./backup.sh --config backup-config.yml

# Partial restore (simulate failure)
./restore.sh --config backup-config.yml --repo test-app

# Rollback
./restore.sh --config backup-config.yml --rollback
```

**Expected**: Rollback restores pre-restore state.

## Progress Reporting Test

```bash
# Run backup with verbose output
./backup.sh --config backup-config.yml --verbose
```

**Expected**: Progress messages with percentages displayed.

## JSON Output Test

```bash
# Run backup with JSON output
./backup.sh --config backup-config.yml --json
```

**Expected**: Valid JSON output with status, duration, and component details.

## Troubleshooting

### Backup Fails with Lock Error

```bash
# Check for stale lock
cat /tmp/k3d-dr-backup.lock

# Remove stale lock (if process not running)
rm /tmp/k3d-dr-backup.lock
```

### Vault Unseal Fails

```bash
# Check unseal key permissions
ls -la ~/.vault-unseal-key

# Fix permissions
chmod 600 ~/.vault-unseal-key
```

### Kopia Repository Not Found

```bash
# Initialize Kopia repository
kopia repository create filesystem --path ~/.kopia-repository
```

## Success Criteria Verification

| Criterion | Test Command | Expected Result |
|-----------|--------------|-----------------|
| SC-001 | Full destroy + restore | Environment recovered |
| SC-002 | Compare pre/post data | Data identical |
| SC-003 | Check Vault/ESO | Secrets restored |
| SC-004 | Invalid config | Clear error messages |
| SC-005 | Selective restore | Other services unaffected |
| SC-007 | Integrity check | Verification passes |
| SC-008 | Check for cloud deps | Local only |
| SC-009 | Repeat test | Consistent results |
| SC-010 | Check metadata | No plaintext secrets |

## Next Steps

After completing quickstart validation:
1. Review [data-model.md](data-model.md) for entity details
2. Review [contracts/](contracts/) for interface specifications
3. Run `/spec.tasks` to generate implementation tasks
