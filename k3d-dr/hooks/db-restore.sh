#!/usr/bin/env bash
# db-restore.sh - Database restore hook runner
# FR-008: Repository-specific database restore hooks using native tools

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../lib"

# Source libraries
source "$LIB_DIR/logging.sh"
source "$LIB_DIR/errors.sh"

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -r|--repository)
                REPOSITORY="$2"
                shift 2
                ;;
            -d|--database)
                DATABASE="$2"
                shift 2
                ;;
            -p|--backup-path)
                BACKUP_PATH="$2"
                shift 2
                ;;
            -n|--namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            -t|--timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                show_help
                exit 1
                ;;
        esac
    done
}

# Show help
show_help() {
    cat << EOF
Usage: db-restore.sh [OPTIONS]

Options:
  -r, --repository NAME    Repository name (required)
  -d, --database TYPE      Database type (e.g., postgres, mysql) (required)
  -p, --backup-path PATH   Directory containing backup file (required)
  -n, --namespace NS       Kubernetes namespace (required)
  -t, --timeout SECONDS    Hook execution timeout (default: 300)
  -h, --help               Show this help message

Environment Variables:
  REPOSITORY               Repository name (required)
  DATABASE                 Database type (required)
  BACKUP_PATH              Directory containing backup file (required)
  NAMESPACE                Kubernetes namespace (required)
  TIMEOUT                  Hook execution timeout (default: 300)
EOF
}

# Main restore workflow
main() {
    # Validate required environment variables
    REPOSITORY="${REPOSITORY:?REPOSITORY required}"
    DATABASE="${DATABASE:?DATABASE required}"
    BACKUP_PATH="${BACKUP_PATH:?BACKUP_PATH required}"
    NAMESPACE="${NAMESPACE:?NAMESPACE required}"
    TIMEOUT="${TIMEOUT:-300}"

    log_info "Starting database restore" "db-restore" '{"repository":"'$REPOSITORY'","database":"'$DATABASE'","namespace":"'$NAMESPACE'"}'

    # Find backup file
    local backup_file
    backup_file="$(find_backup_file)"

    if [[ -z "$backup_file" ]]; then
        echo "No backup file found for repository: $REPOSITORY" >&2
        exit 1
    fi

    # Verify checksum
    if ! verify_checksum "$backup_file"; then
        echo "Checksum verification failed for: $backup_file" >&2
        exit 3
    fi

    # Run database-specific restore
    case "$DATABASE" in
        postgres|postgresql)
            _restore_postgres "$backup_file"
            ;;
        mysql|mariadb)
            _restore_mysql "$backup_file"
            ;;
        mongo|mongodb)
            _restore_mongodb "$backup_file"
            ;;
        *)
            echo "Unsupported database type: $DATABASE" >&2
            exit 1
            ;;
    esac

    log_info "Database restore completed" "db-restore" '{"repository":"'$REPOSITORY'","file":"'$backup_file'"}'
    exit 0
}

# Find backup file
find_backup_file() {
    # Look for backup file with various extensions
    local extensions=("sql" "dump" "bson" "gz")

    for ext in "${extensions[@]}"; do
        local file
        file="$(ls -t "${BACKUP_PATH}/${REPOSITORY}"-*.${ext} 2>/dev/null | head -1)"

        if [[ -n "$file" ]]; then
            echo "$file"
            return 0
        fi
    done

    # Fallback to any file matching the pattern
    ls -t "${BACKUP_PATH}/${REPOSITORY}"-* 2>/dev/null | head -1
}

# Verify checksum
verify_checksum() {
    local backup_file="$1"
    local checksum_file="${backup_file}.checksum"

    if [[ ! -f "$checksum_file" ]]; then
        echo "Warning: Checksum file not found: $checksum_file" >&2
        return 0
    fi

    sha256sum -c "$checksum_file"
}

# Restore PostgreSQL
_restore_postgres() {
    local backup_file="$1"

    log_info "Restoring PostgreSQL" "db-restore"

    # Check if PostgreSQL is running in the namespace
    if ! kubectl get deployment postgres -n "$NAMESPACE" &>/dev/null; then
        echo "PostgreSQL deployment not found in namespace: $NAMESPACE" >&2
        exit 2
    fi

    # Run psql with timeout
    if ! timeout "$TIMEOUT" kubectl exec -i -n "$NAMESPACE" \
        deployment/postgres -- \
        psql -U postgres "$REPOSITORY" < "$backup_file"; then
        echo "PostgreSQL restore failed" >&2
        exit 4
    fi
}

# Restore MySQL
_restore_mysql() {
    local backup_file="$1"

    log_info "Restoring MySQL" "db-restore"

    # Check if MySQL is running in the namespace
    if ! kubectl get deployment mysql -n "$NAMESPACE" &>/dev/null; then
        echo "MySQL deployment not found in namespace: $NAMESPACE" >&2
        exit 2
    fi

    # Run mysql with timeout
    if ! timeout "$TIMEOUT" kubectl exec -i -n "$NAMESPACE" \
        deployment/mysql -- \
        mysql -u root "$REPOSITORY" < "$backup_file"; then
        echo "MySQL restore failed" >&2
        exit 4
    fi
}

# Restore MongoDB
_restore_mongodb() {
    local backup_file="$1"

    log_info "Restoring MongoDB" "db-restore"

    # Check if MongoDB is running in the namespace
    if ! kubectl get deployment mongodb -n "$NAMESPACE" &>/dev/null; then
        echo "MongoDB deployment not found in namespace: $NAMESPACE" >&2
        exit 2
    fi

    # Run mongorestore with timeout
    if ! timeout "$TIMEOUT" kubectl exec -i -n "$NAMESPACE" \
        deployment/mongodb -- \
        mongorestore --archive="$backup_file" --db="$REPOSITORY"; then
        echo "MongoDB restore failed" >&2
        exit 4
    fi
}

# Parse arguments and run main
parse_args "$@"
main