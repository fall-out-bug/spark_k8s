#!/bin/bash
# Test script for Spark Runtime Images
# Validates baseline, GPU, Iceberg, and GPU+Iceberg variants

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS_COUNT=0
FAIL_COUNT=0

# Helper to safely increment counters
increment_pass() { ((PASS_COUNT++)) || true; }
increment_fail() { ((FAIL_COUNT++)) || true; }

echo "=========================================="
echo "Spark Runtime Images Test Suite"
echo "=========================================="

# Test functions
test_spark_version() {
    local image="$1"
    local expected_version="$2"

    echo "Testing Spark version for ${image}..."
    local version=$(docker run --rm "${image}" spark-submit --version 2>&1 | grep "version ${expected_version}" || echo "")

    if [[ -n "$version" ]]; then
        echo "  ✅ PASS: Spark ${expected_version} detected"
        increment_pass
        return 0
    else
        echo "  ❌ FAIL: Spark ${expected_version} not found"
        increment_fail
        return 1
    fi
}

test_rapids_jar() {
    local image="$1"

    echo "Testing RAPIDS JAR for ${image}..."
    local jar_count=$(docker run --rm --entrypoint sh "${image}" -c "ls -la /opt/spark/jars/rapids*.jar 2>/dev/null" | wc -l)

    if [[ "$jar_count" -gt 0 ]]; then
        echo "  ✅ PASS: RAPIDS JAR found (${jar_count} file(s))"
        increment_pass
        return 0
    else
        echo "  ❌ FAIL: RAPIDS JAR not found"
        increment_fail
        return 1
    fi
}

test_iceberg_jars() {
    local image="$1"

    echo "Testing Iceberg JARs for ${image}..."
    local jar_count=$(docker run --rm --entrypoint sh "${image}" -c "ls /opt/spark/jars/iceberg*.jar 2>/dev/null" | wc -l)

    if [[ "$jar_count" -ge 2 ]]; then
        echo "  ✅ PASS: Iceberg JARs found (${jar_count} file(s))"
        increment_pass
        return 0
    else
        echo "  ❌ FAIL: Iceberg JARs not found (expected 2+, got ${jar_count})"
        increment_fail
        return 1
    fi
}

test_spark_home() {
    local image="$1"

    echo "Testing SPARK_HOME for ${image}..."
    local spark_home=$(docker run --rm --entrypoint env "${image}" 2>/dev/null | grep "^SPARK_HOME=" | cut -d'=' -f2 || echo "")

    if [[ "$spark_home" == "/opt/spark" ]]; then
        echo "  ✅ PASS: SPARK_HOME=/opt/spark"
        increment_pass
        return 0
    else
        echo "  ❌ FAIL: SPARK_HOME not set correctly (got: ${spark_home})"
        increment_fail
        return 1
    fi
}

# Test suite
echo ""
echo "=== Spark 3.5.7 Runtime Images ==="

echo ""
echo "Testing: spark-k8s-runtime:3.5-3.5.7-baseline"
test_spark_version "spark-k8s-runtime:3.5-3.5.7-baseline" "3.5.7"
test_spark_home "spark-k8s-runtime:3.5-3.5.7-baseline"

echo ""
echo "Testing: spark-k8s-runtime:3.5-3.5.7-gpu"
test_spark_version "spark-k8s-runtime:3.5-3.5.7-gpu" "3.5.7"
test_rapids_jar "spark-k8s-runtime:3.5-3.5.7-gpu"
test_spark_home "spark-k8s-runtime:3.5-3.5.7-gpu"

echo ""
echo "Testing: spark-k8s-runtime:3.5-3.5.7-iceberg"
test_spark_version "spark-k8s-runtime:3.5-3.5.7-iceberg" "3.5.7"
test_iceberg_jars "spark-k8s-runtime:3.5-3.5.7-iceberg"
test_spark_home "spark-k8s-runtime:3.5-3.5.7-iceberg"

echo ""
echo "Testing: spark-k8s-runtime:3.5-3.5.7-gpu-iceberg"
test_spark_version "spark-k8s-runtime:3.5-3.5.7-gpu-iceberg" "3.5.7"
test_rapids_jar "spark-k8s-runtime:3.5-3.5.7-gpu-iceberg"
test_iceberg_jars "spark-k8s-runtime:3.5-3.5.7-gpu-iceberg"
test_spark_home "spark-k8s-runtime:3.5-3.5.7-gpu-iceberg"

echo ""
echo "=== Spark 4.1.0 Runtime Images ==="

echo ""
echo "Testing: spark-k8s-runtime:4.1-4.1.0-baseline"
test_spark_version "spark-k8s-runtime:4.1-4.1.0-baseline" "4.1.0"
test_spark_home "spark-k8s-runtime:4.1-4.1.0-baseline"

echo ""
echo "Testing: spark-k8s-runtime:4.1-4.1.0-gpu"
test_spark_version "spark-k8s-runtime:4.1-4.1.0-gpu" "4.1.0"
test_rapids_jar "spark-k8s-runtime:4.1-4.1.0-gpu"
test_spark_home "spark-k8s-runtime:4.1-4.1.0-gpu"

echo ""
echo "Testing: spark-k8s-runtime:4.1-4.1.0-iceberg"
test_spark_version "spark-k8s-runtime:4.1-4.1.0-iceberg" "4.1.0"
test_iceberg_jars "spark-k8s-runtime:4.1-4.1.0-iceberg"
test_spark_home "spark-k8s-runtime:4.1-4.1.0-iceberg"

echo ""
echo "Testing: spark-k8s-runtime:4.1-4.1.0-gpu-iceberg"
test_spark_version "spark-k8s-runtime:4.1-4.1.0-gpu-iceberg" "4.1.0"
test_rapids_jar "spark-k8s-runtime:4.1-4.1.0-gpu-iceberg"
test_iceberg_jars "spark-k8s-runtime:4.1-4.1.0-gpu-iceberg"
test_spark_home "spark-k8s-runtime:4.1-4.1.0-gpu-iceberg"

# Summary
echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo "Passed: ${PASS_COUNT}"
echo "Failed: ${FAIL_COUNT}"
echo "Total:  $((PASS_COUNT + FAIL_COUNT))"

if [[ $FAIL_COUNT -eq 0 ]]; then
    echo ""
    echo "✅ All tests passed!"
    exit 0
else
    echo ""
    echo "❌ Some tests failed!"
    exit 1
fi
