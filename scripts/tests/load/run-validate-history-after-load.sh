#!/bin/bash
# Validate History Server: after load, curl API and assert application listed.
# Env: NAMESPACE (required), RELEASE (required)
# Usage: NAMESPACE=spark-matrix-scenario-0009 RELEASE=scenario0009 ./run-validate-history-after-load.sh

set -euo pipefail

NAMESPACE="${NAMESPACE:?NAMESPACE required}"
RELEASE="${RELEASE:?RELEASE required}"
SHARED_INFRA_NS="${SHARED_INFRA_NS:-}"

if [[ -n "$SHARED_INFRA_NS" ]]; then
    HISTORY_URL="http://spark-infra-spark-35-history.${SHARED_INFRA_NS}.svc.cluster.local:18080/api/v1/applications"
else
    HISTORY_URL="http://${RELEASE}-history.${NAMESPACE}.svc.cluster.local:18080/api/v1/applications"
fi

count_apps() {
    python3 -c "
import json, sys
text = sys.stdin.read()
start = text.find('[')
end = text.rfind(']')
if start == -1 or end == -1 or end < start:
    print(0)
    raise SystemExit(0)
payload = text[start:end+1]
try:
    apps = json.loads(payload)
    print(len(apps) if isinstance(apps, list) else 0)
except Exception:
    print(0)
" 2>/dev/null
}

json=""
count=0
for _ in $(seq 1 12); do
    json=$(kubectl run "curl-history-$$" --rm -i --quiet --restart=Never -n "$NAMESPACE" \
        --image=curlimages/curl:latest \
        -- curl -sS "$HISTORY_URL" 2>/dev/null || echo "[]")

    if [[ -n "$json" ]]; then
        count=$(echo "$json" | count_apps || echo "0")
        if [[ "${count:-0}" -ge 1 ]]; then
            echo "HISTORY_VALIDATION_SUCCESS: $count application(s) in History Server"
            exit 0
        fi
    fi

    sleep 10
done

if [[ -z "$json" ]]; then
    echo "Failed to curl History Server at $HISTORY_URL"
else
    echo "History Server validation FAIL: expected >=1 application, got $count"
    echo "Response: $json"
fi
exit 1
