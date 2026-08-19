# Tasks: ArgoCD Install Infra Apps

**Input**: Design documents from `/specs/008-argocd-install-infra/`

**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Review existing script structure and plan insertion points

- [x] T001 [ASYNC] Review current argocd.sh structure and identify insertion points for GitHub credential and ApplicationSet deployment in argocd.sh
- [x] T002 [ASYNC] Review infra/argocd-infra/applicationset.yaml manifest structure and apps/*.yaml registration format

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T003 [SYNC] Add GITHUB_TOKEN env var input with interactive prompt fallback to argocd.sh (FR-007, FR-009)
- [x] T004 [ASYNC] Add ARGOCD_INFRA_BRANCH env var with default value 'main' to argocd.sh (FR-008)

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - Bootstrap Deploys Infra Apps via ArgoCD (Priority: P1) 🎯 MVP

**Goal**: Fresh k3d cluster gets GitHub credentials and ApplicationSet deployed, all infra apps reach Synced status

**Independent Test**: Run argocd.sh on fresh system, verify vault/prometheus/external-secrets pods running within 5 minutes

### Implementation for User Story 1

- [x] T005 [SYNC] [US1] Add create_github_credential function to argocd.sh — creates kubernetes.io/basic-auth Secret with argocd.argoproj.io/secret-type: repository label using kubectl apply for idempotency (FR-001, FR-002, FR-006)
- [x] T006 [SYNC] [US1] Add deploy_applicationset function to argocd.sh — applies ApplicationSet manifest from infra/argocd-infra/ using kubectl apply for idempotency, with branch override via ARGOCD_INFRA_BRANCH (FR-003, FR-004, FR-006, FR-008)
- [x] T007 [ASYNC] [US1] Integrate create_github_credential and deploy_applicationset calls into argocd.sh main flow after ArgoCD password change, before go-server app deployment (FR-005)
- [x] T008 [ASYNC] [US1] Update --help text in argocd.sh to document GITHUB_TOKEN env var, interactive prompt, and ARGOCD_INFRA_BRANCH option (CHK030)

**Checkpoint**: At this point, User Story 1 should be fully functional — running argocd.sh deploys all infra apps via ArgoCD

---

## Phase 4: User Story 2 - Add New Infra App Without Bootstrap Changes (Priority: P2)

**Goal**: New app registration YAML in infra/argocd-infra/apps/ auto-deploys without argocd.sh changes

**Independent Test**: Add apps/my-app.yaml to infra repo, verify ArgoCD creates Application within sync interval

### Implementation for User Story 2

- [ ] T009 [ASYNC] [US2] Verify ApplicationSet git file generator correctly resolves apps/*.yaml from the infra repo after bootstrap (FR-004)
- [ ] T010 [ASYNC] [US2] Document app registration format (name, repoURL, appPath, namespace) in argocd.sh header comments or a README section
- [ ] T015 [ASYNC] [US2] Validate SC-002: add a test apps/ YAML to infra repo, confirm ArgoCD creates Application within sync interval without argocd.sh changes

**Checkpoint**: At this point, User Stories 1 AND 2 should both work — new apps deploy automatically

---

## Phase 5: User Story 3 - Bootstrap Is Idempotent (Priority: P3)

**Goal**: Running argocd.sh multiple times produces no errors and same final state

**Independent Test**: Run argocd.sh twice consecutively, verify no errors and all resources unchanged

### Implementation for User Story 3

- [ ] T011 [ASYNC] [US3] Validate idempotency — run argocd.sh twice consecutively, confirm no errors and resources match expected state

**Checkpoint**: All user stories should now be independently functional

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [ ] T012 [ASYNC] Run quickstart.md validation scenarios against a fresh cluster
- [ ] T013 [ASYNC] Verify GitHub token is never written to git-tracked files (SC-004, FR-009)
- [ ] T014 [ASYNC] Verify all 5 registered apps are accessible via services after bootstrap (SC-005)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3+)**: All depend on Foundational phase completion
  - User Story 1 (P1): First — core deliverable
  - User Story 2 (P2): After US1 — extends US1 with extensibility
  - User Story 3 (P3): After US1 — validates US1 idempotency
- **Polish (Final Phase)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) — No dependencies on other stories
- **User Story 2 (P2)**: Can start after Foundational (Phase 2) — Extends US1 but independently testable
- **User Story 3 (P3)**: Can start after Foundational (Phase 2) — Validates US1 idempotency

### Within Each User Story

- Implementation before validation
- Core functions before integration
- Story complete before moving to next priority

### Parallel Opportunities

- T001 and T002 (Setup) can run in parallel
- T003 and T004 (Foundational) can run in parallel (different env vars)
- US2 and US3 can run in parallel after US1 completes

---

## Parallel Example: User Story 1

```bash
# T005 and T006 can run in parallel (different functions):
Task: "Add create_github_credential function to argocd.sh"
Task: "Add deploy_applicationset function to argocd.sh"

# T007 depends on T005 and T006:
Task: "Integrate functions into argocd.sh main flow"

# T008 can run in parallel with T007:
Task: "Update --help text"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (env vars)
3. Complete Phase 3: User Story 1 (credential + ApplicationSet)
4. **STOP and VALIDATE**: Run argocd.sh, verify infra apps deploy
5. Demo if ready

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test independently → Deploy/Demo (MVP!)
3. Add User Story 2 → Verify extensibility → Deploy/Demo
4. Add User Story 3 → Verify idempotency → Deploy/Demo
5. Polish → Final validation

---

## Notes

- [P] tasks = different functions/files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
