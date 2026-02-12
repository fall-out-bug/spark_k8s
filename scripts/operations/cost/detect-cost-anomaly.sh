#!/bin/bash
# Detect cost anomalies using statistical analysis
#
# Usage:
#   ./detect-cost-anomaly.sh --namespace <ns> [--threshold <stddev>]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../operations/common.sh"

# Configuration
NAMESPACE=""
THRESHOLD=${THRESHOLD:-"3"}  # Standard deviations
PROMETHEUS_URL=${PROMETHEUS_URL:-"http://prometheus:9090"}
LOOKBACK_DAYS=${LOOKBACK_DAYS:-"30"}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        --threshold)
            THRESHOLD="$2"
            shift 2
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [[ -z "$NAMESPACE" ]]; then
    log_error "Usage: $0 --namespace <ns> [--threshold <stddev>]"
    exit 1
fi

log_info "=== Cost Anomaly Detection ==="
log_info "Namespace: ${NAMESPACE}"
log_info "Threshold: ${THRESHOLD}σ"
log_info "Lookback period: ${LOOKBACK_DAYS} days"

# Get current hourly cost
log_info "Fetching current cost metrics..."

CURRENT_QUERY="sum(rate(spark_cost_total{namespace=\"${NAMESPACE}\"}[1h]))"
CURRENT_COST=$(curl -s -G --data-urlencode "query=$CURRENT_QUERY" \
    "${PROMETHEUS_URL}/api/v1/query" | \
    jq -r '.data.result[0].value[1]' 2>/dev/null || echo "null")

if [[ "$CURRENT_COST" == "null" || -z "$CURRENT_COST" ]]; then
    log_warn "No current cost data available"
    exit 0
fi

log_info "Current hourly cost: ${CURRENT_COST}"

# Calculate historical statistics
log_info "Analyzing historical patterns..."

MEAN_QUERY="avg_over_time(sum(rate(spark_cost_total{namespace=\"${NAMESPACE}\"}[1h]))[${LOOKBACK_DAYS}d:])"
MEAN_COST=$(curl -s -G --data-urlencode "query=$MEAN_QUERY" \
    "${PROMETHEUS_URL}/api/v1/query" | \
    jq -r '.data.result[0].value[1]' 2>/dev/null || echo "0")

STDDEV_QUERY="stddev_over_time(sum(rate(spark_cost_total{namespace=\"${NAMESPACE}\"}[1h]))[${LOOKBACK_DAYS}d:])"
STDDEV_COST=$(curl -s -G --data-urlencode "query=$STDDEV_QUERY" \
    "${PROMETHEUS_URL}/api/v1/query" | \
    jq -r '.data.result[0].value[1]' 2>/dev/null || echo "0")

log_info "Historical mean: ${MEAN_COST}"
log_info "Historical stddev: ${STDDEV_COST}"

# Calculate z-score
if [[ $(echo "$STDDEV_COST > 0" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
    Z_SCORE=$(echo "scale=2; ($CURRENT_COST - $MEAN_COST) / $STDDEV_COST" | bc 2>/dev/null || echo "0")
    Z_SCORE_ABS=$(echo "$Z_SCORE" | sed 's/^-//')

    log_info "Z-score: ${Z_SCORE}"

    # Check threshold
    if [[ $(echo "$Z_SCORE_ABS >= $THRESHOLD" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
        log_error "⚠ ANOMALY DETECTED: Z-score ${Z_SCORE} exceeds threshold ${THRESHOLD}"

        # Determine direction
        if [[ $(echo "$Z_SCORE > 0" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
            log_error "Direction: COST SPIKE (+${Z_SCORE}σ)"
            PERCENT_INCREASE=$(echo "scale=1; (($CURRENT_COST - $MEAN_COST) / $MEAN_COST) * 100" | bc 2>/dev/null || echo "0")
            log_error "Cost increase: ${PERCENT_INCREASE}% above normal"
        else
            log_warn "Direction: COST DROP (${Z_SCORE}σ)"
            log_warn "This may indicate job failures or incomplete data"
        fi

        # Find top contributors
        log_info "=== Top Cost Contributors ==="

        TOP_QUERY="topk(5, sum by (app_id) (rate(spark_cost_total{namespace=\"${NAMESPACE}\"}[1h])))"
        curl -s -G --data-urlencode "query=$TOP_QUERY" \
            "${PROMETHEUS_URL}/api/v1/query" | \
            jq -r '.data.result[] | "\(.metric.app_id): \(.value[1])"' 2>/dev/null || true

        # Check for specific anomalies
        log_info "=== Anomaly Analysis ==="

        # Check for executor count spike
        EXECUTOR_QUERY="sum(spark_executors_total{namespace=\"${NAMESPACE}\"})"
        EXECUTOR_COUNT=$(curl -s -G --data-urlencode "query=$EXECUTOR_QUERY" \
            "${PROMETHEUS_URL}/api/v1/query" | \
            jq -r '.data.result[0].value[1]' 2>/dev/null || echo "0")

        EXECUTOR_MEAN="avg_over_time(sum(spark_executors_total{namespace=\"${NAMESPACE}\"})[${LOOKBACK_DAYS}d:])"
        EXECUTOR_AVG=$(curl -s -G --data-urlencode "query=$EXECUTOR_MEAN" \
            "${PROMETHEUS_URL}/api/v1/query" | \
            jq -r '.data.result[0].value[1]' 2>/dev/null || echo "0")

        if [[ $(echo "$EXECUTOR_COUNT > $EXECUTOR_AVG * 2" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
            log_error "Executor count spike: ${EXECUTOR_COUNT} (avg: ${EXECUTOR_AVG})"
        fi

        # Check for long-running jobs
        LONG_JOBS_QUERY="sum by (app_id) (spark_app_duration_seconds{namespace=\"${NAMESPACE}\"}) > 86400"
        LONG_JOBS=$(curl -s -G --data-urlencode "query=$LONG_JOBS_QUERY" \
            "${PROMETHEUS_URL}/api/v1/query" | \
            jq -r '.data.result[] | "\(.metric.app_id): \( (.value[1] / 3600) | floor ) hours"' 2>/dev/null || true)

        if [[ -n "$LONG_JOBS" ]]; then
            log_warn "Long-running jobs detected (>24h):"
            echo "$LONG_JOBS"
        fi

        exit 1
    else
        log_info "✓ No anomaly detected (z-score within ±${THRESHOLD}σ)"
        exit 0
    fi
else
    log_warn "Insufficient data for anomaly detection"
    exit 0
fi
