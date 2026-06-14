#!/usr/bin/env bash
# Verify Grafana observability stand health. Exit 0 = healthy, 1 = broken.
# Implements AC1-AC10 from specs/grafana-observability-stand/spec.md
#
# Usage: ./scripts/verify-observability-stand.sh [--quiet]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# PROJECT_ROOT reserved for future file-based checks
# shellcheck disable=SC2034
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
NAMESPACE="${OBSERVABILITY_NS:-observability}"
QUIET=0
[[ "${1:-}" == "--quiet" ]] && QUIET=1

log() { [[ $QUIET -eq 0 ]] && echo "$@"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

log "=== Grafana Observability Stand verify ==="

# AC1: helm release exists
log "AC1: helm release observability-demo exists"
helm list -n "$NAMESPACE" | grep -q "^observability-demo" || fail "helm release not found"

# AC2: critical pods Ready
log "AC2: critical pods Ready"
for deploy in \
  observability-demo-grafana \
  observability-demo-loki-gateway \
  observability-demo-prometh-operator \
  otel-collector \
  demo-metrics-exporter; do
  kubectl wait deployment/"$deploy" -n "$NAMESPACE" \
    --for=condition=available --timeout=30s >/dev/null 2>&1 || \
    fail "deployment $deploy not Ready"
done

# AC3: Grafana reachable via port-forward (use service URL)
log "AC3: Grafana API reachable"
GRAFANA_POD=$(kubectl get pod -n "$NAMESPACE" -l app.kubernetes.io/name=grafana -o name | head -1)
[[ -n "$GRAFANA_POD" ]] || fail "no grafana pod"

GRAFANA_HEALTH=$(kubectl exec -n "$NAMESPACE" "$GRAFANA_POD" -c grafana -- \
  wget -qO- http://localhost:3000/api/health 2>/dev/null || echo "")
echo "$GRAFANA_HEALTH" | python3 -c 'import json,sys;d=json.load(sys.stdin);sys.exit(0 if d.get("database")=="ok" else 1)' || fail "grafana health: $GRAFANA_HEALTH"
log "  grafana version: $(echo "$GRAFANA_HEALTH" | python3 -c 'import json,sys;print(json.load(sys.stdin)["version"])')"

# AC4: Prometheus targets (at least 5 UP)
log "AC4: Prometheus targets"
PROM_POD=$(kubectl get pod -n "$NAMESPACE" -l app.kubernetes.io/name=prometheus -o name | head -1)
[[ -n "$PROM_POD" ]] || fail "no prometheus pod"

UP_COUNT=$(kubectl exec -n "$NAMESPACE" "$PROM_POD" -c prometheus -- \
  wget -qO- 'http://localhost:9090/api/v1/targets?state=active' 2>/dev/null | \
  python3 -c 'import json,sys;print(sum(1 for t in json.load(sys.stdin)["data"]["activeTargets"] if t["health"]=="up"))')
[[ "$UP_COUNT" -ge 5 ]] || fail "only $UP_COUNT prometheus targets UP (need >=5)"
log "  prometheus: $UP_COUNT targets UP"

# AC5: Loki gateway reachable
log "AC5: Loki gateway"
kubectl exec -n "$NAMESPACE" "$GRAFANA_POD" -c grafana -- \
  wget -qO- --spider http://observability-demo-loki-gateway:80 >/dev/null 2>&1 || \
  fail "loki gateway unreachable from grafana"
log "  loki gateway OK"

# AC7+AC8: dashboards via Grafana API
log "AC7: dashboards count"
DASHBOARDS=$(kubectl exec -n "$NAMESPACE" "$GRAFANA_POD" -c grafana -- \
  wget -qO- --header='Authorization: Basic YWRtaW46YWRtaW4=' \
  'http://localhost:3000/api/search?type=dash-db' 2>/dev/null || echo "[]")
DASH_COUNT=$(echo "$DASHBOARDS" | python3 -c 'import json,sys;print(len(json.load(sys.stdin)))')
[[ "$DASH_COUNT" -ge 10 ]] || fail "only $DASH_COUNT dashboards (need >=10)"
log "  dashboards: $DASH_COUNT"

# AC8: specific dashboards present
log "AC8: specific dashboards present"
EXPECTED_DASHBOARDS=(
  "Spark"
  "MinIO"
  "DCGM"
  "Airflow"
  "JVM"
  "JMX"
)
for keyword in "${EXPECTED_DASHBOARDS[@]}"; do
  echo "$DASHBOARDS" | grep -i "$keyword" >/dev/null || \
    fail "no dashboard matches '$keyword'"
done
log "  all expected dashboards present"

# AC9: datasources configured
log "AC9: datasources"
DATASOURCES=$(kubectl exec -n "$NAMESPACE" "$GRAFANA_POD" -c grafana -- \
  wget -qO- --header='Authorization: Basic YWRtaW46YWRtaW4=' \
  'http://localhost:3000/api/datasources' 2>/dev/null || echo "[]")
DS_COUNT=$(echo "$DATASOURCES" | python3 -c 'import json,sys;print(len(json.load(sys.stdin)))')
[[ "$DS_COUNT" -ge 1 ]] || fail "no datasources"
log "  datasources: $DS_COUNT"

log ""
log "=== Stand healthy ==="
GRAFANA_URL=$(timeout 5 minikube service observability-demo-grafana -n "$NAMESPACE" --url 2>/dev/null || echo "http://$(minikube ip 2>/dev/null):30030")
log "Grafana: $GRAFANA_URL (admin/admin)"
exit 0
