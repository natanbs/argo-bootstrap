# Tasks: Port Management for ArgoCD Apps

**Input**: Design documents from `/specs/005-port-management/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: No automated tests requested — manual verification via bootstrap script and curl.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Path Conventions

- **Bootstrap repo**: `argocd.sh`, `argo-ingress.yaml` at repository root (`/Users/natan/projects/argo-bootstrap/`)
- **App server repo**: `main.go`, `go-server-deploy.yaml` at `/Users/natan/projects/argo-app-go-server/`

## Phase 1: Setup (Review & Preparation)

**Purpose**: Review existing code and prepare for edits

- [ ] T001 [P] [ASYNC] Review current `argocd.sh` port-related logic — document all port mappings, Traefik patch, registry creation, k3d `--port` flags
- [ ] T002 [P] [ASYNC] Review current `argo-ingress.yaml` — note incorrect port 8080 and missing TLS Secret reference
- [ ] T003 [P] [ASYNC] Review Go app `main.go` at `/Users/natan/projects/argo-app-go-server/main.go` — confirm hardcoded port 8090

---

## Phase 2: Foundational (None Required)

**Purpose**: No blocking prerequisites — all changes are independent file edits.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

All user story tasks are independent and can proceed in any order. No foundational phase needed.

**Checkpoint**: Ready to implement user stories in priority order

---

## Phase 3: User Story 1 - Developer resolves port conflicts when bootstrapping ArgoCD (Priority: P1) 🎯 MVP

**Goal**: Modify `argocd.sh` so the bootstrap process avoids port conflicts by patching argocd-server Service ports (8081/8443) instead of Traefik, and add port conflict detection with clear error messages.

**Independent Test**: Run `./argocd.sh` on a clean system — all services reachable at expected ports (8081 HTTP, 8443 HTTPS, 8090 Go app). Traefik untouched on 80/443.

### Implementation for User Story 1

- [ ] T004 [ASYNC] [US1] Add port conflict detection function in `argocd.sh` — use `lsof -i :<port>` (macOS) / `ss -tln` (Linux) to check all mapped ports before binding
- [ ] T005 [P] [ASYNC] [US1] Add registry port fallback loop in `argocd.sh` — iterate through ports 50000–50004 when the registry port is in use
- [ ] T006 [P] [ASYNC] [US1] Replace Traefik port patching with argocd-server Service port patching in `argocd.sh` — patch argocd-server ports from 80/443 to 8081/8443 using `kubectl patch svc argocd-server -n argocd --type='json'`
- [ ] T007 [ASYNC] [US1] Update k3d cluster `--port` flags in `argocd.sh` — change from `--port '8081:80@loadbalancer'` and `--port '8443:443@loadbalancer'` to `--port '8081:8081@loadbalancer'` and `--port '8443:8443@loadbalancer'`
- [ ] T008 [ASYNC] [US1] Remove the Traefik port patching line (contains `kubectl patch svc traefik -n kube-system`) from `argocd.sh` — no longer needed
- [ ] T009 [ASYNC] [US1] Add TLS bootstrap block to `argocd.sh` — generate self-signed cert via openssl, create TLS Secret in argocd namespace via `kubectl create secret tls`
- [ ] T010 [ASYNC] [US1] Update `argo-ingress.yaml` — change target port from 8080 to 8443, reference TLS Secret `argocd-tls`

**Checkpoint**: At this point, User Story 1 should be fully functional and testable independently

---

## Phase 4: User Story 2 - New app added without port collisions (Priority: P2)

**Goal**: Document the port allocation table as a header comment in `argocd.sh`, serving as the single source of truth.

**Independent Test**: A developer can review the header of `argocd.sh` and identify all port assignments for the cluster.

### Implementation for User Story 2

- [ ] T011 [ASYNC] [US2] Add port allocation table header comment at the top of `argocd.sh` — list all services, host ports, cluster ports, service ports, container ports, TLS status, and defining files
- [ ] T012 [ASYNC] [US2] Add reserved port ranges comment to the allocation table in `argocd.sh` — document 8081, 8443, 8090 for apps; 50000–50004 for registry fallback

**Checkpoint**: At this point, User Story 2 should be functional alongside User Story 1

---

## Phase 5: User Story 3 - Operator changes an app's exposed port without rebuild (Priority: P3)

**Goal**: Make the Go server port configurable via `PORT` environment variable so port changes don't require a container rebuild.

**Independent Test**: Deploy Go app with `PORT=9090` env var — app listens on 9090 instead of default 8090.

### Implementation for User Story 3

- [ ] T013 [ASYNC] [US3] Modify `/Users/natan/projects/argo-app-go-server/main.go` — read `PORT` env var via `os.Getenv("PORT")`, default to "8090" if unset; use the env var value in `http.ListenAndServe`
- [ ] T014 [ASYNC] [US3] Add `PORT` environment variable to the Go app Deployment manifest at `/Users/natan/projects/argo-app-go-server/go-server-deploy.yaml` — add env entry under `spec.template.spec.containers[0].env`

**Checkpoint**: All user stories should now be independently functional

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final cleanup and validation

- [ ] T015 [P] [ASYNC] Validate `argo-ingress.yaml` — confirm port 8443 and `tls` section with `secretName: argocd-tls` are correctly configured
- [ ] T016 [ASYNC] Run quickstart.md verification steps: bootstrap cluster, curl HTTP/HTTPS endpoints, verify Go app responds

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately (review tasks run in parallel)
- **Foundational (Phase 2)**: Empty — no blocking prerequisites
- **User Story 1 (Phase 3)**: Can start after Setup review — no dependencies on other stories
- **User Story 2 (Phase 4)**: Can start after Setup review — no dependencies on other stories
- **User Story 3 (Phase 5)**: Can start after Setup review — no dependencies on other stories
- **Polish (Phase 6)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: No dependencies on other stories — independent
- **User Story 2 (P2)**: No dependencies on other stories — independent
- **User Story 3 (P3)**: No dependencies on other stories — independent

### Within Each User Story

- Reviews before implementation
- Simple script edits, no ordering constraints within a story

### Parallel Opportunities

- All Setup tasks (T001–T003) can run in parallel
- T004, T008, T009 (argocd.sh edits) must be sequential within the same file
- T005 and T006 can run in parallel (different sections of argocd.sh)
- T011 and T012 (both argocd.sh header) are sequential
- All user stories are completely independent and can run in parallel

---

## Parallel Example: User Story 1

```bash
# argocd.sh edits that touch different sections:
Task: "Add port conflict detection function" (T004)
Task: "Add registry fallback loop" (T005 — in registry section)
Task: "Replace Traefik patch with argocd-server patch" (T006 — in k8s patch section)
Task: "Update k3d --port flags" (T007 — in cluster creation section)
Task: "Remove Traefik patch line" (T008 — near end of script)
Task: "Add TLS bootstrap" (T009 — after ArgoCD install)
```

Note: Since most edits touch `argocd.sh`, they should be applied sequentially or via overlapping edits to avoid conflicts.

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup — review all files
2. Complete Phase 3: User Story 1 — port conflict resolution, TLS, ingress fix
3. **STOP and VALIDATE**: Run `./argocd.sh` — verify ArgoCD at localhost:8081, HTTPS at localhost:8443, Go app at localhost:8090
4. Deploy/demo if ready

### Incremental Delivery

1. Complete Phase 1: Setup → Understanding of existing code
2. Add User Story 1 → Bootstrap runs cleanly (MVP!)
3. Add User Story 2 → Port table documented
4. Add User Story 3 → Go app port configurable
5. Each story adds value without breaking previous stories

---

## Notes

- [P] tasks = different files, no dependencies
- [ASYNC] tasks = can be delegated to async agents (well-defined, clear specs)
- [US1/2/3] label maps task to specific user story for traceability
- All edits are to existing files — no new files needed
- Manual testing via curl/bootstrap — no automated test framework
- Verify after each user story before proceeding to next
