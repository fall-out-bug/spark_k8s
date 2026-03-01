#!/bin/bash
# ===================================================================
# Spark Metrics Collector
# ===================================================================
# Collect metrics from Spark applications and export to Prometheus
# PushGateway format
#
# Usage:
#   ./collect-metrics.sh <application-id> [pushgateway-url]
#
# Requirements:
#   - kubectl access to cluster
#   - jq installed
# ===================================================================

set -e

APP_ID="${1:-}"
PUSHGATEWAY="${2:-localhost:9091}"
NAMESPACE="${K8S_NAMESPACE:-spark-airflow}"

if [[ -z "$APP_ID" ]]; then
    echo "Usage: $0 <application-id> [pushgateway-url]"
    echo ""
    echo "Available Spark applications:"
    kubectl logs -n $NAMESPACE deployment/airflow-sc-standalone-master 2>/dev/null | grep "Connected to Spark cluster with app ID" | tail -5 || echo "  (none found)"
    exit 1
fi

METRICS_FILE="/tmp/spark_metrics_${APP_ID}.prom"

echo "Collecting metrics for application: $APP_ID"

MASTER_POD=$(kubectl get pods -n $NAMESPACE -l app=spark-standalone-master -o jsonpath='{.items[0].metadata.name}')

if [[ -z "$MASTER_POD" ]]; then
    echo "Error: Spark master pod not found"
    exit 1
fi

DRIVER_LOGS=$(kubectl exec -n $NAMESPACE $MASTER_POD -- grep "$APP_ID" /opt/spark/logs/*.log 2>/dev/null || true)

cat > "$METRICS_FILE" << EOF
# HELP spark_app_running Whether the Spark application is running
# TYPE spark_app_running gauge
spark_app_running{app_id="$APP_ID"} 1

# HELP spark_app_submit_time Application submission timestamp
# TYPE spark_app_submit_time gauge
spark_app_submit_time{app_id="$APP_ID"} $(date +%s)

EOF

EXECUTOR_COUNT=$(echo "$DRIVER_LOGS" | grep -c "Executor added" || echo "0")
COMPLETED_TASKS=$(echo "$DRIVER_LOGS" | grep -c "completed" || echo "0")

cat >> "$METRICS_FILE" << EOF
# HELP spark_app_executor_count Number of executors
# TYPE spark_app_executor_count gauge
spark_app_executor_count{app_id="$APP_ID"} $EXECUTOR_COUNT

# HELP spark_app_completed_tasks Number of completed tasks
# TYPE spark_app_completed_tasks counter
spark_app_completed_tasks{app_id="$APP_ID"} $COMPLETED_TASKS

EOF

echo "Metrics collected:"
cat "$METRICS_FILE"

if command -v curl &> /dev/null && [[ -n "$PUSHGATEWAY" ]]; then
    echo ""
    echo "Pushing to PushGateway: $PUSHGATEWAY"
    curl --data-binary "@$METRICS_FILE" "http://$PUSHGATEWAY/metrics/job/spark_app/app_id/$APP_ID" || echo "Failed to push metrics"
fi

echo ""
echo "Metrics saved to: $METRICS_FILE"
