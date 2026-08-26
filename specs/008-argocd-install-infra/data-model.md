# Data Model: ArgoCD Install Infra Apps

**Feature**: `008-argocd-install-infra`
**Date**: 2026-08-25

## Entities

### GitHub Repository Credential

A Kubernetes Secret containing GitHub authentication details.

| Field | Type | Description |
|-------|------|-------------|
| name | string | `github-repo-cred` (canonical) |
| namespace | string | `argocd` |
| type | string | `kubernetes.io/basic-auth` |
| labels | map | `argocd.argoproj.io/secret-type: repository` |
| stringData.username | string | GitHub username |
| stringData.password | string | GitHub personal access token |

**Validation Rules**:
- Secret MUST be created with `kubectl apply` for idempotency (FR-006)
- Token MUST NOT be written to git-tracked files (FR-009)
- If Secret exists, it MUST be updated, not duplicated (FR-006)

### ApplicationSet

An ArgoCD CRD that generates Applications from a git file generator.

| Field | Type | Description |
|-------|------|-------------|
| name | string | `cluster-apps` |
| namespace | string | `argocd` |
| generator | git | Reads `apps/*.yaml` from `infra/argocd-infra` repo |
| revision | string | Branch from `ARGOCD_INFRA_BRANCH` env var, default `main` |
| template | Application | Template for generated Applications |

**State Transitions**:
- Applied → ArgoCD processes file generator → Applications created → Apps synced

### App Registration

A YAML file in `infra/argocd-infra/apps/` defining a single ArgoCD Application.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| name | string | yes | Application name (e.g., `vault`, `prometheus`) |
| repoURL | string | yes | GitHub repository URL |
| appPath | string | yes | Path within repo (usually `.` or `k8s`) |
| namespace | string | yes | Target Kubernetes namespace |
| syncWave | string | no | Sync wave for ordering (e.g., `-1` for ESO) |

**Validation Rules**:
- File MUST be valid YAML
- `repoURL` MUST be a valid GitHub URL
- `namespace` MUST be a valid Kubernetes namespace name

**Known Registrations**:

| name | repoURL | appPath | namespace | syncWave |
|------|---------|---------|-----------|----------|
| external-secrets | https://github.com/natanbs/external-secrets.git | . | external-secrets | -1 |
| vault | https://github.com/natanbs/vault.git | . | vault | 0 |
| prometheus | https://github.com/natanbs/prometheus.git | . | monitoring | 0 |
| familytree | https://github.com/natanbs/familytree.git | k8s | apps-ns | 0 |
| pdf-scan | https://github.com/natanbs/pdf-scan.git | k8s | apps-ns | 0 |

### Library Module

A bash source file under `lib/` containing functions for a specific infrastructure domain.

| Field | Type | Description |
|-------|------|-------------|
| filename | string | `eso.sh` or `vault.sh` |
| shebang | string | `#!/usr/bin/env bash` |
| error_mode | string | `set -euo pipefail` |
| functions | list | Domain-specific functions |

**Modules**:

| Module | Functions | Source Lines |
|--------|-----------|--------------|
| `lib/eso.sh` | `install_eso_helm()`, `create_eso_argocd_app()`, `wait_for_cluster_secret_store()` | ~25 lines |
| `lib/vault.sh` | `create_vault_tls_secret()`, `create_vault_unseal_placeholder()`, `wait_for_vault_tls()`, `init_vault()`, `unseal_vault()`, `verify_vault_status()` | ~207 lines |

## Relationships

```
App Registration (1) ──deploys──> Infrastructure App (1)
ApplicationSet (1) ──generates──> App Registration (N)
GitHub Repository Credential (1) ──authenticates──> ApplicationSet (1)
Library Module (1) ──sources──> argocd.sh (1)
argocd.sh (1) ──sources──> lib/eso.sh (1)
argocd.sh (1) ──sources──> lib/vault.sh (1)
```

## State Transitions

### Bootstrap Flow

```
1. Tool installation (k3d, kubectl, argocd CLI)
2. Registry creation (k3d-reg)
3. Cluster creation (cluster-argo)
4. ArgoCD installation + configuration
5. ESO Helm install → ESO ArgoCD app → ClusterSecretStore Ready
6. vault-tls.sh → source Secret created
7. vault-unseal-keys placeholder created
8. ApplicationSet deployed → all apps discovered
9. vault-tls synced to vault namespace
10. vault init → unseal keys saved → vault-0/1/2 unsealed
11. App image build + push
```

### Idempotency Rules

| Operation | Idempotent Method |
|-----------|-------------------|
| kubectl apply | Creates or updates resource |
| helm upgrade --install | Installs or upgrades release |
| argocd repo add --upsert | Adds or updates repository |
| argocd app create --upsert | Creates or updates application |
| kubectl create namespace --dry-run=client -o yaml \| kubectl apply -f - | Creates namespace if not exists |
