# Tasks: Restore ArgoCD Ingress

Feature: Restore ArgoCD Ingress  
Branch: 011-restore-argocd-ingress  
Spec: specs/011-restore-argocd-ingress/spec.md  
Plan: specs/011-restore-argocd-ingress/plan.md

## Task Classification
All tasks classified per dual-execution model. This is a simple manifest task - minimal risk.

## Phase 1: Setup (Project Initialization)
- [ ] T001 [ASYNC] Review sibling examples and confirm final ingress manifest format in `argo-ingress.yaml`

## Phase 2: Foundational (Blocking Prerequisites)
- None (no foundational blocking code changes required)

## Phase 3: User Story 1 - Access ArgoCD via HTTP Ingress (Priority: P1) 
**Goal**: Restore ArgoCD Ingress so http://argocd.lab/ routes via Traefik to argocd-server:8081 using plain HTTP

**Independent Test**: curl -i -H "Host: argocd.lab" http://127.0.0.1/ returns 200 OK with ArgoCD login UI

### Tests (if needed) - [ASYNC/optional per mode; but straightforward]
- [ ] T002 [P] [ASYNC] [US1] Create/restore `argo-ingress.yaml` at repo root following contract in `specs/011-restore-argocd-ingress/contracts/ingress-contract.yaml`

### Implementation Tasks
- [ ] T003 [P] [ASYNC] [US1] Write `argo-ingress.yaml` with Traefik annotations for plain HTTP (router.entrypoints=web, router.tls=false), ingressClassName traefik, host argocd.lab, backend to argocd-server:8081

### Integration & Validation
- [ ] T004 [ASYNC] [US1] Validate manifest syntax: `kubectl --dry-run=client apply -f argo-ingress.yaml`
- [ ] T005 [ASYNC] [US1] Apply manifest to cluster (if running): `kubectl apply -f argo-ingress.yaml`
- [ ] T006 [ASYNC] [US1] Verify via curl: `curl -i -H "Host: argocd.lab" http://127.0.0.1/` and confirm access

**Checkpoint**: US1 complete - argocd.lab reachable via ingress

## Phase 4: User Story 2 - Preserve direct port access (Priority: P2)
**Goal**: Ensure existing LoadBalancer access on 8081/8443 remains functional
- [ ] T007 [ASYNC] [US2] Verify 8081/8443 direct access still works after ingress applied (no service changes)

**Checkpoint**: US2 complete

## Phase 5: User Story 3 - Bootstrap reproducibility (Priority: P3)
**Goal**: Ensure manifest is present and reproducible
- [ ] T008 [ASYNC] [US3] Confirm argocd.sh behavior unchanged; manifest exists for future bootstraps

**Checkpoint**: US3 complete

## Phase 6: Polish & Cross-Cutting Concerns
- [ ] T009 [ASYNC] Update docs if needed (quickstart.md already covers validation)
- [ ] T010 [ASYNC] Run final verification per quickstart

## Dependencies
- US1 (P1) must complete before US2, US3 can be verified in parallel context but listed sequentially
- T002-T003 in US1 produce the manifest consumed by validation

## Parallel Execution Examples
- US1: T002, T003 can run in parallel (different concerns - review vs write; but write is the action)
- After T003: T004-T006 validation steps are sequential in practice

## MVP Scope
MVP is User Story 1 only (T002-T006). Others are nice-to-have verifications.
