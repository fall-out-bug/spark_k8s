#!/usr/bin/env bash
# Check executor logs for OOM/Crash issues
# Usage: scripts/recipes/troubleshoot/check-executor-logs.sh <namespace> [selector]

set -euo pipefail

NAMESPACE="${1:-spark}"
SELECTOR="${2:-spark-role=executor}"

echo "=== Checking executor pods in ${NAMESPACE} ==="
kubectl get pods -n "${NAMESPACE}" -l "${SELECTOR}"

echo -e "\n=== Checking for OOMKilled ==="
kubectl get pods -n "${NAMESPACE}" -l "${SELECTOR}" -o json | \
  jq -r '.items[] | select(.status.containerStatuses[0].state.terminated.reason == "OOMKilled") | .metadata.name' || echo "No OOMKilled pods"

echo -e "\n=== Checking for Error/Launch failures ==="
kubectl get pods -n "${NAMESPACE}" -l "${SELECTOR}" -o json | \
  jq -r '.items[] | select(.status.containerStatuses[0].state.waiting.reason != null) | .metadata.name + " waiting: " + .status.containerStatuses[0].state.waiting.reason' || echo "No waiting pods"

echo -e "\n=== Recent executor logs (last 50 lines, first active pod) ==="
POD=$(kubectl get pod -n "${NAMESPACE}" -l "${SELECTOR}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [[ -n "${POD}" ]]; then
  echo "=== Logs from ${POD} ==="
  kubectl logs -n "${NAMESPACE}" "${POD}" --tail=50 | grep -i "error\|exception\|oom\|killed\|failed" || echo "No errors found"
else
  echo "No executor pods found"
fi

echo -e "\n=== Executor resource usage ==="
for pod in $(kubectl get pod -n "${NAMESPACE}" -l "${SELECTOR}" -o jsonpath='{.items[*].metadata.name}' | head -3); do
  echo "Pod: ${pod}"
  kubectl describe pod -n "${NAMESPACE}" "${pod}" | grep -A 5 "Limits\|Requests\|Memory" || true
done
