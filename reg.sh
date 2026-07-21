#!/usr/bin/env bash

REGISTRY_URL="http://localhost:50000"

show_help() {
    echo "Usage: reg.sh [OPTIONS] [-a <app>]"
    echo "List container images and tags from the local registry."
    echo ""
    echo "Options:"
    echo "  -h, --help        Show this help message"
    echo "  -f, --full        Show all tags (default: show last 3)"
    echo "  -a, --app <app>   Show tags only for the specified image"
}

SHOW_ALL=false
APP=""

while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -f|--full)
            SHOW_ALL=true
            shift
            ;;
        -a|--app)
            if [ $# -lt 2 ] || case "$2" in -*) true;; *) false;; esac; then
                echo "Usage: reg.sh [-h|--help] [-f|--full] [-a|--app <app>]" >&2
                exit 1
            fi
            APP="$2"
            shift 2
            ;;
        *)
            echo "Usage: reg.sh [-h|--help] [-f|--full] [-a|--app <app>]" >&2
            exit 1
            ;;
    esac
done

FOUND=false

while read -r repo; do
    if [ -n "$APP" ] && [ "$repo" != "$APP" ]; then
        continue
    fi
    FOUND=true
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
done < <(curl -s "$REGISTRY_URL/v2/_catalog" | jq -r '.repositories[]' | sort)

if [ -n "$APP" ] && [ "$FOUND" = false ]; then
    echo "No matching image found for: $APP"
fi
