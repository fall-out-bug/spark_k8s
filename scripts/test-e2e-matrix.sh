#!/usr/bin/env bash
set -euo pipefail

PREFIX="${PREFIX:-e2e}"
SETUP="${SETUP:-true}"
CLEANUP="${CLEANUP:-false}"

RUN_JUPYTER="${RUN_JUPYTER:-true}"
RUN_AIRFLOW_CONNECT="${RUN_AIRFLOW_CONNECT:-true}"
RUN_AIRFLOW_K8S="${RUN_AIRFLOW_K8S:-true}"
RUN_AIRFLOW_OPERATOR="${RUN_AIRFLOW_OPERATOR:-true}"

usage() {
  cat <<EOF
Usage: $0 [PREFIX]

Env:
  PREFIX                Namespace/release prefix (default: e2e)
  SETUP                 Deploy charts before test (default: true)
  CLEANUP               Cleanup namespaces after test (default: false)
  RUN_JUPYTER            Run Jupyter + Connect tests (default: true)
  RUN_AIRFLOW_CONNECT    Run Airflow + Connect tests (default: true)
  RUN_AIRFLOW_K8S        Run Airflow + Spark k8s submit tests (default: true)
  RUN_AIRFLOW_OPERATOR   Run Airflow + Spark Operator tests (default: true)
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ -n "${1:-}" ]]; then
  PREFIX="${1}"
fi

if ! command -v kubectl >/dev/null 2>&1; then
  echo "ERROR: kubectl not found"
  exit 1
fi

if ! command -v helm >/dev/null 2>&1; then
  echo "ERROR: helm not found"
  exit 1
fi

if ! kubectl cluster-info >/dev/null 2>&1; then
  echo "ERROR: kubectl cannot reach cluster"
  exit 1
fi

failures=()

run_case() {
  local name="$1"
  shift
  echo ""
  echo "=== CASE: ${name} ==="
  if "$@"; then
    echo "=== CASE PASSED: ${name} ==="
  else
    echo "=== CASE FAILED: ${name} ==="
    failures+=("${name}")
  fi
}

versions=("3.5" "4.1")
for v in "${versions[@]}"; do
  suffix="${v//./}"

  if [[ "${RUN_JUPYTER}" == "true" ]]; then
    run_case "jupyter-connect-${v}-k8s" \
      BACKEND_MODE=k8s SETUP="${SETUP}" CLEANUP="${CLEANUP}" \
      ./scripts/test-e2e-jupyter-connect.sh "${PREFIX}-jc${suffix}-k" "jc${suffix}k" "${v}"

    run_case "jupyter-connect-${v}-standalone" \
      BACKEND_MODE=standalone SETUP="${SETUP}" CLEANUP="${CLEANUP}" \
      ./scripts/test-e2e-jupyter-connect.sh "${PREFIX}-jc${suffix}-s" "jc${suffix}s" "${v}"
  fi

  if [[ "${RUN_AIRFLOW_CONNECT}" == "true" ]]; then
    run_case "airflow-connect-${v}-k8s" \
      BACKEND_MODE=k8s SETUP="${SETUP}" CLEANUP="${CLEANUP}" \
      ./scripts/test-e2e-airflow-connect.sh "${PREFIX}-ac${suffix}-k" "ac${suffix}k" "${v}"

    run_case "airflow-connect-${v}-standalone" \
      BACKEND_MODE=standalone SETUP="${SETUP}" CLEANUP="${CLEANUP}" \
      ./scripts/test-e2e-airflow-connect.sh "${PREFIX}-ac${suffix}-s" "ac${suffix}s" "${v}"
  fi

  if [[ "${RUN_AIRFLOW_K8S}" == "true" ]]; then
    run_case "airflow-k8s-submit-${v}" \
      SETUP="${SETUP}" CLEANUP="${CLEANUP}" \
      ./scripts/test-e2e-airflow-k8s-submit.sh "${PREFIX}-ak${suffix}" "ak${suffix}" "${v}"
  fi

  if [[ "${RUN_AIRFLOW_OPERATOR}" == "true" ]]; then
    op_version="3.5.7"
    if [[ "${v}" == "4.1" ]]; then
      op_version="4.1.0"
    fi
    run_case "airflow-operator-${op_version}" \
      SETUP="${SETUP}" CLEANUP="${CLEANUP}" \
      ./scripts/test-e2e-airflow-operator.sh "${PREFIX}-ao${suffix}" "ao${suffix}" "${op_version}"
  fi
done

echo ""
if [[ "${#failures[@]}" -gt 0 ]]; then
  echo "FAILED CASES:"
  for f in "${failures[@]}"; do
    echo "  - ${f}"
  done
  exit 1
fi

echo "ALL CASES PASSED"
