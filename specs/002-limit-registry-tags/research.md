# Research: Limit Registry Tags Display

**Date**: 2026-07-21
**Feature**: 002-limit-registry-tags

## Summary

All technical context items resolved. No NEEDS CLARIFICATION items remain. This is a minimal change to an existing 8-line Bash script.

## Decisions

### 1. Tag limiting approach

**Decision**: Use `tail -n 3` (or equivalent) in the pipeline after sorting tags.

**Rationale**: The existing script already pipes tags through `sort`. Adding `tail -n 3` after the sort preserves the "last 3 in sorted order" requirement with zero new dependencies. The `tail` command is available on all target platforms (macOS, Linux).

**Alternatives considered**:
- `head -n 3`: Would show first 3 alphabetically, not last 3. Wrong semantics.
- `awk` with NR > N-3: More complex, no benefit over `tail`.
- `jq` slicing (`.tags[-3:]`): Possible but couples logic to jq; `tail` is simpler and more portable for this use case.

### 2. Flag parsing approach

**Decision**: Simple `case` statement at the top of the script to check for `-a` or `--all`. Set a variable `SHOW_ALL=true/false`.

**Rationale**: Bash `case` is the idiomatic way to handle simple flag parsing in shell scripts. No need for `getopt` or `getopts` for a single flag. Supports both short (`-a`) and long (`--all`) forms.

**Alternatives considered**:
- `getopts`: Built-in but designed for multiple short flags; overkill for one flag.
- `getopt` (external): Not portable between macOS and Linux without GNU extensions.
- Positional argument check: Less clear, doesn't support `--all` long form.

### 3. Invalid flag handling

**Decision**: After the `case` statement, if no valid flag matched and `$1` starts with `-`, print usage to stderr and exit 1.

**Rationale**: Matches the clarified spec requirement (FR-007). Distinguishes between "no flags" (default behavior) and "invalid flag" (error). Non-zero exit code enables use in scripts.

**Alternatives considered**:
- Ignoring unknown flags: Specified against in clarification session.
- Using `--` as end-of-flags marker: Not needed for single flag.

### 4. Usage message format

**Decision**: `echo "Usage: reg.sh [-a|--all]" >&2`

**Rationale**: Minimal, follows CLI convention. Stderr ensures it doesn't interfere with pipe-able output.

## Open Questions

None. All technical decisions resolved.
