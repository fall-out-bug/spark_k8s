#!/usr/bin/env bash
# Common test functions for JARs intermediate layers

set -euo pipefail

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

# Test counters (global)
TESTS_PASSED=0
TESTS_FAILED=0

# Logging functions
log_info() { echo -e "${YELLOW}[INFO]${NC} $*"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $*"; ((TESTS_PASSED++)); }
log_fail() { echo -e "${RED}[FAIL]${NC} $*"; ((TESTS_FAILED++)); }

# Helper: Run docker command with timeout
docker_run() {
    local image_name="$1"
    shift
    timeout 30 docker run --rm "$image_name" "$@" 2>&1 || echo ""
}

# Test 1: Image exists
test_image_exists() {
    local image_name="$1"
    log_info "Testing image exists: $image_name"
    if docker image inspect "$image_name" &> /dev/null; then
        log_pass "Image exists: $image_name"
        return 0
    else
        log_fail "Image not found: $image_name"
        return 1
    fi
}

# Test 2: SPARK_HOME environment variable
test_spark_home() {
    local image_name="$1"
    log_info "Testing SPARK_HOME environment variable..."
    local spark_home
    spark_home=$(docker_run "$image_name" printenv SPARK_HOME)
    if [[ -n "$spark_home" ]]; then
        log_pass "SPARK_HOME is set: $spark_home"
        return 0
    else
        log_fail "SPARK_HOME is not set"
        return 1
    fi
}

# Test 3: JARs directory exists
test_jars_directory() {
    local image_name="$1"
    log_info "Testing JARs directory exists..."
    local result
    result=$(docker_run "$image_name" test -d /opt/spark/jars && echo "yes" || echo "no")
    if [[ "$result" == *"yes"* ]]; then
        log_pass "JARs directory exists: /opt/spark/jars"
        return 0
    else
        log_fail "JARs directory not found"
        return 1
    fi
}

# Test 4: Custom build verification (Hadoop 3.4.2)
test_custom_build() {
    local image_name="$1"
    log_info "Testing custom build contents (Hadoop 3.4.2)..."
    local result
    result=$(docker_run "$image_name" ls -1 /opt/spark/jars/hadoop-common-3.4.2.jar 2>/dev/null || echo "")
    if [[ -n "$result" ]]; then
        log_pass "Hadoop 3.4.2 jars present (custom build verified)"
        return 0
    else
        log_fail "Hadoop 3.4.2 jars not found (not using custom build)"
        return 1
    fi
}

# Test: JAR file validity
test_jar_validity() {
    local image_name="$1"
    local jar_pattern="$2"
    log_info "Testing JAR file validity..."

    local result
    result=$(docker_run "$image_name" bash -c "jar tf /opt/spark/jars/${jar_pattern} &>/dev/null || unzip -l /opt/spark/jars/${jar_pattern} &>/dev/null && echo OK" || echo "")
    if [[ "$result" == *"OK"* ]]; then
        log_pass "JAR files are valid archives"
        return 0
    else
        log_fail "JAR files are not valid"
        return 1
    fi
}

# Test: Image size check
test_image_size() {
    local image_name="$1"
    local max_size_mb="$2"
    log_info "Testing image size..."
    local size_mb
    size_mb=$(docker image inspect "$image_name" --format='{{.Size}}' | awk '{print int($1/1024/1024)}')

    if [[ $size_mb -lt $max_size_mb ]]; then
        log_pass "Image size is ${size_mb}MB (under ${max_size_mb}MB limit)"
        return 0
    else
        log_fail "Image size is ${size_mb}MB (exceeds ${max_size_mb}MB limit)"
        return 1
    fi
}

# Print test summary
print_summary() {
    echo ""
    echo "=========================================="
    echo "Test Results Summary"
    echo "=========================================="
    echo "Passed: $TESTS_PASSED"
    echo "Failed: $TESTS_FAILED"
    echo ""

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}Some tests failed!${NC}"
        return 1
    fi
}
