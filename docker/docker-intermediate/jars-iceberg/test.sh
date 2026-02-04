#!/usr/bin/env bash
# Test script for Iceberg JARs intermediate layer

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly IMAGE_NAME="${IMAGE_NAME:-spark-k8s-jars-iceberg:3.5.7}"

echo "=========================================="
echo "Testing Iceberg JARs Layer"
echo "=========================================="
echo "Image: $IMAGE_NAME"
echo ""

# Run the Iceberg-specific test script
"${SCRIPT_DIR}/../test-jars-iceberg.sh" "$IMAGE_NAME"
