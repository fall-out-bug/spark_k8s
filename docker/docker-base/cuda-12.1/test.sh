#!/bin/bash
IMAGE_NAME="${IMAGE_NAME:-spark-k8s-cuda-12.1-base}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
FULL_IMAGE="${IMAGE_NAME}:${IMAGE_TAG}"
MAX_SIZE_GB=4

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
PASSED=0; FAILED=0; SKIPPED=0

log() { local lvl=$1; shift; echo -e "${!lvl}[$1]${NC} ${2:-$3}"; }
pass() { log GREEN PASS "$1"; ((PASSED++)); return 0; }
fail() { log RED FAIL "$1"; ((FAILED++)); return 0; }
skip() { log YELLOW SKIP "$1"; ((SKIPPED++)); return 0; }
info() { log BLUE INFO "$1"; }

check_gpu() {
    docker run --rm --gpus all "$FULL_IMAGE" bash -c "nvidia-smi &>/dev/null && nvidia-smi | grep -q 'CUDA Version: 12.1'" 2>/dev/null
}

build() {
    info "Building: $FULL_IMAGE"
    if docker build -t "$FULL_IMAGE" . &>/dev/null; then
        pass "Image built"
        return 0
    else
        fail "Build failed"
        return 1
    fi
}

test_cuda() {
    info "Testing CUDA version..."
    local out=$(docker run --rm "$FULL_IMAGE" bash -c "cat /usr/local/cuda/version.txt 2>/dev/null || nvidia-smi 2>&1 || true")
    if echo "$out" | grep -q "12.1"; then pass "CUDA 12.1 detected";
    else fail "CUDA 12.1 not found"; fi
}

test_java() {
    info "Testing Java version..."
    local out=$(docker run --rm "$FULL_IMAGE" java -version 2>&1)
    if echo "$out" | grep -q "version \"17"; then pass "Java 17 detected";
    else fail "Java 17 not found"; echo "$out"; fi
}

test_utils() {
    info "Testing utilities..."
    docker run --rm "$FULL_IMAGE" curl --version &>/dev/null && pass "curl" || fail "curl missing"
    docker run --rm "$FULL_IMAGE" bash --version &>/dev/null && pass "bash" || fail "bash missing"
    docker run --rm "$FULL_IMAGE" ls /etc/ssl/certs/ca-certificates.crt &>/dev/null && pass "ca-certificates" || fail "ca-certificates missing"
}

test_size() {
    info "Testing image size..."
    local sz=$(docker image inspect "$FULL_IMAGE" --format='{{.Size}}')
    local gb=$(echo "scale=2; $sz / 1024 / 1024 / 1024" | bc)
    local gbi=$(echo "$gb" | cut -d. -f1)
    info "Image size: ${gb}GB"
    if [ "$gbi" -lt "$MAX_SIZE_GB" ]; then pass "Size ${gb}GB < ${MAX_SIZE_GB}GB"; else fail "Size ${gb}GB >= ${MAX_SIZE_GB}GB"; fi
}

test_libs() {
    info "Testing CUDA libraries..."
    docker run --rm "$FULL_IMAGE" bash -c "ls /usr/local/cuda/lib64/libcudart.so.* 2>/dev/null || ls /usr/local/cuda/compat/libcuda.so.* 2>/dev/null" &>/dev/null && pass "CUDA runtime library" || fail "CUDA runtime library missing"
}

test_workdir() {
    info "Testing working directory..."
    local out=$(docker run --rm --entrypoint "" "$FULL_IMAGE" pwd)
    [ "$out" = "/workspace" ] && pass "Working directory is /workspace" || fail "Got: $out"
}

test_gpu() {
    info "Checking GPU availability for nvidia-smi test..."
    if check_gpu; then
        pass "GPU available with CUDA 12.1"
        info "Testing nvidia-smi with GPU..."
        docker run --rm --gpus all "$FULL_IMAGE" bash -c "nvidia-smi &>/dev/null" && pass "nvidia-smi with GPU" || fail "nvidia-smi failed"
    else
        skip "GPU not available (nvidia-smi test skipped)"
    fi
}

main() {
    echo "=========================================="
    echo "  CUDA 12.1 Base Image Test Suite"
    echo "=========================================="
    echo ""
    cd "$(dirname "$0")"
    build || exit 1
    echo ""; echo "Running tests..."; echo ""
    test_cuda; test_java; test_utils; test_size; test_libs; test_workdir; test_gpu
    echo ""
    echo "=========================================="
    echo "  Test Summary"
    echo "=========================================="
    echo -e "  ${GREEN}Passed:${NC}  $PASSED"
    echo -e "  ${YELLOW}Skipped:${NC} $SKIPPED"
    echo -e "  ${RED}Failed:${NC}  $FAILED"
    echo "=========================================="
    [ $FAILED -eq 0 ] && echo -e "${GREEN}All tests passed!${NC}" && exit 0 || echo -e "${RED}Some tests failed!${NC}" && exit 1
}

main "$@"
