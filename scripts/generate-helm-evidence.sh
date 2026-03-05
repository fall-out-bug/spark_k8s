#!/usr/bin/env bash
set -euo pipefail
# Generate helm template snapshots for all 5 deploy modes.
# Usage: ./scripts/generate-helm-evidence.sh [baseline|final]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CHART="${PROJECT_ROOT}/charts/spark-3.5"
PHASE="${1:-baseline}"
OUT="${PROJECT_ROOT}/tests/evidence/${PHASE}"

mkdir -p "$OUT"

COMMON=(
  --set global.s3.accessKey=x
  --set global.s3.secretKey=x
  --set global.postgresql.password=x
)

echo "Generating ${PHASE} evidence snapshots..."

# 1. connect-k8s (default: connect only)
helm template evidence-ck "$CHART" \
  --set connect.enabled=true \
  "${COMMON[@]}" \
  > "$OUT/connect-k8s.yaml"
echo "  connect-k8s: $(grep -c '^kind:' "$OUT/connect-k8s.yaml") resources"

# 2. connect-sa (connect + standalone)
helm template evidence-cs "$CHART" \
  --set connect.enabled=true \
  --set standalone.enabled=true \
  --set standalone.image.repository=spark-custom --set standalone.image.tag=3.5.7 \
  --set connect.image.repository=spark-custom --set connect.image.tag=3.5.7 \
  "${COMMON[@]}" \
  > "$OUT/connect-sa.yaml"
echo "  connect-sa: $(grep -c '^kind:' "$OUT/connect-sa.yaml") resources"

# 3. k8s-native
helm template evidence-kn "$CHART" \
  --set connect.enabled=false \
  --set kubernetes.enabled=true \
  "${COMMON[@]}" \
  > "$OUT/k8s-native.yaml"
echo "  k8s-native: $(grep -c '^kind:' "$OUT/k8s-native.yaml") resources"

# 4. standalone only
helm template evidence-sa "$CHART" \
  --set connect.enabled=false \
  --set standalone.enabled=true \
  --set standalone.image.repository=spark-custom --set standalone.image.tag=3.5.7 \
  "${COMMON[@]}" \
  > "$OUT/standalone.yaml"
echo "  standalone: $(grep -c '^kind:' "$OUT/standalone.yaml") resources"

# 5. demo (full preset)
helm template evidence-demo "$CHART" \
  -f "${CHART}/presets/demo-full-spark-infra.yaml" \
  --set spark-base.postgresql.auth.password=x \
  > "$OUT/demo.yaml"
echo "  demo: $(grep -c '^kind:' "$OUT/demo.yaml") resources"

echo ""
echo "Evidence saved to: $OUT/"
echo "Files:"
ls -la "$OUT/"
