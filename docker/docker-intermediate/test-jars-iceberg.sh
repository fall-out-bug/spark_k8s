#!/usr/bin/env bash
# Test script for Iceberg JARs intermediate layer

set -euo pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./test-jars-common.sh
source "${SCRIPT_DIR}/test-jars-common.sh"

# Test: Iceberg-specific JAR check
test_iceberg_jars() {
    local image_name="$1"
    log_info "Testing Iceberg JAR files..."

    local result
    result=$(docker_run "$image_name" ls -1 /opt/spark/jars/iceberg-spark-runtime*.jar 2>/dev/null || echo "")
    if [[ -n "$result" ]]; then
        log_pass "Iceberg runtime JAR found: $result"
    else
        log_fail "Iceberg runtime JAR not found"
        return 1
    fi

    local aws_result
    aws_result=$(docker_run "$image_name" ls -1 /opt/spark/jars/iceberg-aws-bundle*.jar 2>/dev/null || echo "")
    if [[ -n "$aws_result" ]]; then
        log_pass "Iceberg AWS bundle JAR found: $aws_result"
    else
        log_info "Iceberg AWS bundle JAR not found (optional)"
    fi

    return 0
}

# Test: Iceberg environment variables
test_iceberg_environment() {
    local image_name="$1"
    log_info "Testing Iceberg environment variables..."

    local catalog_impl
    catalog_impl=$(docker_run "$image_name" printenv SPARK_SQL_CATALOG_IMPLEMENTATION)
    if [[ -n "$catalog_impl" ]]; then
        log_pass "SPARK_SQL_CATALOG_IMPLEMENTATION set: $catalog_impl"
    else
        log_info "SPARK_SQL_CATALOG_IMPLEMENTATION not set (optional)"
    fi

    local extensions
    extensions=$(docker_run "$image_name" printenv SPARK_SQL_EXTENSIONS)
    if [[ -n "$extensions" ]]; then
        log_pass "SPARK_SQL_EXTENSIONS set: $extensions"
    else
        log_info "SPARK_SQL_EXTENSIONS not set (optional)"
    fi

    return 0
}

# Main test execution for Iceberg
main() {
    local image_name="${1:-spark-k8s-jars-iceberg:3.5.7}"

    echo "=========================================="
    echo "Iceberg JARs Layer Test Suite"
    echo "=========================================="
    echo "Image: $image_name"
    echo ""

    test_image_exists "$image_name"
    test_spark_home "$image_name"
    test_jars_directory "$image_name"
    test_custom_build "$image_name"
    test_iceberg_jars "$image_name"
    test_jar_validity "$image_name" "iceberg-spark-runtime*.jar"
    test_iceberg_environment "$image_name"
    test_image_size "$image_name" 200

    print_summary
}

main "$@"
