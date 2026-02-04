#!/usr/bin/env bash
# Test script for JARs intermediate layers (RAPIDS, Iceberg)
# Tests JAR availability and validity in Spark classpath

set -euo pipefail

# Configuration
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# Logging functions
log_info() { echo -e "${YELLOW}[INFO]${NC} $*"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $*"; ((TESTS_PASSED++)); }
log_fail() { echo -e "${RED}[FAIL]${NC} $*"; ((TESTS_FAILED++)); }

# Usage
usage() {
    echo "Usage: $0 <jar_type> [image_name]"
    echo ""
    echo "Arguments:"
    echo "  jar_type    Type of JARs layer to test: 'rapids' or 'iceberg'"
    echo "  image_name  Optional image name (default: auto-detected)"
    echo ""
    echo "Examples:"
    echo "  $0 rapids"
    echo "  $0 iceberg my-iceberg-jars:latest"
    exit 1
}

# Parse arguments
[[ $# -lt 1 ]] && usage

readonly JAR_TYPE="$1"
shift

# Validate jar_type
case "$JAR_TYPE" in
    rapids|iceberg)
        ;;
    *)
        log_fail "Invalid jar_type: '$JAR_TYPE'. Must be 'rapids' or 'iceberg'"
        usage
        ;;
esac

# Auto-detect image name if not provided
if [[ -n "${1:-}" ]]; then
    readonly IMAGE_NAME="$1"
else
    case "$JAR_TYPE" in
        rapids)
            IMAGE_NAME="${IMAGE_NAME:-spark-k8s-jars-rapids:latest}"
            ;;
        iceberg)
            IMAGE_NAME="${IMAGE_NAME:-spark-k8s-jars-iceberg:latest}"
            ;;
    esac
fi

# Helper: Run docker command with timeout
docker_run() {
    timeout 30 docker run --rm "$IMAGE_NAME" "$@" 2>&1 || echo ""
}

# Test 1: Image exists
test_image_exists() {
    log_info "Testing image exists: $IMAGE_NAME"
    if docker image inspect "$IMAGE_NAME" &> /dev/null; then
        log_pass "Image exists: $IMAGE_NAME"
        return 0
    else
        log_fail "Image not found: $IMAGE_NAME"
        return 1
    fi
}

# Test 2: SPARK_HOME environment variable
test_spark_home() {
    log_info "Testing SPARK_HOME environment variable..."
    local spark_home
    spark_home=$(docker_run printenv SPARK_HOME)
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
    log_info "Testing JARs directory exists..."
    local result
    result=$(docker_run test -d /opt/spark/jars && echo "yes" || echo "no")
    if [[ "$result" == *"yes"* ]]; then
        log_pass "JARs directory exists: /opt/spark/jars"
        return 0
    else
        log_fail "JARs directory not found"
        return 1
    fi
}

# Test 4: RAPIDS-specific tests
test_rapids_jars() {
    log_info "Testing RAPIDS JAR files..."

    # Check rapids-4-spark JAR (includes shaded cudf)
    local result
    result=$(docker_run ls -1 /opt/spark/jars/rapids-4-spark*.jar 2>/dev/null || echo "")
    if [[ -n "$result" ]]; then
        log_pass "RAPIDS plugin JAR found: $result"
        return 0
    else
        log_fail "RAPIDS plugin JAR not found"
        return 1
    fi
}

# Test 5: Iceberg-specific tests
test_iceberg_jars() {
    log_info "Testing Iceberg JAR files..."

    # Check iceberg-spark-runtime JAR
    local result
    result=$(docker_run ls -1 /opt/spark/jars/iceberg-spark-runtime*.jar 2>/dev/null || echo "")
    if [[ -n "$result" ]]; then
        log_pass "Iceberg runtime JAR found: $result"
    else
        log_fail "Iceberg runtime JAR not found"
        return 1
    fi

    # Check iceberg-aws-bundle JAR (optional)
    local aws_result
    aws_result=$(docker_run ls -1 /opt/spark/jars/iceberg-aws-bundle*.jar 2>/dev/null || echo "")
    if [[ -n "$aws_result" ]]; then
        log_pass "Iceberg AWS bundle JAR found: $aws_result"
    else
        log_info "Iceberg AWS bundle JAR not found (optional)"
    fi

    return 0
}

# Test 6: JAR file validity
test_jar_validity() {
    log_info "Testing JAR file validity..."

    local jar_pattern
    case "$JAR_TYPE" in
        rapids)
            jar_pattern="rapids-4-spark*.jar"
            ;;
        iceberg)
            jar_pattern="iceberg-spark-runtime*.jar"
            ;;
    esac

    # Use jar tf or unzip -l to test if files are valid JAR archives
    local result
    result=$(docker_run bash -c "jar tf /opt/spark/jars/${jar_pattern} &>/dev/null || unzip -l /opt/spark/jars/${jar_pattern} &>/dev/null && echo OK" || echo "")
    if [[ "$result" == *"OK"* ]]; then
        log_pass "JAR files are valid archives"
        return 0
    else
        log_fail "JAR files are not valid"
        return 1
    fi
}

# Test 7: Environment variables set
test_environment_variables() {
    log_info "Testing environment variables..."

    case "$JAR_TYPE" in
        rapids)
            local version
            version=$(docker_run printenv SPARK_RAPIDS_VERSION)
            if [[ -n "$version" ]]; then
                log_pass "SPARK_RAPIDS_VERSION set: $version"
            else
                log_fail "SPARK_RAPIDS_VERSION not set"
                return 1
            fi
            ;;
        iceberg)
            local catalog_impl
            catalog_impl=$(docker_run printenv SPARK_SQL_CATALOG_IMPLEMENTATION)
            if [[ -n "$catalog_impl" ]]; then
                log_pass "SPARK_SQL_CATALOG_IMPLEMENTATION set: $catalog_impl"
            else
                log_info "SPARK_SQL_CATALOG_IMPLEMENTATION not set (optional)"
            fi

            local extensions
            extensions=$(docker_run printenv SPARK_SQL_EXTENSIONS)
            if [[ -n "$extensions" ]]; then
                log_pass "SPARK_SQL_EXTENSIONS set: $extensions"
            else
                log_info "SPARK_SQL_EXTENSIONS not set (optional)"
            fi
            ;;
    esac

    return 0
}

# Test 8: Image size check
test_image_size() {
    log_info "Testing image size..."
    local max_size_mb
    local size_mb

    case "$JAR_TYPE" in
        rapids)
            max_size_mb=800  # RAPIDS JARs are large
            ;;
        iceberg)
            max_size_mb=200  # Iceberg JARs are smaller
            ;;
    esac

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
    echo "JARs Layer Test Suite (${JAR_TYPE})"
    echo "=========================================="
    echo "Image: $IMAGE_NAME"
    echo ""

    test_image_exists
    test_spark_home
    test_jars_directory

    # Type-specific tests
    case "$JAR_TYPE" in
        rapids)
            test_rapids_jars
            ;;
        iceberg)
            test_iceberg_jars
            ;;
    esac

    test_jar_validity
    test_environment_variables
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
