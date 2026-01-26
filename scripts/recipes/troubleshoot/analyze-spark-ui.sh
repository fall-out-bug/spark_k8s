#!/usr/bin/env bash
# Analyze Spark UI metrics
# Usage: scripts/recipes/troubleshoot/analyze-spark-ui.sh <namespace> <pod-name>

set -euo pipefail

NAMESPACE="${1:-spark}"
POD_NAME="${2}"

if [[ -z "${POD_NAME}" ]]; then
  # Find first Spark pod
  POD_NAME=$(kubectl get pod -n "${NAMESPACE}" -l spark-role=driver -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || \
  POD_NAME=$(kubectl get pod -n "${NAMESPACE}" -l app=spark-connect -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
fi

if [[ -z "${POD_NAME}" ]]; then
  echo "Usage: $0 <namespace> <pod-name>"
  echo "Or leave pod-name empty to auto-detect"
  exit 1
fi

echo "=== Analyzing Spark UI for ${POD_NAME} in ${NAMESPACE} ==="

echo -e "\n=== Port forward to Spark UI ==="
PF_PID=""
cleanup() {
  [[ -n "${PF_PID}" ]] && kill "${PF_PID}" 2>/dev/null || true
}
trap cleanup EXIT

kubectl port-forward -n "${NAMESPACE}" "${POD_NAME}" 4040:4040 >/dev/null 2>&1 &
PF_PID=$!
sleep 3

echo -e "\n=== Fetching metrics ==="
curl -sf http://localhost:4040/metrics/json 2>/dev/null | \
  jq -r '.gauges[] | "\(.metric): \(.value // 0)"' | \
  grep -E "(executor|driver|memory|task|job)" || echo "No metrics available"

echo -e "\n=== Fetching environment info ==="
curl -sf http://localhost:4040/api/v1 2>/dev/null | \
  jq -r '.environment.sparkProperties[] | select(.key | contains("memory"; "cpu"; "executor")) | "\(.key): \(.value)"' || echo "Environment info not available"

echo -e "\n=== Fetching active tasks ==="
curl -sf http://localhost:4040/api/v1/applications/*/jobs 2>/dev/null | \
  jq -r '.[0][] | select(.status == "RUNNING") | "\(.jobId): \(.jobName)"' || echo "No running jobs"

echo -e "\n=== Recommendation ==="
echo "If metrics are unavailable:"
echo "  1. Check if job is running: kubectl logs -n ${NAMESPACE} ${POD_NAME}"
echo "  2. Check Spark UI port: 4040 (driver), 18080 (history server)"
echo "  3. For stuck jobs, check: docs/recipes/troubleshoot/job-hangs.md"
