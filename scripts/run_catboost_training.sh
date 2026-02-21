#!/bin/bash
# Run CatBoost Training for NYC Taxi ML Pipeline in k8s

NAMESPACE="${1:-spark-35-airflow-sa}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=== NYC Taxi CatBoost Training ==="
echo "Namespace: $NAMESPACE"
echo ""

# Create/update ConfigMap with Spark jobs
echo "1) Creating ConfigMap with Spark jobs..."
kubectl create configmap spark-ml-jobs \
  --from-file=taxi_feature_engineering.py=${PROJECT_ROOT}/dags/spark_jobs/taxi_feature_engineering.py \
  --from-file=taxi_catboost_training.py=${PROJECT_ROOT}/dags/spark_jobs/taxi_catboost_training.py \
  -n $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
echo "   ✓ Spark jobs uploaded"
echo ""

# Run CatBoost training
echo "2) Running CatBoost training..."
kubectl delete pod catboost-training -n $NAMESPACE --ignore-not-found 2>/dev/null || true

cat << POD | kubectl apply -n $NAMESPACE -f -
apiVersion: v1
kind: Pod
metadata:
  name: catboost-training
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
      # Get pod IP for Spark driver
      POD_IP=$(hostname -i | awk '{print $1}')
      echo "Pod IP: $POD_IP"

      # Verify sklearn is available
      python3 -c "import sklearn; print(f'sklearn version: {sklearn.__version__}')"

      /opt/spark/bin/spark-submit \
        --master spark://scenario2-spark-35-standalone-master:7077 \
        --conf spark.hadoop.fs.s3a.endpoint=http://minio.spark-infra.svc.cluster.local:9000 \
        --conf spark.hadoop.fs.s3a.access.key=minioadmin \
        --conf spark.hadoop.fs.s3a.secret.key=minioadmin \
        --conf spark.driver.host=$POD_IP \
        --conf spark.driver.bindAddress=0.0.0.0 \
        --conf spark.sql.adaptive.enabled=true \
        --conf spark.eventLog.enabled=true \
        --conf spark.eventLog.dir=s3a://spark-logs/events/ \
        --conf spark.eventLog.rolling.enabled=true \
        --conf spark.eventLog.rolling.maxFileSize=128m \
        --conf spark.hadoop.fs.s3a.path.style.access=true \
        /jobs/taxi_catboost_training.py
    env:
    - name: POD_IP
      valueFrom:
        fieldRef:
          fieldPath: status.podIP
    - name: MINIO_ENDPOINT
      value: "http://minio.spark-infra.svc.cluster.local:9000"
    - name: MINIO_ACCESS_KEY
      value: "minioadmin"
    - name: MINIO_SECRET_KEY
      value: "minioadmin"
    volumeMounts:
    - name: spark-jobs
      mountPath: /jobs
  volumes:
  - name: spark-jobs
    configMap:
      name: spark-ml-jobs
POD

echo "   Waiting for training to complete..."
kubectl wait --for=condition=ready pod/catboost-training -n $NAMESPACE --timeout=60s 2>/dev/null || true

# Stream logs
echo ""
echo "=== Training Logs ==="
kubectl logs -f catboost-training -n $NAMESPACE 2>/dev/null || echo "Waiting for logs..."

echo ""
echo "3) Checking trained models..."
kubectl exec -n spark-infra deployment/minio -- \
  mc ls local/ml-models/taxi-predictor/ 2>/dev/null || echo "Models not found"

echo ""
echo "=== Training Complete ==="
