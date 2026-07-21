# Research: Fix Registry Tags Display

**Date**: 2026-07-21
**Feature**: [spec.md](spec.md)

## R1: Human-Readable Version Sorting in Bash

**Decision**: Use `sort -V` (version sort) flag, which is available on both GNU coreutils (Linux) and macOS (BSD sort).

**Rationale**: `sort -V` handles natural number ordering within version segments correctly. Testing confirmed:
- `sort -V` ascending: v1.1.2, v1.1.11, v1.2.0, v2.0.0
- `sort -V -r` descending: v2.0.0, v1.2.0, v1.1.11, v1.1.2

This matches the required behavior where v1.1.2 appears before v1.1.11 (v1.1.11 is "newer").

**Alternatives considered**:
- Manual numeric sort with `sort -t. -k1,1n -k2,2n -k3,3n`: Works but fragile for tags with non-numeric segments (e.g., "latest", "rc1").
- `gsort -V` (GNU coreutils on macOS): Requires Homebrew; `sort -V` already works on modern macOS.
- Custom awk/python sort function: Unnecessarily complex for this use case.

## R2: Flag Parsing Pattern in Bash

**Decision**: Use a `case` statement to parse flags, which is the standard POSIX-compatible approach for simple flag handling.

**Rationale**: The script needs to handle three cases: no flags (default), `-f`/`--full`, and `-h`/`--help`. A `case` statement is simple, readable, and portable across all target platforms.

**Alternatives considered**:
- `getopts` builtin: Supports only short flags (`-f`), not long flags (`--full`).
- `getopt` (external command): Different behavior between GNU and BSD versions; adds complexity.

## R3: Truncating Tags After Version Sort

**Decision**: Pipe the version-sorted output through `head -n 3` to limit to the last 3 tags when no flag is provided.

**Rationale**: Since `sort -V -r` puts the most recent version first, `head -n 3` naturally selects the 3 most recent tags. This is simpler than sorting ascending and using `tail`.

**Alternatives considered**:
- Sort ascending + `tail -n 3`: Functionally equivalent but less intuitive (reading bottom-up).
- Array slicing in bash: More complex, requires bashisms beyond POSIX.

## R4: Help Message Format

**Decision**: Print a concise 3-line usage message to stdout and exit 0 when `-h`/`--help` is provided.

**Rationale**: Standard CLI convention. The help message should describe the script purpose, available flags, and default behavior. Exiting 0 (not non-zero) on `--help` is the standard convention.

**Alternatives considered**:
- Print to stderr: Non-standard for `--help`; stderr is better for error messages.
- Use `man` page: Overkill for a simple 8-line script.
