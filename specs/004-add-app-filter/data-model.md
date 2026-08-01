# Data Model: Add App Filter Flag

**Date**: 2026-07-21
**Feature**: [spec.md](spec.md)

This feature does not introduce new data entities or modify existing data structures. It adds a filter parameter to the display logic.

## Existing Entities (read-only)

### Registry Image

- **Source**: Docker registry v2 API (`/v2/_catalog`)
- **Fields**:
  - `repositories[]` — array of image repository names (strings)
- **Behavior**: List is fetched and filtered by app name (if provided), then sorted alphabetically for display

### Image Tag

- **Source**: Docker registry v2 API (`/v2/{repo}/tags/list`)
- **Fields**:
  - `tags[]` — array of tag names (strings)
- **Behavior**: Tags are sorted using version-aware sort (`sort -V -r`) and limited to 3 by default (or all with `-f`)

### App Filter (new parameter)

- **Source**: User-provided CLI argument (`-a`/`--app`)
- **Fields**:
  - `APP_NAME` — string, exact repository name to match
- **Behavior**: When provided, only the matching repository is displayed. When not provided, all repositories are displayed.
- **Validation**: Must be non-empty; if missing value, script exits with usage hint.

## State Transitions

None. This is a display-only script with no persistent state.
