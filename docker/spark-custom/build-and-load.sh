#!/bin/bash
# Build and load Spark custom images to minikube

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
VERSIONS=("3.5.7" "4.1.0")

log_info() {
    echo "[INFO] $*"
}

log_error() {
    echo "[ERROR] $*" >&2
    exit 1
}

check_prereqs() {
    local missing=()

    command -v docker >/dev/null 2>&1 || missing+=("docker")
    command -v minikube >/dev/null 2>&1 || missing+=("minikube")

    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing prerequisites: ${missing[*]}"
    fi
}

build_image() {
    local version=$1
    local dockerfile="${SCRIPT_DIR}/Dockerfile.${version}"
    local image="spark-custom:${version}"

    if [ ! -f "$dockerfile" ]; then
        log_error "Dockerfile not found: $dockerfile"
    fi

    log_info "Building ${image}..."
    docker build -t "${image}" -f "${dockerfile}" "${SCRIPT_DIR}"
}

load_to_minikube() {
    local version=$1
    local image="spark-custom:${version}"

    log_info "Loading ${image} to minikube..."
    minikube image load "${image}"
}

main() {
    check_prereqs

    # Build all versions first (can be parallelized)
    for version in "${VERSIONS[@]}"; do
        build_image "${version}"
    done

    # Then load to minikube
    for version in "${VERSIONS[@]}"; do
        load_to_minikube "${version}"
    done

    log_info "Done! Images:"
    minikube image ls | grep spark-custom
}

main "$@"
