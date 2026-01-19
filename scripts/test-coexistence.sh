#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${1:-spark-coexistence}"
RELEASE_35="spark-35"
RELEASE_41="spark-41"

CREATED_NAMESPACE="false"

if [[ "${NAMESPACE}" == "default" ]]; then
  echo "ERROR: Use a non-default namespace for coexistence testing."
  exit 1
fi

cleanup() {
  helm uninstall "${RELEASE_35}" -n "${NAMESPACE}" >/dev/null 2>&1 || true
  helm uninstall "${RELEASE_41}" -n "${NAMESPACE}" >/dev/null 2>&1 || true
  if [[ "${CREATED_NAMESPACE}" == "true" ]]; then
    kubectl delete namespace "${NAMESPACE}" >/dev/null 2>&1 || true
  fi
}

trap cleanup EXIT

echo "=== Spark Multi-Version Coexistence Test (${NAMESPACE}) ==="

if ! kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1; then
  kubectl create namespace "${NAMESPACE}" >/dev/null
  CREATED_NAMESPACE="true"
fi

echo "1) Deploying Spark 3.5.7..."
helm install "${RELEASE_35}" charts/spark-3.5 \
  --namespace "${NAMESPACE}" \
  --set spark-standalone.enabled=true \
  --set spark-standalone.hiveMetastore.enabled=true \
  --set spark-standalone.historyServer.enabled=true \
  --wait --timeout=5m

echo "2) Deploying Spark 4.1.0..."
helm install "${RELEASE_41}" charts/spark-4.1 \
  --namespace "${NAMESPACE}" \
  --set connect.enabled=true \
  --set hiveMetastore.enabled=true \
  --set historyServer.enabled=true \
  --wait --timeout=5m

echo "3) Verifying service isolation..."
kubectl get svc -n "${NAMESPACE}" -o name | grep "${RELEASE_35}" >/dev/null
kubectl get svc -n "${NAMESPACE}" -o name | grep "${RELEASE_41}" >/dev/null

SVC_35="$(kubectl get svc -n "${NAMESPACE}" -l app=hive-metastore,app.kubernetes.io/instance="${RELEASE_35}" -o jsonpath='{.items[0].metadata.name}')"
SVC_41="$(kubectl get svc -n "${NAMESPACE}" -l app=hive-metastore,app.kubernetes.io/instance="${RELEASE_41}" -o jsonpath='{.items[0].metadata.name}')"

if [[ -z "${SVC_35}" || -z "${SVC_41}" ]]; then
  echo "ERROR: Hive Metastore service not found for one or both releases."
  exit 1
fi

if [[ "${SVC_35}" == "${SVC_41}" ]]; then
  echo "ERROR: Service name conflict!"
  exit 1
fi

echo "✓ Service isolation OK"

echo "4) Verifying Hive Metastore isolation..."
DB_35="$(kubectl get deploy -n "${NAMESPACE}" -l app=hive-metastore,app.kubernetes.io/instance="${RELEASE_35}" -o jsonpath='{.items[0].spec.template.spec.containers[0].env[?(@.name=="POSTGRES_DB")].value}')"
DB_41="$(kubectl get deploy -n "${NAMESPACE}" -l app=hive-metastore,app.kubernetes.io/instance="${RELEASE_41}" -o jsonpath='{.items[0].spec.template.spec.containers[0].env[?(@.name=="POSTGRES_DB")].value}')"

if [[ -z "${DB_35}" || -z "${DB_41}" || "${DB_35}" == "${DB_41}" ]]; then
  echo "ERROR: Hive Metastore database names are not isolated."
  exit 1
fi

echo "✓ Metastore isolation OK"

echo "5) Verifying History Server isolation..."
LOG_35="$(kubectl get deploy -n "${NAMESPACE}" -l app=spark-history-server,app.kubernetes.io/instance="${RELEASE_35}" -o jsonpath='{.items[0].spec.template.spec.containers[0].env[?(@.name=="SPARK_HISTORY_LOG_DIR")].value}')"
LOG_41="$(kubectl get deploy -n "${NAMESPACE}" -l app=spark-history-server,app.kubernetes.io/instance="${RELEASE_41}" -o jsonpath='{.items[0].spec.template.spec.containers[0].env[?(@.name=="SPARK_HISTORY_LOG_DIR")].value}')"

if [[ -z "${LOG_35}" || -z "${LOG_41}" ]]; then
  echo "ERROR: History Server log directories not found."
  exit 1
fi

if [[ "${LOG_35}" == "${LOG_41}" ]]; then
  echo "ERROR: History Server log directories are not isolated."
  exit 1
fi

echo "✓ History Server isolation OK"

echo "6) Running Spark 3.5.7 test..."
./scripts/test-spark-standalone.sh "${NAMESPACE}" "${RELEASE_35}"

echo "7) Running Spark 4.1.0 smoke test..."
./scripts/test-spark-41-smoke.sh "${NAMESPACE}" "${RELEASE_41}"

echo "8) Cleaning up..."
helm uninstall "${RELEASE_35}" -n "${NAMESPACE}"
helm uninstall "${RELEASE_41}" -n "${NAMESPACE}"

if [[ "${CREATED_NAMESPACE}" == "true" ]]; then
  kubectl delete namespace "${NAMESPACE}"
fi

echo "=== Coexistence test passed ✓ ==="
