#!/usr/bin/env bash
# Deploy shared infra to minikube (no demo: no Airflow, Jupyter, Standalone).
# MinIO + PostgreSQL + Hive Metastore + History Server + Observability.
# Usage: ./scripts/deploy-shared-infra-minikube.sh
# Prerequisites: minikube running, images built (./scripts/tests/minikube/build-and-load-images.sh)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CHART_PATH="$PROJECT_ROOT/charts/spark-3.5"
PRESET="$CHART_PATH/presets/spark-infra-minimal.yaml"
NAMESPACE="spark-infra"

echo "=== Deploying Shared Infra (no demo) to Minikube ==="

helm dependency build "$CHART_PATH" 2>/dev/null || true

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
kubectl annotate namespace "$NAMESPACE" \
  spark-k8s/owner-release=spark-infra \
  spark-k8s/owner-chart=spark-3.5 \
  spark-k8s/protected=true \
  --overwrite 2>/dev/null || true

helm upgrade --install spark-infra "$CHART_PATH" -n "$NAMESPACE" \
  -f "$PRESET" \
  --set global.s3.accessKey=minioadmin \
  --set global.s3.secretKey=minioadmin \
  --set spark-base.postgresql.auth.username=postgres \
  --set spark-base.postgresql.auth.password=postgres \
  --set spark-base.postgresql.authMethod=md5 \
  --timeout 10m \
  --wait

echo "Waiting for core pods..."
kubectl wait --for=condition=ready pod -l app=minio -n "$NAMESPACE" --timeout=120s 2>/dev/null || true
kubectl wait --for=condition=ready pod -l app=postgresql -n "$NAMESPACE" --timeout=120s 2>/dev/null || true

# Ensure spark_db exists and Hive schema is initialized
pg_pod=$(kubectl get pod -n "$NAMESPACE" -l app=postgresql -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [[ -n "$pg_pod" ]]; then
  kubectl exec -n "$NAMESPACE" "$pg_pod" -- psql -U postgres -c "CREATE DATABASE spark_db;" 2>/dev/null || true
fi

# Run Hive schematool (init job may fail if spark_db not ready during helm hook)
kubectl run -n "$NAMESPACE" hive-schema-init --rm -i --restart=Never \
  --image=spark-k8s/hive:3.1.3-pg \
  -- bash -c 'mkdir -p /tmp/hive-conf && echo "<configuration><property><name>javax.jdo.option.ConnectionURL</name><value>jdbc:postgresql://spark-infra-spark-base-postgresql.spark-infra.svc.cluster.local:5432/spark_db</value></property><property><name>javax.jdo.option.ConnectionDriverName</name><value>org.postgresql.Driver</value></property><property><name>javax.jdo.option.ConnectionUserName</name><value>postgres</value></property><property><name>javax.jdo.option.ConnectionPassword</name><value>postgres</value></property></configuration>" > /tmp/hive-conf/hive-site.xml && HIVE_CONF_DIR=/tmp/hive-conf /opt/hive/bin/schematool -dbType postgres -initSchema' 2>/dev/null || true

kubectl delete pod -n "$NAMESPACE" -l app=hive-metastore --ignore-not-found 2>/dev/null || true
kubectl wait --for=condition=ready pod -l app=hive-metastore -n "$NAMESPACE" --timeout=180s 2>/dev/null || true
kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=history-server -n "$NAMESPACE" --timeout=180s 2>/dev/null || true

echo "Deploying Observability..."
"$PROJECT_ROOT/scripts/tests/minikube/deploy-observability.sh"

echo ""
echo "=== Shared Infra deployed ==="
echo "  MinIO: minio.spark-infra.svc.cluster.local:9000"
echo "  History: spark-infra-spark-35-history.spark-infra.svc.cluster.local:18080"
echo "  Hive: spark-infra-spark-35-metastore.spark-infra.svc.cluster.local:9083"
echo "  OTEL: otel-collector.observability.svc.cluster.local:4317"
echo ""
echo "Run matrix: ./scripts/run-matrix-96.sh --shared-infra"
kubectl get pods -n "$NAMESPACE"
kubectl get pods -n observability 2>/dev/null || true
