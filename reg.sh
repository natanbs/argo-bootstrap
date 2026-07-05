REGISTRY_URL="http://localhost:50000"

curl -s "$REGISTRY_URL/v2/_catalog" | jq -r '.repositories[]' | while read -r repo; do
    echo "Image: $repo"
    echo "Tags:"
    curl -s "$REGISTRY_URL/v2/$repo/tags/list" | jq -r '.tags[]? | "  - \(.)"'
    echo "-------------------"
done
