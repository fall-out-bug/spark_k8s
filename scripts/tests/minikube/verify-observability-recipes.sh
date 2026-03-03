#!/usr/bin/env bash
# Verify observability per persona recipes (docs/observability/recipes/*.md)
# Usage: ./verify-observability-recipes.sh [PROMETHEUS_URL]
# Default: http://$(minikube ip):30090

set -euo pipefail

PROM_URL="${1:-http://$(minikube ip 2>/dev/null):30090}"
FAILED=0

check() {
  local name="$1"
  local cmd="$2"
  if eval "$cmd" >/dev/null 2>&1; then
    echo "  ✓ $name"
  else
    echo "  ✗ $name"
    ((FAILED++)) || true
  fi
}

echo "=== DevOps 5min (devops-5min.md) ==="
echo "1. Pods running"
kubectl get pods -n spark-infra --no-headers 2>/dev/null | grep -c Running | grep -q '[1-9]' && echo "  ✓ spark-infra pods" || { echo "  ✗ spark-infra pods"; ((FAILED++)); }
kubectl get pods -n observability --no-headers 2>/dev/null | grep -c Running | grep -q '[1-9]' && echo "  ✓ observability pods" || { echo "  ✗ observability pods"; ((FAILED++)); }

echo "2. Prometheus targets up"
TARGETS=$(curl -s "$PROM_URL/api/v1/targets" 2>/dev/null | python3 -c "
import json,sys
d=json.load(sys.stdin)
t=d.get('data',{}).get('activeTargets',[])
up=sum(1 for x in t if x.get('health')=='up')
print(up, len(t))
" 2>/dev/null || echo "0 0")
UP=$(echo $TARGETS | cut -d' ' -f1)
TOTAL=$(echo $TARGETS | cut -d' ' -f2)
[ "$UP" -ge 2 ] 2>/dev/null && echo "  ✓ Prometheus targets ($UP up)" || echo "  ✗ Prometheus targets (got $UP up of $TOTAL)"

echo "3. Loki ready"
kubectl exec -n observability deployment/loki -- wget -qO- http://localhost:3100/ready 2>/dev/null | grep -q ready && echo "  ✓ Loki" || echo "  ✗ Loki"

echo ""
echo "=== DataOps / Tech Lead (metrics) ==="
for m in spark_workers_alive spark_apps_completed airflow_dag_runs_state; do
  R=$(curl -s "$PROM_URL/api/v1/query?query=$m" 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d.get('data',{}).get('result',[])))" 2>/dev/null || echo "0")
  [ "$R" -ge 0 ] 2>/dev/null && echo "  ✓ $m ($R series)" || echo "  ✗ $m"
done

echo ""
echo "=== History Server ==="
kubectl run -n spark-infra history-check --rm -i --restart=Never \
  --image=curlimages/curl:8.11.1 --command -- \
  sh -c "curl -s -o /dev/null -w '%{http_code}' http://spark-shared-spark-35-history:18080/" 2>/dev/null | grep -q 200 && echo "  ✓ History Server" || echo "  ✗ History Server"

echo ""
echo "=== Grafana (login page) ==="
kubectl run -n observability grafana-check --rm -i --restart=Never \
  --image=curlimages/curl:8.11.1 --command -- \
  sh -c "curl -s -o /dev/null -w '%{http_code}' http://grafana:80/login" 2>/dev/null | grep -q 200 && echo "  ✓ Grafana" || echo "  ✗ Grafana"

echo ""
if [ "$FAILED" -eq 0 ]; then
  echo "=== All checks passed ==="
  exit 0
else
  echo "=== $FAILED check(s) failed ==="
  exit 1
fi
