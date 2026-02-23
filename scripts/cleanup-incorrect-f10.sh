#!/usr/bin/env bash
set -euo pipefail

# Cleanup script for incorrect F10 implementation
# Removes docker/docker-base/spark-core/ that used Apache distros

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
INCORRECT_DIR="${PROJECT_ROOT}/docker/docker-base/spark-core"

echo "=== F10 Cleanup Script ==="
echo "Project root: $PROJECT_ROOT"
echo ""

# Check if incorrect directory exists
if [ ! -d "$INCORRECT_DIR" ]; then
    echo "Directory does not exist (already cleaned?): $INCORRECT_DIR"
    echo "Nothing to do."
    exit 0
fi

# Show what will be deleted
echo "Contents to be removed:"
ls -la "$INCORRECT_DIR" || true
echo ""

# Confirm
read -p "Remove $INCORRECT_DIR ? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Removing..."
    rm -rf "$INCORRECT_DIR"
    echo "Done: Removed $INCORRECT_DIR"
else
    echo "Aborted."
    exit 1
fi

echo ""
echo "=== Cleanup Complete ==="
echo ""
echo "Next steps:"
echo "1. Execute WS-010-01 to create wrapper layers"
echo "2. Execute WS-010-02, WS-010-03, WS-010-04 in parallel"
