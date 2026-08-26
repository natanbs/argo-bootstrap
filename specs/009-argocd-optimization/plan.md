# Implementation Plan: ArgoCD Script Optimization

**Branch**: `009-argocd-optimization` | **Date**: 2026-08-25 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/009-argocd-optimization/spec.md`

## Summary

Simplify and optimize the `argocd.sh` bootstrap script by removing dead code, fixing security issues, and improving reliability while maintaining all existing functionality.

## Technical Context

**Language/Version**: Bash (GNU coreutils, kubectl, argocd CLI)

**Primary Dependencies**: kubectl, argocd CLI, k3d, Docker

**Storage**: Kubernetes Secrets (GitHub credential), ArgoCD ApplicationSet CRD

**Testing**: Manual validation via kubectl/argocd CLI commands

**Target Platform**: macOS / Linux (k3d local cluster)

**Project Type**: Infrastructure automation script (bootstrap tooling)

**Performance Goals**: No performance regression; script should run faster due to removed dead code

**Constraints**: ArgoCD in insecure mode (HTTP); GitHub token never in git-tracked files; idempotent execution

**Scale/Scope**: Single-node k3d cluster; 5 registered apps (3 infra + 2 business)

## Constitution Check

*GATE: No constitution file found at `.specify/memory/constitution.md` — skipping constitution gate.*

## Project Structure

### Documentation (this feature)

```text
specs/009-argocd-optimization/
├── plan.md              # This file
├── spec.md              # Feature specification
└── tasks.md             # Implementation tasks
```

### Source Code (repository root)

```text
argo-bootstrap/
├── argocd.sh            # MODIFIED: remove dead code, fix security, simplify
├── k3d-config.yaml      # UNCHANGED
├── cluster-del.sh       # UNCHANGED
├── reg.sh               # UNCHANGED
├── reg-del.sh           # UNCHANGED
└── k3d-dr/              # UNCHANGED
```

**Structure Decision**: Single file modification to `argocd.sh`. No new files, no restructure. The optimization is a cleanup of the existing script.

## Complexity Tracking

No constitution violations to justify.

## Implementation Strategy

### Phase 1: Remove Dead Code

1. Remove duplicate `VAULT_REPO` definition (line 332)
2. Remove unused `MAPPED_PORTS` and `check_mapped_ports()` (lines 139-148)
3. Remove unnecessary empty lines (lines 114-117)

### Phase 2: Fix Security Issues

1. Remove `echo $init_pass` (line 229)

### Phase 3: Simplify Code

1. Simplify `port_in_use()` to use `lsof` only (remove `ss` command)
2. Update `--help` text to accurately describe `GITHUB_TOKEN` env var
3. Remove arbitrary `sleep 30` (line 232) if health check is sufficient

### Phase 4: Improve Error Handling

1. Add error handling for curl commands (lines 125, 275, 277-283)

### Phase 5: Verify Functionality

1. Run `argocd.sh` on a fresh cluster
2. Verify all 3 vault pods are Running and Ready=True
3. Verify all 5 registered apps deploy successfully

## Risk Assessment

- **Low Risk**: Removing dead code (no functional impact)
- **Low Risk**: Fixing security issues (password not printed)
- **Medium Risk**: Simplifying code (may affect edge cases)
- **Medium Risk**: Improving error handling (may change error behavior)

## Rollback Plan

If optimization causes issues:
1. Revert to previous version of `argocd.sh`
2. Re-run script on fresh cluster
3. Verify all functionality works

## Success Metrics

- All dead code removed
- Security issues fixed
- Code simplified
- All 3 vault pods Running and Ready=True
- All 5 registered apps deployed successfully
- Script runs without errors
