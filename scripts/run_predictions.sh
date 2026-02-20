#!/bin/bash
# Run NYC Taxi 7-Day Prediction in k8s

NAMESPACE="${1:-spark-35-airflow-sa}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODEL_VERSION="${2:-$(date +%Y%m%d)}"

echo "=== NYC Taxi 7-Day Prediction ==="
echo "Namespace: $NAMESPACE"
echo "Model Version: $MODEL_VERSION"
echo ""

# Update ConfigMap with prediction script
echo "1) Updating ConfigMap..."
kubectl create configmap spark-ml-jobs \
  --from-file=taxi_feature_engineering.py=${PROJECT_ROOT}/dags/spark_jobs/taxi_feature_engineering.py \
  --from-file=taxi_catboost_training.py=${PROJECT_ROOT}/dags/spark_jobs/taxi_catboost_training.py \
  --from-file=taxi_predict.py=${PROJECT_ROOT}/dags/spark_jobs/taxi_predict.py \
  -n $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
echo "   ✓ ConfigMap updated"
echo ""

# Run prediction
echo "2) Running 7-day prediction..."
kubectl delete pod taxi-prediction -n $NAMESPACE --ignore-not-found 2>/dev/null || true

cat << POD | kubectl apply -n $NAMESPACE -f -
apiVersion: v1
kind: Pod
metadata:
  name: taxi-prediction
spec:
  restartPolicy: Never
  serviceAccountName: spark
  containers:
  - name: predict
    image: spark-custom:3.5.7-ml
    imagePullPolicy: IfNotPresent
    command:
    - python3
    - /jobs/taxi_predict.py
    env:
    - name: MINIO_ENDPOINT
      value: "http://minio.spark-infra.svc.cluster.local:9000"
    - name: MINIO_ACCESS_KEY
      value: "minioadmin"
    - name: MINIO_SECRET_KEY
      value: "minioadmin"
    - name: MODEL_VERSION
      value: "$MODEL_VERSION"
    volumeMounts:
    - name: spark-jobs
      mountPath: /jobs
  volumes:
  - name: spark-jobs
    configMap:
      name: spark-ml-jobs
POD

echo "   Waiting for prediction to complete..."
kubectl wait --for=condition=ready pod/taxi-prediction -n $NAMESPACE --timeout=60s 2>/dev/null || true
kubectl wait --for=condition=complete pod/taxi-prediction -n $NAMESPACE --timeout=120s 2>/dev/null || true

echo ""
echo "=== Prediction Logs ==="
kubectl logs taxi-prediction -n $NAMESPACE 2>&1 | tail -50

echo ""
echo "3) Checking predictions..."
kubectl exec -n spark-infra deployment/minio -- \
  mc cat local/nyc-taxi/predictions/v${MODEL_VERSION}/7day_forecast.csv 2>/dev/null | head -20

echo ""
echo "=== Prediction Complete ==="
