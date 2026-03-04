#!/bin/bash
# Load against existing deployment. EXECUTES S3 parquet + 3 agg iterations.
# Env: NAMESPACE (required), RELEASE (required for S3 endpoint)
# Usage: NAMESPACE=spark-matrix-scenario-0009 RELEASE=scenario0009 ./run-load-against-release.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="${NAMESPACE:?NAMESPACE required}"
RELEASE="${RELEASE:?RELEASE required}"

S3_ENDPOINT="http://${RELEASE}-minio.${NAMESPACE}.svc.cluster.local:9000"

connect_pod=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/component=connect -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [[ -z "$connect_pod" ]]; then
    echo "No connect pod in $NAMESPACE"
    exit 1
fi

load_script="${SCRIPT_DIR}/scripts/load_s3_parquet_3agg.py"
kubectl cp "$load_script" "$NAMESPACE/$connect_pod:/tmp/load_s3.py"
kubectl exec -n "$NAMESPACE" "$connect_pod" -- /bin/sh -c "
    export S3_ENDPOINT='$S3_ENDPOINT'
    export S3_ACCESS_KEY='${S3_ACCESS_KEY:-minioadmin}'
    export S3_SECRET_KEY='${S3_SECRET_KEY:-minioadmin}'
    /opt/spark/bin/spark-submit \
        --master local[*] \
        --conf spark.driver.memory=1g \
        --conf spark.eventLog.enabled=true \
        --conf spark.eventLog.dir=s3a://spark-logs/events \
        /tmp/load_s3.py
"
