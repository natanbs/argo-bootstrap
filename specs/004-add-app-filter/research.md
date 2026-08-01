# Research: Add App Filter Flag

**Date**: 2026-07-21
**Feature**: [spec.md](spec.md)

## R1: Multi-Argument Flag Parsing in Bash

**Decision**: Replace the single `case` statement with a `while` loop that uses `shift` to consume arguments, allowing `-a <app>` to be parsed alongside `-f` and `-h`.

**Rationale**: The current `case "${1:-}"` only handles the first argument. With `-a <app>`, we need to parse `-a` followed by its value, while still supporting `-f` (boolean) and `-h` (boolean). A `while [ $# -gt 0 ]` loop with `case` inside is the standard bash pattern for multi-argument flag parsing.

**Alternatives considered**:
- `getopts` builtin: Only supports short flags, not long flags (`--app`). Cannot handle `--app` without额外 work.
- `getopt` external command: Different behavior between GNU and BSD versions; adds portability complexity.
- Positional argument detection (`$2` after `-a`): Fragile if flags are combined in different orders.

## R2: Filtering by Repository Name

**Decision**: Filter the repository list using `grep -x` for exact match before entering the display loop, or skip non-matching repos inside the loop.

**Rationale**: Two approaches:
1. **Pre-filter**: Pipe the catalog through `grep -x "$APP"` before the while loop — simpler, but requires an extra curl call or subshell.
2. **In-loop filter**: Check `$repo == "$APP"` inside the while loop and skip if no match — no extra subprocess, natural for the existing loop structure.

Chosen: In-loop filter (option 2). It avoids extra subprocesses and integrates naturally with the existing loop. A `FOUND` flag tracks whether any match was found to display the "no match" message.

**Alternatives considered**:
- `jq` filter: Could filter at the API response level, but the catalog API doesn't support filtering by name.
- `grep -x` pre-filter: Functionally equivalent but adds a subprocess and requires capturing the full catalog first.

## R3: Handling `-a` Without a Value

**Decision**: After consuming `-a`/`--app`, check if `$#` is 0 (no more arguments) or if the next argument starts with `-` (another flag). If so, print usage to stderr and exit 1.

**Rationale**: This prevents `-a` from consuming the next flag as its value (e.g., `-a -f` should not treat `-f` as the app name). The check `$# -eq 0` or `case "$1" in -*)` handles both end-of-args and flag-as-value cases.

**Alternatives considered**:
- Always consume next arg: Would incorrectly treat `-f` as an app name in `-a -f`.
- Require `=` syntax (`--app=api`): Non-standard for shell scripts, less user-friendly.
