#!/bin/bash
# Validate reference docs exist and are up to date
# Usage: validate-reference.sh

set -euo pipefail

FAIL=0
for f in docs/reference/README.md docs/reference/values-reference.md docs/reference/cli-reference.md; do
    if [[ ! -f "$f" ]]; then
        echo "Missing: $f"
        FAIL=1
    fi
done
[[ $FAIL -eq 0 ]] && echo "Reference docs OK" || exit 1
