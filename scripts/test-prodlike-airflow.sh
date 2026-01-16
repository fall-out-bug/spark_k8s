#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${1:-spark-sa-prodlike}"
RELEASE="${2:-spark-prodlike}"

SCHEDULER_DEPLOY="${RELEASE}-spark-standalone-airflow-scheduler"
DAGS=("${@:3}")
if [ ${#DAGS[@]} -eq 0 ]; then
  DAGS=("example_bash_operator" "spark_etl_synthetic")
fi

TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-900}"
POLL_SECONDS="${POLL_SECONDS:-10}"

echo "=== Airflow prod-like DAG tests (${RELEASE} in ${NAMESPACE}) ==="

echo "1) Waiting for scheduler deployment..."
kubectl rollout status -n "${NAMESPACE}" "deploy/${SCHEDULER_DEPLOY}" --timeout=180s

SCHEDULER_POD="$(kubectl get pod -n "${NAMESPACE}" -l "app=airflow-scheduler,app.kubernetes.io/instance=${RELEASE}" -o jsonpath='{.items[0].metadata.name}')"
echo "   Scheduler pod: ${SCHEDULER_POD}"

echo "2) Sanity: airflow CLI reachable..."
kubectl exec -n "${NAMESPACE}" "${SCHEDULER_POD}" -- sh -lc "PYTHONWARNINGS=ignore airflow version >/dev/null"
echo "   OK"

wait_for_run_state() {
  local dag_id="$1"
  local run_id="$2"
  local timeout="$3"

  local deadline=$(( $(date +%s) + timeout ))
  while [ "$(date +%s)" -lt "${deadline}" ]; do
    # Use JSON output to avoid table wrapping.
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

    sleep "${POLL_SECONDS}"
  done

  echo "   ${dag_id} ${run_id}: timeout after ${timeout}s"
  return 2
}

for dag in "${DAGS[@]}"; do
  run_id="prodlike-$(date +%Y%m%d-%H%M%S)-${dag}"
  echo ""
  echo "3) Triggering DAG: ${dag} (run_id=${run_id})"
  kubectl exec -n "${NAMESPACE}" "${SCHEDULER_POD}" -- sh -lc "PYTHONWARNINGS=ignore airflow dags trigger -r '${run_id}' '${dag}'"

  echo "4) Waiting for DAG completion (timeout=${TIMEOUT_SECONDS}s, poll=${POLL_SECONDS}s)..."
  wait_for_run_state "${dag}" "${run_id}" "${TIMEOUT_SECONDS}"
done

echo ""
echo "5) Best-effort: ensure no lingering Airflow worker pods..."
kubectl get pods -n "${NAMESPACE}" -l app=airflow-worker --no-headers 2>/dev/null || true

echo "=== Done ==="

