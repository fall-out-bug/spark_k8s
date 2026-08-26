#!/bin/bash
# E2E against existing deployment. EXECUTES workload (10K rows, aggregations, joins).
# Env: NAMESPACE (required), RELEASE (required for standalone/k8s-native), DEPLOY_MODE (connect|k8s-native|standalone)
# Usage: NAMESPACE=spark-matrix-scenario-0009 RELEASE=scenario0009 DEPLOY_MODE=connect ./run-e2e-against-release.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="${NAMESPACE:?NAMESPACE required}"
DEPLOY_MODE="${DEPLOY_MODE:-connect}"

# Optional S3 round-trip stage: when E2E_S3_ROUNDTRIP=1 the workload writes its
# aggregate to MinIO and reads it back (bucket must exist — spark-jobs is
# provisioned by default via minio.buckets).
S3_BUCKET="${S3_BUCKET:-spark-jobs}"
RT_CONFS=""
if [[ "${E2E_S3_ROUNDTRIP:-0}" == "1" ]]; then
    S3_ACCESS_KEY="${S3_ACCESS_KEY:?S3_ACCESS_KEY required for E2E_S3_ROUNDTRIP}"
    S3_SECRET_KEY="${S3_SECRET_KEY:?S3_SECRET_KEY required for E2E_S3_ROUNDTRIP}"
    RELEASE="${RELEASE:?RELEASE required for E2E_S3_ROUNDTRIP}"
    if [[ -z "${S3_ENDPOINT:-}" ]]; then
        if [[ -n "${SHARED_INFRA_NS:-}" ]]; then
            S3_ENDPOINT="http://minio.${SHARED_INFRA_NS}.svc.cluster.local:9000"
        else
            S3_ENDPOINT="http://${RELEASE}-minio.${NAMESPACE}.svc.cluster.local:9000"
        fi
    fi
    # Full s3a set (also needed for connect/standalone submits that carry no
    # s3a conf of their own); duplicate keys in k8s-native are identical and harmless.
    RT_CONFS="--conf spark.e2e.s3.roundtrip=true \
--conf spark.e2e.s3.path=s3a://${S3_BUCKET}/e2e-roundtrip/${RELEASE} \
--conf spark.hadoop.fs.s3a.endpoint=${S3_ENDPOINT} \
--conf spark.hadoop.fs.s3a.access.key=${S3_ACCESS_KEY} \
--conf spark.hadoop.fs.s3a.secret.key=${S3_SECRET_KEY} \
--conf spark.hadoop.fs.s3a.path.style.access=true \
--conf spark.hadoop.fs.s3a.connection.ssl.enabled=false"
fi

e2e_script="${SCRIPT_DIR}/scripts/e2e_10k_agg_join.py"
case "$DEPLOY_MODE" in
    connect)
        connect_pod=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/component=connect -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
        if [[ -z "$connect_pod" ]]; then
            echo "No connect pod in $NAMESPACE"
            exit 1
        fi
        kubectl cp "$e2e_script" "$NAMESPACE/$connect_pod:/tmp/e2e_10k.py"
        kubectl exec -n "$NAMESPACE" "$connect_pod" -- /bin/sh -c "
            /opt/spark/bin/spark-submit \
                --master local[*] \
                --conf spark.driver.memory=1g \
                $RT_CONFS \
                /tmp/e2e_10k.py
        "
        ;;
    k8s-native)
        RELEASE="${RELEASE:?RELEASE required}"
        SPARK_IMAGE="${SPARK_IMAGE:-spark-custom:3.5.7}"
        driver_service_account="${DRIVER_SERVICE_ACCOUNT:-spark-35}"
        S3_ACCESS_KEY="${S3_ACCESS_KEY:?S3_ACCESS_KEY required}"
        S3_SECRET_KEY="${S3_SECRET_KEY:?S3_SECRET_KEY required}"
        if [[ -n "${SHARED_INFRA_NS:-}" ]]; then
            S3_ENDPOINT="http://minio.${SHARED_INFRA_NS}.svc.cluster.local:9000"
        else
            S3_ENDPOINT="http://${RELEASE}-minio.${NAMESPACE}.svc.cluster.local:9000"
        fi
        submitter_pod=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/component=k8s-native-submitter -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
        if [[ -z "$submitter_pod" ]]; then
            echo "No k8s-native-submitter pod in $NAMESPACE"
            exit 1
        fi
        kubectl cp "$e2e_script" "$NAMESPACE/$submitter_pod:/tmp/e2e_10k.py"
        kubectl exec -n "$NAMESPACE" "$submitter_pod" -- /bin/sh -c "
            /opt/spark/bin/spark-submit \
                --master k8s://https://kubernetes.default.svc:443 \
                --deploy-mode cluster \
                --conf spark.kubernetes.file.upload.path=s3a://spark-jobs/spark-upload/$RELEASE \
                --conf spark.kubernetes.namespace=$NAMESPACE \
                --conf spark.kubernetes.authenticate.driver.serviceAccountName=$driver_service_account \
                --conf spark.kubernetes.container.image=$SPARK_IMAGE \
                --conf spark.hadoop.fs.s3a.endpoint=$S3_ENDPOINT \
                --conf spark.hadoop.fs.s3a.access.key=$S3_ACCESS_KEY \
                --conf spark.hadoop.fs.s3a.secret.key=$S3_SECRET_KEY \
                --conf spark.hadoop.fs.s3a.path.style.access=true \
                --conf spark.hadoop.fs.s3a.connection.ssl.enabled=false \
                --conf spark.driver.memory=1g \
                $RT_CONFS \
                /tmp/e2e_10k.py
        "
        ;;
    standalone)
        RELEASE="${RELEASE:?RELEASE required}"
        worker_pod=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/component=standalone-worker -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
        if [[ -z "$worker_pod" ]]; then
            echo "No standalone-worker pod in $NAMESPACE"
            exit 1
        fi
        spark_master="spark://${RELEASE}-standalone-master:7077"
        kubectl cp "$e2e_script" "$NAMESPACE/$worker_pod:/tmp/e2e_10k.py"
        kubectl exec -n "$NAMESPACE" "$worker_pod" -- /bin/sh -c "
            driver_host=\$(hostname -i)
            /opt/spark/bin/spark-submit \
                --master $spark_master \
                --conf spark.driver.host=\$driver_host \
                --conf spark.driver.bindAddress=0.0.0.0 \
                --conf spark.driver.memory=1g \
                $RT_CONFS \
                /tmp/e2e_10k.py
        "
        ;;
    *)
        echo "Unknown DEPLOY_MODE: $DEPLOY_MODE"
        exit 1
        ;;
esac
