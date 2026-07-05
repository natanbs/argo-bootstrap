# Tasks: CLI Tool Install

**Input**: Design documents from `/specs/001-cli-tool-install/`
**Prerequisites**: plan.md, spec.md (required for user stories), research.md, data-model.md

**Tests**: Manual script execution verification (no automated test framework for shell scripts in this project).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [SYNC/ASYNC] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[SYNC]**: Requires human review (complex logic, security-critical, ambiguous requirements)
- **[ASYNC]**: Can be delegated to async agents (well-defined CRUD, repetitive tasks, clear specs)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Single project**: script at repository root
- All paths relative to repo root unless otherwise noted

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

No setup tasks needed — this feature modifies the existing `argocd.sh` script at the repository root. No new project structure, dependencies, or tooling required.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: OS detection and tool installation infrastructure

- [X] T001 [SYNC] Add OS detection using `uname -s` at the top of `argocd.sh` (line 16)
- [X] T002 [SYNC] Create `install_tool()` function in `argocd.sh` (lines 18-46) with platform branching for macOS (Homebrew) and Linux (binary download)
- [X] T003 [P] [ASYNC] Add kubectl installation case to `install_tool()` for Linux in `argocd.sh` (lines 35-41) — download from `dl.k8s.io/release/stable.txt`
- [X] T004 [P] [ASYNC] Add argocd installation case to `install_tool()` for Linux in `argocd.sh` (lines 31-33) — download from GitHub releases
- [X] T005 [P] [ASYNC] Add k3d installation case to `install_tool()` for Linux in `argocd.sh` (lines 28-29) — curl from `get.k3d.io`
- [X] T006 [ASYNC] Handle Homebrew package name mapping for kubectl (`kubernetes-cli`) in `install_tool()` macOS branch (lines 22-23)

**Checkpoint**: `install_tool()` function supports all 3 tools on both platforms

---

## Phase 3: User Story 1 - Run bootstrap script with missing prerequisites (Priority: P1) 🎯 MVP

**Goal**: User runs `argocd.sh` on a fresh machine — kubectl and argocd are automatically installed before cluster setup proceeds.

**Independent Test**: Run on a clean macOS or Debian/Ubuntu VM; confirm `kubectl version --client` and `argocd version --client` succeed after script completes.

### Implementation for User Story 1

- [X] T007 [ASYNC] [US1] Add `install_tool kubectl` call in `argocd.sh` before kubectl-dependent commands (line 48)
- [X] T008 [ASYNC] [US1] Add `install_tool k3d` call in `argocd.sh` before k3d-dependent commands (line 49)
- [X] T009 [ASYNC] [US1] Add `install_tool argocd` call in `argocd.sh` before argocd-dependent commands (line 74)
- [X] T010 [ASYNC] [US1] Remove old `brew list argocd` / `brew install argocd` direct call (replaced by `install_tool argocd`)

**Checkpoint**: At this point, all three tools are auto-installed on fresh machines. US1 is fully functional.

---

## Phase 4: User Story 2 - Run bootstrap script with existing tools (Priority: P2)

**Goal**: When tools are already installed, the script skips installation without errors or delays.

**Independent Test**: Install kubectl and argocd manually, then run `argocd.sh` — verify no reinstallation occurs (check for skipped install messages).

### Implementation for User Story 2

- [X] T011 [P] [ASYNC] [US2] Verify `command -v` check in `install_tool()` correctly skips when tool is already present (line 26 — covers macOS too via `brew list` on line 24)
- [X] T012 [P] [ASYNC] [US2] Verify `brew list` check on macOS exits cleanly when package is already installed (line 24)

**Checkpoint**: Both stories complete. Script handles fresh and pre-configured environments.

---

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: Edge case handling and error robustness

- [X] T013 [SYNC] Add error handling for network failures during binary download in `install_tool()`
- [X] T014 [SYNC] Add fallback for unsupported OS (neither macOS nor Linux) with clear error message
- [X] T015 [ASYNC] Verify `sudo` installation on Linux handles permission-denied gracefully
- [X] T016 [ASYNC] Run quickstart.md validation — confirm script works end-to-end

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — nothing to set up
- **Foundational (Phase 2)**: T001 must complete before T002; T002 must complete before T003-T005 (can run in parallel)
- **User Story 1 (Phase 3)**: Depends on T002 plus T003-T006 — function must exist before it can be called
- **User Story 2 (Phase 4)**: Depends on Phase 3 completion (function already exists, just verifying behavior)
- **Polish (Phase 5)**: Depends on all user story phases complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Phase 2 (install_tool function exists)
- **User Story 2 (P2)**: Can start after Phase 3 — verifies existing behavior

### Within Each User Story

- Foundational tasks before story tasks
- OS detection before platform-specific install logic
- Function definition before function calls

### Parallel Opportunities

- T003, T004, T005 (add tool cases to install_tool) can run in parallel — different cases in the same case statement
- T011, T012 (verify skip behavior) can run in parallel

---

## Parallel Example: User Story 1

```bash
# Launch all tool case additions together:
Task: "Add kubectl installation case to install_tool() for Linux in argocd.sh"
Task: "Add argocd installation case to install_tool() for Linux in argocd.sh"
Task: "Add k3d installation case to install_tool() for Linux in argocd.sh"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 2: Foundational (install_tool function + all tool cases)
2. Complete Phase 3: User Story 1 (call install_tool for each tool)
3. **STOP and VALIDATE**: Run on fresh macOS + Linux machines
4. Deploy/demo if ready

### Incremental Delivery

1. Complete Foundational → Function ready
2. Add install_tool calls → Fresh machine support (MVP!)
3. Verify existing-tool behavior → No-regression env support
4. Polish edge cases → Production-ready

---

## Notes

- [P] tasks = different parts of the same file but non-overlapping sections
- [SYNC] tasks = core logic decisions (OS detection, function structure)
- [ASYNC] tasks = well-defined, standard installation patterns
- [Story] label maps task to specific user story for traceability
- Each user story is independently testable via script execution
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
