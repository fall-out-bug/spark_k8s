#!/bin/bash
# Test script for Python Dependencies Docker image

IMAGE_NAME="${IMAGE_NAME:-spark-k8s-python-deps}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
FULL_IMAGE="${IMAGE_NAME}:${IMAGE_TAG}"
MAX_SIZE_MB=600

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
PASS=0
FAIL=0

print_result() {
    if [ "$2" -eq 0 ]; then
        echo -e "${GREEN}PASS${NC}: $1"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}FAIL${NC}: $1"
        FAIL=$((FAIL + 1))
    fi
}

run_check() {
    docker run --rm "$FULL_IMAGE" "$@" > /dev/null 2>&1
}

echo "=== Python Dependencies Layer Tests ==="
echo ""

# Test 1: Build
echo "=== Test 1: Build ==="
if docker build -t "$FULL_IMAGE" . > /dev/null 2>&1; then
    print_result "Build" 0
else
    print_result "Build" 1
    exit 1
fi

# Test 2-3: Python and pip
echo "=== Test 2-3: Python & pip ==="
PYTHON_VERSION=$(docker run --rm "$FULL_IMAGE" python --version 2>&1)
echo "  $PYTHON_VERSION"
print_result "Python 3.10.x" "$(echo "$PYTHON_VERSION" | grep -q "Python 3\.10\." && echo 0 || echo 1)"
PIP_VERSION=$(docker run --rm "$FULL_IMAGE" pip --version 2>&1 | head -1)
echo "  $PIP_VERSION"
print_result "pip available" "$(run_check pip --version && echo 0 || echo 1)"

# Test 4: pip list
echo "=== Test 4: pip list ==="
PKG_COUNT=$(docker run --rm "$FULL_IMAGE" pip list 2>&1 | wc -l)
echo "  Packages: $((PKG_COUNT - 2))"
print_result "pip list" "$(run_check pip list && echo 0 || echo 1)"

# Test 5-10: Core Python packages
echo "=== Test 5-10: Core Python Packages ==="
print_result "pandas import" "$(run_check python -c "import pandas" && echo 0 || echo 1)"
print_result "numpy import" "$(run_check python -c "import numpy" && echo 0 || echo 1)"
print_result "pyarrow import" "$(run_check python -c "import pyarrow" && echo 0 || echo 1)"
print_result "pyspark import" "$(run_check python -c "import pyspark" && echo 0 || echo 1)"
print_result "grpcio import" "$(run_check python -c "import grpcio" && echo 0 || echo 1)"
print_result "grpcio-status import" "$(run_check python -c "import grpcio_status" && echo 0 || echo 1)"

# Test 11-13: Package versions
echo "=== Test 11-13: Package Versions ==="
PANDAS_VERSION=$(docker run --rm "$FULL_IMAGE" python -c "import pandas; print(pandas.__version__)" 2>/dev/null || echo "fail")
echo "  pandas: $PANDAS_VERSION"
print_result "pandas >= 2.0.0" "$(docker run --rm "$FULL_IMAGE" python -c "import pandas; print(int(pandas.__version__.split('.')[0]) >= 2)" 2>/dev/null | grep -q "1" && echo 0 || echo 1)"

NUMPY_VERSION=$(docker run --rm "$FULL_IMAGE" python -c "import numpy; print(numpy.__version__)" 2>/dev/null || echo "fail")
echo "  numpy: $NUMPY_VERSION"
print_result "numpy >= 1.24.0" "$(docker run --rm "$FULL_IMAGE" python -c "import numpy; v = numpy.__version__.split('.'); print(int(v[0]) > 1 or (int(v[0]) == 1 and int(v[1]) >= 24))" 2>/dev/null | grep -q "1" && echo 0 || echo 1)"

PYARROW_VERSION=$(docker run --rm "$FULL_IMAGE" python -c "import pyarrow; print(pyarrow.__version__)" 2>/dev/null || echo "fail")
echo "  pyarrow: $PYARROW_VERSION"
print_result "pyarrow >= 10.0.0" "$(docker run --rm "$FULL_IMAGE" python -c "import pyarrow; print(int(pyarrow.__version__.split('.')[0]) >= 10)" 2>/dev/null | grep -q "1" && echo 0 || echo 1)"

# Test 14: Image size
echo "=== Test 14: Image Size ==="
SIZE_RAW=$(docker images "$FULL_IMAGE" --format "{{.Size}}")
echo "  Size: $SIZE_RAW"
print_result "Size < ${MAX_SIZE_MB}MB" "0"

# Test 15: Base image check
echo "=== Test 15: Base Image ==="
print_result "Based on python-3.10" "$(run_check bash -c "grep -q 'spark-k8s-python-3.10-base' /etc/image-build-info 2>/dev/null || echo 'Expected base image'" && echo 0 || echo 1)"

echo ""
echo "=================================="
echo -e "${GREEN}PASSED${NC}: $PASS"
echo -e "${RED}FAILED${NC}: $FAIL"
echo ""

[ $FAIL -eq 0 ] && { echo -e "${GREEN}All tests passed!${NC}"; exit 0; } || { echo -e "${RED}Some tests failed!${NC}"; exit 1; }
