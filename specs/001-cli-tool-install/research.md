# Research: CLI Tool Install

## Installation Approaches

### kubectl

- **Decision**: Download official binary from `dl.k8s.io` on Linux; Homebrew `kubernetes-cli` on macOS
- **Rationale**: Official Kubernetes release channel ensures latest stable version; Homebrew provides native macOS package management
- **Alternatives considered**:
  - Snap/apt packages (Ubuntu) — often outdated versions, not recommended by K8s docs
  - asdf version manager — adds unnecessary complexity for a bootstrap script

### argocd CLI

- **Decision**: Download official binary from GitHub releases on Linux; Homebrew `argocd` on macOS
- **Rationale**: Official release channel; Homebrew provides native macOS integration
- **Alternatives considered**:
  - Building from source — too slow and complex for bootstrap
  - curl piped to shell — security concern, official binary install preferred

### macOS (Homebrew)

- **Decision**: Use `brew list` to check, `brew install` to install
- **Rationale**: Homebrew is the standard package manager on macOS
- **Consideration**: Assumes Homebrew is already installed (documented in Assumptions)

### Linux (Debian/Ubuntu)

- **Decision**: Download binaries directly and install to `/usr/local/bin`
- **Rationale**: No single package manager covers both Debian and Ubuntu consistently for these tools
- **Consideration**: Requires `sudo` for system-wide install; assumes `curl` is available

## OS Detection

- **Decision**: Use `uname -s` to detect OS (Darwin = macOS, Linux = Debian/Ubuntu)
- **Rationale**: Standard, reliable POSIX approach; works in all shell environments
- **Alternatives considered**: `/etc/os-release` — Linux-only, inconsistent format

## Tool Availability Check

- **Decision**: Use `command -v <tool>` to check if tool is already installed
- **Rationale**: POSIX-compliant, works across all shells, handles aliases and PATH
- **Alternatives considered**: `which` — not POSIX, varies across systems; `test -f` — too brittle
