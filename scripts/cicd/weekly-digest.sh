#!/usr/bin/env bash
# WS-031-03: Generate weekly progress digest
# Outputs JSON-like summary for Telegram post
set -euo pipefail

REPO_ROOT="${1:-.}"
cd "$REPO_ROOT"

# Files added to completed/ in last 7 days
FILES=$(git log --since="7 days ago" --diff-filter=A --name-only --pretty=format: -- docs/workstreams/completed/*.md 2>/dev/null | sort -u) || true

if [ -z "$FILES" ]; then
  echo "count=0"
  echo "No workstreams completed in the past 7 days." > "${DIGEST_OUTPUT:-/tmp/digest_body.txt}"
  exit 0
fi

BUF=""
for f in $FILES; do
  [ -f "$f" ] || continue
  WS_ID=$(grep -E '^ws_id:' "$f" 2>/dev/null | head -1 | sed 's/ws_id:[[:space:]]*//' | tr -d '\r')
  FEATURE=$(grep -E '^feature:' "$f" 2>/dev/null | head -1 | sed 's/feature:[[:space:]]*//' | tr -d '\r')
  TITLE=$(grep -E '^## WS-' "$f" 2>/dev/null | head -1 | sed 's/^## WS-[^:]*:[[:space:]]*//' | tr -d '\r')
  BUF="${BUF}• WS-${WS_ID} (${FEATURE}): ${TITLE}\n"
done

COUNT=$(echo "$FILES" | wc -w)
START=$(date -u -d "7 days ago" +%Y-%m-%d 2>/dev/null || date -u -v-7d +%Y-%m-%d)
END=$(date -u +%Y-%m-%d)

REPO="${GITHUB_REPOSITORY:-fall-out-bug/spark_k8s}"
BRANCH="${GITHUB_REF_NAME:-main}"
BODY="📋 Spark K8s Weekly Digest (${START} → ${END})

${COUNT} workstream(s) completed:
${BUF}

📊 ROADMAP: https://github.com/${REPO}/blob/${BRANCH}/ROADMAP.md"

echo "count=$COUNT"
echo "$BODY" > "${DIGEST_OUTPUT:-/tmp/digest_body.txt}"
