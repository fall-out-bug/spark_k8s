#!/usr/bin/env bash
# Test script for JDBC drivers intermediate Docker image
# Tests that the layer extends custom Spark builds (not JDK base)

set -eo pipefail

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

# Test: Image exists
test_image_exists() {
    log_info "Testing image exists..."
    if docker image inspect "$IMAGE_NAME" &>/dev/null; then
        log_pass "Image $IMAGE_NAME exists"
        return 0
    else
        log_fail "Image $IMAGE_NAME not found"
        return 1
    fi
}

# Test: SPARK_HOME is set (from custom Spark build)
test_spark_home() {
    log_info "Testing SPARK_HOME environment variable..."
    local spark_home
    spark_home=$(docker run --rm "$IMAGE_NAME" bash -c 'echo $SPARK_HOME' 2>/dev/null || echo "")
    if [[ "$spark_home" == "/opt/spark" ]]; then
        log_pass "SPARK_HOME=/opt/spark (from custom Spark build)"
        return 0
    else
        log_fail "SPARK_HOME not set correctly: $spark_home"
        return 1
    fi
}

# Test: Spark binaries available (from custom Spark build)
test_spark_binaries() {
    log_info "Testing Spark binaries are available..."
    if docker run --rm "$IMAGE_NAME" bash -c 'test -x ${SPARK_HOME}/bin/spark-submit'; then
        log_pass "Spark binaries found in \${SPARK_HOME}/bin"
        return 0
    else
        log_fail "Spark binaries not found"
        return 1
    fi
}

# Test: PostgreSQL driver (from custom build)
test_postgresql_driver() {
    log_info "Testing PostgreSQL JDBC driver (from custom build)..."
    local jar_name
    jar_name=$(docker run --rm "$IMAGE_NAME" bash -c 'ls ${SPARK_HOME}/jars/postgresql*.jar 2>/dev/null | xargs -n1 basename' || echo "")
    if [[ -n "$jar_name" ]]; then
        log_pass "PostgreSQL driver found: $jar_name"
        return 0
    else
        log_fail "PostgreSQL driver not found"
        return 1
    fi
}

# Test: Oracle driver (from custom build)
test_oracle_driver() {
    log_info "Testing Oracle JDBC driver (from custom build)..."
    local jar_name
    jar_name=$(docker run --rm "$IMAGE_NAME" bash -c 'ls ${SPARK_HOME}/jars/ojdbc*.jar 2>/dev/null | xargs -n1 basename' || echo "")
    if [[ -n "$jar_name" ]]; then
        log_pass "Oracle driver found: $jar_name"
        return 0
    else
        log_fail "Oracle driver not found"
        return 1
    fi
}

# Test: Vertica driver (from custom build)
test_vertica_driver() {
    log_info "Testing Vertica JDBC driver (from custom build)..."
    local jar_name
    jar_name=$(docker run --rm "$IMAGE_NAME" bash -c 'ls ${SPARK_HOME}/jars/vertica*.jar 2>/dev/null | xargs -n1 basename' || echo "")
    if [[ -n "$jar_name" ]]; then
        log_pass "Vertica driver found: $jar_name"
        return 0
    else
        log_fail "Vertica driver not found"
        return 1
    fi
}

# Test: MySQL driver (added by this layer)
test_mysql_driver() {
    log_info "Testing MySQL JDBC driver (added by this layer)..."
    local jar_name
    jar_name=$(docker run --rm "$IMAGE_NAME" bash -c 'ls ${SPARK_HOME}/jars/mysql*.jar 2>/dev/null | xargs -n1 basename' || echo "")
    if [[ -n "$jar_name" ]]; then
        log_pass "MySQL driver found: $jar_name"
        return 0
    else
        log_fail "MySQL driver not found"
        return 1
    fi
}

# Test: MSSQL driver (added by this layer)
test_mssql_driver() {
    log_info "Testing MSSQL JDBC driver (added by this layer)..."
    local jar_name
    jar_name=$(docker run --rm "$IMAGE_NAME" bash -c 'ls ${SPARK_HOME}/jars/mssql*.jar 2>/dev/null | xargs -n1 basename' || echo "")
    if [[ -n "$jar_name" ]]; then
        log_pass "MSSQL driver found: $jar_name"
        return 0
    else
        log_fail "MSSQL driver not found"
        return 1
    fi
}

# Test: Convenience symlinks in /opt/jdbc
test_convenience_symlinks() {
    log_info "Testing convenience symlinks in /opt/jdbc..."
    local symlink_count
    symlink_count=$(docker run --rm "$IMAGE_NAME" bash -c 'ls -la /opt/jdbc/*.jar 2>/dev/null | wc -l' || echo "0")
    if [[ "$symlink_count" -ge 5 ]]; then
        log_pass "Found $symlink_count convenience symlinks in /opt/jdbc"
        return 0
    else
        log_fail "Expected at least 5 symlinks, found $symlink_count"
        return 1
    fi
}

# Test: JDBC_DRIVERS environment variable
test_jdbc_drivers_env() {
    log_info "Testing JDBC_DRIVERS environment variable..."
    local jdbc_drivers
    jdbc_drivers=$(docker run --rm "$IMAGE_NAME" bash -c 'echo $JDBC_DRIVERS' 2>/dev/null || echo "")
    if [[ "$jdbc_drivers" == "/opt/jdbc" ]]; then
        log_pass "JDBC_DRIVERS=/opt/jdbc"
        return 0
    else
        log_fail "JDBC_DRIVERS not set correctly: $jdbc_drivers"
        return 1
    fi
}

# Test: MySQL driver class validation
test_mysql_driver_class() {
    log_info "Testing MySQL driver class..."
    if docker run --rm "$IMAGE_NAME" bash -c "unzip -l \${SPARK_HOME}/jars/mysql*.jar 2>/dev/null | grep -q 'com/mysql/cj/jdbc/Driver.class'"; then
        log_pass "MySQL driver contains Driver class"
        return 0
    else
        log_fail "MySQL driver missing Driver class"
        return 1
    fi
}

# Test: MSSQL driver class validation
test_mssql_driver_class() {
    log_info "Testing MSSQL driver class..."
    if docker run --rm "$IMAGE_NAME" bash -c "unzip -l \${SPARK_HOME}/jars/mssql*.jar 2>/dev/null | grep -q 'com/microsoft/sqlserver/jdbc/SQLServerDriver.class'"; then
        log_pass "MSSQL driver contains Driver class"
        return 0
    else
        log_fail "MSSQL driver missing Driver class"
        return 1
    fi
}

# Main test execution
main() {
    echo "=========================================="
    echo "JDBC Drivers Layer Test Suite"
    echo "=========================================="
    echo "Image: $IMAGE_NAME"
    echo ""

    test_image_exists
    test_spark_home
    test_spark_binaries
    test_postgresql_driver
    test_oracle_driver
    test_vertica_driver
    test_mysql_driver
    test_mssql_driver
    test_convenience_symlinks
    test_jdbc_drivers_env
    test_mysql_driver_class
    test_mssql_driver_class

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
