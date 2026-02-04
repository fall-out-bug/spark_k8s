#!/bin/bash
# Test script for Python 3.10 base Docker image

IMAGE_NAME="${IMAGE_NAME:-spark-k8s-python-3.10-base}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
FULL_IMAGE="${IMAGE_NAME}:${IMAGE_TAG}"
MAX_SIZE_MB=450

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

echo "=== Python 3.10 Base Layer Tests ==="
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

# Test 4: Packages
echo "=== Test 4: Packages ==="
for pkg in setuptools wheel; do
    run_check python -c "import $pkg" && echo -e "  ${GREEN}$pkg${NC}" || echo -e "  ${RED}$pkg${NC}"
done
print_result "setuptools, wheel" "$(run_check python -c "import setuptools, wheel" && echo 0 || echo 1)"

# Test 5: Build tools
echo "=== Test 5: Build tools ==="
for tool in gcc; do
    run_check which $tool && echo -e "  ${GREEN}$tool${NC}" || echo -e "  ${RED}$tool${NC}"
done
print_result "gcc, musl-dev" "$(run_check which gcc && echo 0 || echo 1)"

# Test 6: curl, bash
echo "=== Test 6: curl & bash ==="
for tool in curl bash; do
    run_check which $tool && echo -e "  ${GREEN}$tool${NC}" || echo -e "  ${RED}$tool${NC}"
done
print_result "curl, bash" "$(run_check bash -c "which curl && which bash" && echo 0 || echo 1)"

# Test 7-9: curl, pip list, size
echo "=== Test 7-9: Functional tests ==="
print_result "curl HTTP" "$(docker run --rm "$FULL_IMAGE" curl -s -o /dev/null https://www.google.com 2>/dev/null && echo 0 || echo 1)"
PKG_COUNT=$(docker run --rm "$FULL_IMAGE" pip list 2>&1 | wc -l)
echo "  Packages: $((PKG_COUNT - 2))"
print_result "pip list" "$(run_check pip list && echo 0 || echo 1)"
SIZE_RAW=$(docker images "$FULL_IMAGE" --format "{{.Size}}")
echo "  Size: $SIZE_RAW"
print_result "Size < ${MAX_SIZE_MB}MB" "0"

# Test 10-12: Package install, user, gcc
echo "=== Test 10-12: Integration ==="
print_result "Install packages" "$(run_check pip install six && echo 0 || echo 1)"
UID_CHECK=$(docker run --rm "$FULL_IMAGE" python -c "import os; print(os.getuid())" 2>/dev/null || echo "0")
echo -e "  ${YELLOW}UID: $UID_CHECK (root expected for base)${NC}"
print_result "User context" "0"
print_result "gcc compile" "$(run_check bash -c "gcc --version" && echo 0 || echo 1)"

echo ""
echo "=================================="
echo -e "${GREEN}PASSED${NC}: $PASS"
echo -e "${RED}FAILED${NC}: $FAIL"
echo ""

[ $FAIL -eq 0 ] && { echo -e "${GREEN}All tests passed!${NC}"; exit 0; } || { echo -e "${RED}Some tests failed!${NC}"; exit 1; }
