#!/usr/bin/env bash
# pg-backup.sh - Example PostgreSQL backup hook
# This is an example hook for backing up PostgreSQL databases

set -euo pipefail

# Required environment variables
REPOSITORY="${REPOSITORY:?REPOSITORY required}"
DATABASE="${DATABASE:?DATABASE required}"
BACKUP_PATH="${BACKUP_PATH:?BACKUP_PATH required}"
NAMESPACE="${NAMESPACE:?NAMESPACE required}"
TIMEOUT="${TIMEOUT:-300}"

# Create backup file
BACKUP_FILE="${BACKUP_PATH}/${REPOSITORY}-$(date +%Y%m%d-%H%M%S).sql"

# Run pg_dump with timeout
timeout "$TIMEOUT" kubectl exec -n "$NAMESPACE" \
  deployment/postgres -- \
  pg_dump -U postgres "$DATABASE" > "$BACKUP_FILE"

# Create checksum
sha256sum "$BACKUP_FILE" > "${BACKUP_FILE}.checksum"

echo "Backup created: $BACKUP_FILE"
exit 0