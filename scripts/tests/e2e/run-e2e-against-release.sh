#!/bin/bash
# E2E against existing deployment. EXECUTES workload (10K rows, aggregations, joins).
# Env: NAMESPACE (required)
# Usage: NAMESPACE=spark-matrix-scenario-0009 ./run-e2e-against-release.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="${NAMESPACE:?NAMESPACE required}"

connect_pod=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/component=connect -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [[ -z "$connect_pod" ]]; then
    echo "No connect pod in $NAMESPACE"
    exit 1
fi

e2e_script="${SCRIPT_DIR}/scripts/e2e_10k_agg_join.py"
kubectl cp "$e2e_script" "$NAMESPACE/$connect_pod:/tmp/e2e_10k.py"
kubectl exec -n "$NAMESPACE" "$connect_pod" -- /bin/sh -c "
    /opt/spark/bin/spark-submit \
        --master local[*] \
        --conf spark.driver.memory=1g \
        /tmp/e2e_10k.py
"
