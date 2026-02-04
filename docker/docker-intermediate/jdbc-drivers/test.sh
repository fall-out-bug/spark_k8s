#!/usr/bin/env bash
# Test script for JDBC drivers intermediate Docker image

set -euo pipefail

# Configuration
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'
readonly MAX_IMAGE_SIZE_MB=600
readonly IMAGE_NAME="${IMAGE_NAME:-spark-k8s-jdbc-drivers:latest}"

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# Logging functions
log_info() { echo -e "${YELLOW}[INFO]${NC} $*"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $*"; TESTS_PASSED=$((TESTS_PASSED + 1)); }
log_fail() { echo -e "${RED}[FAIL]${NC} $*"; TESTS_FAILED=$((TESTS_FAILED + 1)); }

# Test: Java 17 from base image
test_base_image() {
    log_info "Testing Java 17 is present (from JDK 17 base)..."
    local java_version
    java_version=$(docker run --rm "$IMAGE_NAME" bash -c 'java -version 2>&1 | head -1' || echo "")
    if echo "$java_version" | grep -qE 'version "17\.'; then
        log_pass "Java 17 verified from base image: $java_version"
        return 0
    else
        log_fail "Java 17 not found: $java_version"
        return 1
    fi
}

# Test: JDBC directory exists
test_jdbc_directory() {
    log_info "Testing /opt/jdbc directory exists..."
    if docker run --rm "$IMAGE_NAME" bash -c 'test -d /opt/jdbc'; then
        log_pass "/opt/jdbc directory exists"
        return 0
    else
        log_fail "/opt/jdbc directory not found"
        return 1
    fi
}

# Test: All driver files present
test_driver_files() {
    log_info "Testing all driver files are present..."
    local missing=0
    for driver in postgresql mysql oracle mssql vertica; do
        if docker run --rm "$IMAGE_NAME" bash -c "ls -la /opt/jdbc/${driver}.jar" >/dev/null 2>&1; then
            echo "  ${driver}.jar: OK"
        else
            echo "  ${driver}.jar: MISSING"
            missing=1
        fi
    done
    if [[ $missing -eq 0 ]]; then
        log_pass "All driver files present"
        return 0
    else
        log_fail "Some driver files missing"
        return 1
    fi
}

# Generic driver class test
test_driver_class() {
    local name="$1"
    local jar="$2"
    local class="$3"
    log_info "Testing ${name} JDBC driver contains Driver class..."
    if docker run --rm "$IMAGE_NAME" bash -c "unzip -l /opt/jdbc/${jar} | grep -q '${class}'"; then
        log_pass "${name} driver contains Driver class"
        return 0
    else
        log_fail "${name} driver missing Driver class"
        return 1
    fi
}

# Test: CLASSPATH environment variable
test_classpath_env() {
    log_info "Testing CLASSPATH environment variable..."
    local classpath
    classpath=$(docker run --rm "$IMAGE_NAME" bash -c 'echo $CLASSPATH')
    if [[ "$classpath" == *"/opt/jdbc/"* ]]; then
        log_pass "CLASSPATH includes JDBC directory"
        return 0
    else
        log_fail "CLASSPATH does not include JDBC directory: $classpath"
        return 1
    fi
}

# Test: JDBC_DRIVERS environment variable
test_jdbc_drivers_env() {
    log_info "Testing JDBC_DRIVERS environment variable..."
    local jdbc_drivers
    jdbc_drivers=$(docker run --rm "$IMAGE_NAME" bash -c 'echo $JDBC_DRIVERS')
    if [[ "$jdbc_drivers" == "/opt/jdbc" ]]; then
        log_pass "JDBC_DRIVERS environment variable is set: $jdbc_drivers"
        return 0
    else
        log_fail "JDBC_DRIVERS environment variable incorrect: $jdbc_drivers"
        return 1
    fi
}

# Test: Image size
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

# Test: Labels
test_labels() {
    log_info "Testing Docker image labels..."
    local maintainer desc version
    maintainer=$(docker image inspect "$IMAGE_NAME" --format='{{.Config.Labels.maintainer}}' 2>/dev/null || echo "")
    desc=$(docker image inspect "$IMAGE_NAME" --format='{{.Config.Labels.description}}' 2>/dev/null || echo "")
    version=$(docker image inspect "$IMAGE_NAME" --format='{{.Config.Labels.version}}' 2>/dev/null || echo "")
    if [[ "$maintainer" == "spark-k8s" ]] && [[ -n "$desc" ]] && [[ -n "$version" ]]; then
        log_pass "Labels present: maintainer=$maintainer, version=$version"
        return 0
    else
        log_fail "Labels incomplete: maintainer=$maintainer, version=$version"
        return 1
    fi
}

# Main test execution
main() {
    echo "=========================================="
    echo "JDBC Drivers Intermediate Layer Test Suite"
    echo "=========================================="
    echo "Image: $IMAGE_NAME"
    echo ""

    test_base_image
    test_jdbc_directory
    test_driver_files
    test_driver_class "PostgreSQL" "postgresql.jar" "org/postgresql/Driver.class"
    test_driver_class "MySQL" "mysql.jar" "com/mysql/cj/jdbc/Driver.class"
    test_driver_class "Oracle" "oracle.jar" "oracle/jdbc/OracleDriver.class"
    test_driver_class "MSSQL" "mssql.jar" "com/microsoft/sqlserver/jdbc/SQLServerDriver.class"
    test_driver_class "Vertica" "vertica.jar" "com/vertica/jdbc/Driver.class"
    test_classpath_env
    test_jdbc_drivers_env
    test_labels
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
