# Implementation Plan: CLI Tool Install

**Branch**: `001-cli-tool-install` | **Date**: 2026-06-10 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-cli-tool-install/spec.md`

**Note**: This template is filled in by the `/spec.plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

Add automatic prerequisite checking and installation for kubectl and argocd CLI to `argocd.sh`. The script detects the OS (macOS via `uname -s`), checks if each tool is already installed (`command -v`), and installs missing tools using platform-appropriate methods (Homebrew on macOS, official binary downloads on Linux).

## Technical Context

**Language/Version**: Bash (POSIX shell)

**Primary Dependencies**: curl, Homebrew (macOS only), kubectl, argocd CLI, k3d, docker

**Storage**: N/A

**Testing**: Manual script execution verification

**Target Platform**: macOS (Darwin), Linux (Debian/Ubuntu)

**Project Type**: Shell script (bootstrap/infrastructure tooling)

**Performance Goals**: N/A — installation happens once per environment

**Constraints**: Must be POSIX-compatible shell script; must not break existing bootstrap flow; must work on both macOS and Linux without modification

**Scale/Scope**: Single shell script (`argocd.sh`), 2 CLI tools (kubectl, argocd), 2 platforms

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Simplicity First**: Adding install checks avoids manual pre-work for users. Implementation is a single function + 2 calls — minimal code for the problem. ✓ PASS
- **Surgical Changes**: Only touches the `install_tool()` function and adds `install_tool kubectl` / `install_tool argocd` calls. Does not modify adjacent script logic. ✓ PASS
- **Tests Drive Confidence**: Acceptance scenarios from spec (4 per tool) are testable via script execution on target platforms. ✓ PASS
- **Build for Observability**: Installation failures must produce clear error messages (FR-008). ✓ PASS
- **Security by Default**: Uses official binary download sources (dl.k8s.io, GitHub releases) — no third-party scripts. ✓ PASS

## Project Structure

### Documentation (this feature)

```text
specs/001-cli-tool-install/
├── plan.md              # This file (/spec.plan command output)
├── spec.md              # Feature specification
├── research.md          # Phase 0 output — installation approaches researched
├── data-model.md        # Phase 1 output — tool/platform entities
├── quickstart.md        # Phase 1 output — usage guide
├── contracts/           # Phase 1 output — not applicable (no external interfaces)
└── tasks.md             # Phase 2 output (/spec.tasks command - NOT created by /spec.plan)
```

### Source Code (repository root)

```text
.                        # Single shell script at repo root
├── argocd.sh            # Modified: install_tool() function extended for kubectl + argocd
└── specs/               # Feature specifications (this feature)
```

**Structure Decision**: Single-file project. The feature modifies the existing `install_tool()` function in `argocd.sh` and adds two calls to install kubectl and argocd CLI. No new files needed.

## Complexity Tracking

> No constitution violations detected. Complexity tracking is not required.
