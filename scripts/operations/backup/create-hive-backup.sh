#!/bin/bash
# Hive Metastore Backup Script
# Creates backups of the Hive Metastore database

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="${NAMESPACE:-spark-operations}"
BACKUP_PREFIX="hive-metastore-backup"
OUTPUT="${OUTPUT:-s3://spark-backups/hive-metastore/}"
BACKUP_NAME="${BACKUP_NAME:-${BACKUP_PREFIX}-$(date +%Y%m%d-%H%M%S).sql}"
TMP_DIR="${TMP_DIR:-/tmp/hive-backup}"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Create a backup of the Hive Metastore database.

OPTIONS:
    -n, --namespace NAME      Kubernetes namespace (default: spark-operations)
    -o, --output PATH         Output path (s3:// or local file)
    -t, --tmp-dir DIR         Temporary directory (default: /tmp/hive-backup)
    -k, --keep-local          Keep local backup file
    -h, --help                Show this help

EXAMPLES:
    $(basename "$0") --output s3://spark-backups/hive-metastore/
    $(basename "$0") -o /tmp/hive-backup.sql --keep-local
EOF
    exit 1
}

KEEP_LOCAL=false

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT="$2"
                shift 2
                ;;
            -t|--tmp-dir)
                TMP_DIR="$2"
                shift 2
                ;;
            -k|--keep-local)
                KEEP_LOCAL=true
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                echo "Unknown option: $1"
                usage
                ;;
        esac
    done
}

main() {
    parse_args "$@"

    echo "=== Hive Metastore Backup ==="
    echo "Namespace: $NAMESPACE"
    echo "Output: $OUTPUT"
    echo "Backup name: $BACKUP_NAME"
    echo ""

    # Create temporary directory
    mkdir -p "$TMP_DIR"
    local backup_file="${TMP_DIR}/${BACKUP_NAME}"

    # Get Hive Metastore pod
    echo "Finding Hive Metastore pod..."
    local hive_pod=$(kubectl get pods -n "$NAMESPACE" -l app=hive-metastore -o jsonpath='{.items[0].metadata.name}')

    if [[ -z "$hive_pod" ]]; then
        echo "Error: Hive Metastore pod not found"
        exit 1
    fi

    echo "Hive Metastore pod: $hive_pod"

    # Get database connection details from secret
    echo "Getting database credentials..."
    local db_host=$(kubectl get secret -n "$NAMESPACE" hive-metastore-db -o jsonpath='{.data.DB_HOST}' | base64 -d)
    local db_port=$(kubectl get secret -n "$NAMESPACE" hive-metastore-db -o jsonpath='{.data.DB_PORT}' | base64 -d)
    local db_name=$(kubectl get secret -n "$NAMESPACE" hive-metastore-db -o jsonpath='{.data.DB_NAME}' | base64 -d)
    local db_user=$(kubectl get secret -n "$NAMESPACE" hive-metastore-db -o jsonpath='{.data.DB_USER}' | base64 -d)
    local db_pass=$(kubectl get secret -n "$NAMESPACE" hive-metastore-db -o jsonpath='{.data.DB_PASS}' | base64 -d)

    echo "Database: $db_user@$db_host:$db_port/$db_name"

    # Create backup
    echo "Creating backup..."
    kubectl exec -n "$NAMESPACE" "$hive_pod" -- \
        mysqldump -h "$db_host" -P "$db_port" -u "$db_user" -p"$db_pass" \
        --single-transaction --routines --triggers \
        "$db_name" > "$backup_file" 2>&1

    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        echo "Error: Backup failed"
        rm -f "$backup_file"
        exit 1
    fi

    # Calculate checksum
    echo "Calculating checksum..."
    local checksum=$(md5sum "$backup_file" | awk '{print $1}')
    echo "MD5 checksum: $checksum"

    # Get backup size
    local backup_size=$(du -h "$backup_file" | awk '{print $1}')
    echo "Backup size: $backup_size"

    # Upload to S3 or MinIO
    if [[ "$OUTPUT" == s3://* ]]; then
        echo "Uploading to S3/MinIO..."
        aws s3 cp "$backup_file" "${OUTPUT}${BACKUP_NAME}"

        # Add checksum as metadata
        aws s3api put-object-tagging \
            --bucket "$(echo "$OUTPUT" | sed 's|s3://||' | sed 's|/.*||')" \
            --key "$(echo "$OUTPUT" | sed 's|s3://[^/]*/||')${BACKUP_NAME}" \
            --tagging "checksum=${checksum},date=$(date +%Y%m%d)"

        echo "Backup uploaded to: ${OUTPUT}${BACKUP_NAME}"
    else
        echo "Copying to: $OUTPUT"
        cp "$backup_file" "$OUTPUT"
    fi

    # Clean up unless --keep-local
    if [[ "$KEEP_LOCAL" == false ]]; then
        echo "Cleaning up temporary files..."
        rm -f "$backup_file"
    else
        echo "Local backup kept at: $backup_file"
    fi

    echo ""
    echo "=== Backup Complete ==="
    echo "Backup: $BACKUP_NAME"
    echo "Size: $backup_size"
    echo "Checksum: $checksum"
    echo "Location: ${OUTPUT}${BACKUP_NAME}"

    # Update Prometheus metrics
    if command -v prometheus_push_gateway &> /dev/null; then
        echo "Updating metrics..."
        echo "backup_success_total{component=\"hive-metastore\",status=\"success\"} 1" | \
            curl --data-binary @- http://prometheus-push-gateway:9091/metrics/job/backup
    fi
}

main "$@"
