# Quickstart Validation: Declarative Bootstrap Migration

## Prerequisites

- k3d cluster created: `k3d cluster create --config k3d-config.yaml`
- ArgoCD installed: `kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml`
- `jq` installed: `brew install jq` (macOS) or `apt install jq` (Linux)

## Validation Scenarios

### Scenario 1: Repo Discovery Uses jq

**Steps**:
1. Run `argocd.sh` with a valid GitHub token
2. Wait for script to reach repo registration section

**Expected**: Script outputs "Adding https://github.com/natanbs/argocd-infra.git ..." and each app repo URL — no Python errors.

**Command**: `argocd.sh $GITHUB_TOKEN 2>&1 | grep -A20 "Registering GitHub"`

### Scenario 2: All Repos Registered

**Steps**:
1. After bootstrap completes, run: `argocd repo list`

**Expected**: Output shows all repos from `apps/*.yaml` (vault, prometheus, external-secrets, familytree, pdf-scan) plus the infra repo.

**Command**: `argocd repo list`

### Scenario 3: Idempotency

**Steps**:
1. Run `argocd.sh` a second time

**Expected**: No errors during repo registration. All repos show "already exists" warnings (non-fatal).

**Command**: `argocd.sh $GITHUB_TOKEN 2>&1 | grep -i "warning\|error"`

### Scenario 4: jq Missing

**Steps**:
1. Temporarily rename `jq`: `sudo mv /usr/local/bin/jq /usr/local/bin/jq.bak`
2. Run `argocd.sh`

**Expected**: Script fails with a clear error about `jq` not being found (or installs it automatically if install_tool handles it).

**Restoration**: `sudo mv /usr/local/bin/jq.bak /usr/local/bin/jq`

### Scenario 5: Full Bootstrap End-to-End

**Steps**:
1. Delete existing cluster: `k3d cluster delete cluster-argo`
2. Run `argocd.sh` from scratch

**Expected**: All apps reach `Synced` status within 5 minutes. Vault unsealed. ESO operational. All repos registered.

**Command**: `argocd.sh $GITHUB_TOKEN 2>&1 | tail -20`
