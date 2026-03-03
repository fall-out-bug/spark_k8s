#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PID_DIR="$ROOT_DIR/tests/observability/.pf"

if [[ ! -d "$PID_DIR" ]]; then
  echo "No port-forward PID directory found"
  exit 0
fi

for pid_file in "$PID_DIR"/*.pid; do
  [[ -e "$pid_file" ]] || continue
  pid="$(cat "$pid_file")"
  name="$(basename "$pid_file" .pid)"
  if kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
    echo "[stopped] $name"
  fi
  rm -f "$pid_file"
done
