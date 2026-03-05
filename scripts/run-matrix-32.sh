#!/usr/bin/env bash
# Run 32 scenarios: 4 spark × 2 connect × 2 k8s_mode × 2 platform
# Minimal config: gpu=false, iceberg=false, shuffle=false, openlineage=false
# Usage: ./run-matrix-32.sh [--shared-infra] [--dry-run] [deploy|smoke|e2e|load|all]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARED=""
DRY=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --shared-infra) SHARED="--shared-infra"; shift ;;
        --dry-run) DRY="--dry-run"; shift ;;
        *) break ;;
    esac
done
LEVELS="${*:-all}"

exec "$SCRIPT_DIR/run-matrix.sh" \
    --filter "gpu=false,iceberg=false,shuffle_service=false,openlineage=false" \
    $SHARED $DRY \
    $LEVELS
