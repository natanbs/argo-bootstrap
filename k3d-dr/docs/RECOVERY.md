# Recovery Procedures

**Version**: 1.0  
**Date**: 2026-08-17  
**Feature**: 006-k3d-disaster-recovery

## Overview

This document describes the recovery procedures for the k3d disaster recovery system.

## Prerequisites

Before performing recovery, ensure you have:

1. Kopia installed and configured
2. Vault unseal key file (if using auto-unseal)
3. Docker running
4. k3d installed
5. kubectl installed
6. Helm installed (for infrastructure apps)
7. kubectl configured for the target cluster

## Recovery Scenarios

### 1. Full Disaster Recovery

**Use case**: Complete cluster destruction and single-command recovery.

**Steps**:

1. Ensure backup exists:
   ```bash
   ./backup.sh -c backup-config.yml
   ```

2. Destroy and recreate cluster:
   ```bash
   k3d cluster delete k3d-dr
   ./restore.sh -c backup-config.yml
   ```

3. Verify recovery:
   ```bash
   kubectl get pods --all-namespaces
   vault status
   ```

### 2. Selective Repository Restore

**Use case**: Restore specific repository without full cluster rebuild.

**Steps**:

1. List available snapshots:
   ```bash
   kopia snapshot list --path /path/to/repository
   ```

2. Restore specific repository:
   ```bash
   ./restore.sh -c backup-config.yml --repo <repository-name>
   ```

3. Verify repository:
   ```bash
   ls -la /path/to/repository
   ```

### 3. Selective Volume Restore

**Use case**: Restore specific volume without affecting other data.

**Steps**:

1. List available PVCs:
   ```bash
   kubectl get pvc --all-namespaces
   ```

2. Restore specific volume:
   ```bash
   ./restore.sh -c backup-config.yml --volume <pvc-name>
   ```

3. Verify volume:
   ```bash
   kubectl get pvc <pvc-name> -n <namespace>
   ```

### 4. Restore from Specific Snapshot

**Use case**: Restore from a known good point in time.

**Steps**:

1. List available snapshots:
   ```bash
   kopia snapshot list --path /path/to/repository
   ```

2. Restore from specific snapshot:
   ```bash
   ./restore.sh -c backup-config.yml --snapshot <snapshot-id>
   ```

3. Verify restore:
   ```bash
   ls -la /path/to/repository
   ```

### 5. Rollback Partial Restore

**Use case**: Revert a failed or partial restore operation.

**Steps**:

1. Run rollback:
   ```bash
   ./restore.sh -c backup-config.yml --rollback
   ```

2. Verify rollback:
   ```bash
   ls -la /path/to/repository
   ```

## Vault Recovery

### Auto-Unseal

If using auto-unseal with stored key:

1. Ensure unseal key file exists:
   ```bash
   ls -la /path/to/unseal-key
   ```

2. Check key permissions:
   ```bash
   stat -f "%Lp" /path/to/unseal-key
   # Should show: 600
   ```

3. Unseal Vault:
   ```bash
   vault operator unseal -key-file /path/to/unseal-key
   ```

### Manual Unseal

If manual unseal is required:

1. Get unseal keys from secure storage

2. Unseal Vault:
   ```bash
   vault operator unseal <key-1>
   vault operator unseal <key-2>
   vault operator unseal <key-3>
   ```

3. Verify Vault status:
   ```bash
   vault status
   ```

## Troubleshooting

### Issue: Backup fails with "Repository path does not exist"

**Solution**:
```bash
mkdir -p /path/to/repository
```

### Issue: Restore fails with "PVC not found"

**Solution**:
```bash
kubectl create namespace <namespace>
kubectl apply -f pvc.yaml
```

### Issue: Vault fails to unseal

**Solution**:
1. Check unseal key file exists and has correct permissions
2. Verify Vault is running
3. Check Vault logs for errors

### Issue: Database hook fails

**Solution**:
1. Verify database is running in the namespace
2. Check hook script is executable
3. Review hook output for errors
4. Adjust timeout if needed

### Issue: Port conflicts during restore

**Solution**:
1. Check port offset configuration
2. Ensure no other services are using the ports
3. Adjust port offset in backup-config.yml

## Verification Checklist

After recovery, verify:

- [ ] All pods are running
- [ ] Vault is unsealed
- [ ] ESO is connected to Vault
- [ ] ExternalSecrets are synced
- [ ] Applications are healthy
- [ ] Data is accessible
- [ ] Ingress resources are working

## Backup Verification

To verify backup integrity:

```bash
# Verify Kopia repository
kopia repository verify

# List all snapshots
kopia snapshot list

# Check specific snapshot
kopia snapshot show <snapshot-id>
```

## Monitoring

Monitor recovery progress:

1. Watch pod status:
   ```bash
   kubectl get pods -w
   ```

2. Check Vault status:
   ```bash
   vault status -format=json
   ```

3. Monitor ESO:
   ```bash
   kubectl get externalsecrets --all-namespaces -w
   ```

## Rollback

If recovery fails:

1. Stop the restore process
2. Review error logs
3. Fix the issue
4. Run restore again
5. Or rollback:
   ```bash
   ./restore.sh -c backup-config.yml --rollback
   ```

## Support

For issues not covered here:

1. Check application logs
2. Review Kopia logs
3. Check Vault logs
4. Consult the troubleshooting section in the main documentation