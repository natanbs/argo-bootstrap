# Feature Specification: Local k3d Disaster Recovery

**Feature Branch**: `006-k3d-disaster-recovery`

**Created**: 2026-08-17

**Status**: Draft

**Input**: User description: "Design and implement a fully local macOS and Linux disaster-recovery system for a disposable k3d Kubernetes cluster."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Full Disaster Recovery from Complete Cluster Loss (Priority: P1)

As a platform engineer, I want to delete my entire k3d cluster and all its data, then rebuild and recover everything from a local backup, so that I can confidently treat my cluster as disposable and recover from catastrophic failure.

**Why this priority**: This is the core value proposition. Without full disaster recovery, the system provides no safety net. This is the P1 because all other features depend on the backup/restore pipeline working end-to-end.

**Independent Test**: Can be fully tested by running `backup.sh`, destroying the k3d cluster completely (including all Docker volumes and containers), then running `restore.sh` against a fresh k3d cluster. Delivers complete environment recovery from local backup.

**Acceptance Scenarios**:

1. **Given** a running k3d cluster with infrastructure, applications, persistent data, Vault, ESO, and registry, **When** the user runs `backup.sh`, **Then** a complete encrypted Kopia snapshot is created on the local host filesystem containing all cluster state, persistent data, Vault snapshots, database dumps, and registry data.
2. **Given** a complete backup exists in the local Kopia repository, **When** the user destroys the k3d cluster and runs `restore.sh` against a fresh cluster, **Then** the entire environment is restored including infrastructure, Vault with its secrets, ESO connectivity, persistent volumes with data, databases, registry images, and applications.
3. **Given** a restored cluster, **When** the user verifies application functionality, **Then** all applications start successfully, persistent data is intact, Vault serves secrets, ESO generates Kubernetes Secrets, and database queries return correct results.

---

### User Story 2 - Selective Restore of Individual Repositories or Volumes (Priority: P2)

As a platform engineer, I want to restore specific repositories or persistent volumes without rebuilding the entire cluster, so that I can recover from partial data loss or selectively restore components.

**Why this priority**: Selective restore is important for operational flexibility but requires the full restore pipeline to work first. This enables targeted recovery scenarios without full cluster teardown.

**Independent Test**: Can be tested by running `restore.sh --repo <name>` or `restore.sh --volume <name>` against a running cluster. Delivers targeted data recovery for specific components.

**Acceptance Scenarios**:

1. **Given** a backup exists and a running cluster, **When** the user runs `restore.sh --repo my-app`, **Then** only the persistent data and configuration for the `my-app` repository are restored.
2. **Given** a backup exists and a running cluster, **When** the user runs `restore.sh --volume data-volume`, **Then** only the specified persistent volume's data is restored from the Kopia snapshot.
3. **Given** a selective restore is in progress, **When** other cluster components are not targeted, **Then** existing running services remain unaffected. Verification: Run `kubectl get pods` before and after, confirm no pod restarts outside the targeted repository's namespace.

---

### User Story 3 - Pre-Backup Validation and Integrity Verification (Priority: P3)

As a platform engineer, I want the backup process to validate configuration, verify Kopia repository integrity, and confirm all required data sources are accessible before creating snapshots, so that I can trust my backups will actually enable recovery.

**Why this priority**: Validation prevents silent backup failures that would be discovered only during a disaster. This is critical for confidence but requires the basic backup/restore to function first.

**Independent Test**: Can be tested by running `backup.sh` with intentionally misconfigured volume mappings or inaccessible Vault. Delivers clear error reporting and non-zero exit codes on validation failure.

**Acceptance Scenarios**:

1. **Given** the backup configuration references a repository that doesn't exist, **When** the user runs `backup.sh`, **Then** the script exits with a non-zero code and reports which repositories are missing.
2. **Given** a valid backup exists, **When** the user runs `backup.sh` and the Kopia repository integrity check passes, **Then** the backup proceeds with a logged integrity verification success.
3. **Given** Vault is unreachable during backup, **When** the backup script attempts to snapshot Vault, **Then** the script fails with a clear error message and does not create a partial snapshot.

---

### User Story 4 - Database Backup and Restore via Native Tools (Priority: P4)

As a platform engineer, I want repository-specific database backup hooks that use native database tools (e.g., pg_dump) and protect the dumps with Kopia, so that databases are backed up consistently and can be restored to a known-good state.

**Why this priority**: Database consistency requires more than filesystem snapshots. This ensures databases are backed up using their native tools for data integrity.

**Independent Test**: Can be tested by deploying a database (e.g., PostgreSQL) into k3d, running `backup.sh`, destroying the database, then running `restore.sh` and verifying data integrity. Delivers database-level backup and restore.

**Acceptance Scenarios**:

1. **Given** a repository with a database backup hook configured, **When** `backup.sh` runs, **Then** the hook is executed before Kopia snapshotting and the database dump is included in the backup.
2. **Given** a database dump exists in the Kopia snapshot, **When** `restore.sh` runs with database restore enabled, **Then** the dump is restored using the native database tool and the database is accessible. Verification: Run `pg_isready` (PostgreSQL) or equivalent, then run a checksum query (e.g., `SELECT md5(string_agg(t::text, '' ORDER BY id)) FROM table`) before and after restore to confirm data integrity.
3. **Given** a database backup hook fails, **When** the hook is configured as mandatory, **Then** `backup.sh` exits with a non-zero code and reports the failure.

---

### User Story 5 - Vault Recovery and Bootstrap Chain (Priority: P5)

As a platform engineer, I want the restore process to recreate the complete Vault bootstrap chain (k3d → Vault → ESO → Kubernetes Secrets → applications) so that Vault remains the authoritative source of secrets after recovery.

**Why this priority**: The bootstrap chain is the critical dependency for all secret-dependent services. Without proper Vault recovery, applications cannot start.

**Independent Test**: Can be tested by running full restore and verifying Vault is unsealed, has its policies, has Kubernetes auth configured, ESO can connect, and applications receive their secrets.

**Acceptance Scenarios**:

1. **Given** a Vault Raft snapshot in the backup, **When** `restore.sh` runs, **Then** Vault is restored from the Raft snapshot with its policies, auth methods, and secrets intact. Verification: Run `vault status` to confirm unsealed, `vault policy list` to confirm policies exist, `vault read sys/auth/kubernetes/config` to confirm K8s auth.
2. **Given** Vault is restored, **When** ESO starts and connects to Vault, **Then** ExternalSecrets are synced and Kubernetes Secrets are generated. Verification: Run `kubectl get externalsecrets --all-namespaces` to confirm status is "SecretSynced", `kubectl get secrets` to confirm secrets exist.
3. **Given** Kubernetes Secrets are generated from Vault, **When** applications start, **Then** they can read their secrets and function correctly. Verification: Check pod logs for successful secret reads, verify application health endpoints return 200.

---

### Edge Cases

- **What happens when the Kopia repository is corrupted?** The system should detect corruption during integrity verification (`kopia repository verify`) and report it, refusing to proceed with a backup or restore that depends on corrupted data. Recovery: Initialize a new Kopia repository and re-run backup from scratch.
- **What happens when only some repositories in the backup configuration exist?** The system should skip missing repositories and continue with available ones, logging warnings. The backup summary should list skipped repositories with reasons.
- **What happens when Vault is partially restored (e.g., Raft snapshot is valid but unseal key file is missing or invalid)?** The system should detect Vault is sealed, attempt auto-unseal using the stored key file, and if that fails, report a clear error with recovery instructions. Recovery: Manually unseal Vault or provide a valid unseal key file.
- **What happens when database backup hooks timeout?** The system should enforce configurable timeouts and fail the backup if a hook exceeds the limit. The hook process should be killed with SIGTERM, then SIGKILL after 10 seconds.
- **What happens when the host filesystem runs out of space during backup?** The system should check available space before snapshotting and fail early with a clear error. Kopia will report errors if space is exhausted mid-operation.
- **What happens when restore is attempted against a cluster with different Kubernetes version?** The system should warn about version mismatches but proceed if the user overrides with `--force`. Compatibility is not guaranteed across major versions.
- **What happens when the same volume is targeted by both full restore and selective restore?** Selective restore should override full restore for the targeted volume. The most specific restore wins.
- **What happens when path configurations differ between repos (e.g., one repo references `/data/app-a` while infra references `/data/app-b` for the same volume)?** The system should detect the mismatch during validation (FR-028) and fail with a clear error identifying the conflicting paths.
- **What happens when the Vault unseal key file is missing or corrupted?** The system should detect the missing file before attempting auto-unseal and report a clear error with recovery instructions. Recovery: Restore the unseal key file from a secure backup.
- **What happens when two backup operations are started simultaneously?** The system should acquire an exclusive lock (FR-048) and fail the second operation with a clear error message.
- **What happens when a non-critical infrastructure component fails during restore?** The system should continue with remaining components and report partial success with specific failures listed in the summary output.
- **What happens when restore is interrupted mid-way?** The system should support resuming from the last completed step (FR-047) or rolling back to pre-restore state (FR-050).
- **What happens when the backup is running while the cluster is being used?** The backup uses filesystem-level snapshots (Kopia) which are point-in-time consistent. Database hooks ensure consistency for live databases. The cluster remains operational during backup.
- **What happens when Vault is unreachable during backup?** The system should fail the Vault snapshot step and report a clear error. If Vault is critical, the entire backup fails. If configured as non-critical, the backup continues without Vault snapshot.
- **What happens when restore is attempted against a running cluster with existing data?** The system should detect existing data and skip already-restored items (FR-043), reporting skipped items in the summary. Use `--force` to overwrite.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a single `backup.sh` script that orchestrates the complete backup workflow.
- **FR-002**: System MUST provide a single `restore.sh` script that supports both full disaster recovery and selective restore.
- **FR-003**: System MUST use Kopia as the sole backup engine with an encrypted local repository on the host filesystem.
- **FR-004**: System MUST maintain a deterministic mapping between repositories, PVC/PV pairs, and host-side directories. The mapping is defined in `backup-config.yml` with fields: `name`, `path`, `pvc`, `data_dir`, `namespace`.
- **FR-005**: System MUST treat the k3d cluster and all Kubernetes PVs as disposable — all durable state must be recoverable from the local backup.
- **FR-006**: System MUST back up Vault configuration, policies, authentication configuration, and Raft snapshots.
- **FR-007**: System MUST NOT back up or store Kubernetes Secret values generated by Vault/ESO — Vault remains the sole source of truth for secret values.
- **FR-008**: System MUST support repository-specific database backup hooks implemented as shell scripts (`db-backup.sh` for backup, `db-restore.sh` for restore) using native database tools (e.g., pg_dump, pg_basebackup), with standardized exit codes (0=success, non-zero=failure). Hook interface: Environment variables `REPOSITORY`, `DATABASE`, `BACKUP_PATH`, `NAMESPACE`; optional `TIMEOUT` (default 300s).
- **FR-009**: System MUST persist the k3d local container registry to a host directory and include its data in Kopia backups.
- **FR-010**: System MUST validate configuration, repository existence, and volume mappings before performing backup or restore.
- **FR-011**: System MUST collect and record cluster bootstrap metadata including versions of k3d, Kubernetes, Docker, Vault, ESO, Helm, repository list, and Kopia snapshot IDs.
- **FR-012**: System MUST verify Kopia repository integrity after backup and before restore.
- **FR-013**: System MUST support configurable retention and pruning policies for Kopia snapshots. Defaults: daily=7, weekly=4, monthly=12. Configurable via `kopia.retention` in `backup-config.yml`.
- **FR-014**: System MUST return non-zero exit codes on any required failure during backup or restore.
- **FR-015**: System MUST produce both human-readable and machine-readable output (structured logs, JSON summary). Human-readable: timestamp + level + message. Machine-readable: JSON with fields `timestamp`, `level`, `message`, `component`, `metadata`.
- **FR-016**: System MUST support the complete infrastructure recovery order: k3d → registry → all infrastructure apps under `~/projects/infra` (including Vault, ESO, and any other infrastructure components) → PV/PVCs → application data → ConfigMaps/configuration → application repos → database recovery → health verification.
- **FR-017**: System MUST encrypt all sensitive backup data in the Kopia repository.
- **FR-018**: System MUST be idempotent where practical — running backup or restore multiple times should produce consistent results. Backup idempotency: same state produces same snapshot. Restore idempotency: already-restored data is skipped.
- **FR-019**: System MUST make environment-specific values configurable via a YAML configuration file (`backup-config.yml`) without modifying scripts. Configurable parameters: repository paths, PVC names, namespaces, Kopia settings, Vault settings, port offset, DNS suffix.
- **FR-020**: System MUST support a repeatable disaster-recovery test that creates a fresh k3d cluster and restores exclusively from the local backup.
- **FR-021**: System MUST preserve the existing `~/projects/repos` directory organization.
- **FR-022**: System MUST document protection and recovery procedures for Kopia credentials, Vault recovery/unseal material, and backup filesystem permissions.
- **FR-023**: System MUST treat declarative Kubernetes configuration from repositories as authoritative, not runtime kubectl output.
- **FR-024**: System MUST support Vault Kubernetes authentication, avoiding long-lived Vault credentials in Kubernetes Secrets where practical.
- **FR-025**: System MUST support configurable port offset for NodePorts and API server to avoid conflicts when running alongside the production cluster. The backup cluster MUST coexist with the production cluster without port conflicts. Port offset applies to: API server (default 6443 + offset), NodePort range (default 30000-32767 + offset), and any custom service ports.
- **FR-026**: System MUST support configurable DNS suffix override for Ingress resources, rewriting hostnames from the production suffix to a backup suffix during restore to enable parallel cluster operation. Example: `http://analyst.lab` in production → `http://analyst.bak` in backup cluster. The DNS suffix pattern format is: `<original-suffix>=<replacement-suffix>` (e.g., `lab=bak`).
- **FR-027**: System MUST support multiple snapshot selection methods: restore from latest (default), restore by timestamp (`--snapshot <timestamp>`), restore by tag (`--tag <name>`), and interactive selection (list available snapshots and let user choose).
- **FR-028**: System MUST verify that volume mount paths, data directory references, and PVC names are consistent between repository Kubernetes manifests and the backup configuration before backup or restore, reporting any mismatches as errors.
- **FR-029**: System MUST associate application data with its repository without polluting Git working trees — persistent data directories MUST be separate from repository source code.
- **FR-029a**: System MUST validate during configuration that each repository's `data_dir` is not a subdirectory of its `path`, preventing data from polluting Git working trees.
- **FR-030**: System MUST support auto-unsealing Vault during restore using a stored unseal key file on the host filesystem, enabling single-command recovery without manual key entry.
- **FR-031**: System MUST protect the Vault unseal key file with restrictive filesystem permissions (0600) and document backup/recovery procedures for the key file.
- **FR-032**: System MUST use AES-256-GCM encryption for Kopia repository encryption with key derived from user-provided password via Argon2id.
- **FR-033**: System MUST validate that no Kubernetes Secret values are stored in repository manifests or backup configuration — only Vault references are permitted.
- **FR-034**: System MUST verify health of each infrastructure component before proceeding to the next restore step, failing if readiness checks do not pass within configurable timeout.
- **FR-035**: System MUST wait for Vault to be unsealed and responsive before attempting ESO connection, with configurable readiness timeout (default: 60 seconds).
- **FR-036**: System MUST validate backup configuration against a formal YAML schema defining required fields, types, and value constraints.
- **FR-037**: System MUST report configuration validation errors with specific field paths and human-readable descriptions before proceeding with backup or restore.
- **FR-038**: System MUST support port offset as integer value (0-65000) with default 0, applying offset to all NodePorts and API server port.
- **FR-039**: System MUST support DNS suffix override as string replacement pattern with syntax: `<original-suffix>=<replacement-suffix>` (e.g., `lab=bak`).
- **FR-040**: System MUST allow environment variable overrides for all configurable values using `KOPIA_BACKUP_<PARAMETER>` naming convention.
- **FR-041**: System MUST guarantee that running backup twice on identical state produces identical snapshots, and running restore twice on identical data produces identical results.
- **FR-042**: System MUST process repositories in deterministic alphabetical order during backup to ensure reproducible snapshot content.
- **FR-043**: System MUST detect and skip already-restored data during restore, reporting skipped items in the summary output.
- **FR-044**: System MUST report backup progress as percentage complete with current phase name (e.g., "Backing up Vault snapshots: 45%").
- **FR-045**: System MUST report restore progress as percentage complete with current phase name and estimated time remaining.
- **FR-046**: System MUST produce logs in structured JSON format with fields: timestamp, level, message, component, and optional metadata.
- **FR-047**: System MUST support resuming interrupted backup operations from the last completed Kopia snapshot without re-processing already-backed-up data.
- **FR-048**: System MUST prevent concurrent backup operations by acquiring an exclusive lock file, failing with clear error if another backup is running.
- **FR-049**: System MUST continue processing remaining components when a non-critical component fails, reporting partial success and specific failures in summary.
- **FR-050**: System MUST provide a `restore.sh --rollback` command that reverts partial restore by restoring from the pre-restore Kopia snapshot.
- **FR-051**: System MUST output errors in machine-readable JSON format with fields: error_code, message, component, and suggested_remediation.
- **FR-052**: System MUST acquire exclusive lock before backup to prevent concurrent operations (FR-048 implementation).
- **FR-053**: System MUST support backup resumption by tracking completed phases and skipping already-processed repositories (FR-047 implementation).
- **FR-054**: System MUST continue processing remaining repositories when a non-critical repository backup fails, unless `database_hooks.mandatory=true` and the failure is a database hook (FR-049 implementation).
- **FR-055**: System MUST support restore rollback by saving pre-restore state and providing `--rollback` flag (FR-050 implementation).
- **FR-056**: System MUST support concurrent restore prevention using same lock mechanism as backup (FR-048 extension).

### Key Entities

- **Backup Configuration**: Defines the set of repositories, volume mappings, database hooks, and Kopia settings. Maps each repository to its PVC/PV and host data directory. Validated against formal YAML schema (FR-036).
- **Kopia Snapshot**: An encrypted (AES-256-GCM, FR-032), deduplicated, incremental point-in-time backup of cluster state, persistent data, configuration, and metadata. Stored in a local Kopia repository on the host filesystem.
- **Vault Raft Snapshot**: A point-in-time backup of Vault's Raft storage including secrets, policies, and authentication configuration.
- **Database Dump**: A native tool output (e.g., pg_dump) capturing consistent database state, protected by Kopia after creation.
- **Cluster Metadata**: Version information, repository list, volume mappings, and snapshot IDs needed to reproduce the environment.
- **Recovery Manifest**: A structured document recording the state of the environment at backup time, enabling ordered restoration.
- **Unseal Key File**: AES-256 encryption key for Vault auto-unseal, stored on host filesystem with 0600 permissions (FR-031).
- **Lock File**: Exclusive lock preventing concurrent backup operations (FR-048).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: After complete cluster destruction (k3d cluster, all Docker volumes, all containers), running `restore.sh` against a fresh k3d cluster fully recovers the environment within a single command invocation.
- **SC-002**: All application persistent data, database contents, Vault secrets, and registry images are identical before destruction and after restoration.
- **SC-003**: Vault authentication and ESO connectivity are restored without manual intervention — applications receive their secrets automatically through the standard Kubernetes Secret generation pipeline.
- **SC-004**: The backup process validates all configuration and data sources, failing fast with clear error messages when prerequisites are not met.
- **SC-005**: A selective restore of a single repository completes without affecting other running services in the cluster.
- **SC-006**: Database backup hooks produce consistent, restorable dumps that pass native database integrity checks after restoration.
- **SC-007**: Kopia repository integrity verification passes after every backup and before every restore operation.
- **SC-008**: The entire backup and restore workflow operates exclusively on the local host filesystem with no cloud or remote dependencies.
- **SC-009**: The disaster-recovery test (full cluster destruction + restoration from backup) is repeatable and produces consistent results across multiple runs.
- **SC-010**: All sensitive data in the Kopia repository is encrypted — no plaintext secrets appear in backup metadata, logs, or configuration files.

## Assumptions

- The local host filesystem (`~/projects/repos`) is the durable storage layer and has sufficient disk space for Kopia snapshots, database dumps, and registry data.
- The existing `infra/` directory contains Vault, ESO, and other infrastructure components that will be discovered during implementation.
- k3d is the Kubernetes distribution used for the local cluster.
- Docker is available on the host system and k3d runs within Docker.
- The `~/projects/repos` layout includes `infra/` for cluster infrastructure and individual application repositories alongside it.
- Application repositories contain declarative Kubernetes configuration (Deployments, StatefulSets, Services, PVCs, Helm charts, Kustomize overlays).
- Vault is deployed into the k3d cluster and uses Raft storage backend.
- ESO is deployed into the k3d cluster and connects to Vault for secret synchronization.
- Database backup hooks are repository-specific and must be configured per-repository — the system provides the framework but each repository defines its own hooks.
- Kopia credentials, Vault unseal keys, and other sensitive material are stored securely on the host outside the Kopia repository. The system MUST document the required credentials and their recovery procedures without prescribing a specific storage location.
- The k3d local registry is configured to persist to a host directory.
- Environment-specific values (paths, namespaces, ports) are configurable via a central configuration file without modifying scripts.
- The system supports macOS and Linux — Windows is out of scope.
- No cloud services, S3 buckets, or remote backup servers are used — all backup data stays local on the host.
- There is no explicit recovery time target — the system prioritizes correctness and completeness over speed. Recovery time is expected to be "as fast as practical" given the sequential nature of infrastructure → Vault → ESO → applications restoration.

## Version Requirements

The system requires the following minimum versions:

| Component | Minimum Version | Notes |
|-----------|-----------------|-------|
| Bash | 4.0 | Required for associative arrays, `${var,,}` |
| Docker | 20.10 | Required for k3d, volume mounts |
| k3d | 5.0 | Cluster management, registry support |
| kubectl | 1.24 | Kubernetes resource management |
| Kopia | 0.12 | Encrypted, deduplicated backups |
| Vault | 1.12 | Raft storage, auto-unseal |
| Helm | 3.10 | Chart deployment |
| ESO | 0.7 | External Secrets Operator |
| macOS | 12.0 (Monterey) | Primary platform |
| Ubuntu | 20.04 | Secondary platform (or equivalent) |

**Note**: These are minimum versions. Newer versions are expected to work. Version-specific incompatibilities will be documented as they are discovered.

## Directory Structure

The expected `~/projects/repos` layout:

```
~/projects/repos/
├── infra/                    # Infrastructure repositories
│   ├── vault/               # Vault deployment
│   ├── external-secrets/    # ESO deployment
│   ├── registry/            # k3d registry config
│   └── ...                  # Other infrastructure components
├── app-a/                   # Application repositories
│   ├── k8s/                 # Kubernetes manifests
│   ├── hooks/               # Database backup hooks
│   │   ├── db-backup.sh
│   │   └── db-restore.sh
│   └── ...
├── app-b/
│   └── ...
└── backup-config.yml        # Backup configuration (or elsewhere)
```

**Data Separation Rule**: Each repository's persistent data directory MUST be separate from its source code directory. Example:
- Source code: `~/projects/repos/app-a/`
- Data directory: `~/projects/repos/app-a-data/` or `/data/app-a/`
- NEVER: `~/projects/repos/app-a/data/` (data inside Git working tree)

## Clarifications

### Session 2026-08-17

- Q: What format should the backup configuration use for defining repositories, volume mappings, database hooks, and Kopia settings? (FR-019) → A: YAML file (`backup-config.yml`)
- Q: What is the target recovery time for a full disaster recovery operation? → A: No explicit target (as fast as practical)
- Q: How should Vault be unsealed during the restore process? → A: Auto-unseal using a stored unseal key file on the host filesystem
- Q: What specific path configurations should FR-028 verify for consistency across repositories? → A: Volume mount paths, data directory references, and PVC names
- Q: What should the database backup hook interface look like? → A: Shell script (`db-backup.sh`) with standardized exit codes (0=success, non-zero=failure)

### Requirements Added (Checklist Gap Resolution)

- FR-031: Vault unseal key file protection (permissions, backup procedures)
- FR-032: Kopia encryption algorithm specification (AES-256-GCM, Argon2id)
- FR-033: Secret-free repository configuration validation
- FR-034: Inter-dependency health checks during restore
- FR-035: Component readiness timing (Vault → ESO)
- FR-036: YAML configuration schema validation
- FR-037: Configuration validation error reporting
- FR-038: Port offset format specification (0-65000, default 0)
- FR-039: DNS suffix format specification (replacement pattern)
- FR-040: Environment variable overrides (KOPIA_BACKUP_* prefix)
- FR-041: Idempotency guarantees (identical state = identical snapshots)
- FR-042: Deterministic backup ordering (alphabetical)
- FR-043: Repeat restore detection and skip
- FR-044: Backup progress reporting (percentage + phase)
- FR-045: Restore progress reporting (percentage + ETA)
- FR-046: Structured JSON log format
- FR-047: Backup resumption capability
- FR-048: Concurrent backup prevention (exclusive lock)
- FR-049: Partial failure handling (continue + report)
- FR-050: Rollback command (--rollback)
- FR-051: Machine-readable error format

### Adjustments (User Clarification)

- FR-025 clarified: Backup cluster MUST coexist with production cluster without port conflicts. Port offset applies to API server, NodePort range, and custom service ports.
- FR-026 clarified: DNS suffix mapping example: `analyst.lab` → `analyst.bak`. Pattern format: `<original>=<replacement>` (e.g., `lab=bak`).
