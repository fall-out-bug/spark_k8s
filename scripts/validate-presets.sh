#!/usr/bin/env bash
# Validate all preset values files via helm template --dry-run
# Usage: scripts/validate-presets.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
cd "${PROJECT_DIR}"

echo "=== Validating preset values files ==="
echo ""

FAILED=0
PASSED=0

# Spark 4.1 presets
CHART_41="charts/spark-4.1"
if [[ -d "${CHART_41}" ]]; then
  echo "Chart: ${CHART_41}"
  for values_file in "${CHART_41}"/values-scenario-*.yaml; do
    if [[ -f "${values_file}" ]]; then
      echo -n "  Validating: $(basename "${values_file}")... "
      if helm template test "${CHART_41}" -f "${values_file}" --dry-run >/dev/null 2>&1; then
        echo "✅ PASSED"
        ((PASSED++))
      else
        echo "❌ FAILED"
        ((FAILED++))
      fi
    fi
  done
  echo ""
fi

# Spark 3.5 spark-connect presets
CHART_35_CONNECT="charts/spark-3.5/charts/spark-connect"
if [[ -d "${CHART_35_CONNECT}" ]]; then
  echo "Chart: ${CHART_35_CONNECT}"
  for values_file in "${CHART_35_CONNECT}"/values-scenario-*.yaml; do
    if [[ -f "${values_file}" ]]; then
      echo -n "  Validating: $(basename "${values_file}")... "
      if helm template test "${CHART_35_CONNECT}" -f "${values_file}" --dry-run >/dev/null 2>&1; then
        echo "✅ PASSED"
        ((PASSED++))
      else
        echo "❌ FAILED"
        ((FAILED++))
      fi
    fi
  done
  echo ""
fi

# Spark 3.5 spark-standalone presets
CHART_35_STANDALONE="charts/spark-3.5/charts/spark-standalone"
if [[ -d "${CHART_35_STANDALONE}" ]]; then
  echo "Chart: ${CHART_35_STANDALONE}"
  for values_file in "${CHART_35_STANDALONE}"/values-scenario-*.yaml; do
    if [[ -f "${values_file}" ]]; then
      echo -n "  Validating: $(basename "${values_file}")... "
      if helm template test "${CHART_35_STANDALONE}" -f "${values_file}" --dry-run >/dev/null 2>&1; then
        echo "✅ PASSED"
        ((PASSED++))
      else
        echo "❌ FAILED"
        ((FAILED++))
      fi
    fi
  done
  echo ""
fi

echo "=== Summary ==="
echo "✅ Passed: ${PASSED}"
echo "❌ Failed: ${FAILED}"

if [[ ${FAILED} -gt 0 ]]; then
  exit 1
fi

echo "=== All presets validated successfully ==="
