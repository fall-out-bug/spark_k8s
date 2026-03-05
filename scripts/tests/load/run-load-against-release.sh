#!/bin/bash
# Load against existing deployment. EXECUTES S3 parquet + 3 agg iterations.
# Env: NAMESPACE (required), RELEASE (required), DEPLOY_MODE (connect|k8s-native|standalone)
# Usage: NAMESPACE=spark-matrix-scenario-0009 RELEASE=scenario0009 DEPLOY_MODE=connect ./run-load-against-release.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="${NAMESPACE:?NAMESPACE required}"
RELEASE="${RELEASE:?RELEASE required}"
DEPLOY_MODE="${DEPLOY_MODE:-connect}"

if [[ -n "${SHARED_INFRA_NS:-}" ]]; then
    S3_ENDPOINT="http://minio.${SHARED_INFRA_NS}.svc.cluster.local:9000"
else
    S3_ENDPOINT="http://${RELEASE}-minio.${NAMESPACE}.svc.cluster.local:9000"
fi

load_script="${SCRIPT_DIR}/scripts/load_s3_parquet_3agg.py"
case "$DEPLOY_MODE" in
    connect)
        connect_pod=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/component=connect -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
        if [[ -z "$connect_pod" ]]; then
            echo "No connect pod in $NAMESPACE"
            exit 1
        fi
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
        ;;
    k8s-native)
        SPARK_IMAGE="${SPARK_IMAGE:-spark-custom:3.5.7}"
        submitter_pod=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/component=k8s-native-submitter -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
        if [[ -z "$submitter_pod" ]]; then
            echo "No k8s-native-submitter pod in $NAMESPACE"
            exit 1
        fi
        kubectl cp "$load_script" "$NAMESPACE/$submitter_pod:/tmp/load_s3.py"
        kubectl exec -n "$NAMESPACE" "$submitter_pod" -- /bin/sh -c "
            export S3_ENDPOINT='$S3_ENDPOINT'
            export S3_ACCESS_KEY='${S3_ACCESS_KEY:-minioadmin}'
            export S3_SECRET_KEY='${S3_SECRET_KEY:-minioadmin}'
            /opt/spark/bin/spark-submit \
                --master k8s://https://kubernetes.default.svc:443 \
                --deploy-mode cluster \
                --conf spark.kubernetes.namespace=$NAMESPACE \
                --conf spark.kubernetes.authenticate.driver.serviceAccountName=spark-35 \
                --conf spark.kubernetes.container.image=$SPARK_IMAGE \
                --conf spark.driver.memory=1g \
                --conf spark.eventLog.enabled=true \
                --conf spark.eventLog.dir=s3a://spark-logs/events \
                /tmp/load_s3.py
        "
        ;;
    standalone)
        worker_pod=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/component=standalone-worker -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
        if [[ -z "$worker_pod" ]]; then
            echo "No standalone-worker pod in $NAMESPACE"
            exit 1
        fi
        spark_master="spark://${RELEASE}-standalone-master:7077"
        kubectl cp "$load_script" "$NAMESPACE/$worker_pod:/tmp/load_s3.py"
        kubectl exec -n "$NAMESPACE" "$worker_pod" -- /bin/sh -c "
            export S3_ENDPOINT='$S3_ENDPOINT'
            export S3_ACCESS_KEY='${S3_ACCESS_KEY:-minioadmin}'
            export S3_SECRET_KEY='${S3_SECRET_KEY:-minioadmin}'
            /opt/spark/bin/spark-submit \
                --master $spark_master \
                --conf spark.driver.memory=1g \
                --conf spark.eventLog.enabled=true \
                --conf spark.eventLog.dir=s3a://spark-logs/events \
                /tmp/load_s3.py
        "
        ;;
    *)
        echo "Unknown DEPLOY_MODE: $DEPLOY_MODE"
        exit 1
        ;;
esac
