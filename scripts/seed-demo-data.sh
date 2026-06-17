#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${1:-spark-infra}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

count_parquet() {
  local bucket="$1"
  kubectl run "count-${bucket//[^a-z0-9]/}-$$" --rm -i --restart=Never -n "$NAMESPACE" \
    --image=python:3.11-slim \
    --overrides='{"spec":{"containers":[{"name":"c","image":"python:3.11-slim","command":["/bin/sh","-c"],"args":["pip install -q boto3 && python3 -c \"import os,boto3; s3=boto3.client(\\\"s3\\\",endpoint_url=os.environ[\\\"E\\\"],aws_access_key_id=\\\"minioadmin\\\",aws_secret_access_key=\\\"minioadmin\\\"); objs=s3.list_objects_v2(Bucket=\\\"'"$bucket"'\\\",Prefix=\\\"raw/\\\") or {}; print(len([x for x in objs.get(\\\"Contents\\\",[]) if x[\\\"Key\\\"].endswith(\\\".parquet\\\")]))\""],"env":[{"name":"E","value":"http://minio.'"$NAMESPACE"'.svc.cluster.local:9000"}]}]}}' \
    2>/dev/null | grep -oE '^[0-9]+$' | tail -1 || echo "0"
}

count_spark_jobs() {
  kubectl run "count-spark-jobs-$$" --rm -i --restart=Never -n "$NAMESPACE" \
    --image=python:3.11-slim \
    --overrides='{"spec":{"containers":[{"name":"c","image":"python:3.11-slim","command":["/bin/sh","-c"],"args":["pip install -q boto3 && python3 -c \"import os,boto3; s3=boto3.client(\\\"s3\\\",endpoint_url=os.environ[\\\"E\\\"],aws_access_key_id=\\\"minioadmin\\\",aws_secret_access_key=\\\"minioadmin\\\"); objs=s3.list_objects_v2(Bucket=\\\"spark-jobs\\\",Prefix=\\\"dags/spark_jobs/\\\") or {}; print(len([x for x in objs.get(\\\"Contents\\\",[]) if x[\\\"Key\\\"].endswith(\\\".py\\\")]))\""],"env":[{"name":"E","value":"http://minio.'"$NAMESPACE"'.svc.cluster.local:9000"}]}]}}' \
    2>/dev/null | grep -oE '^[0-9]+$' | tail -1 || echo "0"
}

spark_jobs_count="$(count_spark_jobs)"
nyc_count="$(count_parquet nyc-taxi)"
citibike_count="$(count_parquet citibike)"

if [[ "$spark_jobs_count" -lt 8 ]]; then
  "$SCRIPT_DIR/upload-spark-jobs-to-minio.sh" "$NAMESPACE"
fi

if [[ "$nyc_count" -lt 24 ]]; then
  "$SCRIPT_DIR/upload-nyc-taxi-sample.sh" "$NAMESPACE"
fi

if [[ "$citibike_count" -lt 1 ]]; then
  "$SCRIPT_DIR/upload-citibike-sample.sh" "$NAMESPACE"
fi
