# Data Model: Fix Registry Tags Display

**Date**: 2026-07-21
**Feature**: [spec.md](spec.md)

This feature does not introduce new data entities or modify existing data structures. It modifies the display logic of an existing script that reads from an external Docker registry API.

## Existing Entities (read-only)

### Registry Image

- **Source**: Docker registry v2 API (`/v2/_catalog`)
- **Fields**:
  - `repositories[]` — array of image repository names (strings)
- **Behavior**: List is fetched and sorted alphabetically for display

### Image Tag

- **Source**: Docker registry v2 API (`/v2/{repo}/tags/list`)
- **Fields**:
  - `tags[]` — array of tag names (strings)
- **Behavior**: Tags are now sorted using version-aware sort (`sort -V`) instead of plain alphabetical sort, and limited to 3 by default

## State Transitions

None. This is a display-only script with no persistent state.
