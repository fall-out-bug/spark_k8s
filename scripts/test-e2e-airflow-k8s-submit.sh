#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${1:-spark-airflow-e2e}"
RELEASE="${2:-spark-airflow}"
SPARK_VERSION="${3:-3.5}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
source "${SCRIPT_DIR}/test-e2e-lib.sh"

SETUP="${SETUP:-true}"
CLEANUP="${CLEANUP:-false}"
SMOKE="${SMOKE:-false}"
SPARK_ROWS="${SPARK_ROWS:-20000}"
SPARK_SLEEP="${SPARK_SLEEP:-120}"

DAG_ID="spark_k8s_submit_e2e"
TASK_ID="spark_k8s_submit_e2e"

SPARK_TAG="$(resolve_spark_tag "${SPARK_VERSION}")"
EVENTLOG_PREFIX="spark-logs/events"
SPARK_IMAGE_DEFAULT="spark-custom:${SPARK_TAG}"
if [[ "${SPARK_VERSION}" == "4.1"* ]]; then
  EVENTLOG_PREFIX="spark-logs/4.1/events"
  SPARK_IMAGE_DEFAULT="spark-custom:${SPARK_TAG}"
fi

ensure_namespace() {
  local ns="$1"
  if ! kubectl get namespace "${ns}" >/dev/null 2>&1; then
    kubectl create namespace "${ns}" >/dev/null
  fi
}

ensure_event_log_prefix() {
  local ns="$1"
  local endpoint="${S3_ENDPOINT:-http://minio.${ns}.svc.cluster.local:9000}"
  local access_key="${S3_ACCESS_KEY:-minioadmin}"
  local secret_key="${S3_SECRET_KEY:-minioadmin}"
  local prefix="$2"

  kubectl run "mc-prefix-$(date +%s)-${RANDOM}" --rm -i --restart=Never -n "${ns}" --command \
    --image=quay.io/minio/mc:latest \
    -- /bin/sh -lc "mc alias set myminio ${endpoint} ${access_key} ${secret_key} >/dev/null 2>&1 && mc mb --ignore-existing myminio/spark-logs >/dev/null 2>&1 && echo '' | mc pipe myminio/${prefix}/.keep >/dev/null 2>&1" \
    >/dev/null 2>&1 || true
}

kubectl_exec_retry() {
  local ns="$1"
  local pod="$2"
  shift 2
  local cmd="$*"
  local attempt=1
  while true; do
    if kubectl exec -n "${ns}" "${pod}" -- sh -lc "${cmd}"; then
      return 0
    fi
    if [[ "${attempt}" -ge 5 ]]; then
      return 1
    fi
    attempt=$((attempt + 1))
    sleep 3
  done
}

get_scheduler_pod() {
  local ns="$1"
  local rel="$2"
  kubectl get pod -n "${ns}" -l "app=airflow-scheduler,app.kubernetes.io/instance=${rel}" -o jsonpath='{.items[0].metadata.name}'
}

wait_for_airflow_scheduler_pod() {
  local ns="$1"
  local rel="$2"
  local attempts=12
  local pod=""
  for _ in $(seq 1 "${attempts}"); do
    pod="$(get_scheduler_pod "${ns}" "${rel}")"
    if [[ -n "${pod}" ]]; then
      echo "${pod}"
      return 0
    fi
    sleep 3
  done
  return 1
}

wait_for_airflow_db() {
  local ns="$1"
  local pod="$2"
  local attempt=1
  while true; do
    if kubectl exec -n "${ns}" "${pod}" -- sh -lc "getent hosts postgresql-airflow >/dev/null 2>&1"; then
      return 0
    fi
    if [[ "${attempt}" -ge 10 ]]; then
      return 1
    fi
    attempt=$((attempt + 1))
    sleep 3
  done
}

wait_for_dag_loaded() {
  local ns="$1"
  local pod="$2"
  local dag_id="$3"
  local attempt=1
  while true; do
    if kubectl exec -n "${ns}" "${pod}" -- sh -lc "PYTHONWARNINGS=ignore airflow dags list --output json | grep -q '\"${dag_id}\"'"; then
      return 0
    fi
    if [[ "${attempt}" -ge 12 ]]; then
      return 1
    fi
    attempt=$((attempt + 1))
    sleep 5
  done
}

wait_for_minio() {
  local ns="$1"
  kubectl wait --for=condition=ready pod -n "${ns}" -l app=minio --timeout=240s >/dev/null 2>&1 || true
}

wait_for_pod() {
  local selector="$1"
  local ns="$2"
  kubectl wait --for=condition=ready pod -n "${ns}" -l "${selector}" --timeout=240s
}

wait_for_event_logs() {
  local ns="$1"
  local endpoint="$2"
  local prefix="$3"
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

wait_for_run_state() {
  local dag_id="$1"
  local run_id="$2"
  local timeout="$3"
  local poll="${POLL_SECONDS}"

  local deadline=$(( $(date +%s) + timeout ))
  while [ "$(date +%s)" -lt "${deadline}" ]; do
    local json
    json="$(kubectl exec -n "${NAMESPACE}" "${SCHEDULER_POD}" -- sh -lc "PYTHONWARNINGS=ignore airflow dags list-runs -d '${dag_id}' --output json" 2>/dev/null || true)"
    if [ -n "${json}" ]; then
      local state
      state="$(RUN_ID="${run_id}" python3 -c 'import json,os,sys; rid=os.environ["RUN_ID"]; runs=json.load(sys.stdin); print(next((r.get("state") or "" for r in runs if r.get("run_id")==rid), ""))' <<<"${json}" 2>/dev/null || true)"
      if [ "${state}" = "success" ]; then
        echo "   ${dag_id} ${run_id}: success"
        return 0
      fi
      if [ "${state}" = "failed" ]; then
        echo "   ${dag_id} ${run_id}: failed"
        return 1
      fi
      if [ -n "${state}" ]; then
        echo "   ${dag_id} ${run_id}: ${state}"
      else
        echo "   ${dag_id} ${run_id}: queued/running"
      fi
    else
      echo "   ${dag_id} ${run_id}: queued/running"
    fi
    sleep "${poll}"
  done
  echo "   ${dag_id} ${run_id}: timeout after ${timeout}s"
  return 2
}

check_metrics_driver() {
  local pod="$1"
  local ns="$2"
  kubectl port-forward "pod/${pod}" 4040:4040 -n "${ns}" >/dev/null 2>&1 &
  local pf_pid=$!
  local ok="false"
  for _ in $(seq 1 30); do
    if curl -fsSL http://localhost:4040/metrics/json 2>/dev/null | grep -q '"gauges"'; then
      ok="true"
      break
    fi
    sleep 2
  done
  kill "${pf_pid}" 2>/dev/null || true
  wait "${pf_pid}" 2>/dev/null || true
  if [[ "${ok}" == "true" ]]; then
    return 0
  fi
  return 1
}

install_airflow_stack() {
  local ns="$1"
  local rel="$2"
  local fernet_key="${FERNET_KEY:-9_jzOiAmnzfASdT81H2Epx6R56z3XQP9N8vr3W76wro=}"
  helm upgrade --install "${rel}" charts/spark-standalone -n "${ns}" \
    --set airflow.enabled=true \
    --set airflow.fernetKey="${fernet_key}" \
    --set airflow.kubernetesExecutor.deleteWorkerPods=false \
    --set minio.enabled=true \
    --set minio.persistence.enabled=false \
    --set mlflow.enabled=false \
    --set hiveMetastore.enabled=false \
    --set historyServer.enabled=false \
    --set sparkMaster.enabled=false \
    --set sparkWorker.enabled=false \
    --set shuffleService.enabled=false \
    --set ingress.enabled=false \
    --set airflow.scheduler.resources.requests.cpu=100m \
    --set airflow.scheduler.resources.requests.memory=256Mi \
    --set airflow.scheduler.resources.limits.cpu=500m \
    --set airflow.scheduler.resources.limits.memory=1Gi \
    --set airflow.webserver.resources.requests.cpu=100m \
    --set airflow.webserver.resources.requests.memory=256Mi \
    --set airflow.webserver.resources.limits.cpu=500m \
    --set airflow.webserver.resources.limits.memory=1Gi \
    --set security.podSecurityStandards=false >/dev/null
  kubectl rollout restart -n "${ns}" "deploy/${rel}-spark-standalone-airflow-scheduler" >/dev/null 2>&1 || true
  kubectl rollout restart -n "${ns}" "deploy/${rel}-spark-standalone-airflow-webserver" >/dev/null 2>&1 || true
}

cleanup_all() {
  helm uninstall "${RELEASE}" -n "${NAMESPACE}" >/dev/null 2>&1 || true
  kubectl delete namespace "${NAMESPACE}" >/dev/null 2>&1 || true
}

TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-900}"
POLL_SECONDS="${POLL_SECONDS:-10}"

echo "=== Airflow + Spark K8s Submit E2E (${RELEASE} in ${NAMESPACE}) ==="

if [[ "${SETUP}" == "true" ]]; then
  ensure_spark_custom_image "${SPARK_VERSION}"
  ensure_namespace "${NAMESPACE}"
  install_airflow_stack "${NAMESPACE}" "${RELEASE}"
fi

wait_for_minio "${NAMESPACE}"
wait_for_pod "app=postgresql-airflow" "${NAMESPACE}"

echo "1) Waiting for Airflow scheduler..."
kubectl rollout status -n "${NAMESPACE}" "deploy/${RELEASE}-spark-standalone-airflow-scheduler" --timeout=180s
SCHEDULER_POD="$(wait_for_airflow_scheduler_pod "${NAMESPACE}" "${RELEASE}")"
echo "   Scheduler pod: ${SCHEDULER_POD}"
wait_for_airflow_db "${NAMESPACE}" "${SCHEDULER_POD}"

MINIO_ENDPOINT="${S3_ENDPOINT:-http://minio.${NAMESPACE}.svc.cluster.local:9000}"
echo "2) Ensuring event log prefix (${EVENTLOG_PREFIX})..."
ensure_event_log_prefix "${NAMESPACE}" "${EVENTLOG_PREFIX}"

echo "3) Setting Airflow Variables..."
SCHEDULER_POD="$(wait_for_airflow_scheduler_pod "${NAMESPACE}" "${RELEASE}")"
wait_for_airflow_db "${NAMESPACE}" "${SCHEDULER_POD}"
SPARK_IMAGE_VALUE="${SPARK_IMAGE_VALUE:-${SPARK_IMAGE_DEFAULT}}"
SPARK_NAMESPACE_VALUE="${SPARK_NAMESPACE_VALUE:-${NAMESPACE}}"
SPARK_K8S_SERVICEACCOUNT_VALUE="${SPARK_K8S_SERVICEACCOUNT_VALUE:-spark}"
SPARK_EVENTLOG_DIR_VALUE="${SPARK_EVENTLOG_DIR_VALUE:-s3a://${EVENTLOG_PREFIX}}"

S3_ENDPOINT_VALUE="${S3_ENDPOINT_VALUE:-${MINIO_ENDPOINT}}"
S3_ACCESS_KEY_VALUE="${S3_ACCESS_KEY_VALUE:-}"
S3_SECRET_KEY_VALUE="${S3_SECRET_KEY_VALUE:-}"

if [[ -z "${S3_ACCESS_KEY_VALUE}" || -z "${S3_SECRET_KEY_VALUE}" ]]; then
  if kubectl get secret -n "${NAMESPACE}" s3-credentials >/dev/null 2>&1; then
    S3_ACCESS_KEY_VALUE="$(kubectl get secret -n "${NAMESPACE}" s3-credentials -o jsonpath='{.data.access-key}' | base64 -d)"
    S3_SECRET_KEY_VALUE="$(kubectl get secret -n "${NAMESPACE}" s3-credentials -o jsonpath='{.data.secret-key}' | base64 -d)"
  fi
fi

if [[ "${SMOKE}" == "true" ]]; then
  SPARK_ROWS=5000
  SPARK_SLEEP=60
fi

kubectl_exec_retry "${NAMESPACE}" "${SCHEDULER_POD}" "PYTHONWARNINGS=ignore airflow variables set 'spark_image' '${SPARK_IMAGE_VALUE}' && PYTHONWARNINGS=ignore airflow variables set 'spark_namespace' '${SPARK_NAMESPACE_VALUE}' && PYTHONWARNINGS=ignore airflow variables set 'spark_k8s_serviceaccount' '${SPARK_K8S_SERVICEACCOUNT_VALUE}' && PYTHONWARNINGS=ignore airflow variables set 'spark_eventlog_dir' '${SPARK_EVENTLOG_DIR_VALUE}' && PYTHONWARNINGS=ignore airflow variables set 's3_endpoint' '${S3_ENDPOINT_VALUE}' && PYTHONWARNINGS=ignore airflow variables set 's3_access_key' '${S3_ACCESS_KEY_VALUE}' && PYTHONWARNINGS=ignore airflow variables set 's3_secret_key' '${S3_SECRET_KEY_VALUE}'"
kubectl_exec_retry "${NAMESPACE}" "${SCHEDULER_POD}" "PYTHONWARNINGS=ignore airflow variables set 'spark_rows' '${SPARK_ROWS}' && PYTHONWARNINGS=ignore airflow variables set 'spark_sleep' '${SPARK_SLEEP}'"

RUN_ID="e2e-k8s-submit-$(date +%Y%m%d-%H%M%S)"
echo ""
echo "4) Triggering DAG ${DAG_ID} (run_id=${RUN_ID})..."
SCHEDULER_POD="$(wait_for_airflow_scheduler_pod "${NAMESPACE}" "${RELEASE}")"
wait_for_airflow_db "${NAMESPACE}" "${SCHEDULER_POD}"
wait_for_dag_loaded "${NAMESPACE}" "${SCHEDULER_POD}" "${DAG_ID}"
kubectl_exec_retry "${NAMESPACE}" "${SCHEDULER_POD}" "PYTHONWARNINGS=ignore airflow dags trigger -r '${RUN_ID}' '${DAG_ID}'"

echo "5) Waiting for task pod to start..."
TASK_POD=""
for _ in $(seq 1 24); do
  TASK_POD="$(kubectl get pod -n "${NAMESPACE}" -l "task_id=${TASK_ID},run_id=${RUN_ID}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
  if [[ -n "${TASK_POD}" ]]; then
    break
  fi
  sleep 5
done
if [[ -z "${TASK_POD}" ]]; then
  echo "ERROR: Task pod not found for run_id=${RUN_ID}"
  exit 1
fi
kubectl wait --for=condition=ready pod -n "${NAMESPACE}" "${TASK_POD}" --timeout=120s >/dev/null 2>&1 || true

echo "6) Waiting for driver pod to start..."
for _ in $(seq 1 24); do
  DRIVER_POD="$(kubectl get pod -n "${SPARK_NAMESPACE_VALUE}" -l "spark-role=driver,e2e_run_id=${RUN_ID}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
  if [[ -n "${DRIVER_POD}" ]]; then
    break
  fi
  sleep 5
done
if [[ -z "${DRIVER_POD}" ]]; then
  echo "Driver pod not found; using task pod as driver (client mode)."
  DRIVER_POD="${TASK_POD}"
fi

echo "7) Checking Spark metrics endpoint..."
if ! check_metrics_driver "${DRIVER_POD}" "${SPARK_NAMESPACE_VALUE}"; then
  if [[ "${DRIVER_POD}" == "${TASK_POD}" ]]; then
    echo "WARN: Spark metrics endpoint not reachable (client mode task pod ended quickly)"
  else
    echo "ERROR: Spark metrics endpoint not reachable"
    exit 1
  fi
fi

echo "8) Waiting for DAG completion..."
wait_for_run_state "${DAG_ID}" "${RUN_ID}" "${TIMEOUT_SECONDS}"

echo "9) Checking driver logs for RESULT_SUM..."
RESULT_LOGS="$(kubectl logs -n "${SPARK_NAMESPACE_VALUE}" "${DRIVER_POD}" 2>/dev/null || true)"
if ! echo "${RESULT_LOGS}" | grep -q "RESULT_SUM="; then
  RESULT_LOGS="$(kubectl -n "${NAMESPACE}" logs -l "run_id=${RUN_ID}" 2>/dev/null || true)"
  echo "${RESULT_LOGS}" | grep -q "RESULT_SUM=" || {
    echo "ERROR: RESULT_SUM not found in driver logs"
    exit 1
  }
fi

echo "9) Checking event logs in MinIO (${EVENTLOG_PREFIX})..."
wait_for_event_logs "${NAMESPACE}" "${MINIO_ENDPOINT}" "${EVENTLOG_PREFIX}" || {
  echo "ERROR: Event logs not found in MinIO prefix ${EVENTLOG_PREFIX}"
  exit 1
}

if [[ "${CLEANUP}" == "true" ]]; then
  cleanup_all
fi

echo "=== E2E PASSED ==="
