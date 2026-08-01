# Quickstart: Fix Registry Tags Display

**Date**: 2026-07-21
**Feature**: [spec.md](spec.md)

## Prerequisites

- Bash shell
- `curl` and `jq` installed
- A Docker registry running at `localhost:50000` (or modify `REGISTRY_URL` in the script)

## Usage

```bash
# Show last 3 tags per image (default)
./reg.sh

# Show all tags per image
./reg.sh -f
./reg.sh --full

# Show help
./reg.sh -h
./reg.sh --help
```

## What Changed

- **Default behavior**: Shows only the 3 most recent tags per image (was: all tags)
- **New flag `-f`/`--full`**: Shows all tags (restores original behavior)
- **New flag `-h`/`--help`**: Displays usage information
- **Sorting**: Tags are now version-sorted (v1.1.2 before v1.1.11) instead of plain alphabetical

## Testing

1. Start a local registry: `docker run -d -p 50000:5000 registry:2`
2. Push some images with multiple tags
3. Run `./reg.sh` and verify only 3 tags shown per image
4. Run `./reg.sh -f` and verify all tags shown
5. Run `./reg.sh -h` and verify help message displayed
