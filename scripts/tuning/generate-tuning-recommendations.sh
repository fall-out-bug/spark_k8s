#!/bin/bash
# Generate tuning recommendations from Prometheus metrics
# Usage: generate-tuning-recommendations.sh [--namespace NS] [--app-id ID]

set -euo pipefail

NAMESPACE="${NAMESPACE:-spark-operations}"
APP_ID="${APP_ID:-}"
PROMETHEUS_URL="${PROMETHEUS_URL:-http://localhost:9090}"

while [[ $# -gt 0 ]]; do
    case $1 in
        --namespace) NAMESPACE="$2"; shift 2 ;;
        --app-id) APP_ID="$2"; shift 2 ;;
        --prometheus) PROMETHEUS_URL="$2"; shift 2 ;;
        *) echo "Unknown: $1"; exit 1 ;;
    esac
done

echo "=== Spark Tuning Recommendations ==="
echo "Namespace: $NAMESPACE"
echo "Prometheus: $PROMETHEUS_URL"
echo ""

# Check if Prometheus is reachable
if ! curl -sSf "${PROMETHEUS_URL}/api/v1/query?query=up" &>/dev/null; then
    echo "Prometheus not reachable at $PROMETHEUS_URL"
    echo "Set PROMETHEUS_URL or port-forward: kubectl port-forward svc/prometheus 9090:9090 -n observability"
    exit 1
fi

query() {
    local q="$1"
    curl -sSG "${PROMETHEUS_URL}/api/v1/query" --data-urlencode "query=$q" | jq -r '.data.result[0].value[1] // "N/A"'
}

echo "Recommendations:"
echo "1. Check executor memory: spark_executor_metrics_memoryUsed / maxMemUsed > 0.8 suggests increase memory"
echo "2. Check task skew: spark_task_duration_max / min > 5 suggests data skew"
echo "3. Check shuffle: High spark_shuffle_read/write suggests Celeborn or memory increase"
echo "4. Run calculate-executor-sizing.sh for workload-specific sizing"
echo ""
echo "See docs/operations/performance-tuning.md for details."
