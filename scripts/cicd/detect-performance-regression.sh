#!/bin/bash
# Detect performance regression by comparing current metrics to baseline
#
# Usage:
#   ./detect-performance-regression.sh --app-id <id> --baseline-file <path>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../operations/common.sh"

# Configuration
APP_ID=""
BASELINE_FILE=""
THRESHOLD_PERCENT=20
PROMETHEUS_URL=${PROMETHEUS_URL:-"http://prometheus:9090"}
TIME_WINDOW="5m"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --app-id)
            APP_ID="$2"
            shift 2
            ;;
        --baseline-file)
            BASELINE_FILE="$2"
            shift 2
            ;;
        --threshold)
            THRESHOLD_PERCENT="$2"
            shift 2
            ;;
        --prometheus-url)
            PROMETHEUS_URL="$2"
            shift 2
            ;;
        --time-window)
            TIME_WINDOW="$2"
            shift 2
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [[ -z "$APP_ID" ]]; then
    log_error "Usage: $0 --app-id <id> [--baseline-file <path>] [--threshold <percent>]"
    exit 1
fi

log_info "=== Performance Regression Detection ==="
log_info "Application: ${APP_ID}"
log_info "Baseline file: ${BASELINE_FILE:-"None (using historical data)"}"
log_info "Threshold: ${THRESHOLD_PERCENT}%"
log_info "Time window: ${TIME_WINDOW}"

declare -i REGRESSIONS=0

# Define metrics to check
METRICS=(
    "spark:job:duration"
    "spark:stage:duration"
    "spark:task:duration"
    "spark:executor:cpu:time"
    "spark:executor:memory:used"
    "spark:shuffle:read:bytes"
    "spark:shuffle:write:bytes"
)

# Load baseline values if provided
declare -A BASELINE_VALUES
if [[ -n "$BASELINE_FILE" && -f "$BASELINE_FILE" ]]; then
    log_info "Loading baseline values..."
    while IFS='=' read -r metric value; do
        BASELINE_VALUES[$metric]=$value
    done < "$BASELINE_FILE"
fi

# Query Prometheus for current metrics
log_info "Querying Prometheus for current metrics..."

for metric in "${METRICS[@]}"; do
    # Query current value (average over time window)
    query="avg(${metric}{app_id=\"${APP_ID}\"})"
    current_value=$(curl -s -G --data-urlencode "query=$query" \
        "${PROMETHEUS_URL}/api/v1/query" | \
        jq -r '.data.result[0].value[1]' 2>/dev/null || echo "null")

    if [[ "$current_value" == "null" || -z "$current_value" ]]; then
        log_info "No data for metric: $metric"
        continue
    fi

    # Get baseline value
    if [[ -n "${BASELINE_VALUES[$metric]:-}" ]]; then
        baseline_value="${BASELINE_VALUES[$metric]}"
    else
        # Query historical baseline (7 days ago)
        baseline_query="avg_over_time(${metric}{app_id=\"${APP_ID}\"}[7d] offset 7d)"
        baseline_value=$(curl -s -G --data-urlencode "query=$baseline_query" \
            "${PROMETHEUS_URL}/api/v1/query" | \
            jq -r '.data.result[0].value[1]' 2>/dev/null || echo "0")
    fi

    if [[ "$baseline_value" == "null" || -z "$baseline_value" ]]; then
        baseline_value="0"
    fi

    # Calculate percent change
    if [[ $(echo "$baseline_value > 0" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
        percent_change=$(echo "scale=2; (($current_value - $baseline_value) / $baseline_value) * 100" | bc 2>/dev/null || echo "0")

        log_info "Metric: $metric"
        log_info "  Current: ${current_value}"
        log_info "  Baseline: ${baseline_value}"
        log_info "  Change: ${percent_change}%"

        # Check if threshold exceeded
        if [[ $(echo "$percent_change > $THRESHOLD_PERCENT" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
            log_error "⚠ REGRESSION DETECTED: $metric increased by ${percent_change}%"
            ((REGRESSIONS++))
        fi
    fi
done

# Check for stage retry increase
log_info "Checking stage retry patterns..."
retry_query="sum(increase(spark_stage_task_failed_total{app_id=\"${APP_ID}\"}[${TIME_WINDOW}]))"
retry_count=$(curl -s -G --data-urlencode "query=$retry_query" \
    "${PROMETHEUS_URL}/api/v1/query" | \
    jq -r '.data.result[0].value[1]' 2>/dev/null || echo "0")

if [[ $(echo "$retry_count > 100" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
    log_error "⚠ HIGH TASK FAILURE RATE: ${retry_count} task failures detected"
    ((REGRESSIONS++))
fi

# Check for executor loss
log_info "Checking executor loss..."
executor_loss_query="sum(increase(spark_executor_removed_total{app_id=\"${APP_ID}\"}[${TIME_WINDOW}]))"
executor_loss=$(curl -s -G --data-urlencode "query=$executor_loss_query" \
    "${PROMETHEUS_URL}/api/v1/query" | \
    jq -r '.data.result[0].value[1]' 2>/dev/null || echo "0")

if [[ $(echo "$executor_loss > 5" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
    log_error "⚠ EXECUTOR LOSS: ${executor_loss} executors removed"
    ((REGRESSIONS++))
fi

# Check for GC time increase
log_info "Checking GC time..."
gc_time_query="avg(rate(jvm_gc_time_seconds{app_id=\"${APP_ID}\"}[${TIME_WINDOW}]))"
gc_time=$(curl -s -G --data-urlencode "query=$gc_time_query" \
    "${PROMETHEUS_URL}/api/v1/query" | \
    jq -r '.data.result[0].value[1]' 2>/dev/null || echo "0")

if [[ $(echo "$gc_time > 0.5" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
    log_warn "High GC time detected: ${gc_time}s/spark"
fi

# Check for skew
log_info "Checking data skew..."
skew_query="max(spark_task_duration_max{app_id=\"${APP_ID}\"}) / avg(spark_task_duration_avg{app_id=\"${APP_ID}\"})"
skew_ratio=$(curl -s -G --data-urlencode "query=$skew_query" \
    "${PROMETHEUS_URL}/api/v1/query" | \
    jq -r '.data.result[0].value[1]' 2>/dev/null || echo "1")

if [[ $(echo "$skew_ratio > 5" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
    log_error "⚠ DATA SKEW: Max/Avg task duration ratio: ${skew_ratio}x"
    ((REGRESSIONS++))
fi

# Generate summary
log_info "=== Regression Detection Summary ==="

if [[ $REGRESSIONS -eq 0 ]]; then
    log_info "✓ No performance regressions detected"
    exit 0
else
    log_error "✗ ${REGRESSIONS} performance regression(s) detected"

    # Generate recommendations
    log_info "=== Recommendations ==="

    if [[ $(echo "$retry_count > 100" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
        echo "- Check for data skew or OOM errors causing task failures"
        echo "- Review executor memory allocation"
    fi

    if [[ $(echo "$skew_ratio > 5" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
        echo "- Consider salting keys for partitioning"
        echo "- Review data distribution"
    fi

    if [[ $(echo "$gc_time > 0.5" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
        echo "- Tune JVM GC settings"
        echo "- Consider reducing executor memory for caching"
    fi

    exit 1
fi
