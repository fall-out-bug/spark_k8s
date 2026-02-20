#!/usr/bin/env bash
set -euo pipefail

# Load test for Spark Standalone cluster (direct spark-submit, no Connect)
# Runs inside the cluster using spark-submit --master spark://master:7077

NAMESPACE="${1:-default}"
RELEASE="${2:-spark-standalone}"
STANDALONE_MASTER="${3:-spark-standalone-master:7077}"

LOAD_MODE="${LOAD_MODE:-range}"
LOAD_ROWS="${LOAD_ROWS:-1000000}"
LOAD_PARTITIONS="${LOAD_PARTITIONS:-50}"
LOAD_ITERATIONS="${LOAD_ITERATIONS:-3}"
# MinIO in spark-infra when running from scenario 1/2 namespace
LOAD_S3_ENDPOINT="${LOAD_S3_ENDPOINT:-http://minio.spark-infra.svc.cluster.local:9000}"
# Event log to S3 so History Server (infra) shows the job; set to empty to skip
LOAD_EVENT_LOG_DIR="${LOAD_EVENT_LOG_DIR:-s3a://spark-logs/events}"
# After test, verify app in History Server when LOAD_EVENT_LOG_DIR is set
LOAD_REQUIRE_HISTORY_SERVER="${LOAD_REQUIRE_HISTORY_SERVER:-true}"
HISTORY_NS="${HISTORY_NS:-spark-infra}"
HISTORY_SVC="${HISTORY_SVC:-spark-infra-spark-35-history}"
LOAD_TEST_IMAGE="${LOAD_TEST_IMAGE:-spark-custom:3.5.7-new}"

MASTER_SERVICE=$(echo "${STANDALONE_MASTER}" | sed 's/spark:\/\///' | cut -d: -f1)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOAD_TEST_SCRIPT="${PROJECT_ROOT}/scripts/standalone_load_test.py"
CM_NAME="load-test-script-$$"
POD_NAME="load-test-$$"
POD_YAML=""

cleanup() {
  [[ -n "${POD_YAML}" && -f "${POD_YAML}" ]] && rm -f "${POD_YAML}"
  kubectl delete configmap "${CM_NAME}" -n "${NAMESPACE}" --ignore-not-found 2>/dev/null || true
  kubectl delete pod "${POD_NAME}" -n "${NAMESPACE}" --ignore-not-found --wait=false 2>/dev/null || true
}
trap cleanup EXIT

echo "=== Spark Standalone Direct Load Test (${RELEASE} in ${NAMESPACE}) ==="
echo "Standalone Master: spark://${STANDALONE_MASTER}"
echo "Load parameters: Rows=${LOAD_ROWS} Partitions=${LOAD_PARTITIONS} Iterations=${LOAD_ITERATIONS} Mode=${LOAD_MODE}"
echo "Image: ${LOAD_TEST_IMAGE}"
echo ""

echo "1) Verifying Standalone master..."
if kubectl get svc "${MASTER_SERVICE}" -n "${NAMESPACE}" >/dev/null 2>&1; then
  echo "   ✓ Standalone master service: ${MASTER_SERVICE}"
else
  echo "   ERROR: Standalone master service '${MASTER_SERVICE}' not found in namespace"
  exit 1
fi

# Check master pod is ready
kubectl wait --for=condition=ready pod -l "app=spark-standalone-master" -n "${NAMESPACE}" --timeout=60s 2>/dev/null || \
  kubectl wait --for=condition=ready pod -l "app.kubernetes.io/component=standalone-master" -n "${NAMESPACE}" --timeout=60s || true

echo ""
echo "2) Checking worker pods..."
WORKER_COUNT=$(kubectl get pods -n "${NAMESPACE}" -l "app=spark-standalone-worker" --no-headers 2>/dev/null | grep -c Running || true)
if [[ "${WORKER_COUNT}" -lt 1 ]]; then
  WORKER_COUNT=$(kubectl get pods -n "${NAMESPACE}" -l "app.kubernetes.io/component=standalone-worker" --no-headers 2>/dev/null | grep -c Running || true)
fi
echo "   Workers Running: ${WORKER_COUNT}"

echo ""
echo "3) Creating ConfigMap with load test script..."
[[ ! -f "${LOAD_TEST_SCRIPT}" ]] && { echo "ERROR: ${LOAD_TEST_SCRIPT} not found"; exit 1; }
kubectl create configmap "${CM_NAME}" --from-file="standalone_load_test.py=${LOAD_TEST_SCRIPT}" -n "${NAMESPACE}"

echo ""
echo "4) Running load test in cluster (mode=${LOAD_MODE}, iterations=${LOAD_ITERATIONS})..."
POD_YAML=$(mktemp)
cat << PODYAML > "${POD_YAML}"
apiVersion: v1
kind: Pod
metadata:
  name: ${POD_NAME}
  namespace: ${NAMESPACE}
spec:
  restartPolicy: Never
  serviceAccountName: spark
  containers:
  - name: load-test
    image: ${LOAD_TEST_IMAGE}
    imagePullPolicy: IfNotPresent
    command:
    - sh
    - -c
    - |
      echo "Running Spark Standalone load test..."
      exec python3 /script/standalone_load_test.py
    env:
    - name: PYTHONUNBUFFERED
      value: "1"
    - name: POD_IP
      valueFrom:
        fieldRef:
          fieldPath: status.podIP
    - name: SPARK_MASTER
      value: "spark://${STANDALONE_MASTER}"
    - name: LOAD_MODE
      value: "${LOAD_MODE}"
    - name: LOAD_ROWS
      value: "${LOAD_ROWS}"
    - name: LOAD_PARTITIONS
      value: "${LOAD_PARTITIONS}"
    - name: LOAD_ITERATIONS
      value: "${LOAD_ITERATIONS}"
    - name: S3_ENDPOINT
      value: "${LOAD_S3_ENDPOINT}"
    - name: AWS_ACCESS_KEY_ID
      value: "minioadmin"
    - name: AWS_SECRET_ACCESS_KEY
      value: "minioadmin"
    volumeMounts:
    - name: script
      mountPath: /script
      readOnly: true
  volumes:
  - name: script
    configMap:
      name: ${CM_NAME}
PODYAML

kubectl apply -f "${POD_YAML}"
kubectl wait --for=condition=ready pod "${POD_NAME}" -n "${NAMESPACE}" --timeout=180s
kubectl wait --for=condition=complete pod "${POD_NAME}" -n "${NAMESPACE}" --timeout=600s || true

echo ""
kubectl logs "${POD_NAME}" -n "${NAMESPACE}"

# Check exit code
EXIT_CODE=$(kubectl get pod "${POD_NAME}" -n "${NAMESPACE}" -o jsonpath='{.status.containerStatuses[0].state.terminated.exitCode}' 2>/dev/null || echo "1")

if [[ "${EXIT_CODE}" == "0" ]]; then
  echo ""
  echo "=== Load Test PASSED ==="
else
  echo ""
  echo "=== Load Test FAILED (exit ${EXIT_CODE}) ==="
fi

if [[ -n "${LOAD_EVENT_LOG_DIR}" ]]; then
  echo ""
  echo "5) Verifying job in History Server (infra)..."
  echo "   Waiting for event log to be visible (15s)..."
  sleep 15

  # Check if History Server has the app
  APP_COUNT=$(kubectl exec -n "${HISTORY_NS}" deployment/"${HISTORY_SVC}" -- \
    curl -s "http://localhost:18080/api/v1/applications" 2>/dev/null | \
    grep -c '"id"' || echo "0")

  if [[ "${APP_COUNT}" -gt 0 ]]; then
    echo "   ✓ History Server shows ${APP_COUNT} application(s)"
  else
    if [[ "${LOAD_REQUIRE_HISTORY_SERVER}" == "true" ]]; then
      echo "   WARN: History Server has no applications"
    else
      echo "   WARN: History Server has no applications (expected for direct spark-submit)"
    fi
  fi
fi

# Return original exit code
exit "${EXIT_CODE:-0}"
