#!/usr/bin/env bash
# Check driver logs and status
# Usage: scripts/recipes/troubleshoot/check-driver-logs.sh <namespace>

set -euo pipefail

NAMESPACE="${1:-spark}"

echo "=== Checking driver pods in ${NAMESPACE} ==="
kubectl get pods -n "${NAMESPACE}" -l "spark-role=driver" --sort-by='.metadata.creationTimestamp'

echo -e "\n=== Checking Spark Connect deployment ==="
kubectl get deployment -n "${NAMESPACE}" -l app=spark-connect

echo -e "\n=== Recent driver logs (last pod) ==="
DRIVER_POD=$(kubectl get pod -n "${NAMESPACE}" -l "spark-role=driver" -o jsonpath='{.items[-1].metadata.name}' 2>/dev/null || echo "")
if [[ -n "${DRIVER_POD}" ]]; then
  echo "=== Logs from ${DRIVER_POD} ==="
  kubectl logs -n "${NAMESPACE}" "${DRIVER_POD}" --tail=50 | grep -i "error\|exception\|failed\|refused" || echo "No errors found"

  echo -e "\n=== Driver pod status ==="
  kubectl describe pod -n "${NAMESPACE}" "${DRIVER_POD}" | grep -A 10 "State:" || true
else
  echo "No driver pods found"
fi

echo -e "\n=== Checking Spark Connect service ==="
kubectl get svc -n "${NAMESPACE}" -l app=spark-connect

echo -e "\n=== Service endpoints ==="
kubectl get endpoints -n "${NAMESPACE}" -l app=spark-connect
