#!/usr/bin/env bash
# Build script for Python Dependencies intermediate layer

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly BASE_IMAGE="${BASE_IMAGE:-localhost/spark-k8s:3.5.7-hadoop3.4.2}"
readonly BUILD_GPU="${BUILD_GPU_DEPS:-false}"
readonly BUILD_ICEBERG="${BUILD_ICEBERG_DEPS:-false}"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

# Logging
log_info() { echo -e "${YELLOW}[INFO]${NC} $*"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $*"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $*"; }

# Determine tag suffix
TAG_SUFFIX=""
if [[ "$BUILD_GPU" == "true" ]]; then
    TAG_SUFFIX="-gpu"
fi
if [[ "$BUILD_ICEBERG" == "true" ]]; then
    TAG_SUFFIX="${TAG_SUFFIX}-iceberg"
fi

readonly IMAGE_NAME="spark-k8s-python-deps:latest${TAG_SUFFIX}"

# Build the image
build_image() {
    log_info "Building Python dependencies layer..."
    log_info "  Base image: $BASE_IMAGE"
    log_info "  GPU deps: $BUILD_GPU"
    log_info "  Iceberg deps: $BUILD_ICEBERG"
    log_info "  Output: $IMAGE_NAME"

    docker build \
        --build-arg "BASE_IMAGE=${BASE_IMAGE}" \
        --build-arg "BUILD_GPU_DEPS=${BUILD_GPU}" \
        --build-arg "BUILD_ICEBERG_DEPS=${BUILD_ICEBERG}" \
        -t "$IMAGE_NAME" \
        "$SCRIPT_DIR"

    log_pass "Built: $IMAGE_NAME"
}

# Run tests
run_tests() {
    log_info "Running tests..."

    # Export variables for test script
    export IMAGE_NAME
    export BUILD_GPU_DEPS="$BUILD_GPU"
    export BUILD_ICEBERG_DEPS="$BUILD_ICEBERG"

    "${SCRIPT_DIR}/test.sh"
}

# Main
main() {
    echo "=========================================="
    echo "Python Dependencies Layer - Build and Test"
    echo "=========================================="
    echo ""

    build_image
    echo ""
    run_tests

    echo ""
    log_pass "Python dependencies layer ready!"
}

main "$@"
