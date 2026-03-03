#!/usr/bin/env bash
# Close beads for scenarios that PASSed in run-matrix output
# Usage: ./scripts/close-matrix-beads-from-log.sh /tmp/matrix-gpu-false.log

set -euo pipefail
LOG="${1:-}"
if [[ -z "$LOG" || ! -f "$LOG" ]]; then
  echo "Usage: $0 <matrix-log-file>"
  exit 1
fi

grep '\[PASS\]' "$LOG" 2>/dev/null | grep -oE 'SCENARIO-[0-9]+' | sort -u | while read -r sid; do
  bead=$(bd search "$sid" 2>/dev/null | tail -1 | awk '{print $1}')
  if [[ -n "$bead" && "$bead" == spark_k8s-* ]]; then
    if bd close "$bead" --reason "Smoke passed (matrix run)" 2>/dev/null; then
      echo "Closed $bead ($sid)"
    fi
  fi
done
