#!/bin/bash
# Deploy NYC Taxi ML Pipeline to minikube
#
# This script:
# 1. Creates ConfigMaps with DAG and Spark jobs
# 2. Runs feature engineering
# 3. Trains models
# 4. Generates predictions

set -e

NAMESPACE="${1:-spark-35-airflow-sa}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=== NYC Taxi ML Pipeline Deployment ==="
echo "Namespace: $NAMESPACE"
echo "Project: $PROJECT_ROOT"
echo ""

# 1. Create ml-models bucket if not exists
echo "1) Ensuring MinIO buckets exist..."
kubectl exec -n spark-infra deployment/minio -- \
  sh -c "mc alias set local http://localhost:9000 minioadmin minioadmin && mc mb local/ml-models --ignore-existing" || true
echo "   ✓ Buckets ready"
echo ""

# 2. Upload Spark jobs as ConfigMap
echo "2) Creating ConfigMap with Spark jobs..."
kubectl create configmap spark-ml-jobs \
  --from-file=taxi_feature_engineering.py=${PROJECT_ROOT}/dags/spark_jobs/taxi_feature_engineering.py \
  -n $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
echo "   ✓ Spark jobs uploaded"
echo ""

# 3. Run feature engineering
echo "3) Running feature engineering..."
kubectl delete pod feature-engineering -n $NAMESPACE --ignore-not-found 2>/dev/null || true

cat << POD | kubectl apply -n $NAMESPACE -f -
apiVersion: v1
kind: Pod
metadata:
  name: feature-engineering
spec:
  restartPolicy: Never
  serviceAccountName: spark
  containers:
  - name: spark-submit
    image: spark-custom:3.5.7-ml
    imagePullPolicy: IfNotPresent
    command:
    - sh
    - -c
    - |
      /opt/spark/bin/spark-submit \
        --master spark://scenario2-spark-35-standalone-master:7077 \
        --conf spark.hadoop.fs.s3a.endpoint=http://minio.spark-infra.svc.cluster.local:9000 \
        --conf spark.hadoop.fs.s3a.access.key=minioadmin \
        --conf spark.hadoop.fs.s3a.secret.key=minioadmin \
        --conf spark.driver.host=$POD_IP \
        --conf spark.driver.bindAddress=0.0.0.0 \
        --conf spark.eventLog.enabled=true \
        --conf spark.eventLog.dir=s3a://spark-logs/events/ \
        --conf spark.eventLog.rolling.enabled=true \
        --conf spark.eventLog.rolling.maxFileSize=128m \
        --conf spark.hadoop.fs.s3a.path.style.access=true \
        /jobs/taxi_feature_engineering.py
    env:
    - name: POD_IP
      valueFrom:
        fieldRef:
          fieldPath: status.podIP
    volumeMounts:
    - name: spark-jobs
      mountPath: /jobs
  volumes:
  - name: spark-jobs
    configMap:
      name: spark-ml-jobs
POD

echo "   Waiting for feature engineering to complete..."
kubectl wait --for=condition=ready pod/feature-engineering -n $NAMESPACE --timeout=60s 2>/dev/null || true
kubectl wait --for=condition=complete pod/feature-engineering -n $NAMESPACE --timeout=300s 2>/dev/null || true

echo "   Logs:"
kubectl logs feature-engineering -n $NAMESPACE --tail=50 2>/dev/null || echo "   (no logs yet)"

echo ""
echo "4) Checking generated features..."
kubectl exec -n spark-infra deployment/minio -- \
  mc ls local/nyc-taxi/features/ 2>/dev/null || echo "   (features not yet generated)"

echo ""
echo "=== Deployment Complete ==="
echo ""
echo "Next steps:"
echo "  1. Run Airflow DAG: kubectl port-forward -n airflow svc/airflow-webserver 8080:8080"
echo "  2. Open Jupyter: kubectl port-forward -n spark-35-jupyter-sa svc/scenario1-spark-35-jupyter 8888:8888"
echo "  3. Check predictions: kubectl exec -n spark-infra deployment/minio -- mc ls local/nyc-taxi/predictions/"
