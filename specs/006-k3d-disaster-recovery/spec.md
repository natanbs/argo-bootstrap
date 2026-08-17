# Feature Specification: Local k3d Disaster Recovery

**Feature Branch**: `006-k3d-disaster-recovery`

**Created**: 2026-08-17

**Status**: Draft

**Input**: User description: "Design and implement a fully local macOS disaster-recovery system for a disposable k3d Kubernetes cluster."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Full Disaster Recovery from Complete Cluster Loss (Priority: P1)

As a platform engineer, I want to delete my entire k3d cluster and all its data, then rebuild and recover everything from a local backup, so that I can confidently treat my cluster as disposable and recover from catastrophic failure.

**Why this priority**: This is the core value proposition. Without full disaster recovery, the system provides no safety net. This is the P1 because all other features depend on the backup/restore pipeline working end-to-end.

**Independent Test**: Can be fully tested by running `backup.sh`, destroying the k3d cluster completely (including all Docker volumes and containers), then running `restore.sh` against a fresh k3d cluster. Delivers complete environment recovery from local backup.

**Acceptance Scenarios**:

1. **Given** a running k3d cluster with infrastructure, applications, persistent data, Vault, ESO, and registry, **When** the user runs `backup.sh`, **Then** a complete encrypted Kopia snapshot is created on the local Mac filesystem containing all cluster state, persistent data, Vault snapshots, database dumps, and registry data.
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
3. **Given** a selective restore is in progress, **When** other cluster components are not targeted, **Then** existing running services remain unaffected.

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
2. **Given** a database dump exists in the Kopia snapshot, **When** `restore.sh` runs with database restore enabled, **Then** the dump is restored using the native database tool and the database is accessible.
3. **Given** a database backup hook fails, **When** the hook is configured as mandatory, **Then** `backup.sh` exits with a non-zero code and reports the failure.

---

### User Story 5 - Vault Recovery and Bootstrap Chain (Priority: P5)

As a platform engineer, I want the restore process to recreate the complete Vault bootstrap chain (k3d → Vault → ESO → Kubernetes Secrets → applications) so that Vault remains the authoritative source of secrets after recovery.

**Why this priority**: The bootstrap chain is the critical dependency for all secret-dependent services. Without proper Vault recovery, applications cannot start.

**Independent Test**: Can be tested by running full restore and verifying Vault is unsealed, has its policies, has Kubernetes auth configured, ESO can connect, and applications receive their secrets.

**Acceptance Scenarios**:

1. **Given** a Vault Raft snapshot in the backup, **When** `restore.sh` runs, **Then** Vault is restored from the Raft snapshot with its policies, auth methods, and secrets intact.
2. **Given** Vault is restored, **When** ESO starts and connects to Vault, **Then** ExternalSecrets are synced and Kubernetes Secrets are generated.
3. **Given** Kubernetes Secrets are generated from Vault, **When** applications start, **Then** they can read their secrets and function correctly.

---

### Edge Cases

- What happens when the Kopia repository is corrupted? The system should detect corruption during integrity verification and report it, refusing to proceed with a backup or restore that depends on corrupted data.
- What happens when only some repositories in the backup configuration exist? The system should skip missing repositories and continue with available ones, logging warnings.
- What happens when Vault is partially restored (e.g., Raft snapshot is valid but unseal keys are missing)? The system should detect Vault is sealed and report a clear error with recovery instructions.
- What happens when database backup hooks timeout? The system should enforce configurable timeouts and fail the backup if a hook exceeds the limit.
- What happens when the Mac filesystem runs out of space during backup? The system should check available space before snapshotting and fail early with a clear error.
- What happens when restore is attempted against a cluster with different Kubernetes version? The system should warn about version mismatches but proceed if the user overrides.
- What happens when the same volume is targeted by both full restore and selective restore? Selective restore should override full restore for the targeted volume.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a single `backup.sh` script that orchestrates the complete backup workflow.
- **FR-002**: System MUST provide a single `restore.sh` script that supports both full disaster recovery and selective restore.
- **FR-003**: System MUST use Kopia as the sole backup engine with an encrypted local repository on the Mac filesystem.
- **FR-004**: System MUST maintain a deterministic mapping between repositories, PVC/PV pairs, and Mac host-side directories.
- **FR-005**: System MUST treat the k3d cluster and all Kubernetes PVs as disposable — all durable state must be recoverable from the local backup.
- **FR-006**: System MUST back up Vault configuration, policies, authentication configuration, and Raft snapshots.
- **FR-007**: System MUST NOT back up or store Kubernetes Secret values generated by Vault/ESO — Vault remains the sole source of truth for secret values.
- **FR-008**: System MUST support repository-specific database backup hooks using native database tools (e.g., pg_dump, pg_basebackup).
- **FR-009**: System MUST persist the k3d local container registry to a Mac directory and include its data in Kopia backups.
- **FR-010**: System MUST validate configuration, repository existence, and volume mappings before performing backup or restore.
- **FR-011**: System MUST collect and record cluster bootstrap metadata including versions of k3d, Kubernetes, Docker, Vault, ESO, Helm, repository list, and Kopia snapshot IDs.
- **FR-012**: System MUST verify Kopia repository integrity after backup and before restore.
- **FR-013**: System MUST support configurable retention and pruning policies for Kopia snapshots.
- **FR-014**: System MUST return non-zero exit codes on any required failure during backup or restore.
- **FR-015**: System MUST produce both human-readable and machine-readable output (structured logs, JSON summary).
- **FR-016**: System MUST support the complete infrastructure recovery order: k3d → registry → base infrastructure → Vault → Vault auth/config → ESO → PV/PVCs → application data → ConfigMaps/configuration → applications → database recovery → health verification.
- **FR-017**: System MUST encrypt all sensitive backup data in the Kopia repository.
- **FR-018**: System MUST be idempotent where practical — running backup or restore multiple times should produce consistent results.
- **FR-019**: System MUST make environment-specific values configurable without modifying scripts.
- **FR-020**: System MUST support a repeatable disaster-recovery test that creates a fresh k3d cluster and restores exclusively from the local backup.
- **FR-021**: System MUST preserve the existing `~/projects/repos` directory organization.
- **FR-022**: System MUST document protection and recovery procedures for Kopia credentials, Vault recovery/unseal material, and backup filesystem permissions.
- **FR-023**: System MUST treat declarative Kubernetes configuration from repositories as authoritative, not runtime kubectl output.
- **FR-024**: System MUST support Vault Kubernetes authentication, avoiding long-lived Vault credentials in Kubernetes Secrets where practical.

### Key Entities

- **Backup Configuration**: Defines the set of repositories, volume mappings, database hooks, and Kopia settings. Maps each repository to its PVC/PV and Mac data directory.
- **Kopia Snapshot**: An encrypted, deduplicated, incremental point-in-time backup of cluster state, persistent data, configuration, and metadata. Stored in a local Kopia repository on the Mac.
- **Vault Raft Snapshot**: A point-in-time backup of Vault's Raft storage including secrets, policies, and authentication configuration.
- **Database Dump**: A native tool output (e.g., pg_dump) capturing consistent database state, protected by Kopia after creation.
- **Cluster Metadata**: Version information, repository list, volume mappings, and snapshot IDs needed to reproduce the environment.
- **Recovery Manifest**: A structured document recording the state of the environment at backup time, enabling ordered restoration.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: After complete cluster destruction (k3d cluster, all Docker volumes, all containers), running `restore.sh` against a fresh k3d cluster fully recovers the environment within a single command invocation.
- **SC-002**: All application persistent data, database contents, Vault secrets, and registry images are identical before destruction and after restoration.
- **SC-003**: Vault authentication and ESO connectivity are restored without manual intervention — applications receive their secrets automatically through the standard Kubernetes Secret generation pipeline.
- **SC-004**: The backup process validates all configuration and data sources, failing fast with clear error messages when prerequisites are not met.
- **SC-005**: A selective restore of a single repository completes without affecting other running services in the cluster.
- **SC-006**: Database backup hooks produce consistent, restorable dumps that pass native database integrity checks after restoration.
- **SC-007**: Kopia repository integrity verification passes after every backup and before every restore operation.
- **SC-008**: The entire backup and restore workflow operates exclusively on the local Mac filesystem with no cloud or remote dependencies.
- **SC-009**: The disaster-recovery test (full cluster destruction + restoration from backup) is repeatable and produces consistent results across multiple runs.
- **SC-010**: All sensitive data in the Kopia repository is encrypted — no plaintext secrets appear in backup metadata, logs, or configuration files.

## Assumptions

- The Mac filesystem (`~/projects/repos`) is the durable storage layer and has sufficient disk space for Kopia snapshots, database dumps, and registry data.
- The existing `infra/` directory contains Vault, ESO, and other infrastructure components that will be discovered during implementation.
- k3d is the Kubernetes distribution used for the local cluster.
- Docker is available on the Mac and k3d runs within Docker.
- The `~/projects/repos` layout includes `infra/` for cluster infrastructure and individual application repositories alongside it.
- Application repositories contain declarative Kubernetes configuration (Deployments, StatefulSets, Services, PVCs, Helm charts, Kustomize overlays).
- Vault is deployed into the k3d cluster and uses Raft storage backend.
- ESO is deployed into the k3d cluster and connects to Vault for secret synchronization.
- Database backup hooks are repository-specific and must be configured per-repository — the system provides the framework but each repository defines its own hooks.
- Kopia credentials, Vault unseal keys, and other sensitive material are stored securely on the Mac outside the Kopia repository and are documented for recovery.
- The k3d local registry is configured to persist to a host directory.
- Environment-specific values (paths, namespaces, ports) are configurable via a central configuration file without modifying scripts.
- The system is macOS-only — Linux and Windows are out of scope.
- No cloud services, S3 buckets, or remote backup servers are used — all backup data stays local on the Mac.
