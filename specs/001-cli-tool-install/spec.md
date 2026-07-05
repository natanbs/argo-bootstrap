# Feature Specification: CLI Tool Install

**Feature Branch**: `001-cli-tool-install`

**Created**: 2026-06-10

**Status**: Draft

**Input**: User description: "check: if kubectl is installed. if not, install it. if argocd cli is installed, if not install it. In both cases support macos and debian/ubuntu."

## User Scenarios & Testing

### User Story 1 - Run bootstrap script with missing prerequisites (Priority: P1)

A DevOps engineer runs `argocd.sh` on a fresh machine that has neither kubectl nor argocd CLI installed. The script automatically detects the missing tools and installs them before proceeding with cluster setup.

**Why this priority**: This is the core value — without automatic prerequisite handling, users must manually install tools before running the script.

**Independent Test**: Can be verified by running the script on a clean macOS or Debian/Ubuntu environment and confirming kubectl and argocd are available after execution.

**Acceptance Scenarios**:

1. **Given** a macOS system without kubectl, **When** the script runs, **Then** kubectl is installed and available after execution
2. **Given** a Debian/Ubuntu system without kubectl, **When** the script runs, **Then** kubectl is installed and available after execution
3. **Given** a macOS system without argocd CLI, **When** the script runs, **Then** argocd CLI is installed and available after execution
4. **Given** a Debian/Ubuntu system without argocd CLI, **When** the script runs, **Then** argocd CLI is installed and available after execution

---

### User Story 2 - Run bootstrap script with existing tools (Priority: P2)

A DevOps engineer runs `argocd.sh` on a machine that already has kubectl and argocd CLI installed. The script skips installation and proceeds without delay.

**Why this priority**: Optimizes for the common case where tools are already present.

**Independent Test**: Can be verified by running the script on a system with kubectl and argocd already installed and confirming no reinstallation occurs.

**Acceptance Scenarios**:

1. **Given** a system where kubectl is already installed, **When** the script runs, **Then** kubectl installation is skipped
2. **Given** a system where argocd CLI is already installed, **When** the script runs, **Then** argocd CLI installation is skipped
3. **Given** both tools are already installed, **When** the script runs, **Then** no installation commands are executed

---

### Edge Cases

- What happens when the system is neither macOS nor Linux (e.g., Windows/WSL)?
- How does the script handle network failures during tool download?
- What happens when `sudo` is required but the user lacks permissions?
- How does the script handle partial installations (one tool present, one missing)?

## Requirements

### Functional Requirements

- **FR-001**: The system MUST detect the operating system and use the platform-appropriate installation method
- **FR-002**: On macOS, the system MUST use Homebrew (`brew`) to install kubectl and argocd CLI
- **FR-003**: On Debian/Ubuntu Linux, the system MUST install kubectl by downloading the official binary from `dl.k8s.io`
- **FR-004**: On Debian/Ubuntu Linux, the system MUST install argocd CLI by downloading the official binary from GitHub releases
- **FR-005**: The system MUST check if each tool is already installed before attempting installation
- **FR-006**: If a tool is already installed, the system MUST skip reinstallation without error
- **FR-007**: The system MUST make installed tools available in the system PATH for subsequent script steps
- **FR-008**: The system MUST provide clear error messages if tool installation fails

### Key Entities

- **Tool**: A CLI program (kubectl, argocd) that may or may not be present on the system
- **Platform**: The target operating system (macOS or Linux) that determines the installation method

## Success Criteria

### Measurable Outcomes

- **SC-001**: Users can run the bootstrap script on a clean macOS machine without manually installing any prerequisites
- **SC-002**: Users can run the bootstrap script on a clean Debian/Ubuntu machine without manually installing any prerequisites
- **SC-003**: When all tools are already present, the script proceeds without noticeable delay for installation checks
- **SC-004**: Installation failures produce clear error messages that identify the failing tool and suggested resolution

## Assumptions

- Target systems have internet connectivity required to download binaries
- Target systems have `curl` available (for Linux installations)
- macOS systems have Homebrew installed
- Docker and git are already installed (handled separately or assumed present)
- The user has sufficient permissions (`sudo` access on Linux) to install system-wide tools
