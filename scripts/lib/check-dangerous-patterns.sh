#!/usr/bin/env bash
# Check staged files for dangerous patterns that could destroy the demo.
# Used as a pre-commit guard or standalone check.
# Exit 0 = safe, exit 1 = dangerous pattern found.
set -euo pipefail

DANGEROUS_PATTERNS=(
  'helm install spark-infra.*spark-standalone'
  'helm upgrade.*spark-infra.*spark-standalone'
  'helm install spark-shared.*-n spark-infra'
  'helm upgrade.*spark-shared.*-n spark-infra'
  'kubectl delete namespace spark-infra'
  'kubectl delete ns spark-infra'
  'helm uninstall spark-infra'
)

MODE="${1:-staged}"
FOUND=0

check_content() {
  local content="$1"
  for pattern in "${DANGEROUS_PATTERNS[@]}"; do
    if echo "$content" | grep -qP "$pattern"; then
      echo "DANGEROUS: Pattern found: $pattern"
      echo "$content" | grep -nP "$pattern" | head -3
      echo ""
      FOUND=1
    fi
  done
}

case "$MODE" in
  staged)
    diff_content=$(git diff --cached --diff-filter=ACMR 2>/dev/null || echo "")
    if [[ -n "$diff_content" ]]; then
      check_content "$diff_content"
    fi
    ;;
  all)
    for f in scripts/*.sh scripts/**/*.sh tests/*.sh; do
      [[ -f "$f" ]] || continue
      content=$(cat "$f")
      check_content "$content"
    done
    ;;
esac

if [[ $FOUND -gt 0 ]]; then
  echo "BLOCKED: Staged changes contain patterns that would destroy the demo."
  echo "If intentional, use --no-verify to bypass."
  exit 1
fi

exit 0
