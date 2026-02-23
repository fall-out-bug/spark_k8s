#!/bin/bash
# Run NYC TLC data download as a pod in k8s cluster

NAMESPACE="${1:-spark-infra}"
BUCKET="${2:-nyc-taxi}"
START_MONTH="${3:-2023-01}"
END_MONTH="${4:-2023-03}"  # 3 months for testing
LIMIT="${5:-3}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=== NYC TLC Data Ingestion ==="
echo "Namespace: $NAMESPACE"
echo "Bucket: $BUCKET"
echo "Period: $START_MONTH to $END_MONTH"
echo "Limit: $LIMIT months"
echo ""

# Create ConfigMap with script
CM_NAME="nyc-tlc-download-script-$$"
kubectl create configmap $CM_NAME \
  --from-file=download_nyc_tlc.py=${SCRIPT_DIR}/download_nyc_tlc.py \
  -n $NAMESPACE

# Run as pod
cat << POD | kubectl apply -n $NAMESPACE -f -
apiVersion: v1
kind: Pod
metadata:
  name: nyc-tlc-download-$$
spec:
  restartPolicy: Never
  containers:
  - name: downloader
    image: spark-custom:3.5.7-ml
    imagePullPolicy: IfNotPresent
    command:
    - sh
    - -c
    - |
      pip3 install --quiet boto3 requests python-dateutil 2>/dev/null || pip install --quiet boto3 requests python-dateutil 2>/dev/null || true
      python3 /script/download_nyc_tlc.py \
        --start-month $START_MONTH \
        --end-month $END_MONTH \
        --endpoint http://minio.spark-infra.svc.cluster.local:9000 \
        --bucket $BUCKET \
        --path raw/ \
        --limit $LIMIT
    volumeMounts:
    - name: script
      mountPath: /script
  volumes:
  - name: script
    configMap:
      name: $CM_NAME
POD

# Wait for completion
echo "Waiting for download to complete..."
kubectl wait --for=condition=ready pod/nyc-tlc-download-$$ -n $NAMESPACE --timeout=60s 2>/dev/null || true
kubectl wait --for=condition=complete pod/nyc-tlc-download-$$ -n $NAMESPACE --timeout=600s 2>/dev/null || true

# Show logs
kubectl logs nyc-tlc-download-$$ -n $NAMESPACE

# Cleanup
kubectl delete cm $CM_NAME -n $NAMESPACE --ignore-not-found
kubectl delete pod nyc-tlc-download-$$ -n $NAMESPACE --ignore-not-found
