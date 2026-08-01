# Tasks: Fix Registry Tags Display

**Input**: Design documents from `/specs/003-fix-registry-tags/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Not requested — manual testing only via quickstart.md scenarios.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [SYNC/ASYNC] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[SYNC]**: Requires human review (complex logic, security-critical, ambiguous requirements)
- **[ASYNC]**: Can be delegated to async agents (well-defined CRUD, repetitive tasks, clear specs)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup

**Purpose**: No project initialization needed — modifying an existing script.

_(No tasks in this phase.)_

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core structure that ALL user stories depend on — flag parsing skeleton and version sort pipeline.

**CRITICAL**: No user story work can begin until this phase is complete.

- [x] T001 [SYNC] Add flag parsing skeleton with case statement in reg.sh (handle -h, --help, -f, --full, and invalid flags)
- [x] T002 [SYNC] Replace plain `sort` with `sort -V -r` for version-aware descending tag sort in reg.sh

**Checkpoint**: Foundation ready — flag parsing and version sort in place, user story implementation can begin.

---

## Phase 3: User Story 1 — Default: Last 3 Tags (Priority: P1) MVP

**Goal**: When running `./reg.sh` without flags, show at most 3 tags per image in version-sorted descending order.

**Independent Test**: Run `./reg.sh` against local registry and verify each image shows at most 3 tags, with v1.1.2 before v1.1.11.

### Implementation for User Story 1

- [x] T003 [US1] Implement default mode: limit tag output to 3 using `head -n 3` after version sort in reg.sh

**Checkpoint**: Default behavior works — running `./reg.sh` shows last 3 version-sorted tags per image.

---

## Phase 4: User Story 2 — Full Flag (Priority: P1)

**Goal**: When running `./reg.sh -f` or `./reg.sh --full`, show all tags per image in version-sorted descending order.

**Independent Test**: Run `./reg.sh -f` and verify all tags shown for each image in version-sorted order.

### Implementation for User Story 2

- [x] T004 [US2] Implement full mode: skip tag limit when `-f` or `--full` flag is provided in reg.sh

**Checkpoint**: Full mode works — running `./reg.sh -f` shows all version-sorted tags.

---

## Phase 5: User Story 3 — Help Flag (Priority: P2)

**Goal**: When running `./reg.sh -h` or `./reg.sh --help`, display a concise usage message.

**Independent Test**: Run `./reg.sh -h` and verify help text is displayed describing available flags.

### Implementation for User Story 3

- [x] T005 [US3] Implement help message: print usage text to stdout and exit 0 when `-h` or `--help` is provided in reg.sh

**Checkpoint**: Help works — running `./reg.sh -h` shows usage information.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Edge cases and error handling that affect multiple user stories.

- [x] T006 [SYNC] Handle invalid flags: print usage hint to stderr and exit with non-zero code in reg.sh
- [x] T007 [SYNC] Handle edge case: gracefully display images with zero tags in reg.sh
- [x] T008 Run quickstart.md validation scenarios against local registry

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — skipped (no initialization needed)
- **Foundational (Phase 2)**: No dependencies — can start immediately
- **User Stories (Phase 3-5)**: All depend on Foundational phase completion
  - US1, US2, US3 can proceed in any order after Phase 2
- **Polish (Phase 6)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) — No dependencies on other stories
- **User Story 2 (P1)**: Can start after Foundational (Phase 2) — Independent of US1
- **User Story 3 (P2)**: Can start after Foundational (Phase 2) — Independent of US1/US2

### Within Each User Story

- Flag parsing (Phase 2) before story-specific logic
- Each story adds one behavioral branch to the same case statement in reg.sh

### Parallel Opportunities

- US1, US2, US3 are logically independent but share the same file (reg.sh) — sequential execution recommended to avoid conflicts
- Polish tasks T006, T007 are independent and can run in parallel

---

## Parallel Example: Polish Phase

```bash
# Launch edge case handlers in parallel:
Task: "T006 Handle invalid flags in reg.sh"
Task: "T007 Handle zero tags edge case in reg.sh"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 2: Foundational (flag parsing + version sort)
2. Complete Phase 3: User Story 1 (default 3-tag limit)
3. **STOP and VALIDATE**: Test `./reg.sh` shows last 3 version-sorted tags
4. Deploy/demo if ready

### Incremental Delivery

1. Complete Foundational → Flag parsing and version sort in place
2. Add US1 → Test `./reg.sh` shows 3 tags → MVP ready
3. Add US2 → Test `./reg.sh -f` shows all tags → Full visibility restored
4. Add US3 → Test `./reg.sh -h` shows help → CLI complete
5. Polish → Invalid flag handling, edge cases → Production ready

---

## Notes

- All tasks modify a single file: `reg.sh`
- Sequential execution recommended due to single-file shared state
- No tests requested — validate via manual testing using quickstart.md scenarios
- `sort -V` confirmed available on both macOS and Linux (see research.md)
- Total tasks: 8 (T001-T008)
