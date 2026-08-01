# Quickstart: Add App Filter Flag

**Date**: 2026-07-21
**Feature**: [spec.md](spec.md)

## Prerequisites

- Bash shell
- `curl` and `jq` installed
- A Docker registry running at `localhost:50000` (or modify `REGISTRY_URL` in the script)
- At least one image pushed to the registry

## Usage

```bash
# Show last 3 tags for a specific image
./reg.sh -a api
./reg.sh --app api

# Show all tags for a specific image
./reg.sh -a api -f
./reg.sh --app api --full

# Show help (includes new -a option)
./reg.sh -h

# Show all images (existing behavior)
./reg.sh
./reg.sh -f
```

## What Changed

- **New flag `-a`/`--app <app>`**: Filters output to only the specified image
- **Combinable with `-f`**: `-a api -f` shows all tags for "api"
- **No match feedback**: Shows "No matching image found" when app not found
- **Updated help**: `-h` now documents the `-a` option

## Testing

1. Start a local registry: `docker run -d -p 50000:5000 registry:2`
2. Push multiple images with tags
3. Run `./reg.sh -a <image-name>` and verify only that image is shown
4. Run `./reg.sh -a <image-name> -f` and verify all tags shown
5. Run `./reg.sh -a nonexistent` and verify "no match" message
6. Run `./reg.sh -h` and verify help includes `-a` option
