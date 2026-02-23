#!/usr/bin/env bash
# Test script for Python Dependencies intermediate layer
# Tests Python package imports for base, GPU, and Iceberg variants
set -eo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly IMAGE_NAME="${IMAGE_NAME:-spark-k8s-python-deps:latest}"
readonly BUILD_GPU="${BUILD_GPU_DEPS:-false}"
readonly BUILD_ICEBERG="${BUILD_ICEBERG_DEPS:-false}"
readonly RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m' NC='\033[0m'
TESTS_PASSED=0
TESTS_FAILED=0

# Logging functions
log_info() { echo -e "${YELLOW}[INFO]${NC} $*"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $*"; TESTS_PASSED=$((TESTS_PASSED + 1)); }
log_fail() { echo -e "${RED}[FAIL]${NC} $*"; TESTS_FAILED=$((TESTS_FAILED + 1)); }

# Helper: Run docker command with timeout
docker_run() {
    timeout 30 docker run --rm "$IMAGE_NAME" "$@" 2>&1 || true
}

# Test 1: Image exists
test_image_exists() {
    log_info "Test 1: Image exists: $IMAGE_NAME"
    if docker image inspect "$IMAGE_NAME" &> /dev/null; then
        log_pass "Image exists: $IMAGE_NAME"
        return 0
    else
        log_fail "Image not found: $IMAGE_NAME"
        return 1
    fi
}

# Test 2: PySpark installation
test_pyspark() {
    log_info "Test 2: PySpark installation"
    local result
    result=$(docker_run python3 -c "import pyspark; print(pyspark.__version__)" 2>/dev/null || echo "")
    if [[ -n "$result" ]]; then
        log_pass "PySpark $result installed"
        return 0
    else
        log_fail "PySpark not found"
        return 1
    fi
}

# Test 3: Core data science packages
test_core_packages() {
    log_info "Test 3: Core packages (pandas, numpy, pyarrow)"
    local result
    result=$(docker_run python3 -c "import pandas, numpy, pyarrow; print('OK')" 2>/dev/null || echo "")
    if [[ "$result" == "OK" ]]; then
        log_pass "Core packages installed"
        return 0
    else
        log_fail "Core packages missing"
        return 1
    fi
}

# Test 4: GPU packages (if requested)
test_gpu_packages() {
    if [[ "$BUILD_GPU" == "true" ]]; then
        log_info "Test 4: GPU packages (cudf, cuml)"
        local result
        result=$(docker_run python3 -c "import cudf, cuml; print('OK')" 2>/dev/null || echo "")
        if [[ "$result" == "OK" ]]; then
            log_pass "GPU packages installed"
            return 0
        else
            log_fail "GPU packages missing"
            return 1
        fi
    else
        log_info "Test 4: Skipped (GPU not requested)"
        return 0
    fi
}

# Test 5: Iceberg packages (if requested)
test_iceberg_packages() {
    if [[ "$BUILD_ICEBERG" == "true" ]]; then
        log_info "Test 5: Iceberg packages (pyiceberg)"
        local result
        result=$(docker_run python3 -c "import pyiceberg; print('OK')" 2>/dev/null || echo "")
        if [[ "$result" == "OK" ]]; then
            log_pass "Iceberg packages installed"
            return 0
        else
            log_fail "Iceberg packages missing"
            return 1
        fi
    else
        log_info "Test 5: Skipped (Iceberg not requested)"
        return 0
    fi
}

# Test 6: Spark integration
test_spark_integration() {
    log_info "Test 6: Spark integration"
    local result
    result=$(docker_run bash -c 'cd /opt/spark && ./bin/pyspark --version 2>&1 | head -1' 2>/dev/null || echo "")
    if [[ -n "$result" ]]; then
        log_pass "Spark integration works: $result"
        return 0
    else
        log_fail "Spark integration failed"
        return 1
    fi
}

# Test 7: User permissions
test_user_permissions() {
    log_info "Test 7: User permissions"
    local result
    result=$(docker_run id -un 2>/dev/null || echo "")
    if [[ "$result" == "185" ]] || [[ "$result" == "spark" ]]; then
        log_pass "Running as non-root user: $result"
        return 0
    else
        log_fail "User check failed: $result"
        return 1
    fi
}

# Test 8: Working directory
test_working_directory() {
    log_info "Test 8: Working directory"
    local result
    result=$(docker_run pwd 2>/dev/null || echo "")
    if [[ "$result" == "/opt/spark/work-dir" ]]; then
        log_pass "Working directory correct: $result"
        return 0
    else
        log_fail "Working directory incorrect: $result"
        return 1
    fi
}

# Test 9: Image size check
test_image_size() {
    log_info "Test 9: Image size check"
    local max_size_mb=2000  # Python packages can be large
    local size_mb
    size_mb=$(docker image inspect "$IMAGE_NAME" --format='{{.Size}}' | awk '{print int($1/1024/1024)}')

    if [[ $size_mb -lt $max_size_mb ]]; then
        log_pass "Image size is ${size_mb}MB (under ${max_size_mb}MB limit)"
        return 0
    else
        log_fail "Image size is ${size_mb}MB (exceeds ${max_size_mb}MB limit)"
        return 1
    fi
}

# Main test execution
main() {
    echo "=========================================="
    echo "Python Dependencies Layer Test Suite"
    echo "=========================================="
    echo "Image: $IMAGE_NAME"
    echo "GPU: $BUILD_GPU"
    echo "Iceberg: $BUILD_ICEBERG"
    echo ""

    test_image_exists
    test_pyspark
    test_core_packages
    test_gpu_packages
    test_iceberg_packages
    test_spark_integration
    test_user_permissions
    test_working_directory
    test_image_size

    echo ""
    echo "=========================================="
    echo "Test Results Summary"
    echo "=========================================="
    echo "Passed: $TESTS_PASSED"
    echo "Failed: $TESTS_FAILED"
    echo ""

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}All tests passed!${NC}"
    else
        echo -e "${RED}Some tests failed!${NC}"
        exit 1
    fi
}

main "$@"
