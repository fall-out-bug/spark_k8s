#!/bin/sh
# SDP-compatible pre-commit for spark_k8s (Python/Helm project).
# Runs: sdp guard check (if active), pre-commit framework, ws-verdict validation.
# CWD = repo root.

set -e

echo "🔍 Pre-commit checks..."

# SDP guard: when scope is active, verify staged files are in scope
if command -v sdp >/dev/null 2>&1; then
  if sdp guard status 2>/dev/null | grep -qi "active"; then
    sdp guard check --staged 2>/dev/null || { echo "pre-commit: sdp guard check failed (staged files out of scope)" >&2; exit 1; }
  fi
fi

if command -v pre-commit >/dev/null 2>&1; then
    pre-commit run || { echo "pre-commit: failed" >&2; exit 1; }
else
    echo "⚠️  pre-commit not installed, running ruff only"
    if command -v ruff >/dev/null 2>&1; then
        ruff check . --exclude "dags" --exclude "docker" --exclude "notebooks" --exclude ".sdp" || exit 1
    else
        echo "ruff not found. Install: pip install ruff" >&2
        exit 1
    fi
fi

# ws-verdict validation (SDP) when docs/ws-verdicts/*.json changed
if git diff --cached --name-only | grep -q '^docs/ws-verdicts/.*\.json$'; then
    if [ -f ./scripts/hooks/validate-ws-verdicts.sh ]; then
        sh ./scripts/hooks/validate-ws-verdicts.sh || { echo "pre-commit: ws-verdict validation failed" >&2; exit 1; }
    fi
fi

echo "✅ Pre-commit passed"
exit 0
