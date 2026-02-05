#!/bin/bash
# Test script for Jupyter Runtime Images
# Validates PySpark, GPU, and Iceberg variants

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS_COUNT=0
FAIL_COUNT=0

# Helper to safely increment counters
increment_pass() { ((PASS_COUNT++)) || true; }
increment_fail() { ((FAIL_COUNT++)) || true; }

echo "=========================================="
echo "Jupyter Runtime Images Test Suite"
echo "=========================================="

# Test functions
test_pyspark_version() {
    local image="$1"
    local expected_version="$2"

    echo "Testing PySpark version for ${image}..."
    local version=$(docker run --rm --entrypoint bash "${image}" -c "python3 -c 'import pyspark; print(pyspark.__version__)'" 2>/dev/null || echo "")

    if [[ "$version" == "$expected_version" ]]; then
        echo "  ✅ PASS: PySpark ${expected_version}"
        increment_pass
        return 0
    else
        echo "  ❌ FAIL: Expected ${expected_version}, got ${version}"
        increment_fail
        return 1
    fi
}

test_jupyter_version() {
    local image="$1"

    echo "Testing Jupyter installation for ${image}..."
    local version=$(docker run --rm --entrypoint jupyter "${image}" --version 2>&1 | head -1 || echo "")

    if [[ -n "$version" ]]; then
        echo "  ✅ PASS: Jupyter installed (${version})"
        increment_pass
        return 0
    else
        echo "  ❌ FAIL: Jupyter not found"
        increment_fail
        return 1
    fi
}

test_rapids_cudf() {
    local image="$1"

    echo "Testing RAPIDS cudf for ${image}..."
    local version=$(docker run --rm --entrypoint bash "${image}" -c "python3 -c 'import cudf; print(cudf.__version__)'" 2>/dev/null || echo "")

    if [[ -n "$version" ]]; then
        echo "  ✅ PASS: cudf ${version}"
        increment_pass
        return 0
    else
        echo "  ❌ FAIL: cudf not found"
        increment_fail
        return 1
    fi
}

test_rapids_cuml() {
    local image="$1"

    echo "Testing RAPIDS cuml for ${image}..."
    local version=$(docker run --rm --entrypoint bash "${image}" -c "python3 -c 'import cuml; print(cuml.__version__)'" 2>/dev/null || echo "")

    if [[ -n "$version" ]]; then
        echo "  ✅ PASS: cuml ${version}"
        increment_pass
        return 0
    else
        echo "  ❌ FAIL: cuml not found"
        increment_fail
        return 1
    fi
}

test_spark_home() {
    local image="$1"

    echo "Testing SPARK_HOME for ${image}..."
    local spark_home=$(docker run --rm --entrypoint bash "${image}" -c "printenv SPARK_HOME" 2>/dev/null || echo "")

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

test_jupyter_port() {
    local image="$1"
    local expected_port="8888"

    echo "Testing Jupyter port exposure for ${image}..."
    local exposed=$(docker image inspect "${image}" --format='{{range $p, $conf := .Config.ExposedPorts}}{{println $p}}{{end}}' 2>/dev/null | grep "${expected_port}" || echo "")

    if [[ -n "$exposed" ]]; then
        echo "  ✅ PASS: Port ${expected_port} exposed"
        increment_pass
        return 0
    else
        echo "  ❌ FAIL: Port ${expected_port} not exposed"
        increment_fail
        return 1
    fi
}

# Test suite
echo ""
echo "=== Jupyter 3.5.7 Runtime Images ==="

echo ""
echo "Testing: spark-k8s-jupyter:3.5-3.5.7-baseline"
test_pyspark_version "spark-k8s-jupyter:3.5-3.5.7-baseline" "3.5.7"
test_jupyter_version "spark-k8s-jupyter:3.5-3.5.7-baseline"
test_spark_home "spark-k8s-jupyter:3.5-3.5.7-baseline"
test_jupyter_port "spark-k8s-jupyter:3.5-3.5.7-baseline"

echo ""
echo "Testing: spark-k8s-jupyter:3.5-3.5.7-gpu"
test_pyspark_version "spark-k8s-jupyter:3.5-3.5.7-gpu" "3.5.7"
test_jupyter_version "spark-k8s-jupyter:3.5-3.5.7-gpu"
test_rapids_cudf "spark-k8s-jupyter:3.5-3.5.7-gpu"
test_rapids_cuml "spark-k8s-jupyter:3.5-3.5.7-gpu"
test_spark_home "spark-k8s-jupyter:3.5-3.5.7-gpu"

echo ""
echo "Testing: spark-k8s-jupyter:3.5-3.5.7-iceberg"
test_pyspark_version "spark-k8s-jupyter:3.5-3.5.7-iceberg" "3.5.7"
test_jupyter_version "spark-k8s-jupyter:3.5-3.5.7-iceberg"
test_spark_home "spark-k8s-jupyter:3.5-3.5.7-iceberg"
test_jupyter_port "spark-k8s-jupyter:3.5-3.5.7-iceberg"

echo ""
echo "Testing: spark-k8s-jupyter:3.5-3.5.7-gpu-iceberg"
test_pyspark_version "spark-k8s-jupyter:3.5-3.5.7-gpu-iceberg" "3.5.7"
test_jupyter_version "spark-k8s-jupyter:3.5-3.5.7-gpu-iceberg"
test_rapids_cudf "spark-k8s-jupyter:3.5-3.5.7-gpu-iceberg"
test_rapids_cuml "spark-k8s-jupyter:3.5-3.5.7-gpu-iceberg"
test_spark_home "spark-k8s-jupyter:3.5-3.5.7-gpu-iceberg"

echo ""
echo "=== Jupyter 4.1.0 Runtime Images ==="

echo ""
echo "Testing: spark-k8s-jupyter:4.1-4.1.0-baseline"
test_pyspark_version "spark-k8s-jupyter:4.1-4.1.0-baseline" "4.1.0"
test_jupyter_version "spark-k8s-jupyter:4.1-4.1.0-baseline"
test_spark_home "spark-k8s-jupyter:4.1-4.1.0-baseline"
test_jupyter_port "spark-k8s-jupyter:4.1-4.1.0-baseline"

echo ""
echo "Testing: spark-k8s-jupyter:4.1-4.1.0-gpu"
test_pyspark_version "spark-k8s-jupyter:4.1-4.1.0-gpu" "4.1.0"
test_jupyter_version "spark-k8s-jupyter:4.1-4.1.0-gpu"
test_rapids_cudf "spark-k8s-jupyter:4.1-4.1.0-gpu"
test_rapids_cuml "spark-k8s-jupyter:4.1-4.1.0-gpu"
test_spark_home "spark-k8s-jupyter:4.1-4.1.0-gpu"

echo ""
echo "Testing: spark-k8s-jupyter:4.1-4.1.0-iceberg"
test_pyspark_version "spark-k8s-jupyter:4.1-4.1.0-iceberg" "4.1.0"
test_jupyter_version "spark-k8s-jupyter:4.1-4.1.0-iceberg"
test_spark_home "spark-k8s-jupyter:4.1-4.1.0-iceberg"
test_jupyter_port "spark-k8s-jupyter:4.1-4.1.0-iceberg"

echo ""
echo "Testing: spark-k8s-jupyter:4.1-4.1.0-gpu-iceberg"
test_pyspark_version "spark-k8s-jupyter:4.1-4.1.0-gpu-iceberg" "4.1.0"
test_jupyter_version "spark-k8s-jupyter:4.1-4.1.0-gpu-iceberg"
test_rapids_cudf "spark-k8s-jupyter:4.1-4.1.0-gpu-iceberg"
test_rapids_cuml "spark-k8s-jupyter:4.1-4.1.0-gpu-iceberg"
test_spark_home "spark-k8s-jupyter:4.1-4.1.0-gpu-iceberg"

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
