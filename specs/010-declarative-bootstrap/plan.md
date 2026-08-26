# Implementation Plan: Declarative Bootstrap Migration

**Branch**: `010-declarative-bootstrap` | **Date**: 2026-08-25 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/010-declarative-bootstrap/spec.md`

## Summary

Replace the Python JSON parser (`python3 -c "import sys,json; ..."`) in `argocd.sh`'s repo discovery loop with `jq`, and add `jq` to the tool installation check. Single-file change to `argocd.sh`.

## Technical Context

**Language/Version**: Bash (shell script)
**Primary Dependencies**: `jq` (new), existing: `curl`, `argocd` CLI, `kubectl`, `k3d`
**Storage**: N/A (no persistence changes)
**Testing**: Manual — run `argocd.sh` on a fresh k3d cluster
**Target Platform**: macOS + Linux (existing constraint)
**Project Type**: CLI bootstrap script
**Performance Goals**: N/A (one-time bootstrap)
**Constraints**: Must not break existing functionality; `jq` must be installable on both OSes
**Scale/Scope**: Single code location (line 273 in `argocd.sh`)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Data Must Outlive the Cluster | ✅ PASS | No data persistence changes |
| II. Repository-Driven Infrastructure | ✅ PASS | Repo URLs still come from `apps/*.yaml` in the infra repo |
| III. Vault Is the Secret Authority | ✅ PASS | No secret handling changes |
| IV. Backup Must Be Locally Recoverable | ✅ PASS | No backup changes |
| V. Recovery Over Backup | ✅ PASS | No recovery changes |
| VI. Consistency Over Convenience | ✅ PASS | No backup changes |
| VII. Dependency-Aware Recovery | ✅ PASS | No dependency order changes |
| VIII. Minimal Secret Duplication | ✅ PASS | No new secrets |
| IX. Idempotent Automation | ✅ PASS | `argocd repo add --upsert` is idempotent |
| X. Simple, Explicit Operations | ✅ PASS | `jq` is simpler than Python one-liner |

No violations. All gates pass.

## Project Structure

### Documentation (this feature)

```text
specs/010-declarative-bootstrap/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output (minimal — no data model changes)
├── quickstart.md        # Phase 1 output
└── tasks.md             # Phase 2 output (/spec.tasks)
```

### Source Code (repository root)

```text
argocd.sh               # Only file modified — line 273: python3 → jq, lines 113-122: install_tool jq
```

**Structure Decision**: Single-file change to existing `argocd.sh` — line 273 (jq replacement) and lines 113-122 (install_tool jq case). No new files, no new directories.

## Triage Framework: [SYNC] vs [ASYNC] Classification

**Execution Strategy**: 7 tasks across 6 phases. T001-T002 are [SYNC] code changes. T003-T007 are [ASYNC] verification.

### Preliminary Task Classification

| Task Category | Estimated [SYNC] Tasks | Estimated [ASYNC] Tasks | Rationale |
|---------------|----------------------|----------------------|-----------|
| Code Change | 2 | 0 | T001 (install_tool jq), T002 (python3 → jq) — both require file edits |
| Verification | 0 | 5 | T003-T007 are read-only validation checks |

### Triage Audit Trail

| Task | Classification | Primary Criteria | Risk Level | Rationale |
|------|----------------|------------------|------------|-----------|
| T001: Add jq to install_tool | [SYNC] | File edit required | Low | New case in existing function |
| T002: Replace python3 with jq | [SYNC] | File edit required | Low | Direct syntax replacement |
| T003: Verify ConfigMap patching | [ASYNC] | Read-only verification | Low | No code change needed |
| T004: Verify jq parsing parity | [ASYNC] | Read-only comparison | Low | Compare outputs |
| T005: Run quickstart scenarios | [ASYNC] | Read-only validation | Low | End-to-end check |
| T006: bash -n syntax check | [ASYNC] | Read-only validation | Low | Standard check |
| T007: Verify jq cross-platform | [ASYNC] | Read-only verification | Low | Check availability |

## Research (Phase 0)

No research needed — the change is a direct syntax replacement. `jq` is well-documented and the mapping from the Python one-liner is straightforward.

**Decision**: No `research.md` needed. Proceed directly to implementation.

## Design (Phase 1)

### Change Description

**File**: `argocd.sh`, line 273

**Current code**:
```bash
for appfile in $(curl -sL -u "${GITHUB_USER}:${token}" "https://api.github.com/repos/natanbs/argocd-infra/contents/apps?ref=${ARGOCD_INFRA_BRANCH}" 2>/dev/null | python3 -c "import sys,json; [print(f['download_url']) for f in json.load(sys.stdin) if f['name'].endswith('.yaml')]" 2>/dev/null); do
```

**New code**:
```bash
for appfile in $(curl -sL -u "${GITHUB_USER}:${token}" "https://api.github.com/repos/natanbs/argocd-infra/contents/apps?ref=${ARGOCD_INFRA_BRANCH}" 2>/dev/null | jq -r '.[] | select(.name | endswith(".yaml")) | .download_url' 2>/dev/null); do
```

**Also**: Add `jq` to `install_tool` function (around line 84-116) — add a `jq)` case for Linux install, and verify macOS `brew install jq` works.

### Data Model

No data model changes. The entities (Repo Registration, ArgoCD ConfigMap) are unchanged.

### Contracts

No external interfaces changed. The script's behavior is identical — only the internal parsing mechanism changes.

### Quickstart Validation

See `quickstart.md` for validation scenarios.
