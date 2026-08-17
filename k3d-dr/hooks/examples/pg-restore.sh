#!/usr/bin/env bash
# pg-restore.sh - Example PostgreSQL restore hook
# This is an example hook for restoring PostgreSQL databases

set -euo pipefail

# Required environment variables
REPOSITORY="${REPOSITORY:?REPOSITORY required}"
DATABASE="${DATABASE:?DATABASE required}"
BACKUP_PATH="${BACKUP_PATH:?BACKUP_PATH required}"
NAMESPACE="${NAMESPACE:?NAMESPACE required}"
TIMEOUT="${TIMEOUT:-300}"

# Find backup file
BACKUP_FILE=$(ls -t "${BACKUP_PATH}/${REPOSITORY}"-*.sql 2>/dev/null | head -1)
if [ -z "$BACKUP_FILE" ]; then
  echo "No backup file found for repository: $REPOSITORY"
  exit 1
fi

# Verify checksum
if ! sha256sum -c "${BACKUP_FILE}.checksum"; then
  echo "Checksum verification failed for: $BACKUP_FILE"
  exit 3
fi

# Run pg_restore with timeout
timeout "$TIMEOUT" kubectl exec -i -n "$NAMESPACE" \
  deployment/postgres -- \
  psql -U postgres "$DATABASE" < "$BACKUP_FILE"

echo "Restore completed: $BACKUP_FILE"
exit 0