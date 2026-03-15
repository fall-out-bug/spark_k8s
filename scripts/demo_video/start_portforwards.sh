#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PID_DIR="${ROOT_DIR}/assets/demo_video_generated/.pf"
LOG_DIR="${ROOT_DIR}/assets/demo_video_generated/.pf-logs"

mkdir -p "$PID_DIR" "$LOG_DIR"

resolve_target() {
  local namespace="$1"
  shift
  local candidate
  for candidate in "$@"; do
    if kubectl get "$candidate" -n "$namespace" >/dev/null 2>&1; then
      printf '%s' "$candidate"
      return 0
    fi
  done
  return 1
}

start_pf() {
  local name="$1"
  local namespace="$2"
  local local_port="$3"
  local remote_port="$4"
  shift 4
  local pid_file="$PID_DIR/${name}.pid"
  local log_file="$LOG_DIR/${name}.log"

  if [[ -f "$pid_file" ]] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
    echo "[skip] $name already running on :$local_port"
    return 0
  fi

  local target
  target=$(resolve_target "$namespace" "$@") || {
    echo "[fail] $name: no matching service in namespace $namespace" >&2
    return 1
  }

  nohup kubectl port-forward --address 127.0.0.1 -n "$namespace" "$target" "$local_port:$remote_port" >"$log_file" 2>&1 &
  echo $! >"$pid_file"
  sleep 1
  if kill -0 "$(cat "$pid_file")" 2>/dev/null; then
    echo "[ok] $name -> localhost:$local_port ($target)"
  else
    if grep -q "address already in use" "$log_file" 2>/dev/null; then
      echo "[skip] $name already bound on :$local_port"
      rm -f "$pid_file"
      return 0
    fi
    echo "[fail] $name (see $log_file)" >&2
    rm -f "$pid_file"
    return 1
  fi
}

start_pf "airflow" "spark-infra" 18080 8080 svc/spark-infra-airflow-webserver svc/spark-infra-standalone-airflow-webserver
start_pf "jupyter" "spark-infra" 18888 8888 svc/spark-infra-spark-35-jupyter svc/spark-infra-spark-41-jupyter
start_pf "history" "spark-infra" 18081 18080 svc/spark-infra-spark-35-history svc/spark-infra-spark-41-history
start_pf "spark-master" "spark-infra" 18082 8080 svc/spark-infra-standalone-master
start_pf "grafana" "observability" 13000 3000 svc/observability-demo-grafana svc/grafana
start_pf "prometheus" "observability" 19090 9090 svc/observability-demo-prometh-prometheus svc/prometheus
start_pf "minio-api" "spark-infra" 19000 9000 svc/minio
start_pf "minio-console" "spark-infra" 19001 9001 svc/minio

echo
echo "UI URLs:"
echo "- Airflow:      http://127.0.0.1:18080"
echo "- Jupyter:      http://127.0.0.1:18888/lab"
echo "- History:      http://127.0.0.1:18081"
echo "- Spark Master: http://127.0.0.1:18082"
echo "- Grafana:      http://127.0.0.1:13000/login"
echo "- Prometheus:   http://127.0.0.1:19090"
echo "- MinIO:        http://127.0.0.1:19001"
