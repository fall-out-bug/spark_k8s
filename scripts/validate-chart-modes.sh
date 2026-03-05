#!/usr/bin/env bash
# Validate helm template + helm lint for all deploy mode combinations.
# Runs 6 modes: connect-only, connect-standalone, kubernetes, standalone, demo, all-disabled.
# Exit code != 0 if any mode fails.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CHART="${PROJECT_ROOT}/charts/spark-3.5"
DEMO_PRESET="${CHART}/presets/demo-full-spark-infra.yaml"

FAILED=0
PASSED=0

validate_mode() {
  local name="$1"
  shift
  local args=("$@")

  echo -n "  ${name}: lint... "
  if ! helm lint "${CHART}" "${args[@]}" --quiet > /dev/null 2>&1; then
    echo "FAIL (lint)"
    FAILED=$((FAILED + 1))
    return
  fi

  echo -n "template... "
  local output
  output=$(helm template "test-mode" "${CHART}" "${args[@]}" 2>&1)
  local rc=$?

  if [[ $rc -ne 0 ]]; then
    echo "FAIL (template exit ${rc})"
    echo "${output}" | tail -3
    FAILED=$((FAILED + 1))
    return
  fi

  if [[ -z "${output}" ]]; then
    echo "FAIL (empty output)"
    FAILED=$((FAILED + 1))
    return
  fi

  local resource_count
  resource_count=$(echo "${output}" | grep -c "^kind:" || true)
  if [[ "${resource_count}" -eq 0 ]]; then
    echo "FAIL (0 resources)"
    FAILED=$((FAILED + 1))
    return
  fi

  echo "OK (${resource_count} resources)"
  PASSED=$((PASSED + 1))
}

S3_ARGS=(--set global.s3.accessKey=x --set global.s3.secretKey=x)

echo "=== Validating chart deploy modes ==="

validate_mode "connect-only" \
  --set connect.enabled=true \
  --set connect.image.repository=spark-custom --set connect.image.tag=3.5.7 \
  "${S3_ARGS[@]}"

validate_mode "connect-standalone" \
  --set connect.enabled=true --set standalone.enabled=true \
  --set connect.image.repository=spark-custom --set connect.image.tag=3.5.7 \
  --set standalone.image.repository=spark-custom --set standalone.image.tag=3.5.7 \
  "${S3_ARGS[@]}"

validate_mode "kubernetes" \
  --set kubernetes.enabled=true \
  --set kubernetes.image.repository=spark-custom --set kubernetes.image.tag=3.5.7 \
  "${S3_ARGS[@]}"

validate_mode "standalone" \
  --set standalone.enabled=true \
  --set standalone.image.repository=spark-custom --set standalone.image.tag=3.5.7 \
  "${S3_ARGS[@]}"

validate_mode "demo" \
  -f "${DEMO_PRESET}" \
  --set spark-base.postgresql.auth.password=x \
  "${S3_ARGS[@]}"

validate_mode "all-disabled" \
  "${S3_ARGS[@]}"

echo ""
echo "=== Results: ${PASSED} passed, ${FAILED} failed ==="

if [[ "${FAILED}" -gt 0 ]]; then
  exit 1
fi
