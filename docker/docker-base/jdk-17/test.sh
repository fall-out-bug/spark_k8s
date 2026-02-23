#!/usr/bin/env bash
# Test script for JDK 17 base Docker image

set -euo pipefail

# Configuration
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'
readonly MAX_IMAGE_SIZE_MB=200
readonly IMAGE_NAME="${IMAGE_NAME:-spark-k8s-jdk-17:latest}"

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# Logging functions
log_info() { echo -e "${YELLOW}[INFO]${NC} $*"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $*"; ((TESTS_PASSED++)); }
log_fail() { echo -e "${RED}[FAIL]${NC} $*"; ((TESTS_FAILED++)); }

# Generic command availability test
test_command() {
    local cmd="$1"
    local name="${2:-$cmd}"
    log_info "Testing $name availability..."
    if command -v "$cmd" &> /dev/null; then
        log_pass "$name is available: $($cmd --version 2>&1 | head -n 1)"
        return 0
    else
        log_fail "$name command not found"
        return 1
    fi
}

# Test Java version is 17
test_java_version() {
    log_info "Testing Java version..."
    local actual_version
    actual_version=$(java -version 2>&1 | head -n 1)
    if echo "$actual_version" | grep -qE 'version "17\.[0-9]'; then
        log_pass "Java version is 17: $actual_version"
        return 0
    else
        log_fail "Java version is not 17: $actual_version"
        return 1
    fi
}

# Test JAVA_HOME environment variable
test_java_home() {
    log_info "Testing JAVA_HOME environment variable..."
    if [[ -n "${JAVA_HOME:-}" && -d "$JAVA_HOME" ]]; then
        log_pass "JAVA_HOME is set and exists: $JAVA_HOME"
        return 0
    else
        log_fail "JAVA_HOME problem: ${JAVA_HOME:-not set}"
        return 1
    fi
}

# Test CA certificates presence
test_ca_certificates() {
    log_info "Testing CA certificates..."
    if [[ -f /etc/ssl/certs/ca-certificates.crt ]] || \
       [[ -f /etc/ssl/cert.pem ]] || \
       [[ -d /etc/ssl/certs ]]; then
        log_pass "CA certificates are present"
        return 0
    else
        log_fail "CA certificates not found"
        return 1
    fi
}

# Test Java execution with memory constraints
test_java_execution() {
    log_info "Testing Java execution with memory constraints..."
    if java -Xms32m -Xmx32m -version &> /dev/null; then
        log_pass "Java can execute with memory constraints"
        return 0
    else
        log_fail "Java execution failed"
        return 1
    fi
}

# Test non-root user
test_non_root_user() {
    log_info "Testing current user..."
    local current_user
    current_user=$(id -un)
    if [[ "$current_user" != "root" ]]; then
        log_pass "Running as non-root user: $current_user (UID: $(id -u))"
        return 0
    else
        log_info "Running as root (acceptable for base image)"
        return 0
    fi
}

# Test workspace directory
test_work_directory() {
    log_info "Testing work directory..."
    if [[ -d /workspace ]]; then
        log_pass "Work directory /workspace exists"
        return 0
    else
        log_fail "Work directory /workspace does not exist"
        return 1
    fi
}

# Test image size (only if docker available)
test_image_size() {
    log_info "Testing image size..."
    if ! command -v docker &> /dev/null; then
        log_info "Docker not available, skipping image size check"
        return 0
    fi
    if ! docker image inspect "$IMAGE_NAME" &> /dev/null; then
        log_info "Image $IMAGE_NAME not found locally, skipping size check"
        return 0
    fi
    local size_mb
    size_mb=$(($(docker image inspect "$IMAGE_NAME" --format='{{.Size}}') / 1024 / 1024))
    if [[ $size_mb -lt $MAX_IMAGE_SIZE_MB ]]; then
        log_pass "Image size is ${size_mb}MB (under ${MAX_IMAGE_SIZE_MB}MB limit)"
        return 0
    else
        log_fail "Image size is ${size_mb}MB (exceeds ${MAX_IMAGE_SIZE_MB}MB limit)"
        return 1
    fi
}

# Main test execution
main() {
    echo "=========================================="
    echo "JDK 17 Base Image Test Suite"
    echo "=========================================="
    echo ""

    test_java_version
    test_java_home
    test_command bash bash
    test_command curl curl
    test_ca_certificates
    test_java_execution
    test_non_root_user
    test_work_directory
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
        exit 0
    else
        echo -e "${RED}Some tests failed!${NC}"
        exit 1
    fi
}

main "$@"
