#!/usr/bin/env bash
# Test script for RAPIDS JARs intermediate layer

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly IMAGE_NAME="${IMAGE_NAME:-spark-k8s-jars-rapids:3.5.7}"

echo "=========================================="
echo "Testing RAPIDS JARs Layer"
echo "=========================================="
echo "Image: $IMAGE_NAME"
echo ""

# Run the RAPIDS-specific test script
"${SCRIPT_DIR}/../test-jars-rapids.sh" "$IMAGE_NAME"
