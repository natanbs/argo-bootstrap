# Tasks: ArgoCD Install Infra Apps

**Input**: Design documents from `/specs/008-argocd-install-infra/`

**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [SYNC/ASYNC] [Story?] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[SYNC]**: Requires human review (complex logic, security-critical)
- **[ASYNC]**: Can be delegated (well-defined, repetitive tasks)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4)
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

**Independent Test**: Add apps/my-app.yaml to infra repo, verify ArgoCD creates Application within 5 minutes

### Implementation for User Story 2

- [x] T009 [ASYNC] [US2] Verify ApplicationSet git file generator correctly resolves apps/*.yaml from the infra repo after bootstrap (FR-004)
- [x] T010 [ASYNC] [US2] Document app registration format (name, repoURL, appPath, namespace) in argocd.sh header comments (CHK030)
- [x] T015 [ASYNC] [US2] Validate SC-002: add a test apps/ YAML to infra repo, confirm ArgoCD creates Application within 5 minutes without argocd.sh changes

**Checkpoint**: At this point, User Stories 1 AND 2 should both work — new apps deploy automatically

---

## Phase 5: User Story 3 - Bootstrap Is Idempotent (Priority: P3)

**Goal**: Running argocd.sh multiple times produces no errors and same final state

**Independent Test**: Run argocd.sh twice consecutively, verify no errors and all resources unchanged

### Implementation for User Story 3

- [x] T011 [ASYNC] [US3] Validate idempotency — run argocd.sh twice consecutively, confirm no errors and resources match expected state

**Checkpoint**: All user stories should now be independently functional

---

## Phase 6: User Story 4 - Modularize Bootstrap Script (Priority: P2)

**Goal**: ESO and Vault setup code extracted into `lib/` modules, following `k3d-dr/lib/` pattern

**Independent Test**: Run argocd.sh on fresh system, verify all functionality works identically to monolithic version

**Reference**: `k3d-dr/lib/vault.sh` for module pattern (set -euo pipefail, header comments with FR references, function naming convention)

### Implementation for User Story 4

- [x] T017 [SYNC] [US4] Create `lib/eso.sh` — extract ESO Helm install + ArgoCD app creation + ClusterSecretStore wait into functions: `install_eso_helm()`, `create_eso_argocd_app()`, `wait_for_cluster_secret_store()` with `set -euo pipefail`, header comments referencing FR-011, function export (FR-011)
- [x] T018 [SYNC] [US4] Create `lib/vault.sh` — extract vault TLS secret creation + unseal placeholder + vault init + unseal vault-0/1/2 into functions: `create_vault_tls_secret()`, `create_vault_unseal_placeholder()`, `wait_for_vault_tls()`, `init_vault()`, `unseal_vault()`, `verify_vault_status()` with `set -euo pipefail`, header comments referencing FR-011 (FR-011)
- [x] T019 [ASYNC] [US4] Source lib/eso.sh and lib/vault.sh from argocd.sh — add `SCRIPT_DIR` detection and `source` calls at top of script, invoke extracted functions in correct dependency order in main flow (FR-011)
- [x] T020 [ASYNC] [US4] Remove extracted ESO/Vault code from argocd.sh — ESO and Vault code removed after verifying sourced functions produce identical behavior (FR-011)
- [x] T021 [SYNC] [US4] Add module-name error reporting — when library function fails, prefix error message with `[eso]` or `[vault]` for easy debugging (US4 Acceptance Scenario 2)

**Checkpoint**: Script is modularized — ESO and Vault code in lib/, single entry point preserved

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories — dead code removal, error handling, security fixes

### FR-012: Dead Code Removal

- [x] T022 [ASYNC] Remove undefined `check_mapped_ports()` call from argocd.sh line 168 — function is called but never defined, crashes first run (FR-012, R5)
- [x] T023 [ASYNC] Verify `VAULT_REPO` definition count in argocd.sh — if only one definition exists (expected), mark as no-op and close (FR-012, R5)
- [x] T024 [SYNC] Remove password echo from argocd.sh line 245 — `echo "VERIFIED: Password changed to: $admin_pass"` prints admin password to console/logs, security risk (FR-012, R5)

### FR-010: Error Handling — Warnings for Non-Critical Steps

- [x] T025 [SYNC] Add warning-based error handling for non-critical steps — curl for app list (line 258), secondary repo adds (line 263-271) should log WARNING and continue, not exit (FR-010, R6)
- [x] T026 [ASYNC] Add explicit exit-on-critical-failure guards — wrap cluster creation (k3d cluster create), ArgoCD install (kubectl apply), vault init, vault unseal in error checks that call `exit 1` on failure (FR-010, R6)

### FR-013: Strict Error Mode

- [x] T027 [SYNC] Add `set -euo pipefail` to argocd.sh — add after header comments/before first executable code; add explicit `|| true` or `|| { echo "WARNING: ..."; }` for steps that may legitimately fail (curl, kubectl get) (FR-013, R6)

### Validation

- [x] T012 [ASYNC] Run quickstart.md validation scenarios against a fresh cluster — verify all 6 scenarios pass
- [x] T013 [ASYNC] Verify GitHub token is never written to git-tracked files (SC-004, FR-009)
- [x] T014 [ASYNC] Verify all 5 registered apps are accessible via services after bootstrap (SC-005) — Vault:8200, Prometheus:9090

### Convergence

- [x] T016 [ASYNC] Add app registration format documentation (name, repoURL, appPath, namespace) to argocd.sh header comments per T010 (partial)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion — BLOCKS all user stories
- **User Stories (Phase 3+)**: All depend on Foundational phase completion
  - User Story 1 (P1): First — core deliverable
  - User Story 2 (P2): After US1 — extends US1 with extensibility
  - User Story 3 (P3): After US1 — validates US1 idempotency
  - User Story 4 (P2): After US1 — modularization preserves existing behavior
- **Polish (Phase 7)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) — No dependencies on other stories
- **User Story 2 (P2)**: Can start after Foundational (Phase 2) — Extends US1 but independently testable
- **User Story 3 (P3)**: Can start after Foundational (Phase 2) — Validates US1 idempotency
- **User Story 4 (P2)**: Can start after US1 complete — Modularization preserves existing behavior

### Within Each User Story

- Implementation before validation
- Core functions before integration
- Story complete before moving to next priority

### Parallel Opportunities

- T001 and T002 (Setup) can run in parallel
- T003 and T004 (Foundational) can run in parallel (different env vars)
- T017 and T018 (US4 lib creation) can run in parallel (different files)
- T022, T023, T024 (dead code removal) can run in parallel (different lines)
- US2 and US3 can run in parallel after US1 completes

---

## Parallel Example: User Story 4

```bash
# T017 and T018 can run in parallel (different files):
Task: "Create lib/eso.sh with ESO functions"
Task: "Create lib/vault.sh with Vault functions"

# T019 depends on T017 and T018:
Task: "Source lib/ modules from argocd.sh"

# T020 depends on T019:
Task: "Remove extracted code from argocd.sh"

# T021 depends on T020:
Task: "Add module-name error reporting"
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
5. Add User Story 4 → Verify modularization → Deploy/Demo
6. Polish → Final validation (dead code, error handling, security)

---

## Notes

- [P] tasks = different functions/files, no dependencies
- [SYNC] tasks = complex logic, security-critical, requires human review
- [ASYNC] tasks = well-defined, repetitive, can be delegated
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
