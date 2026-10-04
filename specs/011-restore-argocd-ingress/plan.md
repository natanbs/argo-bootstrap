# Implementation Plan: Restore ArgoCD Ingress

**Branch**: `011-restore-argocd-ingress` | **Date**: Fri Oct 03 2026 | **Spec**: specs/011-restore-argocd-ingress/spec.md
**Input**: Feature specification from `/specs/011-restore-argocd-ingress/spec.md`

**Note**: This template is filled in by the `/spec.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Restore ArgoCD ingress manifest (`argo-ingress.yaml` in repo root) so `http://argocd.lab/` routes via Traefik to `argocd-server` in namespace `argocd` using plain HTTP (matching sibling repo conventions and existing cluster setup with `server.insecure=true`). No changes to bootstrap flow beyond ensuring the manifest exists and is applied as part of normal cluster bootstrap.

## Technical Context

<!--
  ACTION REQUIRED: Replace the content in this section with the technical details
  for the project. The structure here is presented in advisory capacity to guide
  the iteration process.
-->

**Language/Version**: YAML (Kubernetes manifests)  
**Primary Dependencies**: Kubernetes 1.32+, Traefik ingress controller (bundled with k3s/k3d), ArgoCD  
**Storage**: N/A  
**Testing**: curl/HTTP validation against `http://argocd.lab/`  
**Target Platform**: k3d/k3s cluster (local)  
**Project Type**: Infrastructure-as-Code / bootstrap manifests  
**Performance Goals**: < 2s response for ArgoCD UI over HTTP  
**Constraints**: Must follow sibling repo Traefik conventions; preserve existing Service LoadBalancer on 8081/8443; use plain HTTP (no TLS redirect)  
**Scale/Scope**: Single ingress for ArgoCD in local dev cluster

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. Data Must Outlive the Cluster**: No data impact; only routing/config manifest. ✓
- **II. Repository-Driven Infrastructure**: Manifest lives in repo and is reproducible; no runtime-only state. ✓
- **III. Vault Is the Secret Authority**: No secrets involved. ✓
- **IV. Backup Must Be Locally Recoverable**: Not applicable (config only). ✓
- **V. Recovery Over Backup**: Bootstrap reproduces manifest; contributes to deterministic rebuild. ✓
- **VI. Consistency Over Convenience**: Follows established sibling conventions; explicit manifest. ✓
- **VII. Dependency-Aware Recovery**: ArgoCD must exist before ingress is meaningful; bootstrap order unchanged (ArgoCD installed, then ingress applied). ✓
- **VIII. Minimal Secret Duplication**: No secrets. ✓
- **IX. Idempotent Automation**: `kubectl apply` is idempotent; manifest is declarative. ✓
- **X. Simple, Explicit Operations**: Single YAML manifest, minimal change. ✓

All gates pass.

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/spec.plan command output)
├── research.md          # Phase 0 output (/spec.plan command)
├── data-model.md        # Phase 1 output (/spec.plan command)
├── quickstart.md        # Phase 1 output (/spec.plan command)
├── contracts/           # Phase 1 output (/spec.plan command)
└── tasks.md             # Phase 2 output (/spec.tasks command - NOT created by /spec.plan)
```

### Source Code (repository root)
<!--
  ACTION REQUIRED: Replace the placeholder tree below with the concrete layout
  for this feature. Delete unused options and expand the chosen structure with
  real paths (e.g., apps/admin, packages/something). The delivered plan must
  not include Option labels.
-->

```text
# [REMOVE IF UNUSED] Option 1: Single project (DEFAULT)
src/
├── models/
├── services/
├── cli/
└── lib/

tests/
├── contract/
├── integration/
└── unit/

# [REMOVE IF UNUSED] Option 2: Web application (when "frontend" + "backend" detected)
backend/
├── src/
│   ├── models/
│   ├── services/
│   └── api/
└── tests/

frontend/
├── src/
│   ├── components/
│   ├── pages/
│   └── services/
└── tests/

# [REMOVE IF UNUSED] Option 3: Mobile + API (when "iOS/Android" detected)
api/
└── [same as backend above]

```

**Structure Decision**: This is a simple infrastructure manifest addition; no new source code modules. The only change is restoring `argo-ingress.yaml` in the repo root. `argocd.sh` remains unchanged; the manifest will be applied during bootstrap (as in sibling repos pattern).

## Triage Framework: [SYNC] vs [ASYNC] Classification

**Execution Strategy**: This feature will use a hybrid execution model combining human expertise ([SYNC]) with autonomous agent delegation ([ASYNC]).

### Preliminary Task Classification

Complete during planning phase - will be validated and refined during task generation

| Task Category | Estimated [SYNC] Tasks | Estimated [ASYNC] Tasks | Rationale |
|---------------|----------------------|----------------------|-----------|
| Business Logic | [count] | [count] | [why this split] |
| Data Operations | [count] | [count] | [why this split] |
| UI Components | [count] | [count] | [why this split] |
| Integrations | [count] | [count] | [why this split] |
| Infrastructure | [count] | [count] | [why this split] |

### Triage Decision Criteria Applied

**High-Risk [SYNC] Classifications:**
- None (single YAML manifest, low-risk infrastructure change)

**Agent-Delegated [ASYNC] Classifications:**
- Manifest creation, validation (linting/YAML syntax), basic smoke test

### Triage Audit Trail

| Task | Classification | Primary Criteria | Risk Level | Rationale |
|------|----------------|------------------|------------|-----------|
| Create argo-ingress.yaml | ASYNC | Standard, repetitive YAML following established template | Low | Well-defined pattern from siblings; no business logic |
| Validate manifest syntax | ASYNC | Deterministic validation | Low | kubectl/HTTP checks are mechanical |
| Smoke test via curl | ASYNC | Deterministic test | Low | Verifies end-to-end HTTP routing |

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| None | - | - |
