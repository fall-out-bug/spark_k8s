#!/bin/bash
# Generate metrics reference from Prometheus
# Usage: generate-metrics-reference.sh [prometheus-url]

set -euo pipefail

PROMETHEUS_URL="${1:-http://localhost:9090}"
OUTPUT="${2:-docs/reference/metrics-reference.md}"

echo "# Metrics Reference (Auto-generated)" > "$OUTPUT"
echo "" >> "$OUTPUT"
echo "Run \`curl -s $PROMETHEUS_URL/api/v1/label/__name__/values\` for full list." >> "$OUTPUT"
echo "" >> "$OUTPUT"
echo "Spark metrics prefix: \`spark_\`" >> "$OUTPUT"
