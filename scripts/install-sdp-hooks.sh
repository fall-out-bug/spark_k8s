#!/bin/sh
# Install SDP Git hooks for spark_k8s.
# Run after: git submodule update --remote .sdp
# Symlinks: pre-commit, pre-push (from scripts/hooks), commit-msg (from .sdp/hooks).
# Copies config/sdp-config.yml to .sdp/config.yml if present.
set -e

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

# Copy project SDP config if present
if [ -f config/sdp-config.yml ] && [ -d .sdp ]; then
  cp config/sdp-config.yml .sdp/config.yml
  echo "Copied config/sdp-config.yml -> .sdp/config.yml"
fi

echo "Installing SDP Git hooks..."

# 1. Run SDP install (uses scripts/hooks for pre-commit, pre-push)
if [ -f .sdp/hooks/install-git-hooks.sh ]; then
  sh .sdp/hooks/install-git-hooks.sh
else
  echo "WARN: .sdp/hooks/install-git-hooks.sh not found (run: git submodule update --init .sdp)" >&2
fi

# 2. Install commit-msg (SDP provenance trailers)
HOOKS_DIR="$ROOT/.git/hooks"
if [ -f .sdp/hooks/commit-msg.sh ]; then
  ln -sf "../../.sdp/hooks/commit-msg.sh" "$HOOKS_DIR/commit-msg"
  chmod +x .sdp/hooks/commit-msg.sh
  echo "Installed commit-msg"
fi

echo "Done. Hooks: pre-commit, pre-push (scripts/hooks), commit-msg (.sdp/hooks)"
