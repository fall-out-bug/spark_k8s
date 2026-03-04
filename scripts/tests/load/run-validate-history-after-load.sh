#!/bin/bash
# Validate History Server: after load, curl API and assert application listed.
# Env: NAMESPACE (required), RELEASE (required)
# Usage: NAMESPACE=spark-matrix-scenario-0009 RELEASE=scenario0009 ./run-validate-history-after-load.sh

set -euo pipefail

NAMESPACE="${NAMESPACE:?NAMESPACE required}"
RELEASE="${RELEASE:?RELEASE required}"

HISTORY_URL="http://${RELEASE}-history.${NAMESPACE}.svc.cluster.local:18080/api/v1/applications"

# Curl from within cluster (ephemeral pod)
json=$(kubectl run "curl-history-$$" --rm -i --restart=Never -n "$NAMESPACE" \
    --image=curlimages/curl:latest \
    -- curl -sS "$HISTORY_URL" 2>/dev/null || echo "[]")

if [[ -z "$json" ]]; then
    echo "Failed to curl History Server at $HISTORY_URL"
    exit 1
fi

# Parse and assert at least one application
count=$(echo "$json" | python3 -c "
import json, sys
try:
    apps = json.load(sys.stdin)
    if isinstance(apps, list):
        print(len(apps))
    else:
        print(0)
except Exception:
    print(0)
" 2>/dev/null || echo "0")

if [[ "${count:-0}" -lt 1 ]]; then
    echo "History Server validation FAIL: expected >=1 application, got $count"
    echo "Response: $json"
    exit 1
fi

echo "HISTORY_VALIDATION_SUCCESS: $count application(s) in History Server"
