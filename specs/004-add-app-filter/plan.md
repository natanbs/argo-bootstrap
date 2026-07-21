# Implementation Plan: Add App Filter Flag

**Branch**: `main` | **Date**: 2026-07-21 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/004-add-app-filter/spec.md`

## Summary

Add `-a`/`--app <app>` flag to the existing `reg.sh` script that filters output to a single container image by exact repository name match. The flag combines with existing `-f`/`--full` behavior. Single-file change — no new dependencies, no architectural changes.

## Technical Context

**Language/Version**: Bash (POSIX-compatible shell script)
**Primary Dependencies**: curl, jq (existing — no new dependencies)
**Storage**: N/A — queries a live Docker registry HTTP API
**Testing**: Manual testing against local registry at `localhost:50000`
**Target Platform**: macOS / Linux (any system with Bash, curl, jq)
**Project Type**: CLI tool / shell script
**Performance Goals**: N/A — simple utility, output under 1 second per image
**Constraints**: No new external dependencies beyond curl, jq, sort
**Scale/Scope**: Single file modification (`reg.sh`, currently 46 lines)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Constitution is a placeholder template with no defined principles. No gates to evaluate. Pass.

## Project Structure

### Documentation (this feature)

```text
specs/004-add-app-filter/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (CLI interface contract)
└── tasks.md             # Phase 2 output (/spec.tasks command - NOT created by /spec.plan)
```

### Source Code (repository root)

```text
reg.sh                  # Modified: add -a/--app flag parsing and filtering logic
```

**Structure Decision**: Single-file modification. `reg.sh` is the only source file affected. No new files or directories needed in the source tree.

## Triage Framework: [SYNC] vs [ASYNC] Classification

**Execution Strategy**: This feature uses a simple [SYNC] execution model — single-file shell script modification with no complex architecture.

### Preliminary Task Classification

| Task Category | Estimated [SYNC] Tasks | Estimated [ASYNC] Tasks | Rationale |
|---------------|----------------------|----------------------|-----------|
| Business Logic | 1 | 0 | Flag parsing and filtering is simple pipeline logic |
| Data Operations | 0 | 0 | No data model changes |
| UI Components | 0 | 0 | N/A |
| Integrations | 0 | 0 | No new integrations |
| Infrastructure | 0 | 0 | No infrastructure changes |

### Triage Decision Criteria Applied

**High-Risk [SYNC] Classifications:**

- None — trivial single-file change

**Agent-Delegated [ASYNC] Classifications:**

- None — scope too small to benefit from delegation

### Triage Audit Trail

| Task | Classification | Primary Criteria | Risk Level | Rationale |
|------|----------------|------------------|------------|-----------|
| Modify reg.sh | SYNC | Simplicity | Low | 46-line script, clear requirements, no dependencies |

## Complexity Tracking

No constitution violations. No complexity justifications needed.
