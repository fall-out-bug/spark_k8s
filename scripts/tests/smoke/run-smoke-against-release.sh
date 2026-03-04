#!/bin/bash
# Smoke against existing deployment. EXECUTES workload (1K rows, count, filter).
# Env: NAMESPACE (required)
# Usage: NAMESPACE=spark-matrix-scenario-0009 ./run-smoke-against-release.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="${NAMESPACE:?NAMESPACE required}"

connect_pod=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/component=connect -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [[ -z "$connect_pod" ]]; then
    echo "No connect pod in $NAMESPACE"
    exit 1
fi

smoke_script="${SCRIPT_DIR}/scripts/smoke_1k_count_filter.py"
kubectl cp "$smoke_script" "$NAMESPACE/$connect_pod:/tmp/smoke_1k.py"
kubectl exec -n "$NAMESPACE" "$connect_pod" -- /bin/sh -c "
    /opt/spark/bin/spark-submit \
        --master local[*] \
        --conf spark.driver.memory=512m \
        /tmp/smoke_1k.py
"
