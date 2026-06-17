#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

./tests/observability/start-ui-portforwards.sh >/dev/null
./scripts/check-demo-health.sh
./scripts/validate-demo-reality.sh
