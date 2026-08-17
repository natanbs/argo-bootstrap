# Tasks: Local k3d Disaster Recovery

**Input**: Design documents from `/specs/006-k3d-disaster-recovery/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: bats-core unit tests for library functions, integration tests for full recovery

**Organization**: Tasks grouped by user story for independent implementation and testing.

## Format: `[ID] [P?] [SYNC/ASYNC] [Story?] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[SYNC]**: Requires human review (complex logic, security-critical)
- **[ASYNC]**: Can be delegated (well-defined, repetitive)
- **[Story]**: Which user story (US1-US5)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project directory structure and shared libraries

- [x] T001 [ASYNC] Create project directory structure at k3d-dr/ per plan.md
- [x] T002 [P] [ASYNC] Create shared logging library in k3d-dr/lib/logging.sh (FR-046)
- [x] T003 [P] [ASYNC] Create progress reporting library in k3d-dr/lib/progress.sh (FR-044, FR-045)
- [x] T004 [P] [ASYNC] Create lock management library in k3d-dr/lib/lock.sh (FR-048)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST complete before ANY user story

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T005 [ASYNC] Create configuration loading library in k3d-dr/lib/config.sh (FR-019, FR-036, FR-037)
- [x] T006 [ASYNC] Create YAML validation schema at k3d-dr/schemas/backup-config.yaml (FR-036)
- [x] T007 [ASYNC] Create error format library in k3d-dr/lib/errors.sh (FR-051)
- [x] T008 [P] [ASYNC] Create Kopia wrapper library in k3d-dr/lib/kopia.sh (FR-003, FR-012, FR-013)
- [x] T009 [P] [ASYNC] Create Vault wrapper library in k3d-dr/lib/vault.sh (FR-006, FR-030)
- [x] T010 [P] [ASYNC] Create k3d wrapper library in k3d-dr/lib/k3d.sh (FR-020, FR-025)
- [x] T011 [P] [ASYNC] Create Kubernetes wrapper library in k3d-dr/lib/kubernetes.sh (FR-016)
- [x] T012 [ASYNC] Create port offset utility in k3d-dr/lib/ports.sh (FR-025, FR-038)
- [x] T013 [ASYNC] Create DNS suffix utility in k3d-dr/lib/dns.sh (FR-026, FR-039)
- [x] T013a [P] [ASYNC] Setup bats-core test framework in k3d-dr/tests/unit/
- [x] T013b [P] [ASYNC] Create test fixtures in k3d-dr/tests/fixtures/

**Checkpoint**: Foundation ready - user story implementation can begin

---

## Phase 3: User Story 1 - Full Disaster Recovery (Priority: P1) 🎯 MVP

**Goal**: Complete cluster destruction and single-command recovery from local backup

**Independent Test**: Run `backup.sh`, destroy k3d cluster completely, run `restore.sh`, verify all data recovered

### Implementation for User Story 1

- [x] T014 [SYNC] [US1] Implement backup.sh main orchestration script in k3d-dr/backup.sh (FR-001, FR-014, FR-018, FR-041, FR-042)
- [x] T015 [SYNC] [US1] Implement restore.sh main orchestration script in k3d-dr/restore.sh (FR-002, FR-016, FR-018)
- [x] T016 [P] [ASYNC] [US1] Implement Vault snapshot backup in k3d-dr/lib/vault.sh (FR-006)
- [x] T017 [P] [ASYNC] [US1] Implement Vault restore with auto-unseal in k3d-dr/lib/vault.sh (FR-030, FR-031)
- [x] T018 [P] [ASYNC] [US1] Implement k3d cluster create in k3d-dr/lib/k3d.sh (FR-020, FR-025)
- [x] T019 [P] [ASYNC] [US1] Implement k3d cluster delete in k3d-dr/lib/k3d.sh
- [x] T020 [P] [ASYNC] [US1] Implement Kopia snapshot create in k3d-dr/lib/kopia.sh (FR-003)
- [x] T021 [P] [ASYNC] [US1] Implement Kopia snapshot restore in k3d-dr/lib/kopia.sh
- [x] T022 [ASYNC] [US1] Implement cluster metadata collection in k3d-dr/lib/metadata.sh (FR-011)
- [x] T023 [ASYNC] [US1] Implement infrastructure app discovery under ~/projects/infra in k3d-dr/lib/discovery.sh (FR-016)
- [x] T024 [ASYNC] [US1] Implement Kubernetes resource apply in k3d-dr/lib/kubernetes.sh (FR-016)
- [x] T025 [ASYNC] [US1] Implement health check verification in k3d-dr/lib/health.sh (FR-034, FR-035)
- [x] T026 [SYNC] [US1] Implement port offset application for k3d cluster in k3d-dr/lib/k3d.sh (FR-025, FR-038)
- [x] T027 [SYNC] [US1] Implement DNS suffix rewriting for Ingress resources in k3d-dr/lib/dns.sh (FR-026, FR-039)
- [x] T028 [ASYNC] [US1] Implement backup progress reporting in k3d-dr/lib/progress.sh (FR-044)
- [x] T029 [ASYNC] [US1] Implement restore progress reporting in k3d-dr/lib/progress.sh (FR-045)
- [x] T030 [ASYNC] [US1] Implement backup resume capability in k3d-dr/lib/kopia.sh (FR-047)
- [x] T030a [ASYNC] [US1] Implement backup state tracking in k3d-dr/lib/state.sh (FR-047)
- [x] T031 [ASYNC] [US1] Implement Kopia retention policy in k3d-dr/lib/kopia.sh (FR-013)
- [x] T032 [ASYNC] [US1] Implement Kopia integrity verification in k3d-dr/lib/kopia.sh (FR-012)
- [x] T033 [ASYNC] [US1] Implement registry persistence in k3d-dr/lib/registry.sh (FR-009)

**Checkpoint**: Full backup and restore working end-to-end

---

## Phase 4: User Story 2 - Selective Restore (Priority: P2)

**Goal**: Restore specific repositories or volumes without full cluster rebuild

**Independent Test**: Run `restore.sh --repo <name>` or `restore.sh --volume <name>` on running cluster

### Implementation for User Story 2

- [x] T034 [SYNC] [US2] Add selective restore options to restore.sh (--repo, --volume, --snapshot, --tag) (FR-027)
- [x] T035 [ASYNC] [US2] Implement snapshot listing and interactive selection in k3d-dr/lib/snapshots.sh (FR-027)
- [x] T036 [ASYNC] [US2] Implement skip-already-restored detection in k3d-dr/lib/restore.sh (FR-043)
- [x] T037 [SYNC] [US2] Implement rollback command (--rollback) in k3d-dr/restore.sh (FR-050)
- [x] T038 [ASYNC] [US2] Implement partial failure reporting in k3d-dr/lib/errors.sh (FR-049)

**Checkpoint**: Selective restore working without affecting other services

---

## Phase 5: User Story 3 - Pre-Backup Validation (Priority: P3)

**Goal**: Validate configuration and data sources before backup, fail fast with clear errors

**Independent Test**: Run `backup.sh` with intentionally misconfigured volume mappings or missing Vault

### Implementation for User Story 3

- [x] T039 [SYNC] [US3] Implement configuration validation in k3d-dr/lib/config.sh (FR-010, FR-036, FR-037)
- [x] T040 [ASYNC] [US3] Implement repository existence validation in k3d-dr/lib/config.sh (FR-010)
- [x] T041 [ASYNC] [US3] Implement volume mount path consistency check in k3d-dr/lib/config.sh (FR-028)
- [x] T041a [ASYNC] [US3] Implement data/repo separation validation in k3d-dr/lib/config.sh (FR-029a)
- [x] T042 [ASYNC] [US3] Implement Kopia repository accessibility check in k3d-dr/lib/kopia.sh
- [x] T043 [ASYNC] [US3] Implement Vault connectivity check in k3d-dr/lib/vault.sh
- [x] T044 [ASYNC] [US3] Implement port offset validation (0-65000) in k3d-dr/lib/ports.sh (FR-038)
- [x] T045 [ASYNC] [US3] Implement DNS suffix pattern validation in k3d-dr/lib/dns.sh (FR-039)
- [x] T046 [ASYNC] [US3] Implement environment variable override support in k3d-dr/lib/config.sh (FR-040)
- [x] T047 [ASYNC] [US3] Implement secret-free configuration validation in k3d-dr/lib/config.sh (FR-033)
- [x] T048 [ASYNC] [US3] Implement dry-run mode in k3d-dr/backup.sh (--dry-run flag) (FR-010)

**Checkpoint**: Validation catches all misconfigurations before backup/restore

---

## Phase 6: User Story 4 - Database Backup/Restore (Priority: P4)

**Goal**: Repository-specific database backup hooks using native tools

**Independent Test**: Deploy PostgreSQL, run backup, destroy database, run restore, verify data integrity

### Implementation for User Story 4

- [x] T049 [SYNC] [US4] Implement database backup hook runner in k3d-dr/hooks/db-backup.sh (FR-008)
- [x] T050 [SYNC] [US4] Implement database restore hook runner in k3d-dr/hooks/db-restore.sh (FR-008)
- [x] T051 [ASYNC] [US4] Implement hook timeout enforcement in k3d-dr/hooks/db-backup.sh (FR-008)
- [x] T052 [ASYNC] [US4] Implement hook mandatory/optional handling in k3d-dr/hooks/db-backup.sh (FR-049)
- [x] T053 [ASYNC] [US4] Implement hook checksum verification in k3d-dr/hooks/db-restore.sh
- [x] T054 [P] [ASYNC] [US4] Create example PostgreSQL backup hook in k3d-dr/hooks/examples/pg-backup.sh
- [x] T055 [P] [ASYNC] [US4] Create example PostgreSQL restore hook in k3d-dr/hooks/examples/pg-restore.sh

**Checkpoint**: Database backup/restore working with native tools

---

## Phase 7: User Story 5 - Vault Recovery Chain (Priority: P5)

**Goal**: Complete Vault bootstrap chain restoration (k3d → Vault → ESO → Secrets → Apps)

**Independent Test**: Full restore, verify Vault unsealed, ESO connected, apps receiving secrets

### Implementation for User Story 5

- [x] T056 [SYNC] [US5] Implement Vault Raft snapshot restore in k3d-dr/lib/vault.sh (FR-006, FR-030)
- [x] T057 [SYNC] [US5] Implement Vault auto-unseal with stored key in k3d-dr/lib/vault.sh (FR-030, FR-031)
- [x] T058 [ASYNC] [US5] Implement Vault seal status check in k3d-dr/lib/vault.sh
- [x] T059 [ASYNC] [US5] Implement Vault health wait in k3d-dr/lib/vault.sh (FR-035)
- [x] T060 [ASYNC] [US5] Implement ESO readiness verification in k3d-dr/lib/health.sh (FR-034)
- [x] T061 [ASYNC] [US5] Implement ESO connectivity check in k3d-dr/lib/health.sh
- [x] T062 [ASYNC] [US5] Implement Secret generation verification in k3d-dr/lib/health.sh
- [x] T063 [ASYNC] [US5] Implement Vault Kubernetes auth verification in k3d-dr/lib/vault.sh (FR-024)

**Checkpoint**: Vault recovery chain working end-to-end

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, testing, and hardening

- [x] T064 [SYNC] Create recovery procedures documentation in k3d-dr/docs/RECOVERY.md (FR-022)
- [x] T065 [SYNC] Create credential management guide in k3d-dr/docs/CREDENTIALS.md (FR-022)
- [x] T066 [ASYNC] Create project README in k3d-dr/README.md
- [x] T067 [ASYNC] Create backup-config.yml example in k3d-dr/examples/backup-config.yml
- [x] T068 [ASYNC] Implement deterministic alphabetical repository ordering in k3d-dr/lib/backup.sh (FR-042)
- [x] T069 [ASYNC] Implement idempotency checks in k3d-dr/lib/restore.sh (FR-043)
- [x] T070 [ASYNC] Add JSON output mode to backup.sh and restore.sh (--json flag) (FR-015)
- [x] T071 [ASYNC] Add verbose logging mode (--verbose flag) (FR-015)
- [x] T072 [ASYNC] Implement backup dry-run validation output in k3d-dr/backup.sh (FR-010)
- [ ] T073 [ASYNC] Run quickstart.md validation scenarios
- [x] T074 [ASYNC] Write unit tests for lib/config.sh in k3d-dr/tests/unit/config_test.bats
- [x] T075 [ASYNC] Write unit tests for lib/kopia.sh in k3d-dr/tests/unit/kopia_test.bats
- [x] T076 [ASYNC] Write unit tests for lib/vault.sh in k3d-dr/tests/unit/vault_test.bats
- [x] T077 [SYNC] Write integration test for full recovery in k3d-dr/tests/integration/full_recovery.bats

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies - can start immediately
- **Phase 2 (Foundational)**: Depends on Phase 1 - BLOCKS all user stories
- **Phase 3 (US1 - Full Recovery)**: Depends on Phase 2 - MVP goal
- **Phase 4 (US2 - Selective Restore)**: Depends on Phase 3
- **Phase 5 (US3 - Validation)**: Depends on Phase 2 (can parallel with US1)
- **Phase 6 (US4 - Database Hooks)**: Depends on Phase 2 (can parallel with US1)
- **Phase 7 (US5 - Vault Chain)**: Depends on Phase 3 (needs restore.sh)
- **Phase 8 (Polish)**: Depends on all user stories being complete

### User Story Dependencies

- **US1 (Full Recovery)**: Foundation only - No dependencies on other stories
- **US2 (Selective Restore)**: Depends on US1 (needs restore.sh)
- **US3 (Validation)**: Foundation only - Can parallel with US1
- **US4 (Database Hooks)**: Foundation only - Can parallel with US1
- **US5 (Vault Chain)**: Depends on US1 (needs restore.sh)

### Parallel Opportunities

- **Phase 1**: T002, T003, T004 can run in parallel
- **Phase 2**: T008, T009, T010, T011 can run in parallel
- **Phase 3**: T016-T021 can run in parallel
- **Phase 4**: T035-T038 can run in parallel
- **Phase 5**: T040-T048 can run in parallel
- **Phase 6**: T054, T055 can run in parallel
- **Phase 7**: T058-T063 can run in parallel

---

## Parallel Example: User Story 1

```bash
# After Phase 2 completes, launch parallel tasks:
Task T016: "Implement Vault snapshot backup in k3d-dr/lib/vault.sh"
Task T018: "Implement k3d cluster create in k3d-dr/lib/k3d.sh"
Task T020: "Implement Kopia snapshot create in k3d-dr/lib/kopia.sh"

# Then sequential orchestration:
Task T014: "Implement backup.sh main orchestration" (depends on T016, T020)
Task T015: "Implement restore.sh main orchestration" (depends on T017, T018)
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T004)
2. Complete Phase 2: Foundational (T005-T013)
3. Complete Phase 3: User Story 1 (T014-T033)
4. **STOP and VALIDATE**: Run quickstart.md full validation test
5. Deploy/demo if ready

### Incremental Delivery

1. Setup + Foundational → Foundation ready
2. Add User Story 1 → Test independently → Deploy/Demo (MVP!)
3. Add User Story 3 (Validation) → Test independently → Deploy/Demo
4. Add User Story 4 (Database Hooks) → Test independently → Deploy/Demo
5. Add User Story 2 (Selective Restore) → Test independently → Deploy/Demo
6. Add User Story 5 (Vault Chain) → Test independently → Deploy/Demo
7. Polish → Final delivery

---

## Task Summary

| Phase | Tasks | Parallel | SYNC | ASYNC |
|-------|-------|----------|------|-------|
| Setup | 4 | 3 | 0 | 4 |
| Foundational | 11 | 6 | 0 | 11 |
| US1 (Full Recovery) | 21 | 8 | 4 | 17 |
| US2 (Selective Restore) | 5 | 4 | 2 | 3 |
| US3 (Validation) | 11 | 10 | 1 | 10 |
| US4 (Database Hooks) | 7 | 2 | 2 | 5 |
| US5 (Vault Chain) | 8 | 6 | 2 | 6 |
| Polish | 14 | 0 | 3 | 11 |
| **Total** | **81** | **39** | **14** | **67** |

---

## Notes

- [P] tasks = different files, no dependencies
- [SYNC] tasks require human review (security, critical path, complex logic)
- [ASYNC] tasks can be delegated to async agents
- Each user story should be independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
