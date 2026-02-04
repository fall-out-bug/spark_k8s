#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${1:-spark-airflow-e2e}"
RELEASE="${2:-spark-airflow}"
SPARK_VERSION="${3:-3.5.7}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
source "${SCRIPT_DIR}/test-e2e-lib.sh"

OPERATOR_NAMESPACE="${OPERATOR_NAMESPACE:-${NAMESPACE}}"
SETUP="${SETUP:-true}"
CLEANUP="${CLEANUP:-false}"
SPARK_OPERATOR_IMAGE_REPO="${SPARK_OPERATOR_IMAGE_REPO:-kubeflow/spark-operator}"
SPARK_OPERATOR_IMAGE_TAG="${SPARK_OPERATOR_IMAGE_TAG:-v1beta2-1.6.2-3.5.0}"

DAG_ID="spark_operator_e2e"
TASK_ID="spark_operator_e2e"

SPARK_TAG="$(resolve_spark_tag "${SPARK_VERSION}")"
EVENTLOG_PREFIX="spark-logs/events"
SPARK_IMAGE_DEFAULT="spark-custom:${SPARK_TAG}"
if [[ "${SPARK_VERSION}" == "4.1"* ]]; then
  EVENTLOG_PREFIX="spark-logs/events"
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

wait_for_pod() {
  local selector="$1"
  local ns="$2"
  local timeout="${3:-240}"
  kubectl wait --for=condition=ready pod -n "${ns}" -l "${selector}" --timeout="${timeout}s" >/dev/null 2>&1
}

wait_for_airflow_scheduler_pod() {
  local ns="$1"
  local rel="$2"
  for _ in $(seq 1 24); do
    local pod
    pod="$(kubectl get pod -n "${ns}" -l "app=airflow-scheduler,app.kubernetes.io/instance=${rel}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
    if [[ -n "${pod}" ]]; then
      echo "${pod}"
      return 0
    fi
    sleep 5
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

wait_for_minio() {
  local ns="$1"
  kubectl wait --for=condition=ready pod -n "${ns}" -l app=minio --timeout=240s >/dev/null 2>&1 || true
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
  local empty_attempts=0
  while [ "$(date +%s)" -lt "${deadline}" ]; do
    local json
    SCHEDULER_POD="$(wait_for_airflow_scheduler_pod "${NAMESPACE}" "${RELEASE}")"
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
      empty_attempts=$((empty_attempts + 1))
      if [[ "${empty_attempts}" -ge 6 ]]; then
        echo "   ${dag_id} ${run_id}: unable to query scheduler, continuing"
        return 0
      fi
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
  for _ in $(seq 1 15); do
    if curl -fsSL --max-time 2 http://localhost:4040/metrics/json 2>/dev/null | grep -q '"gauges"'; then
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
    --set airflow.kubernetesExecutor.deleteWorkerPods=false \
    --set airflow.kubernetes.deleteWorkerPods=false \
    --set security.podSecurityStandards=false >/dev/null
  kubectl rollout restart -n "${ns}" "deploy/${rel}-spark-standalone-airflow-scheduler" >/dev/null 2>&1 || true
  kubectl rollout restart -n "${ns}" "deploy/${rel}-spark-standalone-airflow-webserver" >/dev/null 2>&1 || true
}

install_operator() {
  local ns="$1"
  local job_ns="$2"
  helm upgrade --install spark-operator charts/spark-operator -n "${ns}" \
    --set sparkJobNamespace="${job_ns}" \
    --set image.repository="${SPARK_OPERATOR_IMAGE_REPO}" \
    --set image.tag="${SPARK_OPERATOR_IMAGE_TAG}" \
    --set crds.create=false \
    --set webhook.enable=true >/dev/null
  kubectl rollout status -n "${ns}" deploy/spark-operator-spark-operator --timeout=180s >/dev/null
}

ensure_operator_job_sa() {
  local job_ns="$1"
  local sa="spark-operator-spark-operator"
  kubectl -n "${job_ns}" get sa "${sa}" >/dev/null 2>&1 || kubectl -n "${job_ns}" create sa "${sa}" >/dev/null
  kubectl apply -f - >/dev/null <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: spark-operator-job-${job_ns}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: spark-operator-spark-operator
subjects:
  - kind: ServiceAccount
    name: ${sa}
    namespace: ${job_ns}
EOF
}

cleanup_all() {
  helm uninstall "${RELEASE}" -n "${NAMESPACE}" >/dev/null 2>&1 || true
  helm uninstall spark-operator -n "${OPERATOR_NAMESPACE}" >/dev/null 2>&1 || true
  kubectl delete namespace "${NAMESPACE}" >/dev/null 2>&1 || true
  if [[ "${OPERATOR_NAMESPACE}" != "${NAMESPACE}" ]]; then
    kubectl delete namespace "${OPERATOR_NAMESPACE}" >/dev/null 2>&1 || true
  fi
}

TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-900}"
POLL_SECONDS="${POLL_SECONDS:-10}"

echo "=== Airflow + Spark Operator E2E (${RELEASE} in ${NAMESPACE}) ==="

if [[ "${SETUP}" == "true" ]]; then
  ensure_spark_custom_image "${SPARK_VERSION}"
  ensure_namespace "${NAMESPACE}"
  install_airflow_stack "${NAMESPACE}" "${RELEASE}"
  ensure_namespace "${OPERATOR_NAMESPACE}"
  install_operator "${OPERATOR_NAMESPACE}" "${NAMESPACE}"
  ensure_operator_job_sa "${NAMESPACE}"
fi

wait_for_minio "${NAMESPACE}"
wait_for_pod "app=postgresql-airflow" "${NAMESPACE}"

echo "1) Waiting for Airflow scheduler..."
kubectl rollout status -n "${NAMESPACE}" "deploy/${RELEASE}-spark-standalone-airflow-scheduler" --timeout=180s
SCHEDULER_POD="$(wait_for_airflow_scheduler_pod "${NAMESPACE}" "${RELEASE}")"
echo "   Scheduler pod: ${SCHEDULER_POD}"

MINIO_ENDPOINT="${S3_ENDPOINT:-http://minio.${NAMESPACE}.svc.cluster.local:9000}"
echo "2) Ensuring event log prefix (${EVENTLOG_PREFIX})..."
ensure_event_log_prefix "${NAMESPACE}" "${EVENTLOG_PREFIX}"

echo "3) Setting Airflow Variables..."
SCHEDULER_POD="$(wait_for_airflow_scheduler_pod "${NAMESPACE}" "${RELEASE}")"
wait_for_airflow_db "${NAMESPACE}" "${SCHEDULER_POD}"
SPARK_IMAGE_VALUE="${SPARK_IMAGE_VALUE:-${SPARK_IMAGE_DEFAULT}}"
SPARK_NAMESPACE_VALUE="${SPARK_NAMESPACE_VALUE:-${NAMESPACE}}"
SPARK_EVENTLOG_DIR_VALUE="${SPARK_EVENTLOG_DIR_VALUE:-s3a://${EVENTLOG_PREFIX}}"
SPARK_OPERATOR_SERVICEACCOUNT_VALUE="${SPARK_OPERATOR_SERVICEACCOUNT_VALUE:-spark-operator-spark-operator}"

S3_ENDPOINT_VALUE="${S3_ENDPOINT_VALUE:-${MINIO_ENDPOINT}}"
S3_ACCESS_KEY_VALUE="${S3_ACCESS_KEY_VALUE:-}"
S3_SECRET_KEY_VALUE="${S3_SECRET_KEY_VALUE:-}"

if [[ -z "${S3_ACCESS_KEY_VALUE}" || -z "${S3_SECRET_KEY_VALUE}" ]]; then
  if kubectl get secret -n "${NAMESPACE}" s3-credentials >/dev/null 2>&1; then
    S3_ACCESS_KEY_VALUE="$(kubectl get secret -n "${NAMESPACE}" s3-credentials -o jsonpath='{.data.access-key}' | base64 -d)"
    S3_SECRET_KEY_VALUE="$(kubectl get secret -n "${NAMESPACE}" s3-credentials -o jsonpath='{.data.secret-key}' | base64 -d)"
  fi
fi

kubectl exec -n "${NAMESPACE}" "${SCHEDULER_POD}" -- sh -lc "PYTHONWARNINGS=ignore airflow variables set 'spark_image' '${SPARK_IMAGE_VALUE}'"
kubectl exec -n "${NAMESPACE}" "${SCHEDULER_POD}" -- sh -lc "PYTHONWARNINGS=ignore airflow variables set 'spark_namespace' '${SPARK_NAMESPACE_VALUE}'"
kubectl exec -n "${NAMESPACE}" "${SCHEDULER_POD}" -- sh -lc "PYTHONWARNINGS=ignore airflow variables set 'spark_version' '${SPARK_VERSION}'"
kubectl exec -n "${NAMESPACE}" "${SCHEDULER_POD}" -- sh -lc "PYTHONWARNINGS=ignore airflow variables set 'spark_eventlog_dir' '${SPARK_EVENTLOG_DIR_VALUE}'"
kubectl exec -n "${NAMESPACE}" "${SCHEDULER_POD}" -- sh -lc "PYTHONWARNINGS=ignore airflow variables set 'spark_operator_serviceaccount' '${SPARK_OPERATOR_SERVICEACCOUNT_VALUE}'"
kubectl exec -n "${NAMESPACE}" "${SCHEDULER_POD}" -- sh -lc "PYTHONWARNINGS=ignore airflow variables set 's3_endpoint' '${S3_ENDPOINT_VALUE}'"
kubectl exec -n "${NAMESPACE}" "${SCHEDULER_POD}" -- sh -lc "PYTHONWARNINGS=ignore airflow variables set 's3_access_key' '${S3_ACCESS_KEY_VALUE}'"
kubectl exec -n "${NAMESPACE}" "${SCHEDULER_POD}" -- sh -lc "PYTHONWARNINGS=ignore airflow variables set 's3_secret_key' '${S3_SECRET_KEY_VALUE}'"

RUN_ID="e2e-operator-$(date +%Y%m%d-%H%M%S)"
echo ""
echo "4) Triggering DAG ${DAG_ID} (run_id=${RUN_ID})..."
SCHEDULER_POD="$(wait_for_airflow_scheduler_pod "${NAMESPACE}" "${RELEASE}")"
wait_for_airflow_db "${NAMESPACE}" "${SCHEDULER_POD}"
kubectl exec -n "${NAMESPACE}" "${SCHEDULER_POD}" -- sh -lc "PYTHONWARNINGS=ignore airflow dags trigger -r '${RUN_ID}' '${DAG_ID}'"

echo "5) Waiting for SparkApplication to appear..."
APP_NAME="airflow-spark-operator-${RUN_ID}"
FOUND_APP="false"
for _ in $(seq 1 60); do
  if kubectl get sparkapplication "${APP_NAME}" -n "${SPARK_NAMESPACE_VALUE}" >/dev/null 2>&1; then
    FOUND_APP="true"
    break
  fi
  sleep 5
done
if [[ "${FOUND_APP}" != "true" ]]; then
  echo "ERROR: SparkApplication ${APP_NAME} not found"
  TASK_POD="$(kubectl -n "${NAMESPACE}" get pods -l "dag_id=${DAG_ID},task_id=${TASK_ID},run_id=${RUN_ID}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
  if [[ -n "${TASK_POD}" ]]; then
    kubectl -n "${NAMESPACE}" logs "${TASK_POD}" || true
  fi
  exit 1
fi

echo "6) Checking driver metrics while running..."
METRICS_OK="false"
for _ in $(seq 1 24); do
  DRIVER_POD="$(kubectl get pod -n "${SPARK_NAMESPACE_VALUE}" -l "spark-role=driver,e2e_run_id=${RUN_ID}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
  if [[ -n "${DRIVER_POD}" ]]; then
    if check_metrics_driver "${DRIVER_POD}" "${SPARK_NAMESPACE_VALUE}"; then
      METRICS_OK="true"
      break
    fi
  fi
  sleep 5
done
if [[ "${METRICS_OK}" != "true" ]]; then
  echo "WARN: Spark metrics endpoint not reachable"
fi

echo "7) Waiting for DAG completion..."
wait_for_run_state "${DAG_ID}" "${RUN_ID}" "${TIMEOUT_SECONDS}"

echo "8) Verifying SparkApplication status..."
APP_STATE="$(kubectl get sparkapplication "${APP_NAME}" -n "${SPARK_NAMESPACE_VALUE}" -o jsonpath='{.status.applicationState.state}' 2>/dev/null || true)"
if [[ "${APP_STATE}" != "COMPLETED" ]]; then
  echo "ERROR: SparkApplication state is ${APP_STATE}"
  exit 1
fi

echo "9) Checking driver logs for SparkPi result..."
DRIVER_POD="$(kubectl get pod -n "${SPARK_NAMESPACE_VALUE}" -l "spark-role=driver,e2e_run_id=${RUN_ID}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
if [[ -z "${DRIVER_POD}" ]]; then
  echo "ERROR: Driver pod not found for run_id=${RUN_ID}"
  exit 1
fi
FOUND_PI="false"
for _ in $(seq 1 12); do
  if kubectl logs -n "${SPARK_NAMESPACE_VALUE}" "${DRIVER_POD}" 2>/dev/null | grep -q "Pi is roughly"; then
    FOUND_PI="true"
    break
  fi
  sleep 5
done
if [[ "${FOUND_PI}" != "true" ]]; then
  echo "ERROR: SparkPi result not found in driver logs"
  exit 1
fi

echo "10) Checking event logs in MinIO (${EVENTLOG_PREFIX})..."
wait_for_event_logs "${NAMESPACE}" "${MINIO_ENDPOINT}" "${EVENTLOG_PREFIX}" || {
  echo "ERROR: Event logs not found in MinIO prefix ${EVENTLOG_PREFIX}"
  exit 1
}

echo "11) Cleaning SparkApplication..."
kubectl delete sparkapplication "${APP_NAME}" -n "${SPARK_NAMESPACE_VALUE}" >/dev/null 2>&1 || true

if [[ "${CLEANUP}" == "true" ]]; then
  cleanup_all
fi

echo "=== E2E PASSED ==="
