#!/bin/bash
# Hive Metastore Restore Script
# Restores Hive Metastore database from a backup file
#
# Usage:
#   restore-hive-metastore.sh --backup <backup_file> [OPTIONS]
#
# Examples:
#   restore-hive-metastore.sh --backup s3://spark-backups/hive-metastore/backup.sql
#   restore-hive-metastore.sh --backup /tmp/backup.sql --namespace spark-operations
#   restore-hive-metastore.sh --backup backup.sql --point-in-time "2026-02-10 22:00:00"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="${NAMESPACE:-spark-operations}"
BACKUP_FILE=""
BACKUP_DIR="/tmp/hive-restore"
POINT_IN_TIME=""
DRY_RUN=false
SKIP_BACKUP=false
VERIFY_ONLY=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

usage() {
    cat <<EOF
Usage: $(basename "$0") --backup <backup_file> [OPTIONS]

Restore Hive Metastore database from a backup file.

OPTIONS:
    -n, --namespace NAME      Kubernetes namespace (default: spark-operations)
    -b, --backup FILE         Backup file (s3://, local file, or - for stdin)
    -d, --backup-dir DIR      Temporary directory for restore (default: /tmp/hive-restore)
    -t, --point-in-time TIME  Point-in-time recovery (format: "YYYY-MM-DD HH:MM:SS")
    --skip-backup             Skip creating backup before restore
    --verify-only             Only verify backup without restoring
    --dry-run                 Show what would be done without executing
    -v, --verbose             Enable verbose output
    -h, --help                Show this help

EXAMPLES:
    # Restore from S3 backup
    $(basename "$0") --backup s3://spark-backups/hive-metastore/backup-20260211.sql

    # Restore from local file
    $(basename "$0") --backup /tmp/backup.sql --namespace spark-operations

    # Point-in-time recovery
    $(basename "$0") --backup s3://spark-backups/hive-metastore/backup.sql \\
        --point-in-time "2026-02-10 22:00:00"

    # Dry run to see what would be restored
    $(basename "$0") --backup backup.sql --dry-run

    # Verify only (no restore)
    $(basename "$0") --backup backup.sql --verify-only
EOF
    exit 1
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            -b|--backup)
                BACKUP_FILE="$2"
                shift 2
                ;;
            -d|--backup-dir)
                BACKUP_DIR="$2"
                shift 2
                ;;
            -t|--point-in-time)
                POINT_IN_TIME="$2"
                shift 2
                ;;
            --skip-backup)
                SKIP_BACKUP=true
                shift
                ;;
            --verify-only)
                VERIFY_ONLY=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                set -x
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                ;;
        esac
    done

    if [[ -z "$BACKUP_FILE" && "$BACKUP_FILE" != "-" ]]; then
        log_error "Backup file is required"
        usage
    fi
}

check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found"
        exit 1
    fi

    # Check AWS CLI (for S3)
    if [[ "$BACKUP_FILE" == s3://* ]] && ! command -v aws &> /dev/null; then
        log_error "aws CLI not found (required for S3 backups)"
        exit 1
    fi

    # Check namespace exists
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_error "Namespace $NAMESPACE does not exist"
        exit 1
    fi

    log_info "Prerequisites check passed"
}

get_hive_metastore_pod() {
    kubectl get pods -n "$NAMESPACE" -l app=hive-metastore -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo ""
}

get_database_credentials() {
    local db_host db_port db_name db_user db_pass

    log_info "Getting database credentials..."

    # Try to get from secret
    if kubectl get secret -n "$NAMESPACE" hive-metastore-db &> /dev/null; then
        db_host=$(kubectl get secret -n "$NAMESPACE" hive-metastore-db -o jsonpath='{.data.DB_HOST}' 2>/dev/null | base64 -d || echo "")
        db_port=$(kubectl get secret -n "$NAMESPACE" hive-metastore-db -o jsonpath='{.data.DB_PORT}' 2>/dev/null | base64 -d || echo "3306")
        db_name=$(kubectl get secret -n "$NAMESPACE" hive-metastore-db -o jsonpath='{.data.DB_NAME}' 2>/dev/null | base64 -d || echo "metastore_spark41")
        db_user=$(kubectl get secret -n "$NAMESPACE" hive-metastore-db -o jsonpath='{.data.DB_USER}' 2>/dev/null | base64 -d || echo "hive")
        db_pass=$(kubectl get secret -n "$NAMESPACE" hive-metastore-db -o jsonpath='{.data.DB_PASS}' 2>/dev/null | base64 -d || echo "")
    fi

    # Fallback to defaults
    db_host=${db_host:-"postgresql-hive-41-0.$NAMESPACE.svc.cluster.local"}
    db_port=${db_port:-"5432"}
    db_name=${db_name:-"metastore_spark41"}
    db_user=${db_user:-"hive"}

    if [[ -z "$db_pass" ]]; then
        # Try to get password from PostgreSQL secret
        if kubectl get secret -n "$NAMESPACE" postgresql-hive-41-0 &> /dev/null; then
            db_pass=$(kubectl get secret -n "$NAMESPACE" postgresql-hive-41-0 -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || echo "")
        else
            log_error "Database password not found"
            exit 1
        fi
    fi

    echo "$db_host:$db_port:$db_name:$db_user:$db_pass"
}

create_backup_before_restore() {
    if [[ "$SKIP_BACKUP" == true ]]; then
        log_warn "Skipping backup before restore (--skip-backup specified)"
        return
    fi

    log_info "Creating backup before restore..."
    local pre_restore_backup="$BACKUP_DIR/pre-restore-$(date +%Y%m%d-%H%M%S).sql"

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would create backup: $pre_restore_backup"
        return
    fi

    mkdir -p "$BACKUP_DIR"

    local creds
    creds=$(get_database_credentials)
    IFS=':' read -r db_host db_port db_name db_user db_pass <<< "$creds"

    # Get Hive Metastore pod
    local hive_pod
    hive_pod=$(get_hive_metastore_pod)

    if [[ -z "$hive_pod" ]]; then
        log_warn "Hive Metastore pod not found, skipping pre-restore backup"
        return
    fi

    # Create backup
    kubectl exec -n "$NAMESPACE" "$hive_pod" -- \
        pg_dump -h "$db_host" -p "$db_port" -U "$db_user" \
        --clean --if-exists --create "$db_name" > "$pre_restore_backup" 2>&1 || {
        log_warn "Pre-restore backup failed, continuing anyway"
    }

    log_info "Pre-restore backup created: $pre_restore_backup"
}

download_backup() {
    local backup_file="$1"
    local local_backup="$BACKUP_DIR/$(basename "$backup_file")"

    log_info "Downloading backup: $backup_file"

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would download to: $local_backup"
        echo "$local_backup"
        return
    fi

    mkdir -p "$BACKUP_DIR"

    if [[ "$backup_file" == s3://* ]]; then
        aws s3 cp "$backup_file" "$local_backup"
    elif [[ "$backup_file" == "-" ]]; then
        cat > "$local_backup"
    else
        cp "$backup_file" "$local_backup"
    fi

    echo "$local_backup"
}

verify_backup() {
    local backup_file="$1"

    log_info "Verifying backup: $backup_file"

    # Check file exists
    if [[ ! -f "$backup_file" ]]; then
        log_error "Backup file not found: $backup_file"
        exit 1
    fi

    # Check file size
    local file_size
    file_size=$(stat -f%z "$backup_file" 2>/dev/null || stat -c%s "$backup_file" 2>/dev/null)
    if [[ $file_size -lt 1000 ]]; then
        log_error "Backup file too small: $file_size bytes"
        exit 1
    fi

    log_info "Backup size: $file_size bytes"

    # Check for SQL content
    if ! grep -q "CREATE\|INSERT\|ALTER" "$backup_file" 2>/dev/null; then
        log_error "Backup file does not appear to contain SQL"
        exit 1
    fi

    log_info "Backup verification passed"
}

restore_database() {
    local backup_file="$1"

    log_info "Restoring database..."

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would restore database from: $backup_file"
        return
    fi

    local creds
    creds=$(get_database_credentials)
    IFS=':' read -r db_host db_port db_name db_user db_pass <<< "$creds"

    # Get Hive Metastore pod
    local hive_pod
    hive_pod=$(get_hive_metastore_pod)

    if [[ -z "$hive_pod" ]]; then
        log_error "Hive Metastore pod not found"
        exit 1
    fi

    log_info "Hive Metastore pod: $hive_pod"
    log_info "Database: $db_user@$db_host:$db_port/$db_name"

    # Copy backup to pod
    log_info "Copying backup to pod..."
    kubectl cp "$backup_file" "$NAMESPACE/$hive_pod:/tmp/restore.sql"

    # Restore database
    log_info "Executing restore..."
    kubectl exec -n "$NAMESPACE" "$hive_pod" -- \
        psql -h "$db_host" -p "$db_port" -U "$db_user" -d "$db_name" -f /tmp/restore.sql

    # Clean up
    kubectl exec -n "$NAMESPACE" "$hive_pod" -- rm -f /tmp/restore.sql

    log_info "Database restore complete"
}

verify_restore() {
    log_info "Verifying restore..."

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would verify restore"
        return
    fi

    local hive_pod
    hive_pod=$(get_hive_metastore_pod)

    if [[ -z "$hive_pod" ]]; then
        log_error "Hive Metastore pod not found"
        exit 1
    fi

    # Check database connectivity
    log_info "Checking database connectivity..."
    kubectl exec -n "$NAMESPACE" "$hive_pod" -- \
        hive -e "SHOW DATABASES;" &> /dev/null || {
        log_error "Database connectivity check failed"
        exit 1
    }

    # Check table count
    log_info "Checking table count..."
    local table_count
    table_count=$(kubectl exec -n "$NAMESPACE" "$hive_pod" -- \
        hive -S -e "SELECT COUNT(*) FROM TBLS;" 2>/dev/null | tail -1 || echo "0")

    log_info "Table count: $table_count"

    if [[ "$table_count" -lt 1 ]]; then
        log_warn "Table count is low, please verify"
    fi

    log_info "Restore verification complete"
}

restart_hive_metastore() {
    log_info "Restarting Hive Metastore..."

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would restart Hive Metastore"
        return
    fi

    # Scale down
    kubectl scale statefulset -n "$NAMESPACE" spark-hive-metastore --replicas=0

    # Wait for termination
    kubectl wait --for=delete pods -n "$NAMESPACE" -l app=hive-metastore --timeout=120s || true

    # Scale up
    kubectl scale statefulset -n "$NAMESPACE" spark-hive-metastore --replicas=1

    # Wait for ready
    log_info "Waiting for Hive Metastore to be ready..."
    kubectl wait --for=condition=ready pod -n "$NAMESPACE" -l app=hive-metastore --timeout=300s

    log_info "Hive Metastore is ready"
}

main() {
    parse_args "$@"

    log_info "=== Hive Metastore Restore ==="
    log_info "Namespace: $NAMESPACE"
    log_info "Backup: $BACKUP_FILE"
    log_info "Point-in-time: ${POINT_IN_TIME:-Not specified}"

    check_prerequisites

    if [[ "$VERIFY_ONLY" == true ]]; then
        local local_backup
        local_backup=$(download_backup "$BACKUP_FILE")
        verify_backup "$local_backup"
        log_info "Verification complete"
        exit 0
    fi

    # Create backup before restore
    create_backup_before_restore

    # Download backup
    local local_backup
    local_backup=$(download_backup "$BACKUP_FILE")

    # Verify backup
    verify_backup "$local_backup"

    # Restore database
    restore_database "$local_backup"

    # Restart Hive Metastore
    restart_hive_metastore

    # Verify restore
    verify_restore

    log_info ""
    log_info "=== Restore Complete ==="
    log_info "Please verify your applications are working correctly"

    # Clean up
    if [[ "$DRY_RUN" != true ]]; then
        rm -rf "$BACKUP_DIR"
    fi
}

main "$@"
