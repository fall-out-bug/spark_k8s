#!/usr/bin/env bash
# Smoke one matrix scenario with shared infra. Validates deploy + smoke pass.
# Usage: ./scripts/smoke-one-matrix-scenario.sh [SCENARIO_ID]
#   SCENARIO_ID defaults to SCENARIO-0036 (Connect+Standalone, no GPU)
# Prerequisites: deploy-shared-infra-minikube.sh, build-and-load-matrix-images.sh --quick

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCENARIO="${1:-SCENARIO-0036}"

echo "=== Smoke matrix scenario: $SCENARIO (shared-infra) ==="

# Pre-flight: shared infra must exist
if ! kubectl get namespace spark-infra &>/dev/null; then
  echo "ERROR: spark-infra namespace not found. Run: ./scripts/deploy-shared-infra-minikube.sh"
  exit 1
fi

if ! kubectl get svc -n spark-infra minio &>/dev/null; then
  echo "ERROR: MinIO not found in spark-infra. Run: ./scripts/deploy-shared-infra-minikube.sh"
  exit 1
fi

if ! kubectl get namespace observability &>/dev/null; then
  echo "WARN: observability namespace not found. Connect OTEL may fail. Run deploy-shared-infra-minikube.sh (it deploys observability)."
fi

echo "Shared infra OK. Running deploy + smoke..."
if ! "$SCRIPT_DIR/run-matrix.sh" --filter "id=$SCENARIO" --shared-infra deploy smoke; then
  echo "FAIL: $SCENARIO deploy or smoke failed"
  exit 1
fi

echo "PASS: $SCENARIO deploy + smoke succeeded"
