# Tasks: Declarative Bootstrap Migration

**Input**: Design documents from `/specs/010-declarative-bootstrap/`

**Prerequisites**: plan.md, spec.md, quickstart.md

**Tests**: Not requested — test scenarios documented in quickstart.md for manual validation.

**Organization**: Tasks grouped by user story. Single file change to `argocd.sh`.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: No setup needed — existing project with established structure

No tasks.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Add `jq` to tool installation so all subsequent tasks can rely on it being present

- [X] T001 [ASYNC] Add `jq` to the `install_tool` function in `argocd.sh` (lines 84-116) — add a `jq)` case for Linux install (curl + chmod), verify macOS `brew install jq` works

**Checkpoint**: `jq` is now installed automatically if missing

---

## Phase 3: User Story 1 - Robust Repo Registration (Priority: P1) 🎯 MVP

**Goal**: Replace Python JSON parser with jq in the repo discovery loop

**Independent Test**: Run `argocd.sh` and verify `argocd repo list` shows all expected repos

### Implementation for User Story 1

- [X] T002 [US1] Replace Python JSON parser with jq in `argocd.sh` line 273 — change `python3 -c "import sys,json; [print(f['download_url']) for f in json.load(sys.stdin) if f['name'].endswith('.yaml')]"` to `jq -r '.[] | select(.name | endswith(".yaml")) | .download_url'`

**Checkpoint**: Repo discovery now uses jq — Python dependency removed from this code path

---

## Phase 4: User Story 2 - ArgoCD ConfigMap Configured Reliably (Priority: P2)

**Goal**: Verify ConfigMap patching works correctly with jq-based repo registration

**Independent Test**: Check `kubectl get configmap argocd-cmd-params-cm -n argocd -o yaml` shows correct keys

### Implementation for User Story 2

- [X] T003 [US2] Verify ConfigMap patching in `argocd.sh` (line 185) works correctly after jq change — no code change needed, confirm `kubectl patch configmap argocd-cmd-params-cm` still sets `server.insecure` and `server.session.expires` correctly

**Checkpoint**: ConfigMap configuration is verified working

---

## Phase 5: Verification — Parsing Parity

**Goal**: Verify jq produces identical output to Python parser

**Independent Test**: Compare jq and Python outputs against GitHub API response

### Implementation

- [X] T004 [US2] Verify jq parsing produces identical output to Python parser for the GitHub API response — reference quickstart.md Scenario 1

**Checkpoint**: jq produces identical repo URLs as Python parser

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final validation and cleanup

- [X] T005 [ASYNC] Run quickstart.md validation scenarios 1-5 to verify end-to-end functionality
- [X] T006 [ASYNC] Run `bash -n argocd.sh` syntax check to verify no parse errors
- [X] T007 [ASYNC] Verify `jq` installation works on both macOS (brew) and Linux (curl)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — skipped (no setup needed)
- **Foundational (Phase 2)**: No dependencies — can start immediately
- **User Story 1 (Phase 3)**: Depends on T001 (jq must be installable)
- **User Story 2 (Phase 4)**: Can run after T002 (same file, sequential)
- **Polish (Phase 6)**: Depends on all previous tasks

### Within Each User Story

- Single-task stories — no internal ordering needed
- All stories touch `argocd.sh` — must be sequential

### Parallel Opportunities

- T003 (ConfigMap verification) and T004 (jq parsing verification) could run in parallel after T002
- T005, T006, T007 (Polish) could run in parallel

---

## Parallel Example: Verification Phase

```bash
# After T002 completes, run verifications in parallel:
Task: "Verify ConfigMap patching still works (T003)"
Task: "Test jq parsing against Python output (T004)"

# After verifications pass, run polish tasks in parallel (Phase 6):
Task: "Run quickstart.md validation (T005)"
Task: "Run bash -n syntax check (T006)"
Task: "Verify jq installation cross-platform (T007)"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 2: Add jq to install_tool
2. Complete Phase 3: Replace Python with jq
3. **STOP and VALIDATE**: Run quickstart scenario 1 (repo discovery uses jq)
4. Deploy if ready

### Full Delivery

1. Phase 2: Add jq → Phase 3: Replace Python → Phase 4: Verify ConfigMap + parsing → Phase 6: Polish
2. Total: 7 tasks, all in `argocd.sh` or verification steps

---

## Notes

- All tasks touch `argocd.sh` — must be sequential (no true parallelism within the file)
- T003 and T004 are verification tasks, not code changes
- No test framework needed — manual validation via quickstart.md scenarios
- Scope is intentionally narrow: single-line code change + tool installation
