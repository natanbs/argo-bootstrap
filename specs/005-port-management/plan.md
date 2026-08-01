# Implementation Plan: Port Management for ArgoCD Apps

**Branch**: `005-port-management` | **Date**: 2026-07-29 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/005-port-management/spec.md`

## Summary

Analyze and document best practices for managing application ports in the ArgoCD/k3d bootstrap environment. Resolve existing port conflicts by patching argocd-server Service ports (8081/8443) instead of Traefik, add HTTPS/TLS termination for argocd-server, make Go app ports configurable via env vars, and document a port allocation table in `argocd.sh` as the single source of truth.

## Technical Context

**Language/Version**: Bash (argocd.sh, reg.sh), Go 1.x (app server), YAML (Kubernetes manifests)  
**Primary Dependencies**: k3d, kubectl, argocd CLI, openssl, Docker, jq  
**Storage**: N/A — configuration-only feature  
**Testing**: Manual verification against local k3d cluster; no automated test framework  
**Target Platform**: macOS / Linux (Docker Desktop or Docker Engine)
**Project Type**: CLI bootstrap script with Kubernetes manifest configuration  
**Performance Goals**: N/A — local dev tooling  
**Constraints**: Registry ports 50000–50004, cluster ports 8081:8081, 8443:8443, 8090:8090  
**Scale/Scope**: Single developer workstation; not production-ha

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Constitution is a placeholder template with no defined principles. No gates to evaluate. Pass.

## Project Structure

### Documentation (this feature)

```text
specs/005-port-management/
├── plan.md              # This file (/spec.plan command output)
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
└── tasks.md             # Phase 2 output (created by /spec.tasks)
```

### Source Code (repository root)

```text
argocd.sh              # Modified: add port conflict detection, TLS bootstrap, port table header; REMOVE Traefik patching, ADD argocd-server Service port patching
argo-ingress.yaml      # Modified: target HTTPS service port 8443, reference TLS Secret
../argo-app-go-server/ # Modified: add PORT env var support
main.go               # Modified: read port from os.Getenv("PORT")
```

**Structure Decision**: Multi-file change across two repos. `argocd.sh` and `argo-ingress.yaml` in the bootstrap repo; `main.go` and Deployment manifest in the app server repo. No new source files needed.

## Triage Framework: [SYNC] vs [ASYNC] Classification

**Execution Strategy**: All tasks are [ASYNC] — single-file edits with clear requirements, no complex architecture, low risk.

### Preliminary Task Classification

| Task Category | Estimated [SYNC] Tasks | Estimated [ASYNC] Tasks | Rationale |
|---------------|----------------------|----------------------|-----------|
| Business Logic | 0 | 6 | All changes are straightforward script/YAML edits |
| Data Operations | 0 | 0 | No data model changes |
| UI Components | 0 | 0 | N/A |
| Integrations | 0 | 0 | No new integrations |
| Infrastructure | 0 | 0 | No infrastructure changes |

### Triage Decision Criteria Applied

**High-Risk [SYNC] Classifications:**

- None — all changes are low-risk, well-defined edits

**Agent-Delegated [ASYNC] Classifications:**

- Add port conflict detection + fallback loop to argocd.sh
- Add TLS bootstrap to argocd.sh (openssl + kubectl create secret)
- Add port table header to argocd.sh
- Patch argocd-server Service ports (8081/8443) instead of Traefik
- Fix argo-ingress.yaml (HTTPS service port 8443 + TLS Secret)
- Add PORT env var support to Go app

### Triage Audit Trail

| Task | Classification | Primary Criteria | Risk Level | Rationale |
|------|----------------|------------------|------------|-----------|
| Port conflict detection + fallback | ASYNC | Simplicity | Low | Clear spec, straightforward bash loop |
| TLS bootstrap | ASYNC | Simplicity | Low | Standard openssl + kubectl workflow |
| Port table header | ASYNC | Simplicity | Low | Documentation-only change |
| Patch argocd-server ports (instead of Traefik) | ASYNC | Simplicity | Low | Simple kubectl patch, no Traefik conflict |
| Fix argo-ingress.yaml | ASYNC | Simplicity | Low | Single port/secret reference change |
| Go app port env var | ASYNC | Simplicity | Low | One-line code change + deployment env var |

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| N/A | — | — |
