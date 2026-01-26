#!/usr/bin/env bash
set -euo pipefail

MINIKUBE_PROFILE="${MINIKUBE_PROFILE:-minikube}"
SKIP_IMAGE_BUILD="${SKIP_IMAGE_BUILD:-false}"

resolve_spark_tag() {
  case "$1" in
    3.5|3.5.*) echo "3.5.7" ;;
    4.1|4.1.*) echo "4.1.0" ;;
    *) echo "$1" ;;
  esac
}

minikube_running() {
  command -v minikube >/dev/null 2>&1 && minikube status -p "${MINIKUBE_PROFILE}" >/dev/null 2>&1
}

minikube_image_exists() {
  local image="$1"
  minikube image list -p "${MINIKUBE_PROFILE}" 2>/dev/null | grep -q "${image}"
}

docker_image_exists() {
  local image="$1"
  docker image inspect "${image}" >/dev/null 2>&1
}

ensure_image() {
  local image="$1"
  local context="$2"
  local dockerfile="${3:-}"

  if minikube_running && minikube_image_exists "${image}"; then
    return 0
  fi
  if ! minikube_running && docker_image_exists "${image}"; then
    return 0
  fi

  if [[ "${SKIP_IMAGE_BUILD}" == "true" ]]; then
    echo "ERROR: Image ${image} not found and SKIP_IMAGE_BUILD=true"
    exit 1
  fi

  if minikube_running; then
    if [[ -n "${dockerfile}" ]]; then
      minikube image build -p "${MINIKUBE_PROFILE}" -t "${image}" -f "${dockerfile}" "${context}"
    else
      minikube image build -p "${MINIKUBE_PROFILE}" -t "${image}" "${context}"
    fi
    return 0
  fi

  if [[ -n "${dockerfile}" ]]; then
    docker build -t "${image}" -f "${dockerfile}" "${context}"
  else
    docker build -t "${image}" "${context}"
  fi

  if command -v minikube >/dev/null 2>&1; then
    minikube image load -p "${MINIKUBE_PROFILE}" "${image}" >/dev/null
  fi
}

ensure_spark_custom_image() {
  local version="$1"
  local tag
  tag="$(resolve_spark_tag "${version}")"
  local image="spark-custom:${tag}"
  local context
  if [[ "${tag}" == "4.1.0" ]]; then
    context="$(dirname "${BASH_SOURCE[0]}")/../docker/spark-4.1"
  else
    context="$(dirname "${BASH_SOURCE[0]}")/../docker/spark"
  fi
  ensure_image "${image}" "${context}"
}

ensure_jupyter_image() {
  local version="$1"
  local tag
  tag="$(resolve_spark_tag "${version}")"
  local image="jupyter-spark:latest"
  local context
  if [[ "${tag}" == "4.1.0" ]]; then
    image="jupyter-spark:4.1.0"
    context="$(dirname "${BASH_SOURCE[0]}")/../docker/jupyter-4.1"
  else
    context="$(dirname "${BASH_SOURCE[0]}")/../docker/jupyter"
  fi
  ensure_image "${image}" "${context}"
}
