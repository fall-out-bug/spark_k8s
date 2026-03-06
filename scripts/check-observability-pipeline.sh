#!/usr/bin/env bash
# Verify observability pipeline: demo-metrics-exporter → Prometheus → Grafana dashboards.
# Exit 0 = pipeline OK, exit 1 = broken.
# Usage: ./scripts/check-observability-pipeline.sh [--fix]

set -uo pipefail
OBS_NS="${OBSERVABILITY_NS:-observability}"
SPARK_NS="${SPARK_NAMESPACE:-spark-infra}"
FIX="${1:-}"
FAILURES=0

check() {
  local name="$1"
  shift
  if "$@" 2>/dev/null; then
    echo "  OK: $name"
  else
    echo "  FAIL: $name"
    FAILURES=$((FAILURES + 1))
    return 1
  fi
}

echo "=== Observability Pipeline Check ==="

# 1. demo-metrics-exporter pod running
check "demo-metrics-exporter pod running" \
  kubectl get pod -n "$OBS_NS" -l app=demo-metrics-exporter -o jsonpath='{.items[0].status.phase}' | grep -q Running

# 2. Exporter exposes metrics (retry: needs ~20s to scrape Spark after start)
exporter_pod=$(kubectl get pod -n "$OBS_NS" -l app=demo-metrics-exporter -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [[ -n "$exporter_pod" ]]; then
  for i in 1 2 3 4 5; do
    metrics=$(kubectl exec -n "$OBS_NS" "$exporter_pod" -- python3 -c "import urllib.request; print(urllib.request.urlopen('http://localhost:9108/metrics').read().decode())" 2>/dev/null || true)
    if echo "$metrics" | grep -qE "spark_workers_alive|demo_metrics_exporter_up"; then
      echo "  OK: demo-metrics-exporter has Spark/Airflow metrics"
      break
    fi
    [[ $i -lt 5 ]] && sleep 5
  done
  if ! echo "$metrics" | grep -qE "spark_workers_alive|demo_metrics_exporter_up"; then
    echo "  FAIL: demo-metrics-exporter has no spark_* or demo_metrics_exporter metrics (Spark may not be ready)"
    FAILURES=$((FAILURES + 1))
  fi
else
  echo "  FAIL: no demo-metrics-exporter pod"
  FAILURES=$((FAILURES + 1))
fi

# 3. Grafana dashboards ConfigMaps exist
dash_cm_count=$(kubectl get cm -n "$OBS_NS" -l grafana_dashboard=1 --no-headers 2>/dev/null | wc -l)
check "Grafana dashboard ConfigMaps exist (≥5)" \
  test "$dash_cm_count" -ge 5

# 4. Grafana pod running
check "Grafana pod running" \
  kubectl get pod -n "$OBS_NS" -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].status.phase}' | grep -q Running

# 5. Prometheus pod running
check "Prometheus pod running" \
  kubectl get pod -n "$OBS_NS" -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].status.phase}' | grep -q Running

echo ""
if [[ $FAILURES -gt 0 ]]; then
  echo "PIPELINE BROKEN: $FAILURES check(s) failed"
  if [[ "$FIX" == "--fix" ]]; then
    echo "Attempting fix: re-deploy dashboards and restart Grafana..."
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
    (cd "$PROJECT_ROOT" && ./scripts/deploy-grafana-dashboards.sh "$OBS_NS") || true
    kubectl rollout restart deployment/observability-demo-grafana -n "$OBS_NS" 2>/dev/null || true
    echo "Wait 60s for Grafana to restart, then re-run this script."
  else
    echo "Run with --fix to re-deploy dashboards and restart Grafana."
  fi
  exit 1
fi
echo "PIPELINE OK: demo-metrics-exporter → Prometheus → Grafana"
exit 0
