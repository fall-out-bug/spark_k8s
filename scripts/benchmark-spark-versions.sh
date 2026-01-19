#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${1:-spark-bench}"
DATA_SIZE="${2:-1gb}"

RELEASE_35="spark-35"
RELEASE_41="spark-41"

RESULTS_CSV="/tmp/benchmark-results.csv"
METRICS_CSV="/tmp/benchmark-metrics.csv"
REPORT_PATH="docs/testing/F04-performance-benchmark.md"

CREATED_NAMESPACE="false"

rows_for_size() {
  case "$1" in
    1gb) echo "1000000" ;;
    10gb) echo "10000000" ;;
    100gb) echo "100000000" ;;
    *) echo "1000000" ;;
  esac
}

history_service() {
  local release="$1"
  kubectl get svc -n "${NAMESPACE}" \
    -l app=spark-history-server,app.kubernetes.io/instance="${release}" \
    -o jsonpath='{.items[0].metadata.name}'
}

get_app_id() {
  local service="$1"
  local app_name="$2"
  local port="$3"
  local pf_pid=""

  kubectl port-forward "svc/${service}" "${port}:18080" -n "${NAMESPACE}" >/dev/null 2>&1 &
  pf_pid=$!
  sleep 3

  local apps
  apps=$(curl -s "http://localhost:${port}/api/v1/applications" || echo "[]")

  kill "${pf_pid}" 2>/dev/null || true
  wait "${pf_pid}" 2>/dev/null || true

  APP_ID=$(APP_NAME="${app_name}" python3 -c \
    'import json,os,sys; name=os.environ["APP_NAME"]; apps=json.load(sys.stdin); apps=[a for a in apps if a.get("name")==name]; \
     apps=sorted(apps, key=lambda a: a.get("startTime","")); print(apps[-1]["id"] if apps else "")' \
    <<<"${apps}" 2>/dev/null || echo "")

  echo "${APP_ID}"
}

extract_metrics() {
  local service="$1"
  local app_id="$2"
  local port="$3"
  local version="$4"

  kubectl port-forward "svc/${service}" "${port}:18080" -n "${NAMESPACE}" >/dev/null 2>&1 &
  local pf_pid=$!
  sleep 3

  local stages
  local executors
  stages=$(curl -s "http://localhost:${port}/api/v1/applications/${app_id}/stages" || echo "[]")
  executors=$(curl -s "http://localhost:${port}/api/v1/applications/${app_id}/executors" || echo "[]")

  kill "${pf_pid}" 2>/dev/null || true
  wait "${pf_pid}" 2>/dev/null || true

  python3 - <<PY >> "${METRICS_CSV}"
import json,sys
stages = json.loads("""${stages}""")
executors = json.loads("""${executors}""")
shuffle_read = sum(s.get("shuffleReadBytes", 0) for s in stages)
shuffle_write = sum(s.get("shuffleWriteBytes", 0) for s in stages)
peak_mem = 0
for ex in executors:
    mem = ex.get("memoryUsed", 0)
    if isinstance(mem, int) and mem > peak_mem:
        peak_mem = mem
print(f"{version},{app_id},{shuffle_read},{shuffle_write},{peak_mem}")
PY
}

run_query() {
  local version="$1"
  local query="$2"
  local rows="$3"
  local app_name="$4"

  local start_ns end_ns elapsed_ms
  start_ns=$(date +%s%N)

  kubectl run "benchmark-${version}-${query}" \
    --image="spark-custom:${version}" \
    --restart=Never \
    --rm -i -n "${NAMESPACE}" \
    --env="AWS_ACCESS_KEY_ID=minioadmin" \
    --env="AWS_SECRET_ACCESS_KEY=minioadmin" \
    -- /opt/spark/bin/spark-sql \
    --conf spark.app.name="${app_name}" \
    --conf spark.eventLog.enabled=true \
    --conf spark.eventLog.dir="s3a://spark-logs/${version}/events" \
    --conf spark.hadoop.fs.s3a.endpoint=http://minio:9000 \
    --conf spark.hadoop.fs.s3a.path.style.access=true \
    --conf spark.sql.shuffle.partitions=200 \
    -e "${QUERY_SQL}"

  end_ns=$(date +%s%N)
  elapsed_ms=$(( (end_ns - start_ns) / 1000000 ))
  echo "${version},${query},${elapsed_ms}" >> "${RESULTS_CSV}"
}

cleanup() {
  helm uninstall "${RELEASE_35}" -n "${NAMESPACE}" >/dev/null 2>&1 || true
  helm uninstall "${RELEASE_41}" -n "${NAMESPACE}" >/dev/null 2>&1 || true
  if [[ "${CREATED_NAMESPACE}" == "true" ]]; then
    kubectl delete namespace "${NAMESPACE}" >/dev/null 2>&1 || true
  fi
}

trap cleanup EXIT

if [[ "${NAMESPACE}" == "default" ]]; then
  echo "ERROR: Use a non-default namespace for benchmarks."
  exit 1
fi

echo "=== Spark Performance Benchmark ==="
echo "Data size: ${DATA_SIZE}"

ROWS=$(rows_for_size "${DATA_SIZE}")
mkdir -p "$(dirname "${REPORT_PATH}")"
echo "version,query,elapsed_ms" > "${RESULTS_CSV}"
echo "version,app_id,shuffle_read,shuffle_write,peak_mem" > "${METRICS_CSV}"

if ! kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1; then
  kubectl create namespace "${NAMESPACE}" >/dev/null
  CREATED_NAMESPACE="true"
fi

echo "1) Deploying Spark 3.5.7 history server..."
helm install "${RELEASE_35}" charts/spark-3.5 \
  --namespace "${NAMESPACE}" \
  --set spark-standalone.enabled=true \
  --set spark-standalone.historyServer.enabled=true \
  --wait --timeout=5m

echo "2) Deploying Spark 4.1.0 history server..."
helm install "${RELEASE_41}" charts/spark-4.1 \
  --namespace "${NAMESPACE}" \
  --set connect.enabled=false \
  --set hiveMetastore.enabled=false \
  --set historyServer.enabled=true \
  --wait --timeout=5m

QUERY_SQL="SELECT COUNT(*) FROM range(0, ${ROWS})"
run_query "3.5.7" "count" "${ROWS}" "bench-35-count"
run_query "4.1.0" "count" "${ROWS}" "bench-41-count"

QUERY_SQL="SELECT id % 100 AS k, COUNT(*) AS c FROM range(0, ${ROWS}) GROUP BY k"
run_query "3.5.7" "groupby" "${ROWS}" "bench-35-groupby"
run_query "4.1.0" "groupby" "${ROWS}" "bench-41-groupby"

QUERY_SQL="SELECT COUNT(*) FROM range(0, ${ROWS}) a JOIN range(0, ${ROWS}) b ON a.id = b.id"
run_query "3.5.7" "join" "${ROWS}" "bench-35-join"
run_query "4.1.0" "join" "${ROWS}" "bench-41-join"

SVC_35=$(history_service "${RELEASE_35}")
SVC_41=$(history_service "${RELEASE_41}")

APP_ID_35_COUNT=$(get_app_id "${SVC_35}" "bench-35-count" 18081)
APP_ID_41_COUNT=$(get_app_id "${SVC_41}" "bench-41-count" 18082)
APP_ID_35_GROUP=$(get_app_id "${SVC_35}" "bench-35-groupby" 18081)
APP_ID_41_GROUP=$(get_app_id "${SVC_41}" "bench-41-groupby" 18082)
APP_ID_35_JOIN=$(get_app_id "${SVC_35}" "bench-35-join" 18081)
APP_ID_41_JOIN=$(get_app_id "${SVC_41}" "bench-41-join" 18082)

extract_metrics "${SVC_35}" "${APP_ID_35_COUNT}" 18081 "3.5.7"
extract_metrics "${SVC_41}" "${APP_ID_41_COUNT}" 18082 "4.1.0"
extract_metrics "${SVC_35}" "${APP_ID_35_GROUP}" 18081 "3.5.7"
extract_metrics "${SVC_41}" "${APP_ID_41_GROUP}" 18082 "4.1.0"
extract_metrics "${SVC_35}" "${APP_ID_35_JOIN}" 18081 "3.5.7"
extract_metrics "${SVC_41}" "${APP_ID_41_JOIN}" 18082 "4.1.0"

echo "3) Generating benchmark report..."
cat > "${REPORT_PATH}" <<EOF
# Spark 4.1.0 Performance Benchmark

**Date:** $(date)
**Data Size:** ${DATA_SIZE}

## Query Execution Time (ms)

| Query | Spark 3.5.7 | Spark 4.1.0 | Delta (4.1.0 - 3.5.7) |
|-------|-------------|-------------|-----------------------|
$(python3 - <<PY
import csv
rows={}
with open("${RESULTS_CSV}") as f:
    r=csv.DictReader(f)
    for row in r:
        rows.setdefault(row["query"], {})[row["version"]] = int(row["elapsed_ms"])
for q in ["count","groupby","join"]:
    t35 = rows.get(q, {}).get("3.5.7", 0)
    t41 = rows.get(q, {}).get("4.1.0", 0)
    delta = t41 - t35
    print(f"| {q} | {t35} | {t41} | {delta} |")
PY)

## Shuffle + Memory Metrics

| Version | Shuffle Read (bytes) | Shuffle Write (bytes) | Peak Memory (bytes) |
|---------|----------------------|-----------------------|---------------------|
$(python3 - <<PY
import csv
totals={}
with open("${METRICS_CSV}") as f:
    r=csv.DictReader(f)
    for row in r:
        v=row["version"]
        totals.setdefault(v, {"read":0,"write":0,"mem":0})
        totals[v]["read"] += int(row["shuffle_read"])
        totals[v]["write"] += int(row["shuffle_write"])
        totals[v]["mem"] = max(totals[v]["mem"], int(row["peak_mem"]))
for v in ["3.5.7","4.1.0"]:
    t=totals.get(v, {"read":0,"write":0,"mem":0})
    print(f"| {v} | {t['read']} | {t['write']} | {t['mem']} |")
PY)

## Conclusion

- Spark 4.1.0 execution times compared to 3.5.7 are recorded above.
- Shuffle and memory metrics are captured from the History Server API.
EOF

echo "=== Benchmark complete ==="
