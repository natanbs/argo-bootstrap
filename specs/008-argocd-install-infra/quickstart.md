# Quickstart: ArgoCD Install Infra Apps

**Feature**: `008-argocd-install-infra`
**Date**: 2026-08-25

## Prerequisites

- Docker Desktop or Docker Engine running
- k3d installed (auto-installed by script if missing)
- kubectl installed (auto-installed by script if missing)
- argocd CLI installed (auto-installed by script if missing)
- Network access to GitHub (for repo cloning)
- GitHub personal access token (classic PAT with `repo` scope)

## Validation Scenarios

### Scenario 1: Fresh Bootstrap (SC-001)

**Goal**: All registered apps reach Synced status within 5 minutes

**Steps**:
1. Delete existing cluster: `k3d cluster delete cluster-argo`
2. Delete existing registry: `k3d registry delete k3d-reg`
3. Run bootstrap: `./argocd.sh`
4. Wait for completion
5. Verify all apps: `argocd app list`

**Expected Outcome**:
- All 5 apps show `Synced` status
- All pods are Running in their respective namespaces
- Total time < 5 minutes from script start

**Verification Commands**:
```bash
# Check app status
argocd app list

# Check pod status
kubectl get pods -n external-secrets
kubectl get pods -n vault
kubectl get pods -n monitoring
kubectl get pods -n apps-ns

# Check Vault accessibility
kubectl port-forward -n vault svc/vault 8200:8200 &
curl -s http://localhost:8200/v1/sys/health

# Check Prometheus accessibility
kubectl port-forward -n monitoring svc/prometheus 9090:9090 &
curl -s http://localhost:9090/api/v1/status/config
```

### Scenario 2: Add New App (SC-002)

**Goal**: New app YAML auto-deploys within 5 minutes

**Steps**:
1. Ensure bootstrap is complete (Scenario 1 passed)
2. Create test app YAML in infra repo:
   ```bash
   # On GitHub, create apps/test-app.yaml with:
   # name: test-app
   # repoURL: https://github.com/natanbs/external-secrets.git
   # appPath: .
   # namespace: test-ns
   ```
3. Wait 5 minutes
4. Check ArgoCD: `argocd app list`

**Expected Outcome**:
- `test-app` appears in ArgoCD app list
- Application shows `Synced` status
- Pods running in `test-ns` namespace

**Cleanup**:
```bash
# Delete test app YAML from GitHub
# Wait for ArgoCD to prune the Application
argocd app delete test-app --cascade
kubectl delete namespace test-ns
```

### Scenario 3: Idempotent Execution (SC-003)

**Goal**: Running twice produces no errors

**Steps**:
1. Run bootstrap: `./argocd.sh`
2. Wait for completion
3. Run bootstrap again: `./argocd.sh`
4. Check exit code: `echo $?`

**Expected Outcome**:
- Second run completes without errors
- Exit code is 0
- All resources in same state as after first run

### Scenario 4: Token Security (SC-004)

**Goal**: GitHub token never written to git-tracked files

**Steps**:
1. Run bootstrap
2. Check git status: `git status`
3. Check .gitignore: `cat .gitignore`

**Expected Outcome**:
- No `.env` or token files appear in `git status`
- `.gitignore` contains `.env*`, `*.pem`, `*.key`, `kubeconfig*`

### Scenario 5: Modularized Script (US-4)

**Goal**: ESO and Vault code extracted to lib/ modules

**Steps**:
1. Check lib/ directory exists: `ls lib/`
2. Verify `lib/eso.sh` contains ESO functions
3. Verify `lib/vault.sh` contains Vault functions
4. Run bootstrap: `./argocd.sh`
5. Verify all functionality works identically

**Expected Outcome**:
- `lib/eso.sh` and `lib/vault.sh` exist
- Functions are invoked in correct dependency order
- Error messages include module name
- All apps deploy successfully

### Scenario 6: Dead Code Removal (FR-012)

**Goal**: No undefined functions or duplicate definitions

**Steps**:
1. Search for `check_mapped_ports`: `grep -r "check_mapped_ports" argocd.sh`
2. Search for duplicate `VAULT_REPO`: `grep -c "VAULT_REPO=" argocd.sh`
3. Search for password echo: `grep -n "echo.*admin_pass" argocd.sh`

**Expected Outcome**:
- No `check_mapped_ports` references
- `VAULT_REPO=` appears exactly once
- No `echo` statements printing password variables

## Success Criteria Verification

| SC | Criterion | Verification |
|----|-----------|--------------|
| SC-001 | All apps Synced within 5 min | `argocd app list` shows all 5 apps Synced; timer < 5 min |
| SC-002 | New app deploys within 5 min | Add YAML to `apps/`, verify Application created |
| SC-003 | Idempotent execution | Run twice, verify no errors, same final state |
| SC-004 | Token not in git | `git status` shows no token files; `.gitignore` covers patterns |
| SC-005 | Vault:8200, Prometheus:9090 accessible | Port-forward + curl verification |
