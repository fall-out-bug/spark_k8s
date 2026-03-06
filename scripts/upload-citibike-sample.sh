#!/usr/bin/env bash
# Upload sample NYC Citibike data to MinIO for citibike_analytics_pipeline and citibike_eda.
# Downloads real CSV from https://s3.amazonaws.com/tripdata/, samples 5000 rows, uploads to citibike/raw/.
# Run after MinIO is up. Usage: ./scripts/upload-citibike-sample.sh [namespace]

set -euo pipefail

NAMESPACE="${1:-spark-infra}"
MINIO_ENDPOINT="http://minio.${NAMESPACE}.svc.cluster.local:9000"
# Jersey City data (~3MB) — faster download than NYC (~350MB); same schema
CITIBIKE_URL="https://s3.amazonaws.com/tripdata/JC-202404-citibike-tripdata.csv.zip"

echo "=== Uploading Citibike sample data to MinIO (namespace=$NAMESPACE) ==="

PYTHON_SCRIPT='
import io
import os
import zipfile
import urllib.request

import boto3
import pandas as pd

endpoint = os.environ["MINIO_ENDPOINT"]
url = os.environ.get("CITIBIKE_URL", "https://s3.amazonaws.com/tripdata/JC-202404-citibike-tripdata.csv.zip")
sample_rows = int(os.environ.get("CITIBIKE_SAMPLE_ROWS", "5000"))

s3 = boto3.client("s3", endpoint_url=endpoint, aws_access_key_id="minioadmin", aws_secret_access_key="minioadmin")

try:
    s3.head_bucket(Bucket="citibike")
except Exception:
    s3.create_bucket(Bucket="citibike")
    print("Created bucket citibike")

print(f"Downloading {url}...")
with urllib.request.urlopen(url, timeout=300) as resp:
    zip_data = resp.read()

print("Unzipping and reading CSV...")
with zipfile.ZipFile(io.BytesIO(zip_data), "r") as zf:
    csv_names = [n for n in zf.namelist() if n.endswith(".csv")]
    if not csv_names:
        raise SystemExit("No CSV in zip")
    with zf.open(csv_names[0]) as f:
        df = pd.read_csv(f, nrows=sample_rows)

print(f"Loaded {len(df)} rows, columns: {list(df.columns)}")

buf = io.BytesIO()
df.to_parquet(buf, index=False)
buf.seek(0)
key = "raw/202404-citibike-sample.parquet"
s3.put_object(Bucket="citibike", Key=key, Body=buf.getvalue())
print(f"Uploaded {key} ({len(df)} rows)")

print("Done")
'

kubectl create configmap citibike-upload-script --from-literal=upload.py="$PYTHON_SCRIPT" -n "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

OVERRIDES=$(cat <<EOF
{
  "spec": {
    "containers": [{
      "name": "upload",
      "image": "python:3.11-slim",
      "command": ["/bin/sh", "-c"],
      "args": ["pip install -q boto3 pandas pyarrow && python3 /script/upload.py"],
      "env": [
        {"name": "MINIO_ENDPOINT", "value": "${MINIO_ENDPOINT}"},
        {"name": "CITIBIKE_URL", "value": "${CITIBIKE_URL}"}
      ],
      "volumeMounts": [{"name": "script", "mountPath": "/script", "readOnly": true}]
    }],
    "volumes": [{"name": "script", "configMap": {"name": "citibike-upload-script"}}]
  }
}
EOF
)

kubectl run citibike-upload --rm -i --restart=Never -n "$NAMESPACE" \
  --image=python:3.11-slim \
  --overrides="$OVERRIDES"

kubectl delete configmap citibike-upload-script -n "$NAMESPACE" --ignore-not-found 2>/dev/null || true

echo "=== Done ==="
