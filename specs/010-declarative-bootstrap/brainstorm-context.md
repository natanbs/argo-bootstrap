# Brainstorm Context: Declarative Migration for argocd.sh

## Problem Statement

The `argocd.sh` bootstrap script is ~307 lines of imperative bash. Several sections use `kubectl patch`, `argocd repo add`, and API-calling loops to configure resources that could instead be expressed as static Kubernetes manifests. Moving these to declarative code would reduce bugs, improve idempotency, and make the script shorter and easier to reason about.

## Key Concepts

- **Declarative**: Describe the desired end state as a manifest; Kubernetes/ArgoCD reconciles. Idempotent by design.
- **Imperative**: Describe a sequence of actions; the script controls ordering and error handling. Idempotency must be hand-coded.
- **Bootstrap chicken-and-egg**: Some resources (like ArgoCD repo secrets) can only exist after ArgoCD is installed, but ArgoCD needs those secrets to function. The script must still orchestrate the order — but the *content* can be declarative.
- **Existing declarative surface**: `k3d-config.yaml` (cluster), `applicationset.yaml` (apps), `apps/*.yaml` (registrations) are already declarative.

## Current Script Anatomy

| Lines | Section | Imperative or Declarative | Candidate? |
|-------|---------|--------------------------|------------|
| 83-118 | Tool installation (k3d, kubectl, argocd) | Imperative | No — must detect OS, install binaries |
| 142-168 | Registry creation | Imperative | No — k3d CLI, port fallback logic |
| 170-177 | Cluster creation | Semi-declarative (uses k3d-config.yaml) | Already done |
| 179-182 | ArgoCD install | `kubectl apply` from URL | No — remote URL, must run after cluster |
| 184-185 | ArgoCD config (insecure, session) | `kubectl patch` on ConfigMap | **Yes** |
| 187-202 | ArgoCD service (LB, ports) | `kubectl patch` on Service | **Yes** |
| 207-216 | Wait for ArgoCD + read password | Imperative (polling) | No — timing-dependent |
| 224-251 | Port-forward, login, password change | Imperative (process mgmt) | No — interactive |
| 253-272 | Repo registration | `argocd repo add` loop + GitHub API | **Yes — biggest win** |
| 274-277 | ESO install + ArgoCD app | Helm + argocd CLI | Partially — ArgoCD app could be a manifest |
| 279-291 | Vault setup | Imperative (init, unseal, polling) | No — stateful, sequential |
| 296-307 | App image build/push | Docker CLI | No — out of scope per FR-005 |

## Approaches Considered

### Approach A: Convert ArgoCD Repo Credentials to Secret Manifest

- **How it works**: Instead of `argocd repo add` for each repo, generate a Kubernetes Secret with `argocd.argoproj.io/secret-type: repository` label for each repo. Apply via `kubectl apply`. The ApplicationSet already handles app discovery — the script just needs to register the credentials.
- **Tradeoffs**:
  - Eliminates the fragile `for` loop that curls GitHub API to discover repos (lines 262-270)
  - Secret manifests are static YAML — easy to audit, diff, and version
  - Still requires the script to run `kubectl apply` after ArgoCD is installed (chicken-and-egg)
  - Username/password still come from env vars — the manifests would need `envsubst` or templating
- **Risks**: Token rotation requires re-applying manifests (but this is already the case with `argocd repo add`)
- **Best for**: Reducing the most complex imperative code in the script

### Approach B: Convert ArgoCD Patches to Static Manifests

- **How it works**: Replace `kubectl patch argocd-cmd-params-cm` and `kubectl patch svc argocd-server` with pre-built ConfigMap and Service manifests that are applied after ArgoCD install.
- **Tradeoffs**:
  - ConfigMap patch (insecure mode, session expiry) is simple — just a ConfigMap apply
  - Service patch is harder — ArgoCD creates the Service, then the script patches it. A static manifest would need to fully describe the Service (including fields ArgoCD sets)
  - The IP detection logic (macOS/Linux) for `externalIPs` is inherently imperative
- **Risks**: Service manifest might drift from ArgoCD's expected Service spec across versions
- **Best for**: ConfigMap only (insecure mode + session expiry). Service patch should stay imperative.

### Approach C: Both A + B (Full Declarative Migration)

- **How it works**: Combine Approach A (repo credentials) and Approach B (ConfigMap only). Leave Service patches and all other imperative code as-is.
- **Tradeoffs**:
  - Maximizes declarative surface without over-engineering
  - Script shrinks by ~30 lines (the repo registration loop)
  - ConfigMap apply replaces a one-line `kubectl patch`
- **Risks**: Two new manifest files to maintain; but they're simple and static
- **Best for**: Balanced approach — significant simplification without architectural change

## Architecture Notes

The existing architecture already has a good declarative surface:
- `k3d-config.yaml` → cluster topology
- `applicationset.yaml` → app deployment pattern
- `apps/*.yaml` → individual app registrations

Adding repo credential manifests and ArgoCD ConfigMap would extend this pattern naturally. The script becomes a thin orchestration layer: install tools → create cluster → install ArgoCD → apply declarative configs → run imperative vault setup.

The key insight: **the script's job is to create the environment where declarative resources can take over**. The less the script does imperatively, the more reliable it is.

## Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Token in Secret manifest could leak if manifest is committed | Low | High | Use `envsubst` or variable substitution; add to .gitignore if templated |
| Service manifest drift from ArgoCD version | Medium | Medium | Keep Service patch imperative (don't convert) |
| ArgoCD may change Secret format across versions | Low | Medium | Pin ArgoCD version in install URL (already done) |
| `envsubst` adds a dependency | Low | Low | Already available on macOS/Linux; or use `sed` |

## Open Questions

1. Should repo credential Secrets be templated files (with `envsubst`) or generated inline in bash? Templated files are more declarative but add a processing step.
2. Is the ArgoCD app creation in `lib/eso.sh` (line 24-34) a candidate for a static Application manifest applied via `kubectl apply` instead of `argocd app create`?
3. Should the vault-unseal-keys placeholder secret in `lib/vault.sh` be a static manifest instead of inline `kubectl create`?

## Recommended Direction

**Approach C (A + B ConfigMap only)** — the biggest win is converting repo registration from an imperative `argocd repo add` loop to declarative Secret manifests. This eliminates the most complex and fragile code in the script (the GitHub API discovery loop). The ConfigMap for ArgoCD settings is a minor but clean improvement.

Specifically:
1. Create `manifests/argocd-repos.yaml` — a template or generated set of Secrets for each repo
2. Create `manifests/argocd-config.yaml` — ConfigMap with insecure mode + session expiry
3. Replace lines 253-272 (repo registration loop) with `kubectl apply -f manifests/`
4. Replace line 185 (ConfigMap patch) with `kubectl apply -f manifests/argocd-config.yaml`
5. Leave Service patches (lines 194-202) imperative — the IP detection is inherently dynamic
