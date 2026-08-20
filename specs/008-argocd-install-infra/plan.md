# Implementation Plan: ArgoCD Install Infra Apps

**Branch**: `008-argocd-install-infra` | **Date**: 2026-08-19 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/008-argocd-install-infra/spec.md`

## Summary

Modify `argocd.sh` to configure ArgoCD with GitHub repository credentials and deploy the `cluster-apps` ApplicationSet from `infra/argocd-infra/`, enabling automatic deployment of all registered infrastructure apps (vault, prometheus, external-secrets) and business apps (familytree, pdf-scan) on cluster bootstrap.

## Technical Context

**Language/Version**: Bash (GNU coreutils, kubectl, argocd CLI)

**Primary Dependencies**: kubectl, argocd CLI, k3d, Docker

**Storage**: Kubernetes Secrets (GitHub credential), ArgoCD ApplicationSet CRD

**Testing**: Manual validation via kubectl/argocd CLI commands

**Target Platform**: macOS / Linux (k3d local cluster)

**Project Type**: Infrastructure automation script (bootstrap tooling)

**Performance Goals**: Full bootstrap (cluster + ArgoCD + infra apps) completes within 10 minutes

**Constraints**: ArgoCD in insecure mode (HTTP); GitHub token never in git-tracked files; idempotent execution

**Scale/Scope**: Single-node k3d cluster; 5 registered apps (3 infra + 2 business)

## Constitution Check

*GATE: No constitution file found at `.specify/memory/constitution.md` — skipping constitution gate.*

## Project Structure

### Documentation (this feature)

```text
specs/008-argocd-install-infra/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (N/A - no external APIs)
└── tasks.md             # Phase 2 output (/spec.tasks)
```

### Source Code (repository root)

```text
argo-bootstrap/
├── argocd.sh            # MODIFIED: add GitHub credential + ApplicationSet deployment
├── k3d-config.yaml      # UNCHANGED
├── cluster-del.sh       # UNCHANGED
├── reg.sh               # UNCHANGED
├── reg-del.sh           # UNCHANGED
└── k3d-dr/              # UNCHANGED (restore.sh references infra dir separately)
```

**Structure Decision**: Single file modification to `argocd.sh`. No new files, no restructure. The bootstrap is a single script.

## Complexity Tracking

No constitution violations to justify.
