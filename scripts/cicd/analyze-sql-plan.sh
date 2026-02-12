#!/bin/bash
# Analyze Spark SQL query plan for anti-patterns
#
# Usage:
#   ./analyze-sql-plan.sh --sql-file <path> [--warehouse-uri <uri>]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../operations/common.sh"

# Configuration
SQL_FILE=""
WAREHOUSE_URI=${WAREHOUSE_URI:-"thrift://hive-metastore:9083"}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --sql-file)
            SQL_FILE="$2"
            shift 2
            ;;
        --warehouse-uri)
            WAREHOUSE_URI="$2"
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

log_info "=== Spark SQL Plan Analysis ==="
log_info "SQL file: ${SQL_FILE}"

# Check if file exists
if [[ ! -f "$SQL_FILE" ]]; then
    log_error "SQL file not found: ${SQL_FILE}"
    exit 1
fi

# Extract SQL statement
SQL_CONTENT=$(cat "$SQL_FILE")

# Check for common anti-patterns
log_info "Checking for SQL anti-patterns..."

# 1. SELECT *
if grep -qi "SELECT \*" "$SQL_CONTENT"; then
    log_warn "Found SELECT * (consider explicit columns)"
fi

# 2. CROSS JOIN
if grep -qi "CROSS JOIN" "$SQL_CONTENT"; then
    log_warn "Found CROSS JOIN (ensure intentional)"
fi

# 3. DISTINCT on large datasets
if grep -qi "DISTINCT" "$SQL_CONTENT"; then
    log_info "Found DISTINCT (consider GROUP BY for performance)"
fi

# 4. Subqueries in WHERE clause
if grep -qi "WHERE.*IN (SELECT" "$SQL_CONTENT"; then
    log_warn "Found subquery in WHERE (consider JOIN)"
fi

# 5. Multiple COUNT on same dataset
COUNT_COUNT=$(grep -c "COUNT(" "$SQL_CONTENT" 2>/dev/null || echo "0")
if [[ $COUNT_COUNT -gt 3 ]]; then
    log_warn "Multiple COUNT() calls (consider window functions)"
fi

# 6. ORDER BY without LIMIT
if grep -qi "ORDER BY" "$SQL_CONTENT" | grep -qv "LIMIT"; then
    log_warn "ORDER BY without LIMIT (may be slow on large datasets)"
fi

# 7. UDFs in WHERE clause
if grep -qi "WHERE.*udf(" "$SQL_CONTENT"; then
    log_warn "UDF in WHERE prevents predicate pushdown (consider caching)"
fi

# Get query plan using Spark
log_info "Getting physical plan..."

PLAN_OUTPUT=$(spark-sql --verbose --warehouse-uri "$WAREHOUSE_URI" \
    -e "EXPLAIN EXTENDED $(cat "$SQL_FILE")" 2>&1 || true)

# Analyze plan
if [[ -n "$PLAN_OUTPUT" ]]; then
    # Check for Exchange (shuffle)
    if echo "$PLAN_OUTPUT" | grep -q "Exchange"; then
        log_warn "Plan includes shuffle (may be expensive)"
    fi

    # Check for Broadcast
    if echo "$PLAN_OUTPUT" | grep -q "Broadcast"; then
        log_info "Plan includes broadcast (usually OK for small datasets)"
    fi

    # Check for SortMergeJoin
    if echo "$PLAN_OUTPUT" | grep -q "SortMergeJoin"; then
        log_warn "SortMergeJoin (consider enabling spark.sql.autoBroadcastJoinThreshold)"
    fi
fi

# Check for partition pruning
log_info "Checking for partition pruning..."

if grep -qiE "partition_key|WHERE.*partition_col" "$SQL_CONTENT"; then
    log_info "✓ Partition filters detected (good for pruning)"
else
    log_warn "No partition filters found (full table scan likely)"
fi

# Generate recommendations
log_info "=== Recommendations ==="

# Estimate cost factor based on findings
COST_FACTOR=0

if grep -qi "SELECT \*" "$SQL_CONTENT"; then
    echo "- Replace SELECT * with explicit columns"
    ((COST_FACTOR++))
fi

if grep -qi "ORDER BY" "$SQL_CONTENT" && ! grep -qi "LIMIT" "$SQL_CONTENT"; then
    echo "- Add LIMIT clause to ORDER BY"
    ((COST_FACTOR++))
fi

if grep -qi "CROSS JOIN" "$SQL_CONTENT"; then
    echo "- Verify CROSS JOIN is intentional (consider INNER JOIN)"
    ((COST_FACTOR+=2))
fi

if [[ $COST_FACTOR -eq 0 ]]; then
    log_info "✓ No major anti-patterns detected"
else
    log_warn "Found ${COST_FACTOR} optimization opportunities"
fi

log_info "=== Plan Analysis Complete ==="

exit 0
