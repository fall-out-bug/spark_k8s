#!/usr/bin/env bash
# Verify demo environment health. Exit 0 = healthy, exit 1 = broken.
# Usage: ./scripts/check-demo-health.sh [--quiet]
set -euo pipefail

NAMESPACE="spark-infra"
RELEASE="spark-infra"
EXPECTED_CHART_PREFIX="spark-3.5-"
QUIET="${1:-}"
FAILURES=0

check() {
  local name="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    [[ "$QUIET" != "--quiet" ]] && echo "  OK: $name"
  else
    echo "  FAIL: $name"
    ((FAILURES++))
  fi
}

echo "=== Demo Health Check ==="

# 1. Namespace exists
check "Namespace $NAMESPACE exists" \
  kubectl get namespace "$NAMESPACE"

# 2. Helm release exists and is deployed
release_json=$(helm list -n "$NAMESPACE" -f "^${RELEASE}$" -o json 2>/dev/null || echo "[]")
release_status=$(echo "$release_json" | python3 -c "import json,sys; r=json.load(sys.stdin); print(r[0]['status'] if r else 'missing')" 2>/dev/null || echo "error")
release_chart=$(echo "$release_json" | python3 -c "import json,sys; r=json.load(sys.stdin); print(r[0]['chart'] if r else 'none')" 2>/dev/null || echo "error")

check "Release $RELEASE status=deployed (got: $release_status)" \
  test "$release_status" = "deployed"

# 3. Correct chart (spark-3.5, NOT spark-standalone)
check "Chart is ${EXPECTED_CHART_PREFIX}* (got: $release_chart)" \
  bash -c "[[ '$release_chart' == ${EXPECTED_CHART_PREFIX}* ]]"

# 4. No extra releases in namespace
all_releases=$(helm list -n "$NAMESPACE" -o json 2>/dev/null || echo "[]")
all_count=$(echo "$all_releases" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
check "Single release in $NAMESPACE (got: $all_count)" \
  test "$all_count" -le 1

# 5. Core pods running
check_pod_running() {
  local label="$1"
  kubectl get pod -n "$NAMESPACE" -l "$label" -o jsonpath='{.items[0].status.phase}' 2>/dev/null | grep -q Running
}

check "MinIO pod running"                check_pod_running "app=minio"
check "Spark Master pod running"         check_pod_running "app.kubernetes.io/component=spark-master"
check "Spark Worker pod running"         check_pod_running "app.kubernetes.io/component=spark-worker"
check "Airflow Webserver pod running"    check_pod_running "app.kubernetes.io/component=airflow-webserver"

# 6. Core services exist
# Service names depend on chart structure; check both patterns
check "Master service exists" \
  bash -c "kubectl get svc -n $NAMESPACE 2>/dev/null | grep -q 'standalone-master'"
check "Airflow service exists" \
  bash -c "kubectl get svc -n $NAMESPACE 2>/dev/null | grep -q 'airflow-webserver'"

# 7. Orphan test namespaces
orphan_count=$(kubectl get ns -o name 2>/dev/null | grep -c 'test-scenario-' 2>/dev/null || true)
orphan_count="${orphan_count:-0}"
orphan_count=$(echo "$orphan_count" | tr -d '[:space:]')
check "Orphan test namespaces ≤ 1 (got: $orphan_count)" \
  test "$orphan_count" -le 1

# 8. Observability stack
check "Grafana pod running" \
  bash -c "kubectl get pod -n observability -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].status.phase}' 2>/dev/null | grep -q Running"
check "Prometheus pod running" \
  bash -c "kubectl get pod -n observability -l app=prometheus -o jsonpath='{.items[0].status.phase}' 2>/dev/null | grep -q Running"

echo ""
if [[ $FAILURES -gt 0 ]]; then
  echo "DEMO UNHEALTHY: $FAILURES check(s) failed"
  echo "Recovery: ./scripts/restore-demo.sh"
  exit 1
else
  echo "DEMO HEALTHY: all checks passed"
fi
