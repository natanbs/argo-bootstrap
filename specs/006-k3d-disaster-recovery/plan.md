# Implementation Plan: Local k3d Disaster Recovery

**Branch**: `006-k3d-disaster-recovery` | **Date**: 2026-08-17 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/006-k3d-disaster-recovery/spec.md`

## Summary

Design and implement a fully local macOS and Linux disaster-recovery system for a disposable k3d Kubernetes cluster. The system uses Kopia as the sole backup engine, with Vault as the secret authority, supporting complete cluster destruction and single-command recovery.

## Technical Context

**Language/Version**: Bash 4.0+ (shell scripts), YAML 1.2 (configuration)
**Primary Dependencies**: Kopia (backup engine), k3d (Kubernetes cluster), Docker, HashiCorp Vault, External Secrets Operator (ESO), Helm, kubectl
**Storage**: Local filesystem (`~/projects/repos`), Kopia repository (encrypted, deduplicated)
**Testing**: Bash unit tests (bats-core), integration tests (full cluster destroy/restore)
**Target Platform**: macOS (primary), Linux (secondary)
**Project Type**: CLI tool (backup/restore scripts)
**Performance Goals**: No explicit target (as fast as practical)
**Constraints**: Kopia only, no cloud/remote backup, preserve existing directory structure
**Scale/Scope**: Single-developer workstation, ~10-50 repositories, ~10-100GB data

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Evidence |
|-----------|--------|----------|
| I. Data Must Outlive the Cluster | ✅ PASS | FR-005, FR-004 define deterministic host filesystem locations |
| II. Repository-Driven Infrastructure | ✅ PASS | FR-023, FR-021 treat repos as authoritative source |
| III. Vault Is the Secret Authority | ✅ PASS | FR-007, FR-006, FR-030, FR-033 ensure Vault is sole secret source |
| IV. Backup Must Be Locally Recoverable | ✅ PASS | FR-003, FR-017, FR-032 define local encrypted Kopia backup |
| V. Recovery Over Backup | ✅ PASS | FR-020, SC-001 define repeatable recovery test |
| VI. Consistency Over Convenience | ✅ PASS | FR-008, FR-014 ensure database-native backups and explicit failures |
| VII. Dependency-Aware Recovery | ✅ PASS | FR-016, FR-034, FR-035 define recovery order and health checks |
| VIII. Minimal Secret Duplication | ✅ PASS | FR-007, FR-033 prevent secret duplication |
| IX. Idempotent Automation | ✅ PASS | FR-018, FR-041, FR-042, FR-043 define idempotency guarantees |
| X. Simple, Explicit Operations | ✅ PASS | FR-001, FR-002 use simple shell scripts, no unnecessary infrastructure |

**Constitution Gate**: PASS — All 10 principles satisfied.

## Project Structure

### Documentation (this feature)

```text
specs/006-k3d-disaster-recovery/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   ├── backup-config-schema.yaml
│   ├── cli-interface.md
│   └── hook-interface.md
└── tasks.md             # Phase 2 output (/spec.tasks)
```

### Source Code (repository root)

```text
k3d-dr/                      # Main project directory
├── backup.sh                # Primary backup script (FR-001)
├── restore.sh               # Primary restore script (FR-002)
├── lib/                     # Shared library functions
│   ├── kopia.sh             # Kopia operations (snapshot, verify, prune)
│   ├── vault.sh             # Vault operations (snapshot, restore, unseal)
│   ├── k3d.sh               # k3d cluster operations (create, delete, status)
│   ├── kubernetes.sh        # kubectl operations (apply, wait, verify)
│   ├── config.sh            # Configuration loading and validation
│   ├── logging.sh           # Structured JSON logging (FR-046)
│   ├── lock.sh              # Exclusive lock management (FR-048)
│   └── progress.sh          # Progress reporting (FR-044, FR-045)
├── schemas/                 # Validation schemas
│   └── backup-config.yaml   # YAML schema for backup-config.yml (FR-036)
├── hooks/                   # Hook framework
│   ├── db-backup.sh         # Database backup hook runner (FR-008)
│   └── db-restore.sh        # Database restore hook runner (FR-008)
├── tests/                   # Test suite
│   ├── unit/                # bats-core unit tests
│   ├── integration/         # Full cluster destroy/restore tests
│   └── fixtures/            # Test data and configurations
└── docs/                    # Documentation
    ├── RECOVERY.md          # Recovery procedures (FR-022)
    └── CREDENTIALS.md       # Credential management guide
```

**Structure Decision**: Single project with shell scripts. The system is a collection of Bash scripts and shared libraries, not a compiled application. This aligns with constitution Principle X (Simple, Explicit Operations).

## Triage Framework: [SYNC] vs [ASYNC] Classification

**Execution Strategy**: This feature will use a hybrid execution model combining human expertise ([SYNC]) with autonomous agent delegation ([ASYNC]).

### Preliminary Task Classification

| Task Category | Estimated [SYNC] Tasks | Estimated [ASYNC] Tasks | Rationale |
|---------------|----------------------|------------------------|-----------|
| Core Scripts | 2 | 4 | backup.sh/restore.sh need human review; library functions can be delegated |
| Library Functions | 1 | 7 | Core vault/k3d operations need review; utility functions are straightforward |
| Configuration | 1 | 2 | Schema definition needs review; validation logic is mechanical |
| Testing | 3 | 5 | Integration tests need human judgment; unit tests can be generated |
| Documentation | 2 | 1 | Recovery procedures need expert review; README is straightforward |
| Hooks | 1 | 2 | Hook interface needs review; example hooks can be delegated |

### Triage Decision Criteria Applied

**High-Risk [SYNC] Classifications:**
- backup.sh orchestration logic (FR-001) — complex coordination of multiple components
- restore.sh orchestration logic (FR-002) — critical recovery path, must be correct
- Vault snapshot/restore operations (FR-006, FR-030) — data integrity critical
- Integration tests (SC-001) — validates entire recovery chain
- Recovery documentation (FR-022) — must be accurate for disaster scenarios
- Hook interface definition (FR-008) — affects all repository integrations

**Agent-Delegated [ASYNC] Classifications:**
- Kopia wrapper functions (FR-003, FR-012, FR-013) — well-defined operations
- k3d cluster operations (FR-020) — standard CLI wrappers
- Configuration validation (FR-036, FR-037) — schema-based validation
- Logging utilities (FR-046) — structured output formatting
- Progress reporting (FR-044, FR-045) — percentage calculations
- Lock management (FR-048) — standard flock patterns
- Unit tests (FR-041, FR-042) — testable functions

### Triage Audit Trail

| Task | Classification | Primary Criteria | Risk Level | Rationale |
|------|----------------|------------------|------------|-----------|
| backup.sh main | SYNC | Criticality | High | Orchestrates entire backup, must handle all edge cases |
| restore.sh main | SYNC | Criticality | High | Recovery path, errors here mean data loss |
| vault.sh operations | SYNC | Data Integrity | High | Vault snapshots are irreplaceable |
| kopia.sh wrapper | ASYNC | Simplicity | Low | Thin wrapper around kopia CLI |
| config.sh validation | ASYNC | Simplicity | Low | Schema validation is mechanical |
| logging.sh | ASYNC | Simplicity | Low | Structured output formatting |
| progress.sh | ASYNC | Simplicity | Low | Percentage calculations |
| lock.sh | ASYNC | Simplicity | Low | Standard flock patterns |
| db-backup.sh | SYNC | Complexity | Medium | Hook execution with timeout/error handling |
| Unit tests | ASYNC | Simplicity | Low | Test generation for pure functions |
| Integration tests | SYNC | Criticality | High | Validates entire recovery chain |
| RECOVERY.md | SYNC | Criticality | High | Must be accurate for disaster scenarios |
| CREDENTIALS.md | SYNC | Security | High | Security-critical documentation |
| README.md | ASYNC | Simplicity | Low | Standard documentation |

## Complexity Tracking

No constitution violations identified. All requirements align with the 10 core principles.
