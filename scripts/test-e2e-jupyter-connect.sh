#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${1:-spark-jupyter-e2e}"
RELEASE="${2:-spark-connect}"
SPARK_VERSION="${3:-3.5}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
source "${SCRIPT_DIR}/test-e2e-lib.sh"

BACKEND_MODE="${BACKEND_MODE:-k8s}" # k8s|standalone
SETUP="${SETUP:-true}"
CLEANUP="${CLEANUP:-false}"

SA_NAMESPACE="${SA_NAMESPACE:-${NAMESPACE}-sa}"
SA_RELEASE="${SA_RELEASE:-sa-${RELEASE}}"
SA_SPARK_VERSION="${SA_SPARK_VERSION:-${SPARK_VERSION}}"
SPARK_TAG="$(resolve_spark_tag "${SPARK_VERSION}")"
SA_SPARK_TAG="$(resolve_spark_tag "${SA_SPARK_VERSION}")"

if [[ "${BACKEND_MODE}" == "standalone" && "${SPARK_VERSION}" == "4.1"* ]]; then
  SA_NAMESPACE="${NAMESPACE}"
fi

CONNECT_SELECTOR="app=spark-connect,app.kubernetes.io/instance=${RELEASE}"
JUPYTER_SELECTOR="app=jupyter,app.kubernetes.io/instance=${RELEASE}"

EVENTLOG_PREFIX="spark-logs/events"
CONNECT_CHART="charts/spark-3.5/charts/spark-connect"
CONNECT_SERVICE_NAME="spark-connect"
if [[ "${SPARK_VERSION}" == "4.1"* ]]; then
  EVENTLOG_PREFIX="spark-logs/events"
  CONNECT_CHART="charts/spark-4.1"
  CONNECT_SERVICE_NAME="${RELEASE}-spark-41-connect"
fi

get_first_by_selector() {
  local kind="$1"
  local selector="$2"
  local ns="$3"
  kubectl get "${kind}" -n "${ns}" -l "${selector}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true
}

get_ready_pod() {
  local selector="$1"
  local ns="$2"
  kubectl get pod -n "${ns}" -l "${selector}" -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' 2>/dev/null | awk '$2=="True"{print $1; exit}'
}

wait_for_pod() {
  local selector="$1"
  local ns="$2"
  local attempts=24
  for _ in $(seq 1 "${attempts}"); do
    local ready
    local rc
    set +e
    ready="$(kubectl get pod -n "${ns}" -l "${selector}" -o jsonpath='{range .items[*]}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' 2>/dev/null | grep -c '^True$' || true)"
    rc=$?
    set -e
    if [[ "${rc}" -ne 0 ]]; then
      sleep 10
      continue
    fi
    if [[ "${ready}" -ge 1 ]]; then
      return 0
    fi
    sleep 10
  done
  return 1
}

wait_for_ready_pod() {
  local selector="$1"
  local ns="$2"
  local attempts=24
  for _ in $(seq 1 "${attempts}"); do
    local pod
    pod="$(get_ready_pod "${selector}" "${ns}")"
    if [[ -n "${pod}" ]]; then
      echo "${pod}"
      return 0
    fi
    sleep 10
  done
  return 1
}

wait_for_minio() {
  local ns="$1"
  kubectl wait --for=condition=ready pod -n "${ns}" -l app=minio --timeout=240s >/dev/null 2>&1 || true
}

ensure_namespace() {
  local ns="$1"
  if ! kubectl get namespace "${ns}" >/dev/null 2>&1; then
    kubectl create namespace "${ns}" >/dev/null
  fi
}

ensure_s3_secret() {
  local ns="$1"
  local access_key="${S3_ACCESS_KEY:-minioadmin}"
  local secret_key="${S3_SECRET_KEY:-minioadmin}"
  if ! kubectl get secret -n "${ns}" s3-credentials >/dev/null 2>&1; then
    kubectl create secret generic s3-credentials \
      -n "${ns}" \
      --from-literal=access-key="${access_key}" \
      --from-literal=secret-key="${secret_key}" >/dev/null
  fi
}

ensure_event_log_prefix() {
  local ns="$1"
  local endpoint="${S3_ENDPOINT:-http://minio:9000}"
  local access_key="${S3_ACCESS_KEY:-minioadmin}"
  local secret_key="${S3_SECRET_KEY:-minioadmin}"
  local prefix="$2"

  kubectl run "mc-prefix-$(date +%s)-${RANDOM}" --rm -i --restart=Never -n "${ns}" --command \
    --image=quay.io/minio/mc:latest \
    -- /bin/sh -lc "mc alias set myminio ${endpoint} ${access_key} ${secret_key} >/dev/null 2>&1 && mc mb --ignore-existing myminio/spark-logs >/dev/null 2>&1 && echo '' | mc pipe myminio/${prefix}/.keep >/dev/null 2>&1" \
    >/dev/null 2>&1 || true
}

check_metrics() {
  local selector="$1"
  local ns="$2"
  for _ in $(seq 1 15); do
    local pod
    pod="$(get_ready_pod "${selector}" "${ns}")"
    if [[ -z "${pod}" ]]; then
      sleep 2
      continue
    fi
    if kubectl exec -n "${ns}" "${pod}" -- sh -lc "if command -v curl >/dev/null 2>&1; then curl -fsSL --max-time 2 http://localhost:4040/metrics/json 2>/dev/null; else python3 -c \"import urllib.request; print(urllib.request.urlopen('http://localhost:4040/metrics/json', timeout=2).read().decode())\"; fi | grep -q '\"gauges\"'"; then
      return 0
    fi
    sleep 2
  done
  return 1
}

wait_for_event_logs() {
  local ns="$1"
  local prefix="$2"
  local endpoint="${S3_ENDPOINT:-http://minio:9000}"
  local access_key="${S3_ACCESS_KEY:-minioadmin}"
  local secret_key="${S3_SECRET_KEY:-minioadmin}"

  for _ in $(seq 1 12); do
    if kubectl run "mc-check-$(date +%s)-${RANDOM}" --rm -i --restart=Never -n "${ns}" --command \
      --image=quay.io/minio/mc:latest \
      -- /bin/sh -lc "mc alias set myminio ${endpoint} ${access_key} ${secret_key} >/dev/null 2>&1 && mc ls myminio/${prefix} | grep -v '\\.keep$' | head -n 1" \
      >/dev/null 2>&1; then
      return 0
    fi
    sleep 5
  done
  return 1
}

install_standalone() {
  local ns="$1"
  local rel="$2"
  local version="$3"
  local extra_args=()
  if [[ "${ns}" == "${NAMESPACE}" ]]; then
    extra_args+=(--set s3.existingSecret=s3-credentials)
  fi
  helm upgrade --install "${rel}" charts/spark-standalone -n "${ns}" \
    --set minio.enabled=false \
    --set airflow.enabled=false \
    --set mlflow.enabled=false \
    --set hiveMetastore.enabled=false \
    --set historyServer.enabled=false \
    --set shuffleService.enabled=false \
    --set ingress.enabled=false \
    --set sparkWorker.replicas=1 \
    --set sparkMaster.resources.requests.cpu=0 \
    --set sparkMaster.resources.requests.memory=512Mi \
    --set sparkMaster.resources.limits.cpu=500m \
    --set sparkMaster.resources.limits.memory=1Gi \
    --set sparkWorker.resources.requests.cpu=0 \
    --set sparkWorker.resources.requests.memory=512Mi \
    --set sparkWorker.resources.limits.cpu=500m \
    --set sparkWorker.resources.limits.memory=1Gi \
    --set sparkMaster.image.tag="${version}" \
    --set sparkWorker.image.tag="${version}" \
    --set security.podSecurityStandards=false \
    "${extra_args[@]}" >/dev/null
}

install_connect() {
  local ns="$1"
  local rel="$2"
  local backend="$3"
  local master_fqdn="$4"
  local driver_host="$5"

  if [[ "${SPARK_VERSION}" == "4.1"* ]]; then
    local extra_args=()
    if [[ "${backend}" == "standalone" ]]; then
      extra_args+=(--set-string connect.sparkConf.spark\\.executor\\.instances=1)
      extra_args+=(--set-string connect.sparkConf.spark\\.executor\\.cores=1)
      extra_args+=(--set-string connect.sparkConf.spark\\.executor\\.memory=512m)
      extra_args+=(--set-string connect.sparkConf.spark\\.dynamicAllocation\\.enabled=false)
    fi
    ensure_s3_secret "${ns}"
    helm upgrade --install "${rel}" "${CONNECT_CHART}" -n "${ns}" \
      --set connect.enabled=true \
      --set connect.backendMode="${backend}" \
      --set connect.image.tag="${SPARK_TAG}" \
      --set connect.resources.requests.cpu=0 \
      --set connect.resources.requests.memory=512Mi \
      --set connect.resources.limits.cpu=500m \
      --set connect.resources.limits.memory=2Gi \
      --set connect.driver.host="${driver_host}" \
      --set connect.standalone.masterService="${master_fqdn}" \
      --set connect.standalone.masterPort=7077 \
      --set connect.eventLog.enabled=true \
      --set jupyter.enabled=true \
      --set jupyter.image.tag="${SPARK_TAG}" \
      --set jupyter.resources.requests.cpu=0 \
      --set jupyter.resources.requests.memory=256Mi \
      --set jupyter.resources.limits.cpu=500m \
      --set jupyter.resources.limits.memory=1Gi \
      --set historyServer.enabled=false \
      --set hiveMetastore.enabled=false \
      --set security.podSecurityStandards=false \
      --set spark-base.enabled=true \
      --set spark-base.minio.enabled=true \
      --set spark-base.minio.resources.requests.cpu=0 \
      --set spark-base.minio.persistence.enabled=false \
      --set spark-base.postgresql.enabled=false \
      --set global.s3.endpoint="${S3_ENDPOINT:-http://minio:9000}" \
      --set global.s3.accessKey="${S3_ACCESS_KEY:-minioadmin}" \
      --set global.s3.secretKey="${S3_SECRET_KEY:-minioadmin}" \
      "${extra_args[@]}" \
      >/dev/null
    kubectl rollout restart deployment -n "${ns}" -l app=spark-connect >/dev/null 2>&1 || true
  else
    local extra_args=()
    if [[ "${backend}" == "standalone" ]]; then
      extra_args+=(--set-string sparkConnect.sparkConf.spark\\.executor\\.instances=1)
      extra_args+=(--set-string sparkConnect.sparkConf.spark\\.executor\\.cores=1)
      extra_args+=(--set-string sparkConnect.sparkConf.spark\\.executor\\.memory=1g)
    fi
    helm upgrade --install "${rel}" "${CONNECT_CHART}" -n "${ns}" \
      --set sparkConnect.enabled=true \
      --set sparkConnect.backendMode="${backend}" \
      --set sparkConnect.image.tag="${SPARK_TAG}" \
      --set sparkConnect.resources.requests.cpu=50m \
      --set sparkConnect.resources.requests.memory=1Gi \
      --set sparkConnect.resources.limits.cpu=500m \
      --set sparkConnect.resources.limits.memory=3Gi \
      --set sparkConnect.driver.host="${driver_host}" \
      --set sparkConnect.standalone.masterService="${master_fqdn}" \
      --set sparkConnect.standalone.masterPort=7077 \
      --set jupyter.enabled=true \
      --set jupyter.service.type=ClusterIP \
      --set jupyter.resources.requests.cpu=100m \
      --set jupyter.resources.requests.memory=256Mi \
      --set jupyter.resources.limits.cpu=500m \
      --set jupyter.resources.limits.memory=1Gi \
      --set jupyterhub.enabled=false \
      --set historyServer.enabled=false \
      --set hiveMetastore.enabled=false \
      --set postgresql.enabled=false \
      --set minio.enabled=true \
      --set minio.persistence.enabled=false \
      --set minio.resources.requests.cpu=50m \
      --set minio.resources.requests.memory=128Mi \
      --set minio.resources.limits.cpu=200m \
      --set minio.resources.limits.memory=512Mi \
      --set s3.endpoint="${S3_ENDPOINT:-http://minio:9000}" \
      "${extra_args[@]}" \
      >/dev/null
    kubectl rollout restart deployment -n "${ns}" -l app=spark-connect >/dev/null 2>&1 || true
  fi
}

cleanup_all() {
  helm uninstall "${RELEASE}" -n "${NAMESPACE}" >/dev/null 2>&1 || true
  helm uninstall "${SA_RELEASE}" -n "${SA_NAMESPACE}" >/dev/null 2>&1 || true
  kubectl delete namespace "${NAMESPACE}" >/dev/null 2>&1 || true
  kubectl delete namespace "${SA_NAMESPACE}" >/dev/null 2>&1 || true
}

echo "=== Jupyter + Spark Connect E2E (${RELEASE} in ${NAMESPACE}, Spark ${SPARK_VERSION}, backend=${BACKEND_MODE}) ==="

if [[ "${SETUP}" == "true" ]]; then
  ensure_spark_custom_image "${SPARK_VERSION}"
  ensure_jupyter_image "${SPARK_VERSION}"
  ensure_namespace "${NAMESPACE}"
  if [[ "${BACKEND_MODE}" == "standalone" ]]; then
    ensure_namespace "${SA_NAMESPACE}"
    ensure_spark_custom_image "${SA_SPARK_VERSION}"
    install_standalone "${SA_NAMESPACE}" "${SA_RELEASE}" "${SA_SPARK_TAG}"
  fi

  STANDALONE_MASTER_FQDN="${SA_RELEASE}-spark-standalone-master-hl.${SA_NAMESPACE}.svc.cluster.local"
  CONNECT_DRIVER_HOST="${CONNECT_SERVICE_NAME}.${NAMESPACE}.svc.cluster.local"
  install_connect "${NAMESPACE}" "${RELEASE}" "${BACKEND_MODE}" "${STANDALONE_MASTER_FQDN}" "${CONNECT_DRIVER_HOST}"
fi

wait_for_minio "${NAMESPACE}"

echo "1) Ensuring event log prefix (${EVENTLOG_PREFIX})..."
ensure_event_log_prefix "${NAMESPACE}" "${EVENTLOG_PREFIX}"
if [[ "${SPARK_VERSION}" == "4.1"* ]]; then
  kubectl rollout restart deployment -n "${NAMESPACE}" -l app=spark-connect >/dev/null 2>&1 || true
fi

echo "2) Waiting for Spark Connect and Jupyter pods..."
CONNECT_POD="$(wait_for_ready_pod "${CONNECT_SELECTOR}" "${NAMESPACE}")" || true
JUPYTER_POD="$(wait_for_ready_pod "${JUPYTER_SELECTOR}" "${NAMESPACE}")" || true
if [[ -z "${CONNECT_POD}" || -z "${JUPYTER_POD}" ]]; then
  echo "ERROR: Connect or Jupyter pod not found"
  exit 1
fi

CONNECT_SERVICE="$(get_first_by_selector svc "${CONNECT_SELECTOR}" "${NAMESPACE}")"
if [[ -z "${CONNECT_SERVICE}" ]]; then
  if kubectl get svc spark-connect -n "${NAMESPACE}" >/dev/null 2>&1; then
    CONNECT_SERVICE="spark-connect"
  else
    echo "ERROR: Spark Connect service not found"
    exit 1
  fi
fi

CONNECT_URL="sc://${CONNECT_SERVICE}:15002"

echo "3) Running Spark Connect job from Jupyter..."
SPARK_ROWS="${SPARK_ROWS:-200000}"
JOB_OUT=""
JOB_STATUS=1
for attempt in 1 2 3; do
  set +e
  JOB_OUT="$(timeout 180 kubectl exec -n "${NAMESPACE}" "${JUPYTER_POD}" -- /bin/sh -lc "SPARK_CONNECT_URL='${CONNECT_URL}' SPARK_ROWS='${SPARK_ROWS}' python3 - <<'PY'
import os
from pyspark.sql import SparkSession

rows = int(os.environ.get('SPARK_ROWS', '200000'))
spark = (
    SparkSession.builder.appName('JupyterConnectE2E')
    .remote(os.environ['SPARK_CONNECT_URL'])
    .getOrCreate()
)

df = spark.range(0, rows)
result = df.agg({'id': 'sum'}).collect()[0][0]
print(f'RESULT_SUM={result}')
spark.stop()
PY" 2>&1)"
  JOB_STATUS=$?
  set -e
  if [[ "${JOB_STATUS}" -eq 0 ]]; then
    break
  fi
  if [[ "${JOB_STATUS}" -eq 124 ]] || echo "${JOB_OUT}" | grep -qE "SESSION_NOT_FOUND|SESSION_CHANGED|stopped SparkContext|i/o timeout|error reading from error stream|unable to upgrade connection|stream protocol error"; then
    echo "WARN: Spark Connect session reset (attempt ${attempt}), retrying..."
    sleep 10
    continue
  fi
  echo "${JOB_OUT}"
  exit 1
done
if [[ "${JOB_STATUS}" -ne 0 ]]; then
  echo "${JOB_OUT}"
  exit 1
fi

echo "${JOB_OUT}" | grep -q "RESULT_SUM=" || {
  echo "ERROR: Expected RESULT_SUM not found in output"
  exit 1
}

echo "4) Checking Spark metrics endpoint..."
check_metrics "${CONNECT_SELECTOR}" "${NAMESPACE}" || {
  echo "ERROR: Spark metrics endpoint not reachable"
  exit 1
}

echo "5) Checking event logs in MinIO (${EVENTLOG_PREFIX})..."
wait_for_event_logs "${NAMESPACE}" "${EVENTLOG_PREFIX}" || {
  echo "ERROR: Event logs not found in MinIO prefix ${EVENTLOG_PREFIX}"
  exit 1
}

if [[ "${CLEANUP}" == "true" ]]; then
  cleanup_all
fi

echo "=== E2E PASSED ==="
