# Implementation Plan: ArgoCD Install Infra Apps

**Branch**: `008-argocd-install-infra` | **Date**: 2026-08-25 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/008-argocd-install-infra/spec.md`

## Summary

Modify `argocd.sh` to configure ArgoCD with GitHub repository credentials and deploy the `cluster-apps` ApplicationSet from `infra/argocd-infra/`, enabling automatic deployment of all registered infrastructure apps (vault, prometheus, external-secrets) and business apps (familytree, pdf-scan) on cluster bootstrap. Additionally, modularize the script by extracting ESO and Vault setup code into `lib/` modules, removing dead code, fixing security issues, and improving error handling.

## Technical Context

**Language/Version**: Bash (GNU coreutils, kubectl, argocd CLI)

**Primary Dependencies**: kubectl, argocd CLI, k3d, Docker, helm

**Storage**: Kubernetes Secrets (GitHub credential), ArgoCD ApplicationSet CRD

**Testing**: Manual validation via kubectl/argocd CLI commands

**Target Platform**: macOS / Linux (k3d local cluster)

**Project Type**: Infrastructure automation script (bootstrap tooling)

**Performance Goals**: Full bootstrap (cluster + ArgoCD + infra apps) completes within 5 minutes (SC-001, measurement starts at script start)

**Constraints**: ArgoCD in insecure mode (HTTP); GitHub token never in git-tracked files; idempotent execution; non-critical failures log warnings, only critical failures exit

**Scale/Scope**: Single-node k3d cluster; 5 registered apps (3 infra + 2 business); lib/ modules for ESO and Vault

## Constitution Check

**Constitution**: `.specify/memory/constitution.md` (v1.0.2)

| Principle | Compliance | Notes |
|-----------|------------|-------|
| I. Data Must Outlive the Cluster | ✓ | Vault unseal keys stored in K8s secret + host file (`init.json`) |
| II. Repository-Driven Infrastructure | ✓ | All config in git; ApplicationSet reads from repo |
| III. Vault Is the Secret Authority | ✓ | Vault is sole secret authority; ESO syncs from K8s provider |
| IV. Backup Must Be Locally Recoverable | N/A | Bootstrap script, not backup |
| V. Recovery Over Backup | N/A | Bootstrap script, not backup |
| VI. Consistency Over Convenience | ✓ | Vault init/unseal is sequential and deterministic |
| VII. Dependency-Aware Recovery | ✓ | ESO → Vault TLS → Vault init → Vault unseal dependency chain preserved |
| VIII. Minimal Secret Duplication | ✓ | GitHub token in one Secret; Vault unseal keys in one Secret |
| IX. Idempotent Automation | ✓ | kubectl apply, --upsert, helm upgrade --install |
| X. Simple, Explicit Operations | ✓ | Modularize to lib/ without adding new infrastructure |

**No constitution violations.**

## Project Structure

### Documentation (this feature)

```text
specs/008-argocd-install-infra/
├── plan.md              # This file
├── spec.md              # Feature specification
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (N/A - bash script, no external APIs)
└── tasks.md             # Phase 2 output (/spec.tasks)
```

### Source Code (repository root)

```text
argo-bootstrap/
├── argocd.sh            # MODIFIED: add GitHub credential + ApplicationSet + modularize + fix bugs
├── lib/
│   ├── eso.sh           # NEW: ESO Helm install + ArgoCD app creation
│   └── vault.sh         # NEW: Vault init + unseal + status
├── k3d-config.yaml      # UNCHANGED
├── cluster-del.sh       # UNCHANGED
├── reg.sh               # UNCHANGED
├── reg-del.sh           # UNCHANGED
└── k3d-dr/              # UNCHANGED (restore.sh references infra dir separately)
```

**Structure Decision**: Modularize ESO and Vault into `lib/` modules following `k3d-dr/lib/` pattern. Single entry point (`argocd.sh`) sources library files. Dead code removed, security fixed, error handling added.

## Complexity Tracking

No constitution violations to justify.
