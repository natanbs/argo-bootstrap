#!/usr/bin/env bash

REGISTRY_URL="http://localhost:50000"

show_help() {
    echo "Usage: reg.sh [OPTIONS]"
    echo "List container images and tags from the local registry."
    echo ""
    echo "Options:"
    echo "  -h, --help    Show this help message"
    echo "  -f, --full    Show all tags (default: show last 3)"
}

SHOW_ALL=false

case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    -f|--full)
        SHOW_ALL=true
        ;;
    "")
        ;;
    *)
        echo "Usage: reg.sh [-h|--help] [-f|--full]" >&2
        exit 1
        ;;
esac

curl -s "$REGISTRY_URL/v2/_catalog" | jq -r '.repositories[]' | sort | while read -r repo; do
    echo "Image: $repo"
    echo "Tags:"
    TAGS=$(curl -s "$REGISTRY_URL/v2/$repo/tags/list" | jq -r '.tags[]?' | sort -V -r)
    if [ "$SHOW_ALL" = true ]; then
        echo "$TAGS" | while read -r tag; do
            [ -n "$tag" ] && echo "  - $tag"
        done
    else
        echo "$TAGS" | head -n 3 | while read -r tag; do
            [ -n "$tag" ] && echo "  - $tag"
        done
    fi
    echo "-------------------"
done
