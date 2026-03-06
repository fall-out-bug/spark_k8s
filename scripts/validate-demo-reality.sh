#!/usr/bin/env bash
# Validate demo REALITY: not just pods running, but UI reachable and data present.
# Run after: deploy, upload-spark-jobs, upload-nyc-taxi-sample, start-ui-portforwards.
# Usage: ./scripts/validate-demo-reality.sh [--quiet]
# Exit 0 = demo usable; exit 1 = decoration only (nothing works when you click).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

NAMESPACE="spark-infra"
QUIET=""
for arg in "$@"; do
  case "$arg" in
    --quiet) QUIET="--quiet" ;;
    *) NAMESPACE="$arg" ;;
  esac
done
FAILURES=0

check() {
  local name="$1"
  local result="$2"
  if [[ "$result" == "ok" ]]; then
    [[ "$QUIET" != "--quiet" ]] && echo "  OK: $name"
  else
    echo "  FAIL: $name"
    ((FAILURES++))
  fi
}

echo "=== Demo Reality Check (not just decor) ==="

# 1. Decor first (warn only; reality checks below are authoritative)
if ! ./scripts/check-demo-health.sh --quiet 2>/dev/null; then
  [[ "$QUIET" != "--quiet" ]] && echo "  WARN: Basic health check failed (run restore-demo.sh first)"
fi

# 2. Port-forwards alive (UI reachable)
airflow_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 2 http://localhost:18080 2>/dev/null || echo "000")
check "Airflow UI reachable (localhost:18080)" "$([[ "$airflow_code" =~ ^(200|302|401)$ ]] && echo ok || echo "got $airflow_code")"

jupyter_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 2 http://localhost:18888/lab 2>/dev/null || echo "000")
check "Jupyter Lab reachable (localhost:18888)" "$([[ "$jupyter_code" =~ ^(200|302|401)$ ]] && echo ok || echo "got $jupyter_code - run start-ui-portforwards.sh")"

# 3. MinIO has spark-jobs (DAGs need this)
spark_jobs_count=$(kubectl run minio-check --rm -i --restart=Never -n "$NAMESPACE" \
  --image=python:3.11-slim \
  --overrides='{"spec":{"containers":[{"name":"c","image":"python:3.11-slim","command":["/bin/sh","-c"],"args":["pip install -q boto3 && python3 -c \"import os,boto3; s3=boto3.client(\\\"s3\\\",endpoint_url=os.environ[\\\"E\\\"],aws_access_key_id=\\\"minioadmin\\\",aws_secret_access_key=\\\"minioadmin\\\"); objs=s3.list_objects_v2(Bucket=\\\"spark-jobs\\\",Prefix=\\\"dags/spark_jobs/\\\") or {}; print(len([x for x in objs.get(\\\"Contents\\\",[]) if x[\\\"Key\\\"].endswith(\\\".py\\\")]))\""],"env":[{"name":"E","value":"http://minio.'"$NAMESPACE"'.svc.cluster.local:9000"}]}]}}' \
  2>/dev/null | grep -oE '^[0-9]+$' | tail -1 || echo "0")
spark_jobs_count="${spark_jobs_count:-0}"
check "Spark jobs in MinIO (spark-jobs/dags/spark_jobs/*.py, got $spark_jobs_count)" "$([[ "${spark_jobs_count:-0}" -ge 1 ]] && echo ok || echo "run upload-spark-jobs-to-minio.sh")"

# 4. MinIO has nyc-taxi data (nyc_taxi DAG needs this)
nyc_count=$(kubectl run minio-check2 --rm -i --restart=Never -n "$NAMESPACE" \
  --image=python:3.11-slim \
  --overrides='{"spec":{"containers":[{"name":"c","image":"python:3.11-slim","command":["/bin/sh","-c"],"args":["pip install -q boto3 && python3 -c \"import os,boto3; s3=boto3.client(\\\"s3\\\",endpoint_url=os.environ[\\\"E\\\"],aws_access_key_id=\\\"minioadmin\\\",aws_secret_access_key=\\\"minioadmin\\\"); objs=s3.list_objects_v2(Bucket=\\\"nyc-taxi\\\",Prefix=\\\"raw/\\\") or {}; print(len([x for x in objs.get(\\\"Contents\\\",[]) if x[\\\"Key\\\"].endswith(\\\".parquet\\\")]))\""],"env":[{"name":"E","value":"http://minio.'"$NAMESPACE"'.svc.cluster.local:9000"}]}]}}' \
  2>/dev/null | grep -oE '^[0-9]+$' | tail -1 || echo "0")
nyc_count="${nyc_count:-0}"
check "NYC Taxi data in MinIO (nyc-taxi/raw/*.parquet, got $nyc_count)" "$([[ "${nyc_count:-0}" -ge 4 ]] && echo ok || echo "run upload-nyc-taxi-sample.sh")"

# 5. Citibike data (optional — DAG/notebook use synthetic fallback if missing)
citibike_count=$(kubectl run minio-check3 --rm -i --restart=Never -n "$NAMESPACE" \
  --image=python:3.11-slim \
  --overrides='{"spec":{"containers":[{"name":"c","image":"python:3.11-slim","command":["/bin/sh","-c"],"args":["pip install -q boto3 && python3 -c \"import os,boto3; s3=boto3.client(\\\"s3\\\",endpoint_url=os.environ[\\\"E\\\"],aws_access_key_id=\\\"minioadmin\\\",aws_secret_access_key=\\\"minioadmin\\\"); objs=s3.list_objects_v2(Bucket=\\\"citibike\\\",Prefix=\\\"raw/\\\") or {}; print(len([x for x in objs.get(\\\"Contents\\\",[]) if x[\\\"Key\\\"].endswith(\\\".parquet\\\")]))\""],"env":[{"name":"E","value":"http://minio.'"$NAMESPACE"'.svc.cluster.local:9000"}]}]}}' \
  2>/dev/null | grep -oE '^[0-9]+$' | tail -1 || echo "0")
citibike_count="${citibike_count:-0}"
[[ "$QUIET" != "--quiet" ]] && echo "  INFO: Citibike data (citibike/raw/*.parquet, got $citibike_count) — optional, run upload-citibike-sample.sh for real data"

echo ""
if [[ $FAILURES -gt 0 ]]; then
  echo "DEMO DECORATION ONLY: $FAILURES check(s) failed — nothing works when you click"
  echo "Fix: deploy, upload-spark-jobs, upload-nyc-taxi-sample, start-ui-portforwards"
  echo "See: docs/reports/demo-reality-2026-03-06.md"
  exit 1
else
  echo "DEMO USABLE: UI reachable, data present"
fi
