# Data Model: Local k3d Disaster Recovery

**Date**: 2026-08-17
**Feature**: 006-k3d-disaster-recovery
**Status**: Complete

## Overview

This document defines the data entities, their relationships, and validation rules for the k3d disaster recovery system.

## Entity Relationship Diagram

```
┌─────────────────────┐
│   Backup Config     │
│   (backup-config.yml)│
└──────────┬──────────┘
           │
           ├─────────────────────────────┐
           │                             │
           ▼                             ▼
┌─────────────────────┐       ┌─────────────────────┐
│   Repository        │       │   Kopia Settings     │
│   Mapping           │       │   (retention, etc)   │
└──────────┬──────────┘       └──────────┬──────────┘
           │                             │
           ├─────────────────────────────┘
           │
           ▼
┌─────────────────────┐
│   Kopia Snapshot     │
│   (encrypted, dedup) │
└──────────┬──────────┘
           │
           ├─────────────────────────────┐
           │                             │
           ▼                             ▼
┌─────────────────────┐       ┌─────────────────────┐
│   Vault Raft        │       │   Database Dump      │
│   Snapshot          │       │   (per-repo)         │
└─────────────────────┘       └─────────────────────┘
```

## Entities

### 1. Backup Configuration

**Purpose**: Defines the complete backup topology and settings.

**File**: `backup-config.yml`

**Fields**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `version` | string | Yes | Schema version (e.g., "1.0") |
| `repositories` | list | Yes | List of repository mappings |
| `kopia` | object | Yes | Kopia repository settings |
| `vault` | object | No | Vault-specific settings |
| `database_hooks` | object | No | Database backup hook configuration |
| `port_offset` | integer | No | Port offset for parallel clusters (0-65000, default 0) |
| `dns_suffix` | string | No | DNS suffix override pattern (e.g., "lab=bak") |

**Validation Rules** (FR-036, FR-037):
- `version` must be a valid semver string
- `repositories` must contain at least one entry
- `kopia.repository_path` must be an absolute path
- `port_offset` must be between 0 and 65000
- `dns_suffix` must match pattern `<original>=<replacement>`

**Example**:

```yaml
version: "1.0"
repositories:
  - name: my-app
    path: ~/projects/repos/my-app
    pvc: my-app-data
    data_dir: /data/my-app
    namespace: default
  - name: another-app
    path: ~/projects/repos/another-app
    pvc: another-app-data
    data_dir: /data/another-app
    namespace: default

kopia:
  repository_path: ~/.kopia-repository
  password_env: KOPIA_PASSWORD
  retention:
    daily: 7
    weekly: 4
    monthly: 12

vault:
  namespace: vault
  unseal_key_path: ~/.vault-unseal-key

database_hooks:
  timeout: 300
  mandatory: true

port_offset: 0
dns_suffix: "lab=bak"
```

### 2. Repository Mapping

**Purpose**: Maps a repository to its Kubernetes resources and host data directory.

**Fields**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Repository name (unique identifier) |
| `path` | string | Yes | Absolute path to repository on host |
| `pvc` | string | Yes | PersistentVolumeClaim name |
| `data_dir` | string | Yes | Mount path inside container |
| `namespace` | string | Yes | Kubernetes namespace |
| `db_hook` | string | No | Path to database backup hook script |
| `db_restore_hook` | string | No | Path to database restore hook script |

**Validation Rules**:
- `name` must be unique across all repositories
- `path` must be an absolute path on host
- `pvc` must be a valid Kubernetes name (RFC 1123)
- `namespace` must exist in cluster
- If `db_hook` is specified, `db_restore_hook` must also be specified

### 3. Kopia Snapshot

**Purpose**: Represents a point-in-time backup of cluster state.

**Fields** (from Kopia output):

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique snapshot identifier |
| `time` | timestamp | When snapshot was created |
| `root` | string | Root tree hash |
| `size` | integer | Total size in bytes |
| `tags` | list | User-defined tags |
| `hostname` | string | Source hostname |
| `username` | string | Source username |

**Retention Rules** (FR-013):

| Period | Count | Description |
|--------|-------|-------------|
| Daily | 7 | Keep one snapshot per day for 7 days |
| Weekly | 4 | Keep one snapshot per week for 4 weeks |
| Monthly | 12 | Keep one snapshot per month for 12 months |

### 4. Vault Raft Snapshot

**Purpose**: Represents a point-in-time backup of Vault's Raft storage.

**Fields** (from Vault output):

| Field | Type | Description |
|-------|------|-------------|
| `data` | binary | Encrypted Raft snapshot data |
| `size` | integer | Size in bytes |
| `created_at` | timestamp | When snapshot was created |

**Backup Command**: `vault operator raft snapshot save <path>`
**Restore Command**: `vault operator raft snapshot restore <path>`

### 5. Database Dump

**Purpose**: Represents a database backup created by repository-specific hooks.

**Fields**:

| Field | Type | Description |
|-------|------|-------------|
| `repository` | string | Repository name |
| `database` | string | Database type (e.g., "postgres", "mysql") |
| `timestamp` | timestamp | When dump was created |
| `path` | string | Path to dump file on host |
| `checksum` | string | SHA-256 checksum of dump file |

**Hook Interface** (FR-008):
- Input: Environment variables (`REPOSITORY`, `DATABASE`, `BACKUP_PATH`)
- Output: Exit code (0=success, non-zero=failure)
- Timeout: Configurable (default: 300 seconds)

### 6. Cluster Metadata

**Purpose**: Records environment state for reproducibility.

**File**: `cluster-metadata.json`

**Fields**:

| Field | Type | Description |
|-------|------|-------------|
| `k3d_version` | string | k3d CLI version |
| `kubernetes_version` | string | Kubernetes server version |
| `docker_version` | string | Docker Engine version |
| `vault_version` | string | Vault server version |
| `eso_version` | string | External Secrets Operator version |
| `helm_version` | string | Helm CLI version |
| `repositories` | list | List of repository names |
| `volume_mappings` | object | PVC to host directory mappings |
| `kopia_snapshot_id` | string | Latest Kopia snapshot ID |
| `vault_snapshot_id` | string | Latest Vault snapshot ID |
| `created_at` | timestamp | When metadata was collected |

### 7. Recovery Manifest

**Purpose**: Defines the ordered recovery steps and their status.

**File**: `recovery-manifest.json`

**Fields**:

| Field | Type | Description |
|-------|------|-------------|
| `version` | string | Manifest schema version |
| `created_at` | timestamp | When manifest was created |
| `restore_id` | string | Unique restore operation ID |
| `steps` | list | Ordered list of recovery steps |
| `status` | string | Overall status (pending/running/completed/failed) |

**Step Structure**:

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Step identifier (e.g., "k3d-create") |
| `name` | string | Human-readable step name |
| `command` | string | Command to execute |
| `status` | string | Step status (pending/running/completed/failed/skipped) |
| `error` | string | Error message if failed |
| `started_at` | timestamp | When step started |
| `completed_at` | timestamp | When step completed |

### 8. Lock File

**Purpose**: Prevents concurrent backup operations (FR-048).

**File**: `/tmp/k3d-dr-backup.lock`

**Fields**:

| Field | Type | Description |
|-------|------|-------------|
| `pid` | integer | Process ID holding the lock |
| `started_at` | timestamp | When lock was acquired |
| `hostname` | string | Hostname of the machine |

**Behavior**:
- Acquired using `flock -n` (non-blocking)
- Released automatically on process exit
- Stale locks detected by PID check

## State Transitions

### Backup State Machine

```
IDLE → VALIDATING → BACKING_UP → VERIFYING → PRUNING → COMPLETE
  ↓         ↓            ↓           ↓          ↓
  └─────────┴────────────┴───────────┴──────────┘
                    (on error)
                       ↓
                     FAILED
```

### Restore State Machine

```
IDLE → VALIDATING → RESTORING → VERIFYING → COMPLETE
  ↓         ↓            ↓           ↓
  └─────────┴────────────┴───────────┘
                    (on error)
                       ↓
                     FAILED → ROLLBACK (optional)
```

## Validation Rules Summary

| Rule | Entity | Condition | Error Message |
|------|--------|-----------|---------------|
| VR-001 | Backup Config | `version` is valid semver | "Invalid schema version" |
| VR-002 | Backup Config | `repositories` has ≥1 entry | "No repositories defined" |
| VR-003 | Repository | `name` is unique | "Duplicate repository name: {name}" |
| VR-004 | Repository | `path` is absolute | "Path must be absolute: {path}" |
| VR-005 | Repository | `pvc` is RFC 1123 compliant | "Invalid PVC name: {pvc}" |
| VR-006 | Kopia | `repository_path` exists | "Kopia repository not found: {path}" |
| VR-007 | Vault | `unseal_key_path` exists | "Unseal key file not found: {path}" |
| VR-008 | Vault | Unseal key has 0600 permissions | "Unseal key permissions too open: {perms}" |
| VR-009 | Port Offset | `port_offset` is 0-65000 | "Port offset out of range: {offset}" |
| VR-010 | DNS Suffix | `dns_suffix` matches pattern | "Invalid DNS suffix pattern: {suffix}" |
