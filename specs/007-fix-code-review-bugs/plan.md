# Implementation Plan: Fix Code Review Bugs

**Branch**: `007-fix-code-review-bugs` | **Date**: 2026-08-18 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/007-fix-code-review-bugs/spec.md`

## Summary

Fix 7 bugs identified during code review of the k3d-dr backup/restore implementation. Two high-severity bugs (false-positive secret validation, broken env overrides) block all backup/restore operations. Three medium-severity bugs (Vault CA cert, retention flags, idempotency check) cause runtime failures. Two low-severity items (dead code, code duplication) improve maintainability.

## Technical Context

**Language/Version**: Bash 3.2+ (macOS/Linux compatible)

**Primary Dependencies**: bash, yq v4, jq, kopia, vault, kubectl, k3d

**Storage**: N/A (bug fixes to existing scripts)

**Testing**: bats-core unit tests, bash -n syntax validation

**Target Platform**: macOS (primary), Linux (secondary)

**Project Type**: CLI tool / shell scripts

**Performance Goals**: N/A (bug fixes, no performance changes)

**Constraints**: Bash 3.2 compatibility (no `declare -A`, `declare -g`, `local -n`), existing directory structure preserved

**Scale/Scope**: 7 bugs across 6 files, ~100 lines changed

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Data Must Outlive the Cluster | ✅ PASS | Fixes ensure backup/restore actually work |
| II. Repository-Driven Infrastructure | ✅ PASS | Config remains YAML-driven, env overrides now work |
| III. Vault Is the Secret Authority | ✅ PASS | Vault K8s auth fix ensures proper secret management |
| IV. Backup Must Be Locally Recoverable | ✅ PASS | Retention fixes ensure proper local backup management |
| V. Recovery Over Backup | ✅ PASS | Idempotency fix ensures reliable recovery |
| VI. Consistency Over Convenience | ✅ PASS | Validation fixes ensure config correctness |
| VII. Dependency-Aware Recovery | ✅ PASS | No changes to recovery order |
| VIII. Minimal Secret Duplication | ✅ PASS | Validation prevents secret duplication in config |
| IX. Idempotent Automation | ✅ PASS | Idempotency check fix ensures safe re-runs |
| X. Simple, Explicit Operations | ✅ PASS | Fixes are simple, targeted changes |

**No constitution violations.** All fixes align with existing principles.

## Project Structure

### Documentation (this feature)

```text
specs/007-fix-code-review-bugs/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (empty - bug fix, no new interfaces)
└── tasks.md             # Phase 2 output (/spec.tasks command)
```

### Source Code (repository root)

```text
k3d-dr/
├── backup.sh              # Fix: retention flag mapping (FR-004)
├── restore.sh             # Fix: Vault CA cert (FR-003), idempotency check (FR-005)
├── lib/
│   ├── config.sh          # Fix: env overrides consumed by config_get (FR-002)
│   ├── validation.sh      # Fix: validate_no_secrets false-positive (FR-001)
│   ├── kopia.sh           # Fix: kopia_retention keep-latest mapping (FR-004)
│   └── logging.sh         # Fix: extract shared JSON/text helper (FR-007)
└── tests/
    └── test_helper.bash   # No changes needed
```

**Structure Decision**: Bug fixes to existing files. No new directories or files created (except research.md, data-model.md, quickstart.md in specs/).

## Complexity Tracking

No constitution violations. No complexity tracking needed.

## Implementation Tasks

### Phase 1: High-Severity Fixes (P1 - Blocking)

- [ ] **T001 [ASYNC]** Fix `validate_no_secrets` in `lib/validation.sh` (FR-001)
  - Change grep pattern to match only value portion of YAML lines (after colon), not key names
  - Acceptance: `password_env: KOPIA_PASSWORD` passes, `password: my-secret` fails

- [ ] **T002 [ASYNC]** Fix `config_apply_env_overrides` in `lib/config.sh` (FR-002)
  - Make `config_get` check override variables before YAML values for supported keys
  - Acceptance: `KOPIA_PASSWORD_ENV=X` makes `config_get "kopia.password_env"` return `X`

### Phase 2: Medium-Severity Fixes (P2 - Runtime Failures)

- [ ] **T003 [ASYNC]** Fix Vault K8s auth CA cert in `restore.sh` (FR-003)
  - Replace `kubernetes_ca_cert="@"` with actual cert from `/var/run/secrets/kubernetes.io/serviceaccount/ca.crt`
  - Acceptance: Vault auth setup completes without hanging

- [ ] **T004 [ASYNC]** Fix `kopia_retention` in `lib/kopia.sh` and `backup.sh` (FR-004)
  - Add `latest` parameter to `kopia_retention`, map to `--keep-latest` independently
  - Acceptance: `--keep-latest` and `--keep-daily` are independently configurable

- [ ] **T005 [ASYNC]** Fix idempotency check in `restore.sh` (FR-005)
  - Handle case where no pod is mounted on PVC (fall through to restore)
  - Acceptance: Idempotency check completes without error when no pod exists

### Phase 3: Low-Severity Fixes (P3 - Maintainability)

- [ ] **T006 [ASYNC]** Remove dead code in `lib/validation.sh` (FR-006)
  - Remove redundant config re-sourcing in `validate_cross_field`
  - Acceptance: No behavioral change, code is cleaner

- [ ] **T007 [ASYNC]** Extract shared JSON/text helper in `lib/logging.sh` (FR-007)
  - Create `_format_log_entry` function used by both stdout and log file
  - Acceptance: No behavioral change, code duplication eliminated

### Phase 4: Verification

- [ ] **T008 [SYNC]** Run `bash -n` on all modified scripts
- [ ] **T009 [SYNC]** Run existing unit tests to verify no regressions
- [ ] **T100 [SYNC]** Manual verification of each fix against acceptance scenarios

## Task Classification

| Task | Type | Rationale |
|------|------|-----------|
| T001-T007 | ASYNC | Well-defined bug fixes with clear acceptance criteria |
| T008-T100 | SYNC | Verification requires human judgment |

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Env override fix changes config_get behavior | Low | Only affects keys with overrides defined; YAML values still work as fallback |
| Vault CA cert path may differ in some clusters | Low | Use standard Kubernetes service account path; document assumption |
| Retention flag change affects existing behavior | Low | Only changes when explicit latest config is provided |

## Dependencies

- Existing codebase structure preserved
- No new dependencies introduced
- All fixes are backward-compatible
