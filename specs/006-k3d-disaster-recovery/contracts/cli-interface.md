# CLI Interface Contract

**Version**: 1.0
**Date**: 2026-08-17
**Feature**: 006-k3d-disaster-recovery

## Overview

This document defines the command-line interface for the backup and restore scripts.

## backup.sh

### Usage

```bash
backup.sh [OPTIONS]
```

### Options

| Option | Short | Description | Default |
|--------|-------|-------------|---------|
| `--config <path>` | `-c` | Path to backup configuration file | `./backup-config.yml` |
| `--dry-run` | `-n` | Validate configuration without performing backup | false |
| `--verbose` | `-v` | Enable verbose logging | false |
| `--json` | `-j` | Output results in JSON format | false |
| `--skip-validation` | | Skip pre-backup validation | false |
| `--skip-hooks` | | Skip database backup hooks | false |

### Exit Codes

| Code | Description |
|------|-------------|
| 0 | Backup completed successfully |
| 1 | General error |
| 2 | Configuration validation failed |
| 3 | Kopia repository error |
| 4 | Vault snapshot error |
| 5 | Database hook error |
| 6 | Lock acquisition failed (concurrent backup) |
| 7 | Insufficient disk space |

### Output Format

**Human-readable** (default):
```
[2026-08-17 10:00:00] INFO  Starting backup...
[2026-08-17 10:00:01] INFO  Validating configuration...
[2026-08-17 10:00:02] INFO  Backing up Vault snapshots: 45%
[2026-08-17 10:00:05] INFO  Backing up repository my-app: 60%
[2026-08-17 10:00:10] INFO  Verifying Kopia integrity...
[2026-08-17 10:00:12] INFO  Backup complete. Snapshot ID: abc123
```

**JSON** (`--json`):
```json
{
  "status": "success",
  "snapshot_id": "abc123",
  "duration_seconds": 12,
  "components": {
    "vault": {"status": "success", "duration_seconds": 3},
    "repositories": {"status": "success", "count": 2, "duration_seconds": 7},
    "kopia": {"status": "success", "duration_seconds": 2}
  },
  "metadata_path": "/path/to/cluster-metadata.json"
}
```

### Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `KOPIA_PASSWORD` | Password for Kopia repository | Yes |
| `VAULT_ADDR` | Vault server address | No (default: https://127.0.0.1:8200) |
| `VAULT_TOKEN` | Vault authentication token | No (uses Kubernetes auth) |
| `KUBECONFIG` | Path to kubeconfig file | No (default: ~/.kube/config) |

## restore.sh

### Usage

```bash
restore.sh [OPTIONS]
```

### Options

| Option | Short | Description | Default |
|--------|-------|-------------|---------|
| `--config <path>` | `-c` | Path to backup configuration file | `./backup-config.yml` |
| `--snapshot <id>` | `-s` | Restore from specific snapshot ID | latest |
| `--tag <name>` | `-t` | Restore from snapshot with tag | none |
| `--repo <name>` | `-r` | Restore specific repository only | all |
| `--volume <name>` | `-v` | Restore specific volume only | all |
| `--rollback` | | Rollback partial restore to pre-restore state | false |
| `--dry-run` | `-n` | Show what would be restored without executing | false |
| `--verbose` | `-V` | Enable verbose logging | false |
| `--json` | `-j` | Output results in JSON format | false |
| `--force` | `-f` | Skip confirmation prompts | false |

### Exit Codes

| Code | Description |
|------|-------------|
| 0 | Restore completed successfully |
| 1 | General error |
| 2 | Configuration validation failed |
| 3 | Kopia repository error |
| 4 | Vault restore error |
| 5 | Kubernetes apply error |
| 6 | Health check failed |
| 7 | Rollback failed |

### Output Format

**Human-readable** (default):
```
[2026-08-17 10:00:00] INFO  Starting restore...
[2026-08-17 10:00:01] INFO  Validating configuration...
[2026-08-17 10:00:02] INFO  Creating k3d cluster...
[2026-08-17 10:00:10] INFO  Restoring Vault: 30%
[2026-08-17 10:00:15] INFO  Restoring ESO: 50%
[2026-08-17 10:00:20] INFO  Restoring repositories: 75%
[2026-08-17 10:00:25] INFO  Verifying health...
[2026-08-17 10:00:30] INFO  Restore complete. 2/2 repositories restored.
```

**JSON** (`--json`):
```json
{
  "status": "success",
  "restore_id": "restore-abc123",
  "duration_seconds": 30,
  "components": {
    "k3d": {"status": "success", "duration_seconds": 8},
    "vault": {"status": "success", "duration_seconds": 5},
    "eso": {"status": "success", "duration_seconds": 5},
    "repositories": {"status": "success", "count": 2, "duration_seconds": 7},
    "verification": {"status": "success", "duration_seconds": 5}
  },
  "restored_repositories": ["my-app", "another-app"],
  "skipped_repositories": []
}
```

### Interactive Selection

When `--snapshot` and `--tag` are not specified, and multiple snapshots exist, the user is prompted to select:

```
Available snapshots:
1. abc123 (2026-08-17 10:00:00, 1.2 GB)
456def (2026-08-16 10:00:00, 1.1 GB)
789ghi (2026-08-15 10:00:00, 1.0 GB)

Select snapshot [1-3] (default: 1):
```

## Error Output Format

All errors are output in JSON format (FR-051):

```json
{
  "error_code": "VAULT_UNSEAL_KEY_MISSING",
  "message": "Vault unseal key file not found",
  "component": "vault",
  "field": "vault.unseal_key_path",
  "suggested_remediation": "Ensure the unseal key file exists at the configured path or update vault.unseal_key_path in backup-config.yml"
}
```

## Logging Format

All logs are output in structured JSON format (FR-046):

```json
{
  "timestamp": "2026-08-17T10:00:00Z",
  "level": "INFO",
  "message": "Backing up Vault snapshots",
  "component": "vault",
  "metadata": {
    "progress_percent": 45,
    "snapshot_id": "abc123"
  }
}
```
