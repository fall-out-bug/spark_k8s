#!/bin/bash
# Verify History Server in spark-infra is reachable and lists applications (optional).
# Usage: ./verify-history-server.sh [namespace]
# Default namespace: spark-infra

set -euo pipefail

NAMESPACE="${1:-spark-infra}"
SVC="${2:-spark-infra-spark-35-history}"
PORT=18080

echo "=== History Server verification (namespace=${NAMESPACE}, svc=${SVC}) ==="
kubectl get pod -n "$NAMESPACE" -l app=spark-history-server -o wide 2>/dev/null || true

echo ""
echo "Port-forwarding to ${SVC}:${PORT}..."
kubectl port-forward "svc/${SVC}" "${PORT}:${PORT}" -n "$NAMESPACE" &
PF_PID=$!
trap "kill $PF_PID 2>/dev/null || true" EXIT
sleep 3

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${PORT}" 2>/dev/null || echo "000")
if [[ "$HTTP_CODE" == "200" ]]; then
  echo "  HTTP ${HTTP_CODE} - History Server UI is reachable"
else
  echo "  HTTP ${HTTP_CODE} - check if History Server is running"
fi

# Optional: parse API for application list (History Server REST API)
APP_COUNT=$(curl -s "http://127.0.0.1:${PORT}/api/v1/applications" 2>/dev/null | grep -c '"id"' || echo "0")
echo "  Applications in History Server: ${APP_COUNT}"

echo ""
echo "=== Done ==="
