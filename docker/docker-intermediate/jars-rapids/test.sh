#!/usr/bin/env bash
# Build and test script for RAPIDS JARs intermediate layer

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly IMAGE_NAME="${IMAGE_NAME:-spark-k8s-jars-rapids:latest}"
readonly BASE_IMAGE="${BASE_IMAGE:-apache/spark:3.5.7-scala2.12-java17-ubuntu}"
readonly RAPIDS_VERSION="${RAPIDS_VERSION:-24.10.0}"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

# Logging
log_info() { echo -e "${YELLOW}[INFO]${NC} $*"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $*"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $*"; }

# Build the image
build_image() {
    log_info "Building RAPIDS JARs image: $IMAGE_NAME"
    log_info "Base image: $BASE_IMAGE"
    log_info "RAPIDS version: $RAPIDS_VERSION"

    docker build \
        --build-arg "BASE_IMAGE=${BASE_IMAGE}" \
        --build-arg "RAPIDS_VERSION=${RAPIDS_VERSION}" \
        -t "$IMAGE_NAME" \
        "$SCRIPT_DIR"

    log_pass "Image built successfully: $IMAGE_NAME"
}

# Run tests
run_tests() {
    log_info "Running tests for RAPIDS JARs layer..."

    # Run the shared test script
    local test_script="${SCRIPT_DIR}/../test-jars.sh"
    if [[ -f "$test_script" ]]; then
        "$test_script" rapids "$IMAGE_NAME"
    else
        log_fail "Test script not found: $test_script"
        return 1
    fi
}

# Main
main() {
    echo "=========================================="
    echo "RAPIDS JARs Layer - Build and Test"
    echo "=========================================="
    echo ""

    build_image
    echo ""
    run_tests

    echo ""
    log_pass "RAPIDS JARs layer ready!"
}

main "$@"
