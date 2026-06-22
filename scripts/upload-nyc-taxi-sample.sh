#!/usr/bin/env bash
# Upload real NYC Taxi data to MinIO for nyc_taxi_ml_full_pipeline DAG.
# Downloads from NYC TLC (CloudFront), uploads to MinIO.
# 2 years: 2022-01..12, 2023-01..12 (24 months).
# Run after MinIO is up. Usage: ./scripts/upload-nyc-taxi-sample.sh [namespace]

set -euo pipefail

NAMESPACE="${1:-spark-infra}"
MINIO_ENDPOINT="http://minio.${NAMESPACE}.svc.cluster.local:9000"
TLC_BASE="https://d37ci6vzurychx.cloudfront.net/trip-data"

echo "=== Uploading real NYC Taxi data to MinIO (namespace=$NAMESPACE) ==="
echo "Source: NYC TLC (CloudFront)"
echo ""

PYTHON_SCRIPT='
import os
import sys
import tempfile
import boto3
import requests

endpoint = os.environ["MINIO_ENDPOINT"]
tlc_base = os.environ.get("TLC_BASE", "https://d37ci6vzurychx.cloudfront.net/trip-data")

s3 = boto3.client("s3", endpoint_url=endpoint, aws_access_key_id=os.environ.get("MINIO_ACCESS_KEY", ""), aws_secret_access_key=os.environ.get("MINIO_SECRET_KEY", ""))

try:
    s3.head_bucket(Bucket="nyc-taxi")
except Exception:
    s3.create_bucket(Bucket="nyc-taxi")
    print("Created bucket nyc-taxi")

for year in [2022, 2023]:
    for month in range(1, 13):
        filename = f"yellow_tripdata_{year}-{month:02d}.parquet"
        url = f"{tlc_base}/{filename}"
        key = f"raw/{filename}"
        print(f"Downloading {url}...", flush=True)
        try:
            r = requests.get(url, stream=True, timeout=300)
            r.raise_for_status()
            tmp = tempfile.NamedTemporaryFile(suffix=".parquet", delete=False)
            try:
                for chunk in r.iter_content(chunk_size=2**20):
                    if chunk:
                        tmp.write(chunk)
                tmp.flush()
                size = tmp.tell()
                tmp.close()
                s3.upload_file(tmp.name, "nyc-taxi", key)
            finally:
                os.unlink(tmp.name)
            print(f"  Uploaded {key} ({size // 1024 // 1024} MB)")
        except Exception as e:
            print(f"  ERROR: {e}", file=sys.stderr)
            sys.exit(1)

print("Done")
'

kubectl create configmap nyc-taxi-upload-script --from-literal=upload.py="$PYTHON_SCRIPT" -n "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

OVERRIDES=$(cat <<EOF
{
  "spec": {
    "containers": [{
      "name": "upload",
      "image": "python:3.11-slim",
      "command": ["/bin/sh", "-c"],
      "args": ["pip install -q boto3 requests && python3 /script/upload.py"],
      "env": [
        {"name": "MINIO_ENDPOINT", "value": "${MINIO_ENDPOINT}"},
        {"name": "TLC_BASE", "value": "${TLC_BASE}"}
      ],
      "volumeMounts": [{"name": "script", "mountPath": "/script", "readOnly": true}],
      "resources": {"requests": {"memory": "128Mi"}, "limits": {"memory": "512Mi"}}
    }],
    "volumes": [{"name": "script", "configMap": {"name": "nyc-taxi-upload-script"}}]
  }
}
EOF
)

echo "Downloading 24 files (~1GB total). This may take several minutes..."
kubectl run nyc-taxi-upload --rm -i --restart=Never -n "$NAMESPACE" \
  --image=python:3.11-slim \
  --overrides="$OVERRIDES"

kubectl delete configmap nyc-taxi-upload-script -n "$NAMESPACE" --ignore-not-found 2>/dev/null || true

echo "=== Done ==="
