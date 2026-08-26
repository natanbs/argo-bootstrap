# Feature Specification: Declarative Bootstrap Migration

**Feature Branch**: `010-declarative-bootstrap`

**Created**: 2026-08-25

**Status**: Draft

**Input**: "follow the brainstorm: Brainstorm Complete — move imperative bash code to declarative manifests"

## Mission Brief

**Goal**: Replace the fragile Python JSON parser in `argocd.sh`'s repo discovery loop with `jq`, making the bootstrap script more robust and reducing external dependencies.

**Success Criteria**:
- SC-001: After bootstrap, all 6 GitHub repos (infra + 5 apps from `apps/*.yaml`) are registered via `argocd repo list` with no errors
- SC-002: `argocd-cmd-params-cm` contains `server.insecure: "true"` and `server.session.expires` with the configured value (default 720h)
- SC-003: Running `argocd.sh` on a fresh system produces the same end state as before (all apps Synced, Vault unsealed, ESO operational)
- SC-004: The Python JSON parser is replaced with `jq` — `python3` no longer appears in the repo discovery loop

**Constraints**:
- Service patch (LoadBalancer, port reassignment) must remain imperative — IP detection is inherently dynamic and OS-dependent
- GitHub token must not appear in git-tracked files
- Bootstrap must remain a single entry point (`argocd.sh`)
- Constitution principle IX (Idempotent Automation) applies
- Repo registration uses `argocd repo add` (ArgoCD CLI), not `kubectl` Secret creation

## Clarifications

### Session 2026-08-25

- Q: Which approach for creating ArgoCD repo credential Secrets during bootstrap? → A: Option C — Keep using `argocd repo add` with the GitHub API for discovery, but replace the Python JSON parser with jq.
- Q: How should the script discover repo URLs from apps/*.yaml without the GitHub API? → A: Keep the GitHub API approach but replace the Python JSON parser with jq for robustness.
- Q: Should the ConfigMap patching stay as kubectl patch or change? → A: Keep kubectl patch — it's reliable and idempotent.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Robust Repo Registration (Priority: P1)

As a platform operator, I want the repo registration loop in `argocd.sh` to use `jq` instead of a Python one-liner for parsing GitHub API responses, so that the bootstrap is more robust and has fewer fragile dependencies.

**Why this priority**: The repo registration loop (lines 262-270 in `argocd.sh`) uses a Python one-liner to parse JSON — this is fragile and adds an unnecessary dependency. `jq` is more standard for shell scripting.

**Independent Test**: Can be tested by running `argocd.sh` and verifying that `argocd repo list` shows all expected repos registered.

**Acceptance Scenarios**:

1. **Given** a fresh ArgoCD install, **When** the bootstrap registers repos, **Then** all repos from `apps/*.yaml` are registered via `argocd repo add` using `jq` for JSON parsing
2. **Given** the bootstrap is run a second time, **When** `argocd repo add` runs again with `--upsert`, **Then** no errors occur (idempotent)
3. **Given** `jq` is not installed, **When** the script runs, **Then** it fails with a clear error message or installs `jq` automatically

---

### User Story 2 - ArgoCD ConfigMap Configured Reliably (Priority: P2)

As a platform operator, I want ArgoCD configuration (insecure mode, session expiry) applied reliably without complex patching logic, so that the bootstrap doesn't fail on ConfigMap updates.

**Why this priority**: Lower risk than repo registration, but contributes to overall bootstrap reliability.

**Independent Test**: Can be tested by checking that `kubectl get configmap argocd-cmd-params-cm -n argocd -o yaml` shows `server.insecure: "true"` and the configured session expiry value.

**Acceptance Scenarios**:

1. **Given** ArgoCD is installed, **When** the bootstrap configures ArgoCD, **Then** `argocd-cmd-params-cm` contains `server.insecure: "true"` and `server.session.expires` with the configured value
2. **Given** the ConfigMap already has the correct values, **When** the bootstrap runs again, **Then** no errors occur (idempotent)

---

### Edge Cases

- What happens when a repo URL in `apps/*.yaml` is a private repo and the token lacks access? `argocd repo add` fails with an error — this is existing behavior and unchanged.
- What happens if a repo is already registered? `argocd repo add --upsert` handles this gracefully.
- What happens if the infra repo URL changes? The script uses a hardcoded infra repo URL — this is existing behavior and unchanged.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST register each ArgoCD repository credential using `argocd repo add` with `--upsert`
- **FR-002**: Each repo registration MUST use the `--username` and `--password` flags with credentials from environment variables (GITHUB_USER, GITHUB_TOKEN)
- **FR-003**: System MUST use `jq` (not Python) to parse GitHub API responses when discovering repo URLs from `apps/*.yaml`
- **FR-004**: The infra repo (`argocd-infra`) MUST be registered first, followed by repos from `apps/*.yaml`
- **FR-005**: ArgoCD insecure mode and session expiry MUST be configured via `kubectl patch` on `argocd-cmd-params-cm`
- **FR-006**: GitHub token MUST NOT be committed to git
- **FR-007**: The Service patch (LoadBalancer type, port reassignment, externalIPs) MUST remain as imperative `kubectl patch` calls
- **FR-008**: The script MUST remain a single entry point (`argocd.sh`) with no new required user-facing flags

### Key Entities

- **Repo Registration**: The process of telling ArgoCD how to authenticate to a Git repository, done via `argocd repo add`. Each repo needs a URL, username, and password/token.
- **ArgoCD ConfigMap**: The `argocd-cmd-params-cm` ConfigMap in the `argocd` namespace that controls ArgoCD server behavior (insecure mode, session expiry).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- SC-001: After bootstrap, all 6 GitHub repos (infra + 5 apps from `apps/*.yaml`) are registered via `argocd repo list` with no errors
- SC-002: `argocd-cmd-params-cm` contains `server.insecure: "true"` and `server.session.expires` with the configured value (default 720h)
- SC-003: Running `argocd.sh` on a fresh system produces the same end state as before (all apps Synced, Vault unsealed, ESO operational)
- SC-004: The Python JSON parser is replaced with `jq` — `python3` no longer appears in the repo discovery loop

## Assumptions

- `jq` is available on both macOS and Linux (it's commonly pre-installed or easily installable via package manager)
- The GitHub API approach for repo discovery is reliable enough to keep — the improvement is in JSON parsing robustness
- ArgoCD CLI `argocd repo add` is stable and idempotent with `--upsert`
- Constitution principle II (Repository-Driven Infrastructure) is satisfied — repo URLs come from repository contents

## Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| `jq` may not be installed on some systems | Low | Low | Check for `jq` at script start and install if missing (like other tools) |
| `jq` syntax may differ from Python parsing in edge cases | Low | Low | Test with existing `apps/*.yaml` files; `jq` is well-documented for this use case |

## Scope Boundaries

**In scope**:
- Replacing the Python JSON parser with `jq` in the repo discovery loop
- Adding `jq` to the tool installation check (if not already present)
- Ensuring the repo registration loop works correctly with `jq`

**Out of scope**:
- Eliminating the GitHub API dependency entirely
- Converting repo registration to Kubernetes Secret manifests
- Converting ConfigMap patching to a different approach
- Converting the Service patch (LoadBalancer, ports) to declarative
- Converting Vault init/unseal to declarative
- Reducing overall script line count
