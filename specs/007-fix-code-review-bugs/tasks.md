# Tasks: Fix Code Review Bugs

**Input**: Design documents from `/specs/007-fix-code-review-bugs/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md

**Tests**: bats-core unit tests for library functions, bash -n syntax validation

**Organization**: Tasks grouped by user story for independent implementation and testing.

## Format: `[ID] [P?] [SYNC/ASYNC] [Story?] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[SYNC]**: Requires human review (complex logic, security-critical)
- **[ASYNC]**: Can be delegated (well-defined, repetitive)
- **[Story]**: Which user story (US1-US5)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Verify existing test framework and dependencies

- [x] T001 [ASYNC] Verify bats-core test framework is available and working in k3d-dr/tests/
- [x] T002 [ASYNC] Verify all modified scripts pass `bash -n` syntax validation before changes

---

## Phase 2: High-Severity Fixes (P1 - Blocking)

**Purpose**: Fix bugs that block all backup/restore operations

**⚠️ CRITICAL**: These fixes must complete before any user story can function

### User Story 1 - Backup and Restore Execute Without False Validation Failures

**Goal**: Fix `validate_no_secrets` false-positive on config key names
**Independent Test**: Run `validate_no_secrets` against config with `password_env: KOPIA_PASSWORD` — should pass

- [x] T003 [ASYNC] [US1] Fix `validate_no_secrets` grep pattern in k3d-dr/lib/validation.sh (FR-001) — change to match only value portion after colon, not key names
- [x] T004 [SYNC] [US1] Add unit test for `validate_no_secrets` in k3d-dr/tests/unit/test_validation.bats — test with config containing `password_env` key (should pass) and inline `password` value (should fail)

**Checkpoint**: US1 complete — validation no longer blocks backup/restore

### User Story 2 - Environment Variable Overrides Are Applied

**Goal**: Make `config_get` consume env override variables
**Independent Test**: Set `KOPIA_PASSWORD_ENV=my-password`, run `config_load`, verify `config_get "kopia.password_env"` returns `my-password`

- [x] T005 [ASYNC] [US2] Modify `config_get` in k3d-dr/lib/config.sh (FR-002) — check override variables before YAML values for supported keys (kopia.password_env, vault.unseal_key_path, database_hooks.mandatory)
- [x] T006 [SYNC] [US2] Add unit test for env overrides in k3d-dr/tests/unit/test_config.bats — test that env overrides take priority over YAML values

**Checkpoint**: US2 complete — env overrides now functional

---

## Phase 3: Medium-Severity Fixes (P2 - Runtime Failures)

**Purpose**: Fix bugs that cause runtime failures during backup/restore

### User Story 3 - Vault K8s Auth Uses Correct CA Certificate

**Goal**: Fix `kubernetes_ca_cert="@"` that causes Vault CLI to hang
**Independent Test**: Run Vault K8s auth setup — should complete without hanging

- [x] T007 [ASYNC] [US3] Fix Vault K8s auth CA cert in k3d-dr/restore.sh (FR-003) — replace `kubernetes_ca_cert="@"` with actual cert from `/var/run/secrets/kubernetes.io/serviceaccount/ca.crt`
- [x] T008 [SYNC] [US3] Add error handling for missing CA cert path in k3d-dr/restore.sh — log warning and return 1 if cert file not readable

**Checkpoint**: US3 complete — Vault K8s auth setup works

### User Story 4 - Retention Policy Flags Are Correctly Mapped

**Goal**: Make `--keep-latest` and `--keep-daily` independently configurable
**Independent Test**: Set `retention.daily=7` and `retention.latest=30`, verify Kopia receives both flags

- [x] T009 [ASYNC] [US4] Add `latest` parameter to `kopia_retention` in k3d-dr/lib/kopia.sh (FR-004) — map to `--keep-latest` independently from `--keep-daily`
- [x] T010 [ASYNC] [US4] Update `kopia_retention` call in k3d-dr/backup.sh — pass `retention.latest` config value
- [x] T011 [ASYNC] [US4] Add `retention.latest` case to `config_get` in k3d-dr/lib/config.sh — read from YAML with default fallback
- [x] T012 [SYNC] [US4] Add unit test for retention flags in k3d-dr/tests/unit/test_kopia.bats — test independent `--keep-latest` and `--keep-daily` values

**Checkpoint**: US4 complete — retention policy correctly configured

### User Story 5 - Idempotency Check Works Without Running Pods

**Goal**: Handle case where no pod is mounted on PVC during restore
**Independent Test**: Run idempotency check against PVC with no pods — should fall through to restore

- [x] T013 [ASYNC] [US5] Fix idempotency check in k3d-dr/restore.sh (FR-005) — handle empty `pod_name` gracefully (fall through to restore)
- [x] T014 [SYNC] [US5] Add edge case handling for PVC with no data and no pod in k3d-dr/restore.sh — ensure restore proceeds

**Checkpoint**: US5 complete — idempotency check handles all cases

---

## Phase 4: Low-Severity Fixes (P3 - Maintainability)

**Purpose**: Clean up code quality issues

- [x] T015 [ASYNC] Remove dead code in `validate_cross_field` in k3d-dr/lib/validation.sh (FR-006) — remove redundant config re-sourcing
- [x] T016 [ASYNC] Extract `_format_log_entry` helper in k3d-dr/lib/logging.sh (FR-007) — eliminate duplicate JSON/text construction
- [x] T017 [ASYNC] Update stdout and log file sections in k3d-dr/lib/logging.sh to use `_format_log_entry` helper

**Checkpoint**: Code quality improvements complete

---

## Phase 5: Verification

**Purpose**: Verify all fixes and ensure no regressions

- [x] T018 [SYNC] Run `bash -n` on all modified scripts: backup.sh, restore.sh, lib/config.sh, lib/validation.sh, lib/kopia.sh, lib/logging.sh
- [x] T019 [SYNC] Run existing unit tests in k3d-dr/tests/unit/ — verify no regressions
- [x] T020 [SYNC] Manual verification of each fix against acceptance scenarios from spec.md
- [x] T021 [SYNC] Run integration test if k3d cluster available: k3d-dr/tests/integration/test_full_recovery.bats

---

## Dependencies

```text
Phase 1 (Setup) ──▶ Phase 2 (High-Severity) ──▶ Phase 3 (Medium-Severity) ──▶ Phase 4 (Low-Severity) ──▶ Phase 5 (Verification)
```

**User Story Dependencies**:
- US1 and US2 are independent (different files)
- US3, US4, US5 are independent (different files)
- All user stories depend on Phase 1 setup
- Phase 4 depends on all user stories complete
- Phase 5 depends on all phases complete

## Parallel Execution Examples

**Within Phase 2**:
- T003 (US1) and T005 (US2) can run in parallel (different files: validation.sh vs config.sh)

**Within Phase 3**:
- T007 (US3), T009 (US4), T013 (US5) can run in parallel (different files: restore.sh sections, kopia.sh, backup.sh)

**Within Phase 4**:
- T015 (validation.sh), T016-T017 (logging.sh) can run in parallel

## Implementation Strategy

**MVP Scope**: US1 + US2 (Phase 2) — fixes the blocking bugs
**Full Scope**: All 5 user stories + maintainability fixes
**Verification**: Run after each phase to catch regressions early

## Task Summary

| Phase | Tasks | Status |
|-------|-------|--------|
| Phase 1: Setup | T001-T002 | ✅ Complete |
| Phase 2: High-Severity (US1+US2) | T003-T006 | ✅ Complete |
| Phase 3: Medium-Severity (US3+US4+US5) | T007-T014 | ✅ Complete |
| Phase 4: Low-Severity | T015-T017 | ✅ Complete |
| Phase 5: Verification | T018-T021 | ✅ Complete |
| Phase 6: Code Review Fixes | T022-T024 | ✅ Complete |
| **Total** | **24 tasks** | **All Complete** |

---

## Phase 6: Code Review Fixes

**Purpose**: Fix bugs identified during post-implementation code review

- [x] T022 [ASYNC] Fix `kopia_retention` eval bug in k3d-dr/lib/kopia.sh — remove eval, use direct argument passing
- [x] T023 [ASYNC] Fix `validate_no_secrets` regex false-positives in k3d-dr/lib/validation.sh — handle quoted env var names, paths, and var refs
- [x] T024 [ASYNC] Fix hardcoded K8s CA cert path in k3d-dr/restore.sh — use kubectl to fetch cert from cluster instead of reading from in-cluster path
