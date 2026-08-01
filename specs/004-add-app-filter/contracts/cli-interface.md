# CLI Interface Contract: reg.sh (with App Filter)

**Date**: 2026-07-21
**Feature**: [spec.md](spec.md)

## Command

```
./reg.sh [OPTIONS] [-a <app>]
```

## Options

| Flag | Long Form | Argument | Description | Default |
|------|-----------|----------|-------------|---------|
| `-h` | `--help` | none | Display help/usage message | — |
| `-f` | `--full` | none | Show all tags (no limit) | — |
| `-a` | `--app` | `<app>` | Show tags only for the specified image | — (show all) |

## Behavior Matrix

| Invocation | Output | Exit Code |
|------------|--------|-----------|
| `./reg.sh` | All images, at most 3 tags each, version-sorted | 0 |
| `./reg.sh -f` | All images, all tags, version-sorted | 0 |
| `./reg.sh -a api` | Only "api" image, at most 3 tags | 0 |
| `./reg.sh -a api -f` | Only "api" image, all tags | 0 |
| `./reg.sh --app api --full` | Same as `-a api -f` | 0 |
| `./reg.sh -h` | Help message | 0 |
| `./reg.sh -a` (no value) | Usage hint to stderr | 1 |
| `./reg.sh -a nonexistent` | "No matching image" message | 0 |
| `./reg.sh -x` (invalid) | Usage hint to stderr | 1 |

## Output Format

### Default mode with app filter

```
Image: <matched-repository>
Tags:
  - <tag1>
  - <tag2>
  - <tag3>
-------------------
```

### No match

```
No matching image found for: <app>
```

### Help (updated)

```
Usage: reg.sh [OPTIONS] [-a <app>]
List container images and tags from the local registry.

Options:
  -h, --help        Show this help message
  -f, --full        Show all tags (default: show last 3)
  -a, --app <app>   Show tags only for the specified image
```

## Sorting Contract

- Tags are always sorted in **descending version order** using `sort -V -r`
- Image names are sorted alphabetically (ascending) when listing all images
- When `-a` is used, only the matching image is shown (no image-level sorting needed)
