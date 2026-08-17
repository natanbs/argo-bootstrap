#!/usr/bin/env bash
# db-backup.sh - Database backup hook runner
# FR-008: Repository-specific database backup hooks using native tools

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
Usage: db-backup.sh [OPTIONS]

Options:
  -r, --repository NAME    Repository name (required)
  -d, --database TYPE      Database type (e.g., postgres, mysql) (required)
  -p, --backup-path PATH   Directory to write backup file (required)
  -n, --namespace NS       Kubernetes namespace (required)
  -t, --timeout SECONDS    Hook execution timeout (default: 300)
  -h, --help               Show this help message

Environment Variables:
  REPOSITORY               Repository name (required)
  DATABASE                 Database type (required)
  BACKUP_PATH              Directory to write backup file (required)
  NAMESPACE                Kubernetes namespace (required)
  TIMEOUT                  Hook execution timeout (default: 300)
EOF
}

# Main backup workflow
main() {
    # Validate required environment variables
    REPOSITORY="${REPOSITORY:?REPOSITORY required}"
    DATABASE="${DATABASE:?DATABASE required}"
    BACKUP_PATH="${BACKUP_PATH:?BACKUP_PATH required}"
    NAMESPACE="${NAMESPACE:?NAMESPACE required}"
    TIMEOUT="${TIMEOUT:-300}"

    log_info "Starting database backup" "db-backup" '{"repository":"'$REPOSITORY'","database":"'$DATABASE'","namespace":"'$NAMESPACE'"}'

    # Create backup directory
    mkdir -p "$BACKUP_PATH"

    # Get timestamp for backup file
    local timestamp
    timestamp="$(date +%Y%m%d-%H%M%S)"

    # Determine backup file extension based on database type
    local extension
    case "$DATABASE" in
        postgres|postgresql)
            extension="sql"
            ;;
        mysql|mariadb)
            extension="sql"
            ;;
        mongo|mongodb)
            extension="bson"
            ;;
        *)
            extension="dump"
            ;;
    esac

    # Set backup file path
    BACKUP_FILE="${BACKUP_PATH}/${REPOSITORY}-${timestamp}.${extension}"

    # Run database-specific backup
    case "$DATABASE" in
        postgres|postgresql)
            _backup_postgres
            ;;
        mysql|mariadb)
            _backup_mysql
            ;;
        mongo|mongodb)
            _backup_mongodb
            ;;
        *)
            echo "Unsupported database type: $DATABASE" >&2
            exit 1
            ;;
    esac

    # Create checksum
    sha256sum "$BACKUP_FILE" > "${BACKUP_FILE}.checksum"

    log_info "Database backup completed" "db-backup" '{"repository":"'$REPOSITORY'","file":"'$BACKUP_FILE'"}'
    exit 0
}

# Backup PostgreSQL
_backup_postgres() {
    log_info "Backing up PostgreSQL" "db-backup"

    # Check if PostgreSQL is running in the namespace
    if ! kubectl get deployment postgres -n "$NAMESPACE" &>/dev/null; then
        echo "PostgreSQL deployment not found in namespace: $NAMESPACE" >&2
        exit 2
    fi

    # Run pg_dump with timeout
    if ! timeout "$TIMEOUT" kubectl exec -n "$NAMESPACE" \
        deployment/postgres -- \
        pg_dump -U postgres "$REPOSITORY" > "$BACKUP_FILE"; then
        echo "PostgreSQL dump failed" >&2
        exit 3
    fi
}

# Backup MySQL
_backup_mysql() {
    log_info "Backing up MySQL" "db-backup"

    # Check if MySQL is running in the namespace
    if ! kubectl get deployment mysql -n "$NAMESPACE" &>/dev/null; then
        echo "MySQL deployment not found in namespace: $NAMESPACE" >&2
        exit 2
    fi

    # Run mysqldump with timeout
    if ! timeout "$TIMEOUT" kubectl exec -n "$NAMESPACE" \
        deployment/mysql -- \
        mysqldump -u root "$REPOSITORY" > "$BACKUP_FILE"; then
        echo "MySQL dump failed" >&2
        exit 3
    fi
}

# Backup MongoDB
_backup_mongodb() {
    log_info "Backing up MongoDB" "db-backup"

    # Check if MongoDB is running in the namespace
    if ! kubectl get deployment mongodb -n "$NAMESPACE" &>/dev/null; then
        echo "MongoDB deployment not found in namespace: $NAMESPACE" >&2
        exit 2
    fi

    # Run mongodump with timeout
    if ! timeout "$TIMEOUT" kubectl exec -n "$NAMESPACE" \
        deployment/mongodb -- \
        mongodump --archive="$BACKUP_FILE" --db="$REPOSITORY"; then
        echo "MongoDB dump failed" >&2
        exit 3
    fi
}

# Parse arguments and run main
parse_args "$@"
main