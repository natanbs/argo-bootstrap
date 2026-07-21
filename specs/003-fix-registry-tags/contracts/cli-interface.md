# CLI Interface Contract: reg.sh

**Date**: 2026-07-21
**Feature**: [spec.md](spec.md)

## Command

```
./reg.sh [OPTIONS]
```

## Options

| Flag | Long Form | Description | Default |
|------|-----------|-------------|---------|
| `-h` | `--help` | Display help/usage message | — |
| `-f` | `--full` | Show all tags (no limit) | — |

## Behavior Matrix

| Invocation | Output | Exit Code |
|------------|--------|-----------|
| `./reg.sh` | All images with at most 3 tags each, version-sorted descending | 0 |
| `./reg.sh -f` | All images with all tags, version-sorted descending | 0 |
| `./reg.sh --full` | Same as `-f` | 0 |
| `./reg.sh -h` | Help message to stdout | 0 |
| `./reg.sh --help` | Same as `-h` | 0 |
| `./reg.sh -x` (invalid) | Usage hint to stderr | non-zero |

## Output Format

### Default mode (no flags)

```
Image: <repository-name>
Tags:
  - <tag1>    (most recent)
  - <tag2>
  - <tag3>    (3rd most recent)
-------------------
```

### Full mode (`-f`/`--full`)

```
Image: <repository-name>
Tags:
  - <tag1>    (most recent)
  - <tag2>
  - <tag3>
  - ...       (all tags, version-sorted descending)
-------------------
```

### Help mode (`-h`/`--help`)

```
Usage: reg.sh [OPTIONS]
List container images and tags from the local registry.

Options:
  -h, --help    Show this help message
  -f, --full    Show all tags (default: show last 3)
```

## Sorting Contract

- Tags are always sorted in **descending version order** using `sort -V -r`
- v1.1.11 is considered "newer" than v1.1.2 (natural number ordering)
- Image names are sorted alphabetically (ascending) using `sort`
