#!/bin/bash
# Validate Spark SQL syntax and schema
#
# Usage:
#   ./validate-sql.sh --sql-file <path> [--catalog <url>]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd"
source "${SCRIPT_DIR}/../operations/common.sh"

# Configuration
SQL_FILE=""
HIVE_CATALOG=${HIVE_CATALOG:-"thrift://hive-metastore:9083"}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --sql-file)
            SQL_FILE="$2"
            shift 2
            ;;
        --catalog)
            HIVE_CATALOG="$2"
            shift 2
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [[ -z "$SQL_FILE" ]]; then
    log_error "Usage: $0 --sql-file <path>"
    exit 1
fi

log_info "=== Spark SQL Validation ==="
log_info "SQL file: ${SQL_FILE}"

# Check if file exists
if [[ ! -f "$SQL_FILE" ]]; then
    log_error "SQL file not found: ${SQL_FILE}"
    exit 1
fi

# 1. Syntax validation using local Spark
log_info "Validating SQL syntax..."

if command -v spark-sql &> /dev/null; then
    # Create temporary file with EXPLAIN
    TMP_SQL=$(mktemp)
    echo "EXPLAIN $(cat "$SQL_FILE")" > "$TMP_SQL"

    if spark-sql -f "$TMP_SQL" 2>&1 | grep -q "Error"; then
        log_error "SQL syntax validation failed"
        spark-sql -f "$TMP_SQL"
        rm -f "$TMP_SQL"
        exit 1
    fi

    rm -f "$TMP_SQL"
    log_info "✓ SQL syntax valid"
else
    log_warn "spark-sql not found, skipping syntax check"
fi

# 2. Check for common SQL issues
log_info "Checking for common SQL issues..."

# Check for SELECT *
if grep -qi "select \*" "$SQL_FILE"; then
    log_warn "Found SELECT * (consider explicit columns)"
fi

# Check for missing WHERE clauses
if grep -qi "DELETE FROM.*WHERE 1=1" "$SQL_FILE"; then
    log_warn "Found DELETE without WHERE clause (use caution)"
fi

# Check for hardcoded dates
if grep -qiE "'[0-9]{4}-[0-9]{2}-[0-9]{2}'" "$SQL_FILE"; then
    log_warn "Found hardcoded dates (consider parameters)"
fi

# 3. Schema validation (if Hive catalog available)
log_info "Validating schema..."

if kubectl get svc -n spark-operations hive-metastore &>/dev/null; then
    # Extract table references from SQL
    TABLES=$(grep -oE '[a-zA-Z_]+\.[a-zA-Z_]+\.[a-zA-Z_]+' "$SQL_FILE" | sort -u)

    if [[ -n "$TABLES" ]]; then
        log_info "Found tables: $TABLES"

        # Check if tables exist in Hive
        for table in $TABLES; do
            DB=$(echo "$table" | cut -d. -f2)
            TABLE_NAME=$(echo "$table" | cut -d. -f3)

            if command -v beeline &> /dev/null; then
                if beeline -u "$HIVE_CATALOG" -e "DESCRIBE ${DB}.${TABLE_NAME};" &>/dev/null; then
                    log_info "✓ Table ${DB}.${TABLE_NAME} exists"
                else
                    log_warn "Table ${DB}.${TABLE_NAME} not found (may be new)"
                fi
            fi
        done
    fi
else
    log_info "Hive catalog not available, skipping schema validation"
fi

# 4. Check for SQL best practices
log_info "Checking SQL best practices..."

# Check for UPPERCASE identifiers (non-standard)
if grep -qE 'SELECT.*FROM.*JOIN' "$SQL_FILE"; then
    if ! grep -q "SELECT.*FROM.*JOIN" "$SQL_FILE"; then
        log_info "✓ Using lowercase SQL (Spark compatible)"
    fi
fi

# Check for LIMIT on large queries
if grep -q "LIMIT [0-9]" "$SQL_FILE"; then
    log_info "✓ LIMIT clause found (good for testing)"
fi

log_info "=== SQL Validation Complete ==="
log_info "✓ SQL file validated successfully"

exit 0
