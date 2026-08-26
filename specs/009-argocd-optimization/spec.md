# Feature Specification: ArgoCD Script Optimization

**Feature Branch**: `009-argocd-optimization`

**Created**: 2026-08-25

**Status**: Draft

**Input**: "Check unnecessary code, simplify/optimize, confirm functionality wouldn't degrade and all pods would run successfully"

## Mission Brief

**Goal**: Simplify and optimize the `argocd.sh` bootstrap script by removing dead code, fixing security issues, and improving reliability while maintaining all existing functionality.

**Success Criteria**:
- SC-001: All dead code removed without affecting functionality
- SC-002: Security issues fixed (password no longer printed to console)
- SC-003: Code simplified where possible (duplicate definitions, redundant checks)
- SC-004: All 3 vault pods remain Running and Ready=True after optimization
- SC-005: All 5 registered apps deploy successfully via ApplicationSet

**Constraints**:
- Must maintain backward compatibility with existing workflows
- Must preserve all existing functionality (k3d cluster, ArgoCD, vault, apps)
- Changes must be idempotent (script can run multiple times)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Remove Dead Code (Priority: P1)

As a developer, I want dead code removed from `argocd.sh`, so that the script is easier to maintain and understand.

**Why this priority**: Dead code adds confusion and maintenance burden.

**Independent Test**: Run `argocd.sh` and verify all functionality works as before.

**Acceptance Scenarios**:

1. **Given** the script has duplicate `VAULT_REPO` definitions, **When** the script runs, **Then** `VAULT_REPO` is defined only once
2. **Given** the script has unused `MAPPED_PORTS` and `check_mapped_ports()`, **When** the script runs, **Then** these are removed
3. **Given** the script has unnecessary empty lines, **When** the script runs, **Then** whitespace is cleaned up

---

### User Story 2 - Fix Security Issues (Priority: P1)

As a security-conscious operator, I want the script to not print passwords to the console, so that sensitive information is not exposed.

**Why this priority**: Security issues should be fixed immediately.

**Independent Test**: Run `argocd.sh` and verify passwords are not printed to console.

**Acceptance Scenarios**:

1. **Given** the script prints `echo $init_pass`, **When** the script runs, **Then** the password is not printed to console
2. **Given** the script has a password variable, **When** the script runs, **Then** the password is only used internally

---

### User Story 3 - Simplify Code (Priority: P2)

As a developer, I want the script simplified where possible, so that it is easier to read and maintain.

**Why this priority**: Simplification improves maintainability.

**Independent Test**: Run `argocd.sh` and verify all functionality works as before.

**Acceptance Scenarios**:

1. **Given** the `port_in_use()` function uses Linux-only `ss` command, **When** the script runs on macOS, **Then** it uses `lsof` only
2. **Given** the `--help` text says `$0 [git-token]`, **When** the user runs `--help`, **Then** it accurately describes the `GITHUB_TOKEN` env var
3. **Given** the script has an arbitrary `sleep 30`, **When** the script runs, **Then** it uses health checks instead

---

### User Story 4 - Improve Error Handling (Priority: P2)

As an operator, I want the script to handle errors consistently, so that failures are detected and reported clearly.

**Why this priority**: Consistent error handling improves reliability.

**Independent Test**: Run `argocd.sh` and verify errors are detected and reported.

**Acceptance Scenarios**:

1. **Given** the script has missing error handling for curl commands, **When** a curl command fails, **Then** the script reports the error
2. **Given** the script has `set -e` disabled, **When** an error occurs, **Then** the script detects it via explicit checks

---

### Edge Cases

- What happens if `VAULT_REPO` directory doesn't exist? Script should report error clearly
- What happens if curl commands fail? Script should detect and report
- What happens if `--help` is called with other args? Script should show help and exit

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST remove duplicate `VAULT_REPO` definition (lines 322, 332)
- **FR-002**: System MUST remove unused `MAPPED_PORTS` and `check_mapped_ports()` (lines 139-148)
- **FR-003**: System MUST remove `echo $init_pass` (line 229) to prevent password exposure
- **FR-004**: System MUST simplify `port_in_use()` to use `lsof` only (remove `ss` command)
- **FR-005**: System MUST update `--help` text to accurately describe `GITHUB_TOKEN` env var
- **FR-006**: System MUST remove unnecessary empty lines (lines 114-117)
- **FR-007**: System MUST add error handling for curl commands (lines 125, 275, 277-283)
- **FR-008**: System MUST preserve all existing functionality (k3d, ArgoCD, vault, apps)
- **FR-009**: System MUST maintain idempotent execution
- **FR-010**: System MUST keep all 3 vault pods Running and Ready=True

### Key Entities

- **argocd.sh**: Main bootstrap script for ArgoCD installation
- **VAULT_REPO**: Path to vault configuration directory
- **port_in_use()**: Function to check if a port is in use
- **vault_exec()**: Helper function to run vault CLI commands

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All dead code removed without affecting functionality
- **SC-002**: Security issues fixed (password not printed)
- **SC-003**: Code simplified where possible
- **SC-004**: All 3 vault pods remain Running and Ready=True
- **SC-005**: All 5 registered apps deploy successfully

## Assumptions

- The user has read access to the argocd.sh script
- The user can run the script on a fresh k3d cluster
- The user has access to the vault and infra repositories
- The optimization changes are backward compatible

## Clarifications

### Overlap with Spec 008

- **FR-001 (VAULT_REPO dedup)** and **FR-002 (check_mapped_ports removal)** are also covered by `specs/008-argocd-install-infra` FR-012. Implementation is tracked in spec 008 tasks T022-T024. This spec retains the requirements for traceability but implementation ownership belongs to spec 008.

### Session 2026-08-25

- Q: What is the scope of the optimization? → A: Remove dead code, fix security issues, simplify code, improve error handling
- Q: Should we create a new feature branch? → A: Yes, create `009-argocd-optimization` branch
- Q: How do we verify the optimization works? → A: Run `argocd.sh` on a fresh cluster and verify all pods are running
