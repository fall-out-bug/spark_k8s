#!/bin/bash
# Create dashboard ConfigMaps for Grafana sidecar

NAMESPACE="observability"
DASHBOARDS_DIR="charts/observability/grafana/dashboards"

# Create ConfigMaps for each dashboard
for f in ${DASHBOARDS_DIR}/*.json; do
  name=$(basename "$f" .json)
  echo "Creating ConfigMap for dashboard: $name"

  cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: dashboard-${name}
  namespace: ${NAMESPACE}
  labels:
    grafana_dashboard: "1"
data:
  ${name}.json: |
$(cat "$f" | sed 's/^/    /')
EOF
done

echo ""
echo "=== Dashboard ConfigMaps created ==="
kubectl get cm -n ${NAMESPACE} -l grafana_dashboard=1
