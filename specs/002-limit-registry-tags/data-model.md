# Data Model: Limit Registry Tags Display

**Date**: 2026-07-21
**Feature**: 002-limit-registry-tags

## Overview

This feature modifies a read-only query script. There is no persistent data model — the script fetches live data from a Docker registry API. Below documents the data structures involved.

## Entities

### Registry Catalog

The response from `GET /v2/_catalog`.

| Field | Type | Description |
|-------|------|-------------|
| repositories | string[] | List of image repository names |

### Tag List

The response from `GET /v2/{repo}/tags/list`.

| Field | Type | Description |
|-------|------|-------------|
| name | string | Repository name |
| tags | string[] | List of tag labels (may be empty or absent) |

## Data Flow

```
Registry API  →  catalog (repositories[])  →  for each repo:
                                                fetch tags list
                                                sort tags alphabetically
                                                [NEW] if not --all: take last 3
                                                display
```

## Validation Rules

- Tags with zero entries: image is listed, no tags shown (existing behavior, preserved)
- Tags sorted alphabetically: `sort` command (existing behavior, preserved)
- Tag limit: at most 3 when `--all` not specified; all when `--all` specified

## State Transitions

None — this is a stateless query script.
