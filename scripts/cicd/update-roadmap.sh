#!/usr/bin/env bash
# WS-031-02: Generate ROADMAP.md from docs/workstreams/INDEX.md
set -euo pipefail

INDEX="${1:-docs/workstreams/INDEX.md}"
ROADMAP="${2:-ROADMAP.md}"

# Extract summary table from INDEX (between ## Summary and ---)
awk '
  /^## Summary$/ { in_summary=1; next }
  in_summary && /^---$/ { exit }
  in_summary && /^\| Feature \|/ { next }
  in_summary && /^\|---------/ { next }
  in_summary && /^\|/ { print; next }
' "$INDEX" > /tmp/roadmap_table.txt || true

{
  echo "# Spark K8s Roadmap"
  echo ""
  echo "Project progress by feature. Auto-generated from [docs/workstreams/INDEX.md](docs/workstreams/INDEX.md)."
  echo ""
  echo "| Feature | Total WS | Completed | In Progress | Backlog |"
  echo "|---------|----------|-----------|-------------|---------|"
  [ -s /tmp/roadmap_table.txt ] && cat /tmp/roadmap_table.txt || echo "| (no data) | 0 | 0 | 0 | 0 |"
  echo ""
  echo "_Last updated: $(date -u +%Y-%m-%d)_"
} > "$ROADMAP"

echo "Updated $ROADMAP"
