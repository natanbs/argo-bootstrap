# Feature Specification: ArgoCD Install Infra Apps

**Feature Branch**: `008-argocd-install-infra`

**Created**: 2026-08-19

**Status**: Draft

**Input**: "What is needed for ArgoCD to install the infra apps under ~/projects/repos/infra? 1. github 2. token 3. infra"

## Mission Brief

**Goal**: Configure ArgoCD to automatically deploy infrastructure apps from the `~/projects/repos/infra` repository using GitHub token authentication, and modularize the bootstrap script for maintainability.

**Success Criteria**:
- SC-001: Running `argocd.sh` on a fresh system results in all apps registered in `infra/argocd-infra/apps/*.yaml` reaching `Synced` status within 5 minutes (measurement starts at script start)
- SC-002: Adding a new app registration YAML to `infra/argocd-infra/apps/` results in ArgoCD deploying it within 5 minutes without any changes to `argocd.sh`
- SC-003: Running `argocd.sh` twice consecutively produces no errors and all resources remain in the expected state (idempotent)

**Constraints**:
- GitHub personal access token provided via env var or interactive prompt, never in git-tracked files
- All 5 registered apps (vault, prometheus, external-secrets, familytree, pdf-scan) deploy via ApplicationSet; scope covers credential, ApplicationSet deployment, and script modularization
- ArgoCD in insecure mode (HTTP)
- Non-critical step failures log warnings; only critical failures (cluster creation, ArgoCD install, vault init, vault unseal) cause script exit

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Bootstrap Deploys Infra Apps via ArgoCD (Priority: P1)

As a platform operator, I want the `argocd.sh` bootstrap script to automatically configure ArgoCD with GitHub repository access and deploy all registered infrastructure apps, so that a fresh k3d cluster has a complete infrastructure layer without manual intervention.

**Why this priority**: This is the core deliverable — without it, every cluster recreation requires manual ArgoCD configuration and app deployment, defeating the purpose of the disaster recovery system.

**Independent Test**: Can be fully tested by running `argocd.sh` on a fresh system and verifying all registered apps (vault, prometheus, external-secrets, familytree, pdf-scan) reach `Synced` status in ArgoCD within 5 minutes.

**Acceptance Scenarios**:

1. **Given** a fresh k3d cluster with ArgoCD installed, **When** `argocd.sh` completes execution, **Then** a Kubernetes Secret named `github-repo-cred` exists in the `argocd` namespace containing the GitHub token
2. **Given** the GitHub repository credential exists, **When** ArgoCD processes the ApplicationSet, **Then** ArgoCD Applications are created for each `apps/*.yaml` file in the `infra/argocd-infra/` directory
3. **Given** ArgoCD Applications are created, **When** sync completes, **Then** all 5 registered apps (vault, prometheus, external-secrets, familytree, pdf-scan) pods are running in their respective namespaces

---

### User Story 2 - Add New Infra App Without Bootstrap Changes (Priority: P2)

As a platform operator, I want to add a new infrastructure app by simply creating a YAML file in `infra/argocd-infra/apps/`, so that the bootstrap script does not need modification when the infrastructure layer grows.

**Why this priority**: This ensures the system is extensible and follows the existing ApplicationSet pattern already established in the infra repo.

**Independent Test**: Can be tested by adding a new `apps/my-app.yaml` file to the infra repo and verifying ArgoCD automatically creates a corresponding Application without any changes to `argocd.sh`.

**Acceptance Scenarios**:

1. **Given** the ApplicationSet is deployed, **When** a new `apps/my-app.yaml` is added to the infra repo, **Then** ArgoCD automatically creates an Application for it within 5 minutes
2. **Given** a new Application is created, **When** the referenced repo and path are valid, **Then** the app deploys to its specified namespace

---

### User Story 3 - Bootstrap Is Idempotent (Priority: P3)

As a platform operator, I want to run `argocd.sh` multiple times without errors or duplicate resources, so that I can safely re-bootstrap or update the cluster configuration.

**Why this priority**: Idempotency is critical for disaster recovery — the restore process may re-run the bootstrap.

**Independent Test**: Can be tested by running `argocd.sh` twice consecutively and verifying no errors on the second run and all resources remain in the expected state.

**Acceptance Scenarios**:

1. **Given** ArgoCD is already configured with GitHub credentials, **When** `argocd.sh` runs again, **Then** the repository credential secret is updated (not duplicated)
2. **Given** the ApplicationSet is already applied, **When** `argocd.sh` runs again, **Then** the ApplicationSet is updated in-place without creating duplicates

---

### User Story 4 - Modularize Bootstrap Script (Priority: P2)

As a developer, I want the ESO and Vault setup code extracted into `lib/` modules, so that the script is easier to maintain, test, and understand.

**Why this priority**: The ESO + Vault section is ~200 lines (40% of the script) with a 10-step dependency chain. Modularization improves maintainability without changing behavior.

**Independent Test**: Can be tested by running `argocd.sh` on a fresh system and verifying all functionality works identically to the monolithic version.

**Acceptance Scenarios**:

1. **Given** the modularized script, **When** `argocd.sh` runs, **Then** all functions from `lib/eso.sh` and `lib/vault.sh` are invoked in the correct dependency order
2. **Given** the modularized script, **When** a library function fails, **Then** the error is reported with the module name for easy debugging
3. **Given** the modularized script, **When** `argocd.sh` runs, **Then** the single entry point (`./argocd.sh`) still works with no additional arguments required

---

### Edge Cases

- What happens when the GitHub token is invalid or expired? ArgoCD should report the repository as inaccessible with a clear error message in the Application status
- What happens when the infra repo is unreachable? The ApplicationSet should remain applied but Apps should show `Unknown` sync status
- What happens when `infra/argocd-infra/apps/` contains invalid YAML? ArgoCD should skip the invalid file and deploy valid apps
- What happens when a registered app's target namespace conflicts with an existing namespace? The `CreateNamespace=true` sync option should handle this gracefully
- What happens when a non-critical step fails during bootstrap? The script logs a warning and continues; only critical failures (cluster creation, ArgoCD install, vault init, vault unseal) cause exit

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST create a Kubernetes Secret of type `kubernetes.io/basic-auth` in the `argocd` namespace containing the GitHub username and personal access token
- **FR-002**: System MUST configure the secret with the label `argocd.argoproj.io/secret-type: repository` so ArgoCD recognizes it as a repository credential
- **FR-003**: System MUST deploy the ApplicationSet manifest from `infra/argocd-infra/applicationset.yaml` by fetching it from the remote repository and applying it to the `argocd` namespace
- **FR-004**: System MUST ensure the ApplicationSet's git file generator can resolve `apps/*.yaml` from the correct repository and branch
- **FR-005**: System MUST preserve the existing bootstrap behavior (k3d cluster creation, ArgoCD installation, port configuration, password change). App image build/push (argo-app-go-server) is out of scope and will remain as-is.
- **FR-006**: System MUST handle the case where the GitHub credential already exists by updating it rather than failing
- **FR-007**: System MUST read the GitHub token from the `GITHUB_TOKEN` environment variable; if unset, prompt the operator interactively for username and token
- **FR-008**: System MUST read the ApplicationSet target branch from `ARGOCD_INFRA_BRANCH` env var, defaulting to `main` if unset
- **FR-009**: System MUST NOT store the GitHub token in any file that is committed to version control
- **FR-010**: System MUST log warnings for non-critical step failures and exit only on critical failures (cluster creation, ArgoCD install, vault init, vault unseal)
- **FR-011**: System MUST extract ESO setup code into `lib/eso.sh` and Vault setup code into `lib/vault.sh`, maintaining the same dependency chain
- **FR-012**: System MUST remove dead code: undefined `check_mapped_ports()` function call and password echo to console
- **FR-013**: System MUST add `set -euo pipefail` for strict error mode, with explicit error handling for steps that may legitimately fail (curl, kubectl)

### Key Entities

- **GitHub Repository Credential**: A Kubernetes Secret containing GitHub authentication details (username + PAT), labeled for ArgoCD repository detection
- **ApplicationSet**: An ArgoCD CRD that generates Applications from a git file generator reading `apps/*.yaml` registrations
- **App Registration**: A YAML file in `infra/argocd-infra/apps/` defining a single ArgoCD Application (repo, path, namespace, sync policy)
- **Infrastructure App**: A deployable component (vault, prometheus, external-secrets) managed by ArgoCD through the ApplicationSet
- **Library Module**: A bash source file under `lib/` containing functions for a specific infrastructure domain (eso.sh, vault.sh)

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Running `argocd.sh` on a fresh system results in all registered infra apps reaching `Synced` status within 5 minutes (measurement starts at script start)
- **SC-002**: Adding a new app registration YAML to `infra/argocd-infra/apps/` results in ArgoCD deploying it within 5 minutes without any changes to `argocd.sh`
- **SC-003**: Running `argocd.sh` twice consecutively produces no errors and all resources remain in the expected state (idempotent)
- **SC-004**: The GitHub token is never written to any file tracked by git (verified by checking `.gitignore` and commit history)
- **SC-005**: Vault (port 8200) and Prometheus (port 9090) are accessible via their respective services after bootstrap completes; ESO health is verified by pod Running status (no user-facing service)

## Assumptions

- The GitHub personal access token is provided via the `GITHUB_TOKEN` environment variable; if unset, the operator is prompted interactively for username and token
- The ApplicationSet targets the `main` branch by default; override via `ARGOCD_INFRA_BRANCH` env var
- The `infra` repo is hosted on GitHub under the `natanbs` organization (matching existing repo references in `apps/*.yaml`)
- The ApplicationSet in `infra/argocd-infra/applicationset.yaml` is the single source of truth for app registrations
- The existing `apps/*.yaml` files already reference the correct GitHub repository URLs and paths
- The k3d cluster has network access to GitHub (for cloning repos)
- The ApplicationSet deploys all 5 registered apps; no filtering is applied at bootstrap time
- The ArgoCD server is configured in insecure mode (HTTP) as per the existing bootstrap, so TLS certificate verification for the repo is not required

## Clarifications

### Session 2026-08-19

- Q: How should the GitHub personal access token be provided to the bootstrap script? → A: Env var `GITHUB_TOKEN` with interactive prompt fallback if unset
- Q: Should the ApplicationSet point at a fixed branch or the current feature branch? → A: Default to `main`, allow override via `ARGOCD_INFRA_BRANCH` env var

### Session 2026-08-25

- Q: When measuring SC-001, when does the 5-minute clock start? → A: Measurement starts at script start (includes tool installation, cluster creation, ArgoCD install)
- Q: What is the ArgoCD sync interval that SC-002 refers to? → A: Change SC-002 to "within 5 minutes" for consistency with SC-001 (removes "sync interval" qualifier)
- Q: How should the script behave when a non-critical step fails? → A: Log warnings for non-critical steps, exit only on critical failures (cluster creation, ArgoCD install, vault init, vault unseal)
- Q: Should ESO/Vault extraction and app splitting be part of this spec? → A: Yes, include in this spec. ESO/Vault modularization via `lib/` modules. App splitting deferred (flat structure retained).
- Q: For splitting ESO and Vault from argocd.sh, which approach? → A: Modularize in-place — extract to `lib/eso.sh`, `lib/vault.sh` (single `argocd.sh` entry point, following `k3d-dr/lib/` pattern)
- Q: SC-005 says "accessible via their respective services" — which services and ports? → A: Vault:8200, Prometheus:9090, ESO: skip (no user-facing service; pod Running status is sufficient)
