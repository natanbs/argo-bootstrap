# Research: Local k3d Disaster Recovery

**Date**: 2026-08-17
**Feature**: 006-k3d-disaster-recovery
**Status**: Complete

## Executive Summary

Research confirms that a fully local disaster-recovery system for k3d clusters is feasible using Bash scripts, Kopia for backup, and existing Kubernetes tooling. All technical unknowns have been resolved.

## Technical Decisions

### 1. Backup Engine: Kopia

**Decision**: Use Kopia as the sole backup engine (constitution requirement).

**Rationale**:
- Kopia provides encrypted, deduplicated, incremental snapshots
- Local repository support (no cloud dependency)
- Point-in-time recovery capability
- Strong integrity verification
- CLI interface suitable for scripting

**Alternatives Considered**:
- restic: Similar features but less mature encryption
- borg: No Kubernetes integration patterns
- tar+gpg: No deduplication, no incrementals

### 2. Vault Recovery: Raft Snapshots + Auto-Unseal

**Decision**: Backup Vault using `vault operator raft snapshot save` and restore with auto-unseal using stored key file.

**Rationale**:
- Raft snapshots capture complete Vault state (secrets, policies, auth)
- Auto-unseal enables single-command recovery (FR-030)
- Stored key file on host filesystem (0600 permissions, FR-031)
- No cloud KMS dependency (constitution requirement)

**Alternatives Considered**:
- Manual unseal: Requires user interaction, violates single-command goal
- Shamir seal: Requires multiple key holders, too complex
- Cloud KMS: Violates local-only requirement

### 3. Configuration Format: YAML

**Decision**: Use YAML for `backup-config.yml` (clarified requirement).

**Rationale**:
- Human-readable with comments
- Kubernetes ecosystem standard
- Supports complex nested structures
- Easy to validate against schema

**Alternatives Considered**:
- JSON: No comments, less readable
- TOML: Less ecosystem support
- Shell-sourceable: Less structured, error-prone

### 4. Hook Interface: Shell Scripts

**Decision**: Database backup hooks as shell scripts (`db-backup.sh`, `db-restore.sh`) with standardized exit codes.

**Rationale**:
- Simple, explicit operations (Principle X)
- Any language can be called from shell
- Exit codes provide clear success/failure semantics
- Timeouts enforced at wrapper level

**Alternatives Considered**:
- YAML-defined hooks: More complex, less flexible
- Docker-based: Heavyweight, adds complexity
- Makefile targets: Less portable

### 5. Encryption: AES-256-GCM via Kopia

**Decision**: Use Kopia's built-in AES-256-GCM encryption with Argon2id key derivation.

**Rationale**:
- Kopia handles encryption transparently
- AES-256-GCM is industry standard
- Argon2id is memory-hard, resistant to GPU attacks
- No custom encryption code needed

**Alternatives Considered**:
- Custom encryption: Unnecessary complexity, security risk
- Different algorithm: AES-256-GCM is well-vetted

### 6. Logging: Structured JSON

**Decision**: Output logs in structured JSON format (FR-046).

**Rationale**:
- Machine-readable for automation
- Human-readable with `jq` or similar tools
- Consistent with cloud-native logging standards
- Supports filtering and aggregation

**Alternatives Considered**:
- Plain text: Harder to parse programmatically
- syslog: Overkill for local tool
- Binary format: Not human-inspectable

### 7. Locking: File-Based Exclusive Lock

**Decision**: Use `flock` for exclusive backup lock (FR-048).

**Rationale**:
- Standard Unix mechanism
- Atomic acquisition
- Automatic release on process exit
- No external dependencies

**Alternatives Considered**:
- PID file: Race conditions possible
- Memory-based: Lost on crash
- Database lock: Overkill

### 8. Progress Reporting: Percentage + Phase

**Decision**: Report progress as percentage complete with current phase name (FR-044, FR-045).

**Rationale**:
- Simple to calculate (step count)
- Clear user feedback
- Phase name provides context
- No complex tracking needed

**Alternatives Considered**:
- ETA calculation: Unreliable for variable-duration operations
- Byte-level progress: Hard to estimate for deduplication
- Spinner only: No progress information

## Best Practices Identified

### Bash Scripting

1. Use `set -euo pipefail` for strict error handling
2. Use `trap` for cleanup on exit
3. Use `readonly` for constants
4. Use `local` for function variables
5. Quote all variables to prevent word splitting
6. Use `[[ ]]` instead of `[ ]` for conditionals

### Kopia Operations

1. Always verify integrity after backup (`kopia repository verify`)
2. Use `--json` flag for machine-readable output
3. Tag snapshots with meaningful names for selection
4. Configure retention policies in repository parameters
5. Use `--parallel` for faster operations on SSDs

### Vault Operations

1. Always check seal status before operations
2. Use `vault operator raft snapshot save` for backups
3. Use `vault operator raft snapshot restore` for recovery
4. Store unseal key file outside Kopia repository
5. Test unseal procedure regularly

### k3d Operations

1. Use `k3d cluster create` with explicit configuration
2. Wait for nodes to be ready before proceeding
3. Use `k3d cluster delete` with `--volume` flag to remove all data
4. Configure registry persistence via `--registry-config`

### Kubernetes Operations

1. Use `kubectl wait` for resource readiness
2. Use `kubectl apply -k` for Kustomize overlays
3. Use `kubectl get -o json` for machine-readable output
4. Use `kubectl rollout status` for deployment verification

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Kopia repository corruption | Low | High | Regular integrity verification, multiple snapshots |
| Vault unseal key loss | Low | Critical | Document backup procedures, test recovery |
| k3d version incompatibility | Medium | Medium | Version pinning, compatibility testing |
| Disk space exhaustion | Medium | High | Pre-check available space, configurable retention |
| Concurrent backup corruption | Low | High | Exclusive lock file (FR-048) |

## Open Questions

None. All technical unknowns have been resolved.

## References

- [Kopia Documentation](https://kopia.io/docs/)
- [Vault Raft Snapshots](https://developer.hashicorp.com/vault/docs/concepts/seal)
- [k3d Documentation](https://k3d.io/)
- [External Secrets Operator](https://external-secrets.io/)
