#!/usr/bin/env bash
set -euo pipefail

REGISTRY_URL="http://localhost:50000"

usage() {
  echo "Usage: $0 <image> <tag>"
  echo
  echo "Examples:"
  echo "  $0 argo-app-go-server v1.0"
  echo "  $0 my-image latest"
  exit 1
}

[ $# -lt 2 ] && usage

IMAGE="$1"
TAG="$2"

# Get manifest digest (try Docker manifest first, then OCI index)
DIGEST=""
for ACCEPT in \
  "application/vnd.docker.distribution.manifest.v2+json" \
  "application/vnd.docker.distribution.manifest.list.v2+json" \
  "application/vnd.oci.image.index.v1+json" \
  "application/vnd.oci.image.manifest.v1+json"; do
  HEADER=$(curl -sI \
    -H "Accept: $ACCEPT" \
    "$REGISTRY_URL/v2/$IMAGE/manifests/$TAG" 2>/dev/null) || true
  DIGEST=$(echo "$HEADER" | grep -i docker-content-digest | awk '{print $2}' | tr -d '\r') || true
  [ -n "$DIGEST" ] && break
done

if [ -z "$DIGEST" ]; then
  echo "Error: Could not get digest for $IMAGE:$TAG"
  exit 1
fi

echo "Digest: $DIGEST"

# Delete manifest
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE \
  "$REGISTRY_URL/v2/$IMAGE/manifests/$DIGEST")

if [ "$HTTP_CODE" = "202" ] || [ "$HTTP_CODE" = "200" ]; then
  echo "Deleted $IMAGE:$TAG"
  echo "Run garbage collection to reclaim disk space:"
  echo "  docker exec -it \$(docker ps -q -f name=k3d-reg) bin/registry garbage-collect /etc/docker/registry/config.yml"
else
  echo "Error: Delete failed (HTTP $HTTP_CODE)"
  exit 1
fi
