# Tasks: ArgoCD Script Optimization

**Input**: Design documents from `/specs/009-argocd-optimization/`

**Prerequisites**: plan.md (required), spec.md (required for user stories)

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Remove Dead Code

**Purpose**: Remove unused code to reduce maintenance burden

- [ ] T001 [ASYNC] [US1] Remove duplicate VAULT_REPO definition at line 332 in argocd.sh (keep line 322)
- [ ] T002 [ASYNC] [US1] Remove unused MAPPED_PORTS and check_mapped_ports() at lines 139-148 in argocd.sh
- [ ] T003 [ASYNC] [US1] Remove unnecessary empty lines at lines 114-117 in argocd.sh

---

## Phase 2: Fix Security Issues

**Purpose**: Prevent sensitive information from being exposed

- [ ] T004 [ASYNC] [US2] Remove echo $init_pass at line 229 in argocd.sh

---

## Phase 3: Simplify Code

**Purpose**: Improve code readability and maintainability

- [ ] T005 [ASYNC] [US3] Simplify port_in_use() to use lsof only (remove ss command) at lines 151-156 in argocd.sh
- [ ] T006 [ASYNC] [US3] Update --help text to accurately describe GITHUB_TOKEN env var at lines 26-38 in argocd.sh
- [ ] T007 [ASYNC] [US3] Remove arbitrary sleep 30 at line 232 in argocd.sh (verify health check is sufficient)

---

## Phase 4: Improve Error Handling

**Purpose**: Detect and report errors consistently

- [ ] T008 [ASYNC] [US4] Add error handling for curl command at line 125 in argocd.sh
- [ ] T009 [ASYNC] [US4] Add error handling for curl command at line 275 in argocd.sh
- [ ] T010 [ASYNC] [US4] Add error handling for curl commands in loop at lines 277-283 in argocd.sh

---

## Phase 5: Verify Functionality

**Purpose**: Ensure optimization doesn't break existing functionality

- [ ] T011 [ASYNC] [ALL] Run argocd.sh on fresh cluster and verify all 3 vault pods are Running and Ready=True
- [ ] T012 [ASYNC] [ALL] Verify all 5 registered apps deploy successfully via ApplicationSet
- [ ] T013 [ASYNC] [ALL] Verify script is idempotent (can run twice without errors)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Remove Dead Code)**: No dependencies - can start immediately
- **Phase 2 (Fix Security Issues)**: No dependencies - can start immediately
- **Phase 3 (Simplify Code)**: No dependencies - can start immediately
- **Phase 4 (Improve Error Handling)**: No dependencies - can start immediately
- **Phase 5 (Verify Functionality)**: Depends on all other phases being complete

### Within Each Phase

- Tasks within a phase can run in parallel (different files or different parts of same file)
- No dependencies between tasks within a phase

### Parallel Opportunities

- T001, T002, T003 (Phase 1) can run in parallel
- T004 (Phase 2) can run in parallel with Phase 1
- T005, T006, T007 (Phase 3) can run in parallel
- T008, T009, T010 (Phase 4) can run in parallel
- T011, T012, T013 (Phase 5) can run in parallel after all other phases

---

## Parallel Example: Phase 1

```bash
# T001, T002, T003 can run in parallel (different parts of same file):
Task: "Remove duplicate VAULT_REPO definition at line 332"
Task: "Remove unused MAPPED_PORTS and check_mapped_ports() at lines 139-148"
Task: "Remove unnecessary empty lines at lines 114-117"
```

---

## Implementation Strategy

### MVP First (Remove Dead Code + Fix Security)

1. Complete Phase 1: Remove Dead Code
2. Complete Phase 2: Fix Security Issues
3. **STOP and VALIDATE**: Run script, verify functionality
4. Demo if ready

### Incremental Delivery

1. Complete Phase 1 + 2 → Dead code removed, security fixed → Test
2. Complete Phase 3 → Code simplified → Test
3. Complete Phase 4 → Error handling improved → Test
4. Complete Phase 5 → Full validation → Done

---

## Notes

- [P] tasks = different files or different parts of same file, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- All changes are to `argocd.sh` only - no other files modified
