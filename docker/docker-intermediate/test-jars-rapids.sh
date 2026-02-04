#!/usr/bin/env bash
# Test script for RAPIDS JARs intermediate layer

set -euo pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./test-jars-common.sh
source "${SCRIPT_DIR}/test-jars-common.sh"

# Test: RAPIDS-specific JAR check
test_rapids_jars() {
    local image_name="$1"
    log_info "Testing RAPIDS JAR files..."

    local result
    result=$(docker_run "$image_name" ls -1 /opt/spark/jars/rapids-4-spark*.jar 2>/dev/null || echo "")
    if [[ -n "$result" ]]; then
        log_pass "RAPIDS plugin JAR found: $result"
        return 0
    else
        log_fail "RAPIDS plugin JAR not found"
        return 1
    fi
}

# Test: RAPIDS environment variables
test_rapids_environment() {
    local image_name="$1"
    log_info "Testing RAPIDS environment variables..."

    local version
    version=$(docker_run "$image_name" printenv SPARK_RAPIDS_VERSION)
    if [[ -n "$version" ]]; then
        log_pass "SPARK_RAPIDS_VERSION set: $version"
    else
        log_fail "SPARK_RAPIDS_VERSION not set"
        return 1
    fi

    local cuda_version
    cuda_version=$(docker_run "$image_name" printenv SPARK_RAPIDS_CUDA_VERSION)
    if [[ -n "$cuda_version" ]]; then
        log_pass "SPARK_RAPIDS_CUDA_VERSION set: $cuda_version"
    else
        log_info "SPARK_RAPIDS_CUDA_VERSION not set (optional)"
    fi

    return 0
}

# Main test execution for RAPIDS
main() {
    local image_name="${1:-spark-k8s-jars-rapids:3.5.7}"

    echo "=========================================="
    echo "RAPIDS JARs Layer Test Suite"
    echo "=========================================="
    echo "Image: $image_name"
    echo ""

    test_image_exists "$image_name"
    test_spark_home "$image_name"
    test_jars_directory "$image_name"
    test_custom_build "$image_name"
    test_rapids_jars "$image_name"
    test_jar_validity "$image_name" "rapids-4-spark*.jar"
    test_rapids_environment "$image_name"
    test_image_size "$image_name" 800

    print_summary
}

main "$@"
