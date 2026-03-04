#!/bin/bash
# Send budget alert to Slack/email
# Usage: send-budget-alert.sh [--period daily|weekly|monthly] [--slack-url URL]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PERIOD="${PERIOD:-daily}"
SLACK_URL="${SLACK_WEBHOOK_URL:-}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --period) PERIOD="$2"; shift 2 ;;
        --slack-url) SLACK_URL="$2"; shift 2 ;;
        *) echo "Unknown: $1"; exit 1 ;;
    esac
done

# Run check-budget
"$SCRIPT_DIR/check-budget.sh" --period "$PERIOD" --output /tmp/budget-status.json 2>&1 || true

# If Slack webhook configured, send alert
if [[ -n "$SLACK_URL" ]] && [[ -f /tmp/budget-status.json ]]; then
    STATUS=$(jq -r '.teams[0].status // "OK"' /tmp/budget-status.json 2>/dev/null || echo "OK")
    if [[ "$STATUS" != "OK" ]]; then
        curl -sS -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"Budget alert: $STATUS for period $PERIOD\"}" \
            "$SLACK_URL" || true
    fi
fi

echo "Budget check complete: $PERIOD"
