# Hook Interface Contract

**Version**: 1.0
**Date**: 2026-08-17
**Feature**: 006-k3d-disaster-recovery

## Overview

This document defines the interface for repository-specific database backup hooks (FR-008).

## Hook Types

### 1. Database Backup Hook (`db-backup.sh`)

**Purpose**: Create a consistent database backup before Kopia snapshot.

**Input Environment Variables**:

| Variable | Description | Required |
|----------|-------------|----------|
| `REPOSITORY` | Repository name | Yes |
| `DATABASE` | Database type (e.g., "postgres", "mysql") | Yes |
| `BACKUP_PATH` | Directory to write backup file | Yes |
| `NAMESPACE` | Kubernetes namespace | Yes |
| `TIMEOUT` | Hook execution timeout in seconds | No (default: 300) |

**Expected Behavior**:
1. Connect to database using native tools
2. Create consistent backup dump
3. Write dump to `$BACKUP_PATH/<repository>-<timestamp>.<extension>`
4. Output checksum to `$BACKUP_PATH/<repository>-<timestamp>.checksum`
5. Exit with code 0 on success, non-zero on failure

**Exit Codes**:

| Code | Description |
|------|-------------|
| 0 | Backup completed successfully |
| 1 | General error |
| 2 | Database connection failed |
| 3 | Database dump failed |
| 4 | Checksum verification failed |
| 5 | Timeout exceeded |

**Example** (`db-backup.sh` for PostgreSQL):

```bash
#!/bin/bash
set -euo pipefail

# Required environment variables
REPOSITORY="${REPOSITORY:?REPOSITORY required}"
DATABASE="${DATABASE:?DATABASE required}"
BACKUP_PATH="${BACKUP_PATH:?BACKUP_PATH required}"
NAMESPACE="${NAMESPACE:?NAMESPACE required}"
TIMEOUT="${TIMEOUT:-300}"

# Create backup file
BACKUP_FILE="${BACKUP_PATH}/${REPOSITORY}-$(date +%Y%m%d-%H%M%S).sql"

# Run pg_dump with timeout
timeout "$TIMEOUT" kubectl exec -n "$NAMESPACE" \
  deployment/postgres -- \
  pg_dump -U postgres "$DATABASE" > "$BACKUP_FILE"

# Create checksum
sha256sum "$BACKUP_FILE" > "${BACKUP_FILE}.checksum"

echo "Backup created: $BACKUP_FILE"
exit 0
```

### 2. Database Restore Hook (`db-restore.sh`)

**Purpose**: Restore database from backup dump.

**Input Environment Variables**:

| Variable | Description | Required |
|----------|-------------|----------|
| `REPOSITORY` | Repository name | Yes |
| `DATABASE` | Database type (e.g., "postgres", "mysql") | Yes |
| `BACKUP_PATH` | Directory containing backup file | Yes |
| `NAMESPACE` | Kubernetes namespace | Yes |
| `TIMEOUT` | Hook execution timeout in seconds | No (default: 300) |

**Expected Behavior**:
1. Find backup file in `$BACKUP_PATH`
2. Verify checksum
3. Restore database using native tools
4. Exit with code 0 on success, non-zero on failure

**Exit Codes**:

| Code | Description |
|------|-------------|
| 0 | Restore completed successfully |
| 1 | General error |
| 2 | Database connection failed |
| 3 | Checksum verification failed |
| 4 | Database restore failed |
| 5 | Timeout exceeded |

**Example** (`db-restore.sh` for PostgreSQL):

```bash
#!/bin/bash
set -euo pipefail

# Required environment variables
REPOSITORY="${REPOSITORY:?REPOSITORY required}"
DATABASE="${DATABASE:?DATABASE required}"
BACKUP_PATH="${BACKUP_PATH:?BACKUP_PATH required}"
NAMESPACE="${NAMESPACE:?NAMESPACE required}"
TIMEOUT="${TIMEOUT:-300}"

# Find backup file
BACKUP_FILE=$(ls -t "${BACKUP_PATH}/${REPOSITORY}"-*.sql 2>/dev/null | head -1)
if [ -z "$BACKUP_FILE" ]; then
  echo "No backup file found for repository: $REPOSITORY"
  exit 1
fi

# Verify checksum
if ! sha256sum -c "${BACKUP_FILE}.checksum"; then
  echo "Checksum verification failed for: $BACKUP_FILE"
  exit 3
fi

# Run pg_restore with timeout
timeout "$TIMEOUT" kubectl exec -i -n "$NAMESPACE" \
  deployment/postgres -- \
  psql -U postgres "$DATABASE" < "$BACKUP_FILE"

echo "Restore completed: $BACKUP_FILE"
exit 0
```

## Hook Configuration

### backup-config.yml

```yaml
repositories:
  - name: my-app
    path: ~/projects/repos/my-app
    pvc: my-app-data
    data_dir: /data/my-app
    namespace: default
    db_hook: ~/projects/repos/my-app/hooks/db-backup.sh
    db_restore_hook: ~/projects/repos/my-app/hooks/db-restore.sh

database_hooks:
  timeout: 300
  mandatory: true
```

### Mandatory vs Optional Hooks

- **Mandatory** (`mandatory: true`): Hook failure causes backup/restore to fail
- **Optional** (`mandatory: false`): Hook failure is logged as warning, operation continues

## Error Handling

### Hook Timeout

If a hook exceeds the configured timeout:
1. Process is killed with SIGTERM
2. Wait 10 seconds for graceful shutdown
3. If still running, kill with SIGKILL
4. Hook is marked as failed
5. If mandatory, backup/restore fails with exit code 5

### Hook Failure

If a hook exits with non-zero code:
1. Error output is captured
2. Error is logged with hook name and exit code
3. If mandatory, backup/restore fails
4. If optional, operation continues with warning

### Hook Not Found

If configured hook script does not exist:
1. Error is logged
2. If mandatory, backup/restore fails with exit code 5
3. If optional, hook is skipped with warning

## Testing Hooks

### Unit Testing

Test hooks in isolation using mock environment:

```bash
REPOSITORY=test-db \
DATABASE=postgres \
BACKUP_PATH=/tmp/test-backup \
NAMESPACE=default \
./db-backup.sh
```

### Integration Testing

Test hooks with real database in k3d cluster:

```bash
# Deploy test database
kubectl apply -f tests/fixtures/postgres.yaml

# Run backup hook
./backup.sh --config tests/fixtures/test-config.yml

# Verify backup exists
ls -la ~/.kopia-repository/

# Run restore hook
./restore.sh --config tests/fixtures/test-config.yml --repo test-db
```

## Security Considerations

1. **No Secrets in Environment**: Database credentials should be retrieved from Vault or Kubernetes Secrets, not passed via environment variables
2. **Restrictive Permissions**: Hook scripts should have 0700 permissions
3. **Input Validation**: Hooks should validate all input environment variables
4. **Timeout Enforcement**: Always enforce timeout to prevent runaway processes
5. **Checksum Verification**: Always verify checksums before restore
