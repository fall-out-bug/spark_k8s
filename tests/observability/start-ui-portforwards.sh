#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PID_DIR="$ROOT_DIR/tests/observability/.pf"
LOG_DIR="$ROOT_DIR/tests/observability/.pf-logs"

mkdir -p "$PID_DIR" "$LOG_DIR"

start_pf() {
  local name="$1"
  local namespace="$2"
  local target="$3"
  local local_port="$4"
  local remote_port="$5"

  local pid_file="$PID_DIR/${name}.pid"
  local log_file="$LOG_DIR/${name}.log"

  if [[ -f "$pid_file" ]] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
    echo "[skip] $name already running on :$local_port"
    return
  fi

  nohup kubectl port-forward --address 0.0.0.0 -n "$namespace" "$target" "$local_port:$remote_port" >"$log_file" 2>&1 &
  echo $! >"$pid_file"
  sleep 1
  if kill -0 "$(cat "$pid_file")" 2>/dev/null; then
    echo "[ok] $name -> localhost:$local_port"
  else
    echo "[fail] $name (see $log_file)"
    rm -f "$pid_file"
  fi
}

start_pf "airflow" "spark-infra" "svc/spark-infra-spark-standalone-airflow-webserver" "18080" "8080"
start_pf "jupyter" "spark-infra" "svc/spark-shared-spark-35-jupyter" "18888" "8888"
start_pf "grafana" "observability" "svc/grafana" "13000" "3000"
start_pf "history" "spark-infra" "svc/spark-shared-spark-35-history" "18081" "18080"
start_pf "prometheus" "observability" "svc/prometheus" "19090" "9090"
start_pf "spark-master" "spark-infra" "svc/spark-infra-spark-standalone-master" "18082" "8080"
start_pf "minio-api" "spark-infra" "svc/minio" "19000" "9000"
start_pf "minio-console" "spark-infra" "svc/minio" "19001" "9001"

echo ""
echo "UI URLs (host-local):"
echo "- Airflow:     http://localhost:18080"
echo "- Jupyter:     http://localhost:18888/lab"
echo "- Grafana:     http://localhost:13000/login"
echo "- History:     http://localhost:18081"
echo "- Spark Master: http://localhost:18082"
echo "- Prometheus:  http://localhost:19090"
echo "- MinIO:       http://localhost:19001"
