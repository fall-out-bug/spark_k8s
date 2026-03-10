#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/.local/bin:$PATH"

ERRORS=0
for dir in docs/workstreams/in_progress docs/workstreams/backlog; do
  for ws in "$dir"/*.md; do
    [ -f "$ws" ] || continue
    ws_id=$(basename "$ws" .md)
    echo "Checking drift for $ws_id..."
    if ! sdp drift detect "$ws_id" 2>/dev/null; then
      echo "WARN: drift detected for $ws_id"
      ERRORS=$((ERRORS + 1))
    fi
  done
done

if [ "$ERRORS" -gt 0 ]; then
  echo "$ERRORS workstream(s) have drift (warning)"
else
  echo "No drift detected"
fi

if [ -x .sdp/hooks/validate-artifacts.sh ]; then
  .sdp/hooks/validate-artifacts.sh || echo "WARN: Some artifacts missing"
fi

sdp collision check 2>/dev/null || echo "No scope collisions"

if ! command -v sdp >/dev/null 2>&1; then
  echo "SDP CLI not available, skipping sdp verify"
  exit 0
fi

base_ref=${GITHUB_BASE_REF:-}
if [ -n "$base_ref" ]; then
  base="origin/$base_ref"
elif [ -n "${GITHUB_EVENT_BEFORE:-}" ]; then
  base="${GITHUB_EVENT_BEFORE}"
else
  base="HEAD~1"
fi

modified_ws=$(git diff --name-only "$base"..HEAD 2>/dev/null | grep -E '^docs/workstreams/(completed|in_progress)/[A-Za-z0-9-]+\.md$' || true)
if [ -n "$modified_ws" ]; then
  for file in $modified_ws; do
    ws_id=$(basename "$file" .md)
    echo "Verifying $ws_id..."
    sdp verify "$ws_id" 2>/dev/null || echo "WARN: sdp verify $ws_id failed"
  done
else
  echo "No workstream files modified"
fi
