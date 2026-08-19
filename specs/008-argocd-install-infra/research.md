# Research: ArgoCD Install Infra Apps

**Date**: 2026-08-19 | **Feature**: 008-argocd-install-infra

## R1: ArgoCD Repository Credential Secret Format

**Decision**: Use `kubernetes.io/basic-auth` type Secret with `argocd.argoproj.io/secret-type: repository` label.

**Rationale**: This is the standard ArgoCD pattern for repository credentials. The label tells ArgoCD to treat the Secret as a repository credential. The `basic-auth` type stores username and password (PAT) as base64-encoded data fields.

**Alternatives considered**:
- SSH key-based auth: More complex to set up, requires deploy key configuration on GitHub side. Not needed for HTTPS repos.
- ArgoCD CLI `repo add`: Creates the same Secret but via CLI. Using `kubectl apply` directly is more scriptable and idempotent.

## R2: ApplicationSet Branch Targeting

**Decision**: ApplicationSet uses `revision: HEAD` (already in manifest). Override via `ARGOCD_INFRA_BRANCH` env var by patching the manifest before apply.

**Rationale**: The existing `applicationset.yaml` uses `revision: HEAD` which resolves to the default branch. For explicit control, we can `sed`-replace `HEAD` with the target branch before applying.

**Alternatives considered**:
- Fork the ApplicationSet per environment: Overkill for a local dev setup.
- Use ArgoCD ApplicationSet parameter overrides: More complex, not needed for single-cluster.

## R3: Idempotent Secret Creation

**Decision**: Use `kubectl apply` (not `create`). `kubectl apply` is inherently idempotent — creates if not exists, updates if changed.

**Rationale**: Already the pattern used throughout `argocd.sh` for other resources.

**Alternatives considered**:
- `kubectl create --dry-run=client -o yaml | kubectl apply -f -`: More verbose, same result.
- Check-then-create pattern: Race conditions, not idempotent.

## R4: GitHub Token Input Flow

**Decision**: Read `GITHUB_TOKEN` env var; if unset, prompt interactively for username and token using `read -p`.

**Rationale**: Supports both automation (CI/CD with env var) and interactive use (local dev). Matches the existing pattern in `argocd.sh` where `token="${1:-$GITHUB_TOKEN}"` already reads from arg or env var.

**Alternatives considered**:
- Argv-only: Already partially implemented (`$1`), but no interactive fallback.
- Prompt-only: Breaks automation use cases.

## R5: ApplicationSet App Scope

**Decision**: Deploy the ApplicationSet as-is (all 5 registered apps). The spec says "infra apps only" but the ApplicationSet is the single source of truth — filtering would require maintaining a separate manifest.

**Rationale**: The ApplicationSet already registers all apps. Business apps (familytree, pdf-scan) will deploy alongside infra apps. This matches the existing architecture and avoids manifest duplication.

**Alternatives considered**:
- Filter apps at bootstrap time: Requires parsing YAML in bash, fragile.
- Separate ApplicationSet for infra-only: Duplicates the pattern, adds maintenance burden.
