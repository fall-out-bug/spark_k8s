#!/usr/bin/env bash
# WS-031-04: Generate metrics.json from INDEX and completed/
set -euo pipefail

INDEX="${1:-docs/workstreams/INDEX.md}"
COMPLETED_DIR="${2:-docs/workstreams/completed}"
OUTPUT="${3:-docs/metrics.json}"

TOTAL_WS=$(grep -cE '^\| WS-[0-9]+-[0-9]+ \|' "$INDEX" 2>/dev/null || echo 0)
COMPLETED_WS=$(find "$COMPLETED_DIR" -name 'WS-*.md' 2>/dev/null | wc -l)
PCT=$([ "$TOTAL_WS" -gt 0 ] && echo $((COMPLETED_WS * 100 / TOTAL_WS)) || echo 0)

# Extract summary table for per-feature
awk '
  /^## Summary$/ { in_summary=1; next }
  in_summary && /^---$/ { exit }
  in_summary && /^\| [* ]*F[0-9]+:|^\| TESTING:/ {
    gsub(/\|/, "|"); n=split($0,a,"|");
    feat=a[2]; gsub(/^ *| *$/, "", feat);
    tot=a[3]; gsub(/^ *| *$/, "", tot);
    done=a[4]; gsub(/^ *| *$/, "", done);
    if (feat !~ /^---$/ && feat !~ /TOTAL/ && feat != "") print feat"|"tot"|"done
  }
' "$INDEX" > /tmp/feat_table.txt 2>/dev/null || true

{
  echo '{'
  echo "  \"generated_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
  echo "  \"total_ws\": $TOTAL_WS,"
  echo "  \"completed_ws\": $COMPLETED_WS,"
  echo "  \"completion_pct\": $PCT,"
  echo "  \"features\": ["
  first=1
  while IFS='|' read -r feat tot done; do
    [ -z "$feat" ] && continue
    tot=$(echo "$tot" | tr -d ' *+')
    done=$(echo "$done" | tr -d ' *')
    tot=${tot:-0}; done=${done:-0}
    [ "$tot" -gt 0 ] 2>/dev/null || tot=0
    [ "$done" -gt 0 ] 2>/dev/null || done=0
    pct=$([ "$tot" -gt 0 ] && echo $((done * 100 / tot)) || echo 0)
    [ $first -eq 0 ] && echo ","
    echo -n "    {\"id\": \"$feat\", \"total\": $tot, \"completed\": $done, \"pct\": $pct}"
    first=0
  done < /tmp/feat_table.txt 2>/dev/null || true
  echo ""
  echo "  ]"
  echo '}'
} > "$OUTPUT"

echo "Generated $OUTPUT (completed: $COMPLETED_WS/$TOTAL_WS = ${PCT}%)"
