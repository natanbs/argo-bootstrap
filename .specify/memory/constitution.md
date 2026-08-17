<!--
Sync Impact Report
Version change: 1.0.1 → 1.0.2 (PATCH: platform generalization)
Added principles: none
Removed sections: none
Modified sections:
  - I. Data Must Outlive the Cluster: "Mac filesystem location" → "host filesystem location"
  - IV. Backup Must Be Locally Recoverable: "on the Mac" → "on the local host"
Deferred items: none
-->

# Local k3d Disaster Recovery Constitution

## Core Principles

### I. Data Must Outlive the Cluster
The k3d cluster is disposable. No critical data may exist only inside Kubernetes, k3d, Docker, or cluster-managed storage.

All persistent application data MUST have a deterministic host filesystem location and MUST be recoverable after complete cluster destruction.

### II. Repository-Driven Infrastructure
`~/projects/repos` is the source of truth for declarative infrastructure and application configuration.

Configuration MUST be reproducible from repository contents. Runtime Kubernetes state MUST NOT be treated as authoritative.

### III. Vault Is the Secret Authority
HashiCorp Vault is the sole source of truth for application secret values.

Secrets managed by Vault/ESO MUST NOT be duplicated in Git or backup artifacts. Vault recovery data, configuration, and required recovery/unseal material MUST be backed up securely.

### IV. Backup Must Be Locally Recoverable
All backups MUST remain on the local host and MUST be encrypted, deduplicated, integrity-checkable, and versioned.

Kopia is the sole backup engine.

No cloud or remote backup dependency may be required for disaster recovery.

### V. Recovery Over Backup
A backup is considered valid only if it can be restored.

The system MUST support complete recovery from a new k3d cluster without relying on the original cluster.

Restore procedures MUST be deterministic, repeatable, and testable.

### VI. Consistency Over Convenience
Backups MUST preserve data consistency.

Live databases MUST use database-native backup mechanisms where filesystem snapshots alone cannot guarantee consistency.

Backup failures MUST be explicit and MUST result in a non-zero exit status.

### VII. Dependency-Aware Recovery
Infrastructure MUST be restored before applications.

The default dependency order is:

k3d → registry → all infrastructure apps under `~/projects/infra` (Vault, ESO, etc.) → PV/PVCs → application data → application repos → verification

Actual dependencies discovered under `~/projects/repos/infra` MUST be respected.

### VIII. Minimal Secret Duplication
Store each piece of sensitive information in exactly one authoritative location whenever practical.

Derived Kubernetes Secrets MUST be recreated from Vault rather than backed up independently.

### IX. Idempotent Automation
Bootstrap, backup, and restore operations MUST be safely repeatable wherever practical.

Automation MUST fail clearly rather than silently producing a partially recoverable environment.

### X. Simple, Explicit Operations
Prefer simple, inspectable tools and scripts over additional infrastructure.

The system MUST use existing tooling where possible and MUST NOT introduce architectural complexity without a clear recovery benefit.

## Engineering Standards

- All environment-specific paths and settings MUST be configurable.
- Backup and restore operations MUST provide actionable logs.
- Backup integrity MUST be verifiable.
- Recovery credentials and encryption keys MUST have an explicitly documented recovery path.
- Destructive operations MUST require explicit confirmation or an equivalent safety mechanism.
- Documentation MUST describe both full disaster recovery and selective data restoration.

## Success Principle

The ultimate test of the system is:

> Delete the entire k3d cluster and all its data, then rebuild and recover everything from a local backup with a single command.

## Governance

This constitution governs the Local k3d Disaster Recovery project. All design decisions, implementation choices, and operational procedures MUST comply with these principles.

Amendments require:
1. Written proposal with rationale
2. Impact analysis on existing principles
3. Version bump per semantic versioning rules

Compliance is verified through specification review and implementation checklist validation.

**Version**: 1.0.2 | **Ratified**: 2026-08-17 | **Last Amended**: 2026-08-17
