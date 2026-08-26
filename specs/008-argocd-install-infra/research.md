# Research: ArgoCD Install Infra Apps

**Feature**: `008-argocd-install-infra`
**Date**: 2026-08-25

## R1: ArgoCD ApplicationSet Git File Generator Pattern

**Decision**: Use ArgoCD ApplicationSet with git file generator reading `apps/*.yaml`

**Rationale**: The existing `infra/argocd-infra/applicationset.yaml` already implements this pattern. Each YAML file provides template variables (name, repoURL, appPath, namespace, syncWave). ArgoCD auto-discovers and creates Applications without script changes.

**Alternatives considered**:
- List generator: Requires explicit app list in ApplicationSet (less extensible)
- Matrix generator: Overkill for single-repo pattern
- Webhook-triggered: Adds complexity; polling is sufficient for local dev

## R2: GitHub Token Handling Pattern

**Decision**: Env var `GITHUB_TOKEN` with interactive prompt fallback

**Rationale**: Follows existing pattern in argocd.sh (lines 17-28). Token is never written to git-tracked files. `.gitignore` covers `.env*`, `*.pem`, `*.key`.

**Alternatives considered**:
- Vault-only: Requires Vault to be running before bootstrap (circular dependency)
- Kubernetes Secret only: Requires cluster to be running first (can't bootstrap)
- Config file: Risk of accidental commit; env var is safer

## R3: ESO + Vault Dependency Chain

**Decision**: 10-step sequential dependency chain preserved

**Rationale**: The chain is: ESO Helm install → ESO ArgoCD app → ClusterSecretStore Ready → vault-tls.sh → placeholder secret → ApplicationSet deploy → vault-tls in vault namespace → vault init → unseal keys → unseal vault-0/1/2. Each step is a hard prerequisite for the next.

**Alternatives considered**:
- Parallel execution: Not possible due to hard dependencies
- Declarative unseal: Requires auto-unseal backend (AWS KMS, GCP Cloud KMS) — overkill for local dev
- Remove ESO: Vault's ExternalSecret depends on it for TLS cert sync

## R4: Script Modularization Pattern

**Decision**: Extract to `lib/eso.sh` and `lib/vault.sh`, following `k3d-dr/lib/` pattern

**Rationale**: The `k3d-dr/lib/` directory has 17 modules with consistent patterns: `set -euo pipefail`, header comments with FR references, function naming convention (`module_action()`). ESO and Vault sections are ~200 lines (40% of script) with clear boundaries.

**Alternatives considered**:
- Separate scripts: Adds coordination overhead; single entry point is simpler
- Full extraction (all functions): Overkill; ESO and Vault are the only large sections
- Crossplane/declarative: Over-engineered for local k3d cluster

## R5: Dead Code Identification

**Decision**: Remove `check_mapped_ports()`, duplicate `VAULT_REPO`, password echo

**Rationale**:
- `check_mapped_ports()`: Called on line 168 but never defined anywhere in the repo. Crashes first run.
- `VAULT_REPO`: Only one definition exists (line 310). The "duplicate" claim was incorrect — verify before removal. If no duplicate exists, T023 can be downgraded to a no-op or removed.
- Password echo: `echo "VERIFIED: Password changed to: $admin_pass"` prints admin password to console/logs.

**Alternatives considered**:
- Keep dead code with comments: Adds confusion; removal is cleaner
- Add `check_mapped_ports()` implementation: Not needed; port checking is handled by k3d

## R6: Error Handling Strategy

**Decision**: `set -euo pipefail` with explicit error handling for critical and non-critical steps

**Rationale**: Constitution Principle IX says "Automation MUST fail clearly rather than silently producing a partially recoverable environment." However, some steps (curl for app list, secondary repo adds) are non-critical and transient failures should be warnings.

**Alternatives considered**:
- `set -e` only: Catches most errors but misses unset variables
- No error mode: Current behavior — silent failures (violates constitution)
- `set -euo pipefail` everywhere: Too strict; causes abort on transient curl failures

## R7: Measurement Start Point for SC-001

**Decision**: Measurement starts at script start

**Rationale**: Reflects the operator's actual experience. Including tool installation, cluster creation, and ArgoCD install in the 5-minute window ensures the script is practical end-to-end.

**Alternatives considered**:
- After ArgoCD install: Excludes cluster creation time; less realistic
- After ApplicationSet apply: Excludes most of the script; not useful for operator experience
