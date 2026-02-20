#!/bin/bash
# Run Spark 3.5.7 scenarios in minikube: Infra, Jupyter+SA, Airflow+SA
# Usage: ./run-minikube-scenarios.sh [0|1|2|all]
#   0 = Infra only (MinIO + Hive + History + optional Observability)
#   1 = Jupyter + Spark Connect (standalone) + Spark Standalone K8s
#   2 = Airflow K8s + Spark Standalone K8s
#   all = 0 then 1 then 2

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CHART_PATH="${PROJECT_ROOT}/charts/spark-3.5"
SPARK_VERSION="3.5.7"
NAMESPACE_INFRA="spark-infra"

run_scenario_0() {
  echo "=== Scenario 0: Infra (MinIO + Hive Metastore + History Server) ==="
  kubectl create namespace "$NAMESPACE_INFRA" --dry-run=client -o yaml | kubectl apply -f -
  helm upgrade --install spark-infra "$CHART_PATH" \
    -f "$CHART_PATH/presets/spark-infra.yaml" \
    -n "$NAMESPACE_INFRA" \
    --timeout 10m \
    --wait
  echo "Waiting for infra pods..."
  kubectl wait --for=condition=ready pod -l app=minio -n "$NAMESPACE_INFRA" --timeout=120s || true
  kubectl wait --for=condition=ready pod -l app=postgresql -n "$NAMESPACE_INFRA" --timeout=120s || true
  kubectl get pods -n "$NAMESPACE_INFRA"
}

# Deploy OTEL Collector + Grafana (for telemetry and dashboards in scenarios 1/2)
run_observability() {
  echo "=== Deploying Observability (OTEL + Grafana) ==="
  "${SCRIPT_DIR}/deploy-observability.sh"
}

run_scenario_1() {
  echo "=== Scenario 1: Jupyter + Spark Connect (standalone) + Spark Standalone K8s ==="
  local ns="spark-35-jupyter-sa"
  kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
  # Shared infra: MinIO + History Server from spark-infra; telemetry to observability
  helm upgrade --install scenario1 "$CHART_PATH" \
    -f "$CHART_PATH/presets/scenarios/jupyter-connect-standalone.yaml" \
    -n "$ns" \
    --set global.s3.enabled=true \
    --set global.s3.endpoint=http://minio.spark-infra.svc.cluster.local:9000 \
    --set spark-base.minio.enabled=false \
    --set sparkStandalone.enabled=true \
    --set connect.image.repository=spark-custom \
    --set connect.image.tag="${SPARK_VERSION}-new" \
    --set connect.image.pullPolicy=IfNotPresent \
    --set connect.eventLog.enabled=true \
    --set connect.eventLog.dir=s3a://spark-logs/events \
    --set connect.openTelemetry.enabled=false \
    --set sparkStandalone.image.repository=spark-custom \
    --set sparkStandalone.image.tag="${SPARK_VERSION}-new" \
    --set sparkStandalone.image.pullPolicy=IfNotPresent \
    --set historyServer.enabled=false \
    --set hiveMetastore.enabled=false \
    --timeout 15m \
    --wait
  kubectl get pods -n "$ns"
}

run_scenario_2() {
  echo "=== Scenario 2: Airflow K8s + Spark Standalone K8s ==="
  local ns="spark-35-airflow-sa"
  kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
  # Shared infra: MinIO + History Server from spark-infra; telemetry to observability
  helm upgrade --install scenario2 "$CHART_PATH" \
    -f "$CHART_PATH/presets/scenarios/airflow-connect-standalone.yaml" \
    -n "$ns" \
    --set global.s3.enabled=true \
    --set global.s3.endpoint=http://minio.spark-infra.svc.cluster.local:9000 \
    --set spark-base.minio.enabled=false \
    --set sparkStandalone.enabled=true \
    --set connect.image.repository=spark-custom \
    --set connect.image.tag="${SPARK_VERSION}-new" \
    --set connect.image.pullPolicy=IfNotPresent \
    --set connect.eventLog.enabled=true \
    --set connect.eventLog.dir=s3a://spark-logs/events \
    --set connect.openTelemetry.enabled=false \
    --set airflow.image.repository=apache/airflow \
    --set airflow.image.tag="2.11.0" \
    --set airflow.image.pullPolicy=IfNotPresent \
    --set sparkStandalone.image.repository=spark-custom \
    --set sparkStandalone.image.tag="${SPARK_VERSION}-new" \
    --set sparkStandalone.image.pullPolicy=IfNotPresent \
    --set historyServer.enabled=false \
    --set hiveMetastore.enabled=false \
    --timeout 15m \
    --wait
  kubectl get pods -n "$ns"
}

main() {
  cd "$PROJECT_ROOT"
  local target="${1:-0}"
  case "$target" in
    0) run_scenario_0 ;;
    1) run_scenario_1 ;;
    2) run_scenario_2 ;;
    all) run_scenario_0; run_observability; run_scenario_1; run_scenario_2 ;;
    *) echo "Usage: $0 [0|1|2|all]"; exit 1 ;;
  esac
}

main "$@"
