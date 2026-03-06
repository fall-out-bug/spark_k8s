#!/bin/sh
# Commit-msg hook: conventional commits + SDP provenance trailers.
# CWD = repo root.

COMMIT_MSG_FILE="${1:?}"
COMMIT_MSG=$(cat "$COMMIT_MSG_FILE")

# Conventional commits: type(scope): description
PATTERN="^(feat|fix|docs|test|refactor|style|chore|perf|ci|build)(\([a-z0-9_-]+\))?: .{1,}"
MERGE_PATTERN="^Merge "
REVERT_PATTERN="^Revert "

FIRST_LINE=$(echo "$COMMIT_MSG" | grep -v "^Co-authored-by:" | head -1)

if echo "$FIRST_LINE" | grep -qE "$REVERT_PATTERN"; then
  exit 0
elif echo "$FIRST_LINE" | grep -qE "$PATTERN"; then
  exit 0
elif echo "$FIRST_LINE" | grep -qE "$MERGE_PATTERN"; then
  exit 0
fi

echo "Invalid commit message. Use: type(scope): description" >&2
echo "Types: feat, fix, docs, test, refactor, style, chore, perf, ci, build" >&2
exit 1
