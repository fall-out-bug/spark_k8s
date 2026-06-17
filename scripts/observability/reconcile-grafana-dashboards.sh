#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
NAMESPACE="${1:-observability}"

apply_dashboard() {
  local name="$1"
  local folder="$2"
  local source_file="$3"
  local key
  key="$(basename "$source_file")"

  kubectl create configmap "$name" \
    --from-file="$key=$source_file" \
    -n "$NAMESPACE" \
    --dry-run=client -o yaml | kubectl apply -f - >/dev/null

  kubectl label configmap "$name" -n "$NAMESPACE" grafana_dashboard=1 --overwrite >/dev/null
  kubectl annotate configmap "$name" -n "$NAMESPACE" k8s-sidecar-target-directory="/tmp/dashboards/$folder" --overwrite >/dev/null
}

annotate_existing() {
  local name="$1"
  local folder="$2"
  if kubectl get configmap "$name" -n "$NAMESPACE" >/dev/null 2>&1; then
    kubectl label configmap "$name" -n "$NAMESPACE" grafana_dashboard=1 --overwrite >/dev/null 2>&1 || true
    kubectl annotate configmap "$name" -n "$NAMESPACE" k8s-sidecar-target-directory="/tmp/dashboards/$folder" --overwrite >/dev/null 2>&1 || true
  fi
}

apply_dashboard "dashboard-demo-spark-overview" "Spark" "$PROJECT_ROOT/charts/observability/grafana/dashboards/demo-spark-overview.json"
apply_dashboard "dashboard-spark-job-anatomy" "Spark" "$PROJECT_ROOT/charts/observability/grafana/dashboards/spark-job-anatomy.json"
apply_dashboard "dashboard-performance-analysis" "Spark" "$PROJECT_ROOT/charts/observability/grafana/dashboards/performance-analysis.json"
apply_dashboard "dashboard-cost-by-job" "Operations" "$PROJECT_ROOT/charts/observability/grafana/dashboards/cost-by-job.json"
apply_dashboard "dashboard-cost-by-team" "Operations" "$PROJECT_ROOT/charts/observability/grafana/dashboards/cost-by-team.json"
apply_dashboard "dashboard-incident-metrics" "Operations" "$PROJECT_ROOT/charts/observability/grafana/dashboards/incident-metrics.json"

kubectl delete configmap dashboard-spark-overview -n "$NAMESPACE" --ignore-not-found >/dev/null 2>&1 || true

for cm in \
  spark-infra-spark-35-dashboard-autotuning \
  spark-infra-spark-35-dashboard-executor-metrics \
  spark-infra-spark-35-dashboard-jmx \
  spark-infra-spark-35-dashboard-job-performance \
  spark-infra-spark-35-dashboard-ml-training \
  spark-infra-spark-35-dashboard-nyc-taxi \
  spark-infra-spark-35-dashboard-spark-overview \
  spark-infra-spark-35-dashboard-streaming; do
  annotate_existing "$cm" "Spark"
done

for cm in \
  dashboard-backup-status \
  dashboard-budget-status \
  dashboard-chaos-metrics \
  dashboard-cost-breakdown \
  dashboard-cost-trends \
  dashboard-incident-metrics \
  dashboard-rto-rpo \
  dashboard-slo-forecast; do
  annotate_existing "$cm" "Operations"
done

if kubectl get pod -n "$NAMESPACE" -l app.kubernetes.io/name=grafana >/dev/null 2>&1; then
  kubectl exec -n "$NAMESPACE" deploy/observability-demo-grafana -c grafana -- curl -s -X POST 'http://admin:admin@localhost:3000/api/admin/provisioning/dashboards/reload' >/dev/null 2>&1 || true
  pf_log="$(mktemp)"
  kubectl port-forward -n "$NAMESPACE" svc/observability-demo-grafana 23000:3000 >"$pf_log" 2>&1 &
  pf_pid=$!
  sleep 3
  python3 - <<'PY'
import base64, json, urllib.request
auth = base64.b64encode(b'admin:admin').decode()
headers = {'Authorization': f'Basic {auth}'}
req = urllib.request.Request('http://localhost:23000/api/folders', headers=headers)
with urllib.request.urlopen(req) as resp:
    folders = json.load(resp)
for folder in folders:
    if folder.get('title') in {'spark', 'ops'}:
        req = urllib.request.Request(f"http://localhost:23000/api/folders/{folder['uid']}", headers=headers, method='DELETE')
        urllib.request.urlopen(req).read()
PY
  kill "$pf_pid" >/dev/null 2>&1 || true
  rm -f "$pf_log"
fi
