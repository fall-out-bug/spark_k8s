#!/usr/bin/env bash
set -euo pipefail

# Runtime load test for Spark Connect with Standalone backend
# Runs inside the cluster (no host Python / port-forward).
# Default: spark-custom:3.5.7-new (has pyspark, pyarrow; we pip install grpcio in-pod).
# Or LOAD_TEST_IMAGE=python:3.11-slim to install all deps in-pod (~10 min first run).

NAMESPACE="${1:-default}"
RELEASE="${2:-spark-connect-standalone}"
STANDALONE_MASTER="${3:-spark-sa-spark-standalone-master:7077}"

LOAD_MODE="${LOAD_MODE:-range}"
LOAD_ROWS="${LOAD_ROWS:-1000000}"
LOAD_PARTITIONS="${LOAD_PARTITIONS:-50}"
LOAD_ITERATIONS="${LOAD_ITERATIONS:-3}"
LOAD_DATASET="${LOAD_DATASET:-nyc}"
# MinIO in spark-infra when running from scenario 1/2 namespace
LOAD_S3_ENDPOINT="${LOAD_S3_ENDPOINT:-http://minio.spark-infra.svc.cluster.local:9000}"
# Event log to S3 so History Server (infra) shows the job; set to empty to skip
LOAD_EVENT_LOG_DIR="${LOAD_EVENT_LOG_DIR:-s3a://spark-logs/events}"
# After test, verify app in History Server when LOAD_EVENT_LOG_DIR is set
# Set LOAD_REQUIRE_HISTORY_SERVER=false to only warn if History Server has no apps (e.g. server not configured for event log)
LOAD_REQUIRE_HISTORY_SERVER="${LOAD_REQUIRE_HISTORY_SERVER:-true}"
HISTORY_NS="${HISTORY_NS:-spark-infra}"
HISTORY_SVC="${HISTORY_SVC:-spark-infra-spark-35-history}"
LOAD_TEST_IMAGE="${LOAD_TEST_IMAGE:-spark-custom:3.5.7-new}"

CONNECT_SELECTOR="app=spark-connect,app.kubernetes.io/instance=${RELEASE}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOAD_TEST_SCRIPT="${PROJECT_ROOT}/scripts/connect_load_test.py"

MASTER_SERVICE=$(echo "${STANDALONE_MASTER}" | sed 's/spark:\/\///' | cut -d: -f1)
CM_NAME="load-test-script-$$"
POD_NAME="load-test-$$"
POD_YAML=""

cleanup() {
  [[ -n "${POD_YAML}" && -f "${POD_YAML}" ]] && rm -f "${POD_YAML}"
  kubectl delete configmap "${CM_NAME}" -n "${NAMESPACE}" --ignore-not-found 2>/dev/null || true
  kubectl delete pod "${POD_NAME}" -n "${NAMESPACE}" --ignore-not-found --wait=false 2>/dev/null || true
}
trap cleanup EXIT

echo "=== Spark Connect Standalone Backend Load Test (${RELEASE} in ${NAMESPACE}) ==="
echo "Standalone Master: ${STANDALONE_MASTER}"
echo "Load parameters: Rows=${LOAD_ROWS} Partitions=${LOAD_PARTITIONS} Iterations=${LOAD_ITERATIONS} Mode=${LOAD_MODE}"
echo "Image: ${LOAD_TEST_IMAGE}"
echo ""

echo "1) Checking Spark Connect pod..."
kubectl wait --for=condition=ready pod -l "${CONNECT_SELECTOR}" -n "${NAMESPACE}" --timeout=180s
CONNECT_SERVICE=$(kubectl get svc -n "${NAMESPACE}" -l "${CONNECT_SELECTOR}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
[[ -z "${CONNECT_SERVICE}" ]] && CONNECT_SERVICE="spark-connect"
echo "   Connect service: ${CONNECT_SERVICE}"

echo ""
echo "2) Verifying Standalone master..."
if kubectl get svc "${MASTER_SERVICE}" -n "${NAMESPACE}" >/dev/null 2>&1; then
  echo "   ✓ Standalone master service: ${MASTER_SERVICE}"
else
  echo "   WARN: Standalone master service '${MASTER_SERVICE}' not found in namespace"
fi

echo ""
echo "3) Creating ConfigMap with load test script..."
[[ ! -f "${LOAD_TEST_SCRIPT}" ]] && { echo "ERROR: ${LOAD_TEST_SCRIPT} not found"; exit 1; }
kubectl create configmap "${CM_NAME}" --from-file="connect_load_test.py=${LOAD_TEST_SCRIPT}" -n "${NAMESPACE}"

echo ""
echo "4) Running load test in cluster (mode=${LOAD_MODE}, iterations=${LOAD_ITERATIONS})..."
CONNECT_URL="sc://${CONNECT_SERVICE}:15002"
POD_YAML=$(mktemp)
cat << PODYAML > "${POD_YAML}"
apiVersion: v1
kind: Pod
metadata:
  name: ${POD_NAME}
  namespace: ${NAMESPACE}
spec:
  restartPolicy: Never
  containers:
  - name: load-test
    image: ${LOAD_TEST_IMAGE}
    imagePullPolicy: IfNotPresent
    command:
    - sh
    - -c
    - |
      echo "Installing Spark Connect client deps (grpcio, grpcio-status, protobuf)..."
      pip3 install --quiet 'grpcio>=1.48' grpcio-status protobuf 2>/dev/null || pip install --quiet 'grpcio>=1.48' grpcio-status protobuf 2>/dev/null || true
      echo "Running load test..."
      exec python3 /script/connect_load_test.py
    env:
    - name: PYTHONUNBUFFERED
      value: "1"
    - name: CONNECT_URL
      value: "${CONNECT_URL}"
    - name: LOAD_MODE
      value: "${LOAD_MODE}"
    - name: LOAD_ROWS
      value: "${LOAD_ROWS}"
    - name: LOAD_PARTITIONS
      value: "${LOAD_PARTITIONS}"
    - name: LOAD_ITERATIONS
      value: "${LOAD_ITERATIONS}"
    - name: LOAD_DATASET
      value: "${LOAD_DATASET}"
    - name: LOAD_S3_ENDPOINT
      value: "${LOAD_S3_ENDPOINT}"
    - name: LOAD_EVENT_LOG_DIR
      value: "${LOAD_EVENT_LOG_DIR}"
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
kubectl wait --for=condition=Ready pod/"${POD_NAME}" -n "${NAMESPACE}" --timeout=120s 2>/dev/null || true
kubectl wait --for=condition=ContainersReady pod/"${POD_NAME}" -n "${NAMESPACE}" --timeout=60s 2>/dev/null || true
kubectl logs -f "${POD_NAME}" -n "${NAMESPACE}" 2>/dev/null || true
EXIT_CODE=0
kubectl wait --for=condition=ContainersTerminated pod/"${POD_NAME}" -n "${NAMESPACE}" --timeout=300s 2>/dev/null || true
EXIT_CODE=$(kubectl get pod "${POD_NAME}" -n "${NAMESPACE}" -o jsonpath='{.status.containerStatuses[0].state.terminated.exitCode}' 2>/dev/null || echo "1")
[[ -z "${EXIT_CODE}" ]] && EXIT_CODE=1

if [[ "${EXIT_CODE}" == "0" ]]; then
  echo ""
  echo "5) Verifying job in History Server (infra)..."
  if [[ -n "${LOAD_EVENT_LOG_DIR}" ]]; then
    if ! kubectl get svc "${HISTORY_SVC}" -n "${HISTORY_NS}" &>/dev/null; then
      echo "   ERROR: LOAD_EVENT_LOG_DIR is set but History Server svc ${HISTORY_SVC}.${HISTORY_NS} not found"
      exit 1
    fi
    echo "   Waiting for event log to be visible (15s)..."
    sleep 15
    if kubectl run "history-check-$$" -n "${HISTORY_NS}" --rm -i --restart=Never --image=curlimages/curl:latest -- \
      curl -sf "http://${HISTORY_SVC}:18080/api/v1/applications" 2>/dev/null | grep -q "ConnectStandaloneLoadTest\|application"; then
      echo "   ✓ History Server shows applications (event log in S3 used)"
    else
      sleep 15
      if kubectl run "history-check-retry-$$" -n "${HISTORY_NS}" --rm -i --restart=Never --image=curlimages/curl:latest -- \
        curl -sf "http://${HISTORY_SVC}:18080/api/v1/applications" 2>/dev/null | grep -q "ConnectStandaloneLoadTest\|application"; then
        echo "   ✓ History Server shows applications (event log in S3 used)"
      elif [[ "${LOAD_REQUIRE_HISTORY_SERVER}" == "true" ]]; then
        echo "   ERROR: History Server has no applications after load test (event log: ${LOAD_EVENT_LOG_DIR}). Deploy Connect with connect.eventLog.enabled=true."
        exit 1
      else
        echo "   WARN: History Server has no applications (set connect.eventLog.enabled=true on Connect server for event log)"
      fi
    fi
  fi
  echo ""
  echo "=== Load Test PASSED ==="
  exit 0
else
  echo ""
  echo "=== Load Test FAILED (exit ${EXIT_CODE}) ==="
  exit 1
fi
