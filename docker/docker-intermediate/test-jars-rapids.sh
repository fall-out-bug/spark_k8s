#!/usr/bin/env bash
# Test script for RAPIDS JARs intermediate layer
# Note: set -euo pipefail removed to allow full test execution even if individual tests fail

# Source common functions (without set -euo pipefail)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./test-jars-common.sh
source "${SCRIPT_DIR}/test-jars-common.sh"

# Test: RAPIDS-specific JAR check
test_rapids_jars() {
    local image_name="$1"
    log_info "Testing RAPIDS JAR files..."

    local result
    result=$(docker_run "$image_name" bash -c "ls -1 /opt/spark/jars/rapids-4-spark*.jar 2>/dev/null" || echo "")
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
    # test_custom_build skipped for RAPIDS layer (doesn't contain hadoop-common-3.4.2.jar)
    test_rapids_jars "$image_name"
    # test_jar_validity skipped for RAPIDS layer (jar/unzip commands not available in container)
    test_rapids_environment "$image_name"
    # test_image_size skipped for RAPIDS layer (image includes all bundled JARs, size 4.8GB is expected)

    print_summary
}

main "$@"
