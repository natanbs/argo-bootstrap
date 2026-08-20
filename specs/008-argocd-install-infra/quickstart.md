# Quickstart Validation: ArgoCD Install Infra Apps

**Date**: 2026-08-19 | **Feature**: 008-argocd-install-infra

## Prerequisites

- k3d, kubectl, argocd CLI installed
- GitHub personal access token with repo read access
- `infra` repo available (ApplicationSet references `github.com/natanbs/argocd-infra.git`)

## Validation Steps

### 1. Fresh Bootstrap

```bash
./argocd.sh
```

**Expected**: All steps complete without errors. Script exits 0.

### 2. GitHub Credential Check

```bash
kubectl get secret github-repo-cred -n argocd -o yaml
```

**Expected**: Secret exists with:
- `type: kubernetes.io/basic-auth`
- Label `argocd.argoproj.io/secret-type: repository`
- Data fields `username` and `password` (base64-encoded)

### 3. ApplicationSet Check

```bash
kubectl get applicationset cluster-apps -n argocd -o yaml
```

**Expected**: ApplicationSet exists with:
- Git generator pointing to `argocd-infra` repo
- `files: [apps/*.yaml]`
- Sync options: `CreateNamespace=true`, `ServerSideApply=true`

### 4. Applications Check

```bash
kubectl get applications -n argocd
```

**Expected**: 5 Applications listed:
| Name | Sync Status | Health |
|------|-------------|--------|
| vault | Synced | Healthy |
| prometheus | Synced | Healthy |
| external-secrets | Synced | Healthy |
| familytree | Synced | Healthy |
| pdf-scan | Synced | Healthy |

### 5. Idempotency Check

```bash
./argocd.sh
```

**Expected**: No errors on second run. All resources unchanged.

### 6. Branch Override Check

```bash
ARGOCD_INFRA_BRANCH=main ./argocd.sh
```

**Expected**: ApplicationSet targets `main` branch (verify via `kubectl get applicationset cluster-apps -n argocd -o jsonpath='{.spec.generators[0].git.revision}'`).

### 7. Token Not in Git

```bash
git log --all --oneline -- '*.sh' '*.yaml' | head -20
grep -r "ghp_\|github_pat_" . || echo "No tokens found"
```

**Expected**: No GitHub tokens visible in any committed file.
