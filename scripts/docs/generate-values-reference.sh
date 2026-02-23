#!/usr/bin/env bash
# Generate values reference from Helm chart (WS-019-13).
# Usage: ./scripts/docs/generate-values-reference.sh [chart-path]
# Default chart: charts/spark-3.5

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CHART_PATH="${1:-$REPO_ROOT/charts/spark-3.5}"
OUTPUT_DIR="$REPO_ROOT/docs/reference"
CHART_NAME=$(basename "$CHART_PATH")
OUTPUT_FILE="$OUTPUT_DIR/${CHART_NAME}-defaults.md"

cd "$REPO_ROOT"

if ! helm show values "$CHART_PATH" &>/dev/null; then
  echo "Error: helm show values failed for $CHART_PATH" >&2
  exit 1
fi

CHART_VERSION=$(helm show chart "$CHART_PATH" 2>/dev/null | grep '^version:' | sed 's/version: *//' || echo "0.2.0")
APP_VERSION=$(helm show chart "$CHART_PATH" 2>/dev/null | grep '^appVersion:' | sed 's/appVersion: *//' || echo "3.5.7")

mkdir -p "$OUTPUT_DIR"

{
  echo "# $CHART_NAME — Default Values"
  echo ""
  echo "Generated from chart \`$CHART_PATH\` (version $CHART_VERSION, appVersion $APP_VERSION)."
  echo "Run \`scripts/docs/generate-values-reference.sh [chart-path]\` to regenerate."
  echo ""
  echo "## Full default values (helm show values)"
  echo ""
  echo '```yaml'
  helm show values "$CHART_PATH"
  echo '```'
} > "$OUTPUT_FILE.tmp"

mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"
echo "Wrote $OUTPUT_FILE"
