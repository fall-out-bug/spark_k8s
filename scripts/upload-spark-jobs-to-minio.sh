#!/usr/bin/env bash
# Upload spark_jobs from chart to MinIO spark-jobs bucket.
# Run after MinIO is up and buckets exist (see demo-runbook section 2).
# Usage: ./scripts/upload-spark-jobs-to-minio.sh [namespace]

set -euo pipefail

# Credentials from env (local demo default = MinIO factory; override for real clusters)
: "${S3_ACCESS_KEY:=minioadmin}"
: "${S3_SECRET_KEY:=minioadmin}"


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
NAMESPACE="${1:-spark-infra}"
SPARK_JOBS_DIR="$PROJECT_ROOT/charts/spark-3.5/dags"

if [[ ! -d "$SPARK_JOBS_DIR" ]]; then
  echo "Error: spark_jobs dir not found: $SPARK_JOBS_DIR"
  exit 1
fi

echo "=== Uploading spark_jobs to MinIO (namespace=$NAMESPACE) ==="

# Create ConfigMap from spark_jobs (keys = filenames)
kubectl create configmap spark-jobs-upload \
  --from-file="$SPARK_JOBS_DIR" \
  -n "$NAMESPACE" \
  --dry-run=client -o yaml | kubectl apply -f -

# Upload via Python pod
kubectl run spark-jobs-upload --rm -i --restart=Never -n "$NAMESPACE" \
  --image=python:3.11-slim \
  --env="MINIO_ENDPOINT=http://minio.${NAMESPACE}.svc.cluster.local:9000" \
  --overrides='{
  "spec": {
    "containers": [{
      "name": "upload",
      "image": "python:3.11-slim",
      "command": ["/bin/sh", "-c"],
      "args": ["pip install -q boto3 && python3 -c \"import boto3,os; from pathlib import Path; s3=boto3.client(\\\"s3\\\",endpoint_url=os.environ.get(\\\"MINIO_ENDPOINT\\\",\\\"http://minio.${NAMESPACE}.svc.cluster.local:9000\\\"),aws_access_key_id=os.environ[\\"S3_ACCESS_KEY\"],aws_secret_access_key=os.environ[\\"S3_SECRET_KEY\"]); [s3.upload_file(str(f),\\\"spark-jobs\\\",\\\"dags/spark_jobs/\\\"+f.name) or print(\\\"Uploaded\\\",f.name) for f in Path(\\\"/scripts\\\").glob(\\\"*.py\\\")]\""],
      "volumeMounts": [{"name": "scripts", "mountPath": "/scripts", "readOnly": true}]
    }],
    "volumes": [{"name": "scripts", "configMap": {"name": "spark-jobs-upload"}}]
  }
}'

# Cleanup
kubectl delete configmap spark-jobs-upload -n "$NAMESPACE" --ignore-not-found 2>/dev/null || true

echo "=== Done ==="
