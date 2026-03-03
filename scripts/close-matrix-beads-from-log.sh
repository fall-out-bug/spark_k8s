#!/usr/bin/env bash
# Close beads for scenarios that PASSed in run-matrix output
# Usage: $0 <log> [--skip-too]
# --skip-too: also close SKIP beads (image not built)

set -euo pipefail
LOG="${1:-}"
CLOSE_SKIP=false
[[ "${2:-}" == "--skip-too" ]] && CLOSE_SKIP=true
if [[ -z "$LOG" || ! -f "$LOG" ]]; then
  echo "Usage: $0 <matrix-log-file> [--skip-too]"
  exit 1
fi

close_bead() {
  local sid="$1" reason="$2"
  bead=$(bd search "$sid" 2>/dev/null | tail -1 | awk '{print $1}')
  if [[ -n "$bead" && "$bead" == spark_k8s-* ]]; then
    bd close "$bead" --reason "$reason" 2>/dev/null && echo "Closed $bead ($sid)" || true
  fi
}
grep '\[PASS\]' "$LOG" 2>/dev/null | grep -oE 'SCENARIO-[0-9]+' | sort -u | while read -r sid; do
  close_bead "$sid" "Smoke passed (matrix run)"
done
if [[ "$CLOSE_SKIP" == "true" ]]; then
  grep '\[SKIP\]' "$LOG" 2>/dev/null | grep -oE 'SCENARIO-[0-9]+' | sort -u | while read -r sid; do
    close_bead "$sid" "Skipped - image not built"
  done
fi
