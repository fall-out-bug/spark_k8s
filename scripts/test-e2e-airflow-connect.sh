#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${1:-spark-airflow-e2e}"
RELEASE="${2:-spark-airflow}"
SPARK_VERSION="${3:-3.5}"
CONNECT_NAMESPACE="${4:-${NAMESPACE}-connect}"
CONNECT_RELEASE="${5:-${RELEASE}-connect}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
source "${SCRIPT_DIR}/test-e2e-lib.sh"

BACKEND_MODE="${BACKEND_MODE:-k8s}" # k8s|standalone
SETUP="${SETUP:-true}"
CLEANUP="${CLEANUP:-false}"
SA_SPARK_VERSION="${SA_SPARK_VERSION:-${SPARK_VERSION}}"
SPARK_TAG="$(resolve_spark_tag "${SPARK_VERSION}")"
SA_SPARK_TAG="$(resolve_spark_tag "${SA_SPARK_VERSION}")"

if [[ "${BACKEND_MODE}" == "standalone" && "${SPARK_VERSION}" == "4.1"* ]]; then
  CONNECT_NAMESPACE="${NAMESPACE}"
fi
SMOKE="${SMOKE:-false}"
SPARK_ROWS="${SPARK_ROWS:-20000}"

DAG_ID="spark_connect_e2e"
TASK_ID="spark_connect_e2e"

EVENTLOG_PREFIX="spark-logs/events"
SPARK_IMAGE_DEFAULT="spark-custom:${SPARK_TAG}"
CONNECT_CHART="charts/spark-3.5/charts/spark-connect"
CONNECT_SERVICE_NAME="spark-connect"
if [[ "${SPARK_VERSION}" == "4.1"* ]]; then
  EVENTLOG_PREFIX="spark-logs/4.1/events"
  SPARK_IMAGE_DEFAULT="spark-custom:${SPARK_TAG}"
  CONNECT_CHART="charts/spark-4.1"
  CONNECT_SERVICE_NAME="${CONNECT_RELEASE}-spark-41-connect"
fi

CONNECT_SELECTOR="app=spark-connect,app.kubernetes.io/instance=${CONNECT_RELEASE}"

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

wait_for_pod() {
  local selector="$1"
  local ns="$2"
  kubectl wait --for=condition=ready pod -n "${ns}" -l "${selector}" --timeout=240s
}

wait_for_minio() {
  local ns="$1"
  kubectl wait --for=condition=ready pod -n "${ns}" -l app=minio --timeout=240s >/dev/null 2>&1 || true
}

get_first_by_selector() {
  local kind="$1"
  local selector="$2"
  local ns="$3"
  kubectl get "${kind}" -n "${ns}" -l "${selector}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true
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
ensure_event_log_prefix() {
  local ns="$1"
  local endpoint="$2"
  local access_key="${S3_ACCESS_KEY:-minioadmin}"
  local secret_key="${S3_SECRET_KEY:-minioadmin}"
  local prefix="$3"

  kubectl run "mc-prefix-$(date +%s)-${RANDOM}" --rm -i --restart=Never -n "${ns}" --command \
    --image=quay.io/minio/mc:latest \
    -- /bin/sh -lc "mc alias set myminio ${endpoint} ${access_key} ${secret_key} >/dev/null 2>&1 && mc mb --ignore-existing myminio/spark-logs >/dev/null 2>&1 && echo '' | mc pipe myminio/${prefix}/.keep >/dev/null 2>&1" \
    >/dev/null 2>&1 || true
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

check_metrics() {
  local pod="$1"
  local ns="$2"
  kubectl port-forward "pod/${pod}" 4040:4040 -n "${ns}" >/dev/null 2>&1 &
  local pf_pid=$!
  local ok="false"
  for _ in $(seq 1 15); do
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
  local backend="$3"
  local spark_version="$4"
  local master_enabled="false"
  local worker_enabled="false"
  local master_worker_args=()
  local fernet_key="${FERNET_KEY:-9_jzOiAmnzfASdT81H2Epx6R56z3XQP9N8vr3W76wro=}"
  local worker_memory="1g"
  local worker_memory_request="1Gi"
  local worker_memory_limit="1Gi"

  if [[ "${backend}" == "standalone" ]]; then
    master_enabled="true"
    worker_enabled="true"
    if [[ "${spark_version}" == "4.1"* ]]; then
      worker_memory="2g"
      worker_memory_request="2Gi"
      worker_memory_limit="2Gi"
    fi
    master_worker_args+=(
      --set sparkMaster.resources.requests.cpu=200m
      --set sparkMaster.resources.requests.memory=512Mi
      --set sparkMaster.resources.limits.cpu=1
      --set sparkMaster.resources.limits.memory=1Gi
      --set sparkWorker.cores=1
      --set sparkWorker.memory="${worker_memory}"
      --set sparkWorker.resources.requests.cpu=200m
      --set sparkWorker.resources.requests.memory="${worker_memory_request}"
      --set sparkWorker.resources.limits.cpu=1
      --set sparkWorker.resources.limits.memory="${worker_memory_limit}"
    )
  fi

  helm upgrade --install "${rel}" charts/spark-standalone -n "${ns}" \
    --set airflow.enabled=true \
    --set airflow.fernetKey="${fernet_key}" \
    --set minio.enabled=true \
    --set minio.persistence.enabled=false \
    --set mlflow.enabled=false \
    --set hiveMetastore.enabled=false \
    --set historyServer.enabled=false \
    --set sparkMaster.enabled="${master_enabled}" \
    --set sparkWorker.enabled="${worker_enabled}" \
    --set sparkWorker.replicas=1 \
    --set shuffleService.enabled=false \
    --set ingress.enabled=false \
    --set sparkMaster.image.tag="${spark_version}" \
    --set sparkWorker.image.tag="${spark_version}" \
    "${master_worker_args[@]}" \
    --set airflow.scheduler.resources.requests.cpu=100m \
    --set airflow.scheduler.resources.requests.memory=256Mi \
    --set airflow.scheduler.resources.limits.cpu=500m \
    --set airflow.scheduler.resources.limits.memory=1Gi \
    --set airflow.webserver.resources.requests.cpu=100m \
    --set airflow.webserver.resources.requests.memory=256Mi \
    --set airflow.webserver.resources.limits.cpu=500m \
    --set airflow.webserver.resources.limits.memory=1Gi \
    --set airflow.kubernetesExecutor.deleteWorkerPods=false \
    --set security.podSecurityStandards=false >/dev/null
  kubectl rollout restart -n "${ns}" "deploy/${rel}-spark-standalone-airflow-scheduler" >/dev/null 2>&1 || true
  kubectl rollout restart -n "${ns}" "deploy/${rel}-spark-standalone-airflow-webserver" >/dev/null 2>&1 || true
}

install_connect() {
  local ns="$1"
  local rel="$2"
  local backend="$3"
  local driver_host="$4"
  local master_fqdn="$5"
  local s3_endpoint="$6"
  local minio_enabled="$7"
  local use_shared_sa="false"
  local driver_host_value="${driver_host}"
  local sa_args=()
  local rbac_args=()
  local s3_args=()

  if [[ "${ns}" == "${NAMESPACE}" ]]; then
    use_shared_sa="true"
  fi
  if [[ "${use_shared_sa}" == "true" ]]; then
    sa_args+=(--set serviceAccount.create=false --set serviceAccount.name=spark)
    rbac_args+=(--set spark-base.serviceAccount.create=false --set spark-base.serviceAccount.name=spark --set rbac.create=false --set rbac.serviceAccountName=spark)
    s3_args+=(--set s3.existingSecret=s3-credentials)
  else
    sa_args+=(--set serviceAccount.create=true --set serviceAccount.name=spark)
    rbac_args+=(--set rbac.create=true)
  fi

  if [[ "${SPARK_VERSION}" == "4.1"* ]]; then
    ensure_s3_secret "${ns}"
    local connect_extra=()
    if [[ "${backend}" == "standalone" ]]; then
      driver_host_value='${POD_IP}'
    fi
    if [[ "${backend}" == "k8s" ]]; then
      connect_extra+=(--set connect.executor.memory=512Mi)
      connect_extra+=(--set connect.executor.memoryLimit=1Gi)
      connect_extra+=(--set connect.executor.cores=0.1)
      connect_extra+=(--set connect.executor.coresLimit=0.5)
      connect_extra+=(--set connect.dynamicAllocation.enabled=false)
      connect_extra+=(--set connect.dynamicAllocation.minExecutors=1)
      connect_extra+=(--set connect.dynamicAllocation.maxExecutors=1)
      connect_extra+=(--set-string connect.sparkConf.spark\\.driver\\.memory=512m)
      connect_extra+=(--set-string connect.sparkConf.spark\\.executor\\.memory=512m)
      connect_extra+=(--set-string connect.sparkConf.spark\\.executor\\.instances=1)
      connect_extra+=(--set-string connect.sparkConf.spark\\.sql\\.shuffle\\.partitions=2)
      connect_extra+=(--set-string connect.sparkConf.spark\\.kubernetes\\.executor\\.request\\.cores=0.1)
      connect_extra+=(--set-string connect.sparkConf.spark\\.kubernetes\\.executor\\.limit\\.cores=0.5)
    else
      connect_extra+=(--set-string connect.sparkConf.spark\\.driver\\.memory=512m)
      connect_extra+=(--set-string connect.sparkConf.spark\\.executor\\.memory=512m)
      connect_extra+=(--set-string connect.sparkConf.spark\\.executor\\.memoryOverhead=128m)
      connect_extra+=(--set-string connect.sparkConf.spark\\.executor\\.cores=1)
      connect_extra+=(--set-string connect.sparkConf.spark\\.executor\\.instances=1)
      connect_extra+=(--set-string connect.sparkConf.spark\\.cores\\.max=1)
      connect_extra+=(--set-string connect.sparkConf.spark\\.scheduler\\.minRegisteredResourcesRatio=0.0)
      connect_extra+=(--set-string connect.sparkConf.spark\\.scheduler\\.maxRegisteredResourcesWaitingTime=30s)
      connect_extra+=(--set-string connect.sparkConf.spark\\.sql\\.shuffle\\.partitions=2)
    fi
    helm upgrade --install "${rel}" "${CONNECT_CHART}" -n "${ns}" \
      --set connect.enabled=true \
      --set connect.backendMode="${backend}" \
      --set connect.image.tag="${SPARK_TAG}" \
      --set connect.resources.requests.cpu=200m \
      --set connect.resources.requests.memory=512Mi \
      --set connect.resources.limits.cpu=1 \
      --set connect.resources.limits.memory=2Gi \
      --set connect.driver.host="${driver_host_value}" \
      --set connect.standalone.masterService="${master_fqdn}" \
      --set connect.standalone.masterPort=7077 \
      --set connect.eventLog.enabled=true \
      --set jupyter.enabled=false \
      --set historyServer.enabled=false \
      --set hiveMetastore.enabled=false \
      --set security.podSecurityStandards=false \
      --set spark-base.enabled=true \
      --set spark-base.minio.enabled=false \
      --set spark-base.postgresql.enabled=false \
      --set global.s3.endpoint="${s3_endpoint}" \
      --set global.s3.accessKey="${S3_ACCESS_KEY:-minioadmin}" \
      --set global.s3.secretKey="${S3_SECRET_KEY:-minioadmin}" \
      "${rbac_args[@]}" \
      "${connect_extra[@]}" \
      >/dev/null
    kubectl rollout restart deployment -n "${ns}" -l app=spark-connect >/dev/null 2>&1 || true
  else
    local extra_args=()
    local resource_args=(
      --set sparkConnect.resources.requests.cpu=200m
      --set sparkConnect.resources.requests.memory=512Mi
      --set sparkConnect.resources.limits.cpu=1
      --set sparkConnect.resources.limits.memory=2Gi
      --set sparkConnect.driver.memory=512m
    )
    if [[ "${backend}" == "standalone" ]]; then
      extra_args+=(--set-string sparkConnect.sparkConf.spark\\.executor\\.instances=1)
      extra_args+=(--set-string sparkConnect.sparkConf.spark\\.executor\\.cores=1)
      extra_args+=(--set-string sparkConnect.sparkConf.spark\\.executor\\.memory=512m)
      extra_args+=(--set-string sparkConnect.sparkConf.spark\\.executor\\.memoryOverhead=128m)
      extra_args+=(--set-string sparkConnect.sparkConf.spark\\.cores\\.max=1)
      extra_args+=(--set-string sparkConnect.sparkConf.spark\\.scheduler\\.minRegisteredResourcesRatio=0.0)
      extra_args+=(--set-string sparkConnect.sparkConf.spark\\.scheduler\\.maxRegisteredResourcesWaitingTime=30s)
    else
      extra_args+=(--set sparkConnect.executor.memory=512m)
      extra_args+=(--set sparkConnect.executor.cores=1)
      extra_args+=(--set-string sparkConnect.sparkConf.spark\\.kubernetes\\.executor\\.request\\.cores=0.1)
      extra_args+=(--set-string sparkConnect.sparkConf.spark\\.kubernetes\\.executor\\.limit\\.cores=0.5)
    fi
    helm upgrade --install "${rel}" "${CONNECT_CHART}" -n "${ns}" \
      --set sparkConnect.enabled=true \
      --set sparkConnect.backendMode="${backend}" \
      --set sparkConnect.image.tag="${SPARK_TAG}" \
      --set sparkConnect.driver.host="${driver_host}" \
      --set sparkConnect.standalone.masterService="${master_fqdn}" \
      --set sparkConnect.standalone.masterPort=7077 \
      --set jupyter.enabled=false \
      --set jupyterhub.enabled=false \
      --set historyServer.enabled=false \
      --set hiveMetastore.enabled=false \
      --set minio.enabled="${minio_enabled}" \
      --set s3.endpoint="${s3_endpoint}" \
      "${sa_args[@]}" \
      "${s3_args[@]}" \
      "${resource_args[@]}" \
      "${extra_args[@]}" \
      >/dev/null
    kubectl rollout restart deployment -n "${ns}" -l app=spark-connect >/dev/null 2>&1 || true
  fi
}

cleanup_all() {
  helm uninstall "${RELEASE}" -n "${NAMESPACE}" >/dev/null 2>&1 || true
  helm uninstall "${CONNECT_RELEASE}" -n "${CONNECT_NAMESPACE}" >/dev/null 2>&1 || true
  kubectl delete namespace "${NAMESPACE}" >/dev/null 2>&1 || true
  if [[ "${CONNECT_NAMESPACE}" != "${NAMESPACE}" ]]; then
    kubectl delete namespace "${CONNECT_NAMESPACE}" >/dev/null 2>&1 || true
  fi
}

TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-900}"
POLL_SECONDS="${POLL_SECONDS:-10}"

echo "=== Airflow + Spark Connect E2E (${RELEASE} in ${NAMESPACE}, backend=${BACKEND_MODE}) ==="

if [[ "${SETUP}" == "true" ]]; then
  ensure_spark_custom_image "${SPARK_VERSION}"
  ensure_spark_custom_image "${SA_SPARK_VERSION}"
  ensure_namespace "${NAMESPACE}"
  install_airflow_stack "${NAMESPACE}" "${RELEASE}" "${BACKEND_MODE}" "${SA_SPARK_TAG}"

  ensure_namespace "${CONNECT_NAMESPACE}"
  MINIO_ENDPOINT="${S3_ENDPOINT:-http://minio.${NAMESPACE}.svc.cluster.local:9000}"
  CONNECT_MINIO_ENABLED="false"

  ensure_event_log_prefix "${NAMESPACE}" "${MINIO_ENDPOINT}" "${EVENTLOG_PREFIX}"
  if [[ "${BACKEND_MODE}" == "standalone" ]]; then
    STANDALONE_MASTER_FQDN="${RELEASE}-spark-standalone-master-hl.${NAMESPACE}.svc.cluster.local"
  else
    STANDALONE_MASTER_FQDN="${RELEASE}-spark-standalone-master.${NAMESPACE}.svc.cluster.local"
  fi
  CONNECT_DRIVER_HOST="${CONNECT_SERVICE_NAME}.${CONNECT_NAMESPACE}.svc.cluster.local"
  install_connect "${CONNECT_NAMESPACE}" "${CONNECT_RELEASE}" "${BACKEND_MODE}" "${CONNECT_DRIVER_HOST}" "${STANDALONE_MASTER_FQDN}" "${MINIO_ENDPOINT}" "${CONNECT_MINIO_ENABLED}"
fi

wait_for_minio "${NAMESPACE}"
wait_for_pod "app=postgresql-airflow" "${NAMESPACE}"

echo "1) Waiting for Airflow scheduler..."
kubectl rollout status -n "${NAMESPACE}" "deploy/${RELEASE}-spark-standalone-airflow-scheduler" --timeout=180s
SCHEDULER_POD="$(wait_for_airflow_scheduler_pod "${NAMESPACE}" "${RELEASE}")"
echo "   Scheduler pod: ${SCHEDULER_POD}"
wait_for_airflow_db "${NAMESPACE}" "${SCHEDULER_POD}"

CONNECT_SERVICE="$(get_first_by_selector svc "${CONNECT_SELECTOR}" "${CONNECT_NAMESPACE}")"
if [[ -z "${CONNECT_SERVICE}" ]]; then
  if kubectl get svc spark-connect -n "${CONNECT_NAMESPACE}" >/dev/null 2>&1; then
    CONNECT_SERVICE="spark-connect"
  else
    echo "ERROR: Spark Connect service not found in ${CONNECT_NAMESPACE}"
    exit 1
  fi
fi

CONNECT_FQDN="${CONNECT_SERVICE}.${CONNECT_NAMESPACE}.svc.cluster.local"
SPARK_CONNECT_URL="sc://${CONNECT_FQDN}:15002"

MINIO_ENDPOINT="${S3_ENDPOINT:-http://minio.${NAMESPACE}.svc.cluster.local:9000}"
EVENTLOG_NAMESPACE="${NAMESPACE}"
wait_for_minio "${EVENTLOG_NAMESPACE}"

echo "1b) Waiting for Spark Connect pod..."
wait_for_pod "${CONNECT_SELECTOR}" "${CONNECT_NAMESPACE}"

echo "2) Ensuring event log prefix (${EVENTLOG_PREFIX})..."
ensure_event_log_prefix "${EVENTLOG_NAMESPACE}" "${MINIO_ENDPOINT}" "${EVENTLOG_PREFIX}"

echo "3) Setting Airflow Variables..."
SCHEDULER_POD="$(wait_for_airflow_scheduler_pod "${NAMESPACE}" "${RELEASE}")"
wait_for_airflow_db "${NAMESPACE}" "${SCHEDULER_POD}"
SPARK_IMAGE_VALUE="${SPARK_IMAGE_VALUE:-${SPARK_IMAGE_DEFAULT}}"
SPARK_NAMESPACE_VALUE="${SPARK_NAMESPACE_VALUE:-${NAMESPACE}}"

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
fi

kubectl_exec_retry "${NAMESPACE}" "${SCHEDULER_POD}" "PYTHONWARNINGS=ignore airflow variables set 'spark_image' '${SPARK_IMAGE_VALUE}' && PYTHONWARNINGS=ignore airflow variables set 'spark_namespace' '${SPARK_NAMESPACE_VALUE}' && PYTHONWARNINGS=ignore airflow variables set 'spark_connect_url' '${SPARK_CONNECT_URL}' && PYTHONWARNINGS=ignore airflow variables set 'spark_rows' '${SPARK_ROWS}' && PYTHONWARNINGS=ignore airflow variables set 's3_endpoint' '${S3_ENDPOINT_VALUE}' && PYTHONWARNINGS=ignore airflow variables set 's3_access_key' '${S3_ACCESS_KEY_VALUE}' && PYTHONWARNINGS=ignore airflow variables set 's3_secret_key' '${S3_SECRET_KEY_VALUE}'"

RUN_ID="e2e-connect-$(date +%Y%m%d-%H%M%S)"
echo ""
echo "4) Triggering DAG ${DAG_ID} (run_id=${RUN_ID})..."
SCHEDULER_POD="$(wait_for_airflow_scheduler_pod "${NAMESPACE}" "${RELEASE}")"
wait_for_airflow_db "${NAMESPACE}" "${SCHEDULER_POD}"
kubectl_exec_retry "${NAMESPACE}" "${SCHEDULER_POD}" "PYTHONWARNINGS=ignore airflow dags trigger -r '${RUN_ID}' '${DAG_ID}'"

echo "5) Waiting for DAG completion..."
DAG_ID="${DAG_ID}" RUN_ID="${RUN_ID}" NAMESPACE="${NAMESPACE}" SCHEDULER_POD="${SCHEDULER_POD}" TIMEOUT_SECONDS="${TIMEOUT_SECONDS}" POLL_SECONDS="${POLL_SECONDS}" python3 - <<PY
import json, os, subprocess, sys, time
dag_id = os.environ["DAG_ID"]
run_id = os.environ["RUN_ID"]
namespace = os.environ["NAMESPACE"]
sched_pod = os.environ["SCHEDULER_POD"]
timeout = int(os.environ["TIMEOUT_SECONDS"])
poll = int(os.environ["POLL_SECONDS"])
deadline = time.time() + timeout
while time.time() < deadline:
    cmd = ["kubectl","exec","-n",namespace,sched_pod,"--","sh","-lc",f"PYTHONWARNINGS=ignore airflow dags list-runs -d '{dag_id}' --output json"]
    try:
        proc = subprocess.run(cmd, text=True, capture_output=True, timeout=15, check=True)
        out = proc.stdout
        runs = json.loads(out) if out.strip() else []
        state = next((r.get("state","") for r in runs if r.get("run_id")==run_id), "")
    except Exception:
        state = ""
    if state == "success":
        print(f"   {dag_id} {run_id}: success")
        sys.exit(0)
    if state == "failed":
        print(f"   {dag_id} {run_id}: failed")
        sys.exit(1)
    print(f"   {dag_id} {run_id}: {state or 'queued/running'}")
    time.sleep(poll)
print(f"   {dag_id} {run_id}: timeout after {timeout}s")
sys.exit(2)
PY

echo "6) Checking task logs for RESULT_SUM..."
TASK_POD="$(kubectl -n "${SPARK_NAMESPACE_VALUE}" get pod -l "task_id=${TASK_ID},run_id=${RUN_ID}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
if [[ -z "${TASK_POD}" ]]; then
  TASK_POD="$(kubectl -n "${SPARK_NAMESPACE_VALUE}" get pod -l "run_id=${RUN_ID}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
fi
if [[ -n "${TASK_POD}" ]]; then
  TASK_LOGS="$(kubectl -n "${SPARK_NAMESPACE_VALUE}" logs "${TASK_POD}" 2>/dev/null || true)"
else
  TASK_LOGS=""
fi
if [[ -z "${TASK_LOGS}" ]]; then
  SCHEDULER_POD="$(get_scheduler_pod "${NAMESPACE}" "${RELEASE}")"
  TASK_LOGS="$(kubectl -n "${NAMESPACE}" logs "${SCHEDULER_POD}" --since=60m 2>/dev/null | grep "RESULT_SUM=" || true)"
fi
echo "${TASK_LOGS}" | grep -q "RESULT_SUM=" || {
  echo "ERROR: RESULT_SUM not found in task logs"
  exit 1
}

echo "7) Checking Spark metrics endpoint..."
CONNECT_POD="$(get_first_by_selector pod "${CONNECT_SELECTOR}" "${CONNECT_NAMESPACE}")"
if [[ -z "${CONNECT_POD}" ]]; then
  echo "ERROR: Spark Connect pod not found in ${CONNECT_NAMESPACE}"
  exit 1
fi
check_metrics "${CONNECT_POD}" "${CONNECT_NAMESPACE}" || {
  echo "ERROR: Spark metrics endpoint not reachable"
  exit 1
}

echo "8) Checking event logs in MinIO (${EVENTLOG_PREFIX})..."
wait_for_event_logs "${EVENTLOG_NAMESPACE}" "${MINIO_ENDPOINT}" "${EVENTLOG_PREFIX}" || {
  echo "ERROR: Event logs not found in MinIO prefix ${EVENTLOG_PREFIX}"
  exit 1
}

if [[ "${CLEANUP}" == "true" ]]; then
  cleanup_all
fi

echo "=== E2E PASSED ==="
