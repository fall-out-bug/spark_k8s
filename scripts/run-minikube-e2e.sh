#!/usr/bin/env bash
# Minikube E2E Test Runner
# Runs all E2E and load tests on Minikube
# Usage: ./scripts/run-minikube-e2e.sh [options]
#
# Options:
#   --skip-setup     Skip Minikube setup
#   --skip-cleanup   Skip cleanup after tests
#   --only-e2e       Run only E2E tests
#   --only-load      Run only load tests
#   --with-parquet   Include parquet data tests
#   --spark-version  Spark version (3.5 or 4.1, default: both)
#
# Examples:
#   ./scripts/run-minikube-e2e.sh                    # Run all tests
#   ./scripts/run-minikube-e2e.sh --only-e2e         # Only E2E tests
#   ./scripts/run-minikube-e2e.sh --with-parquet     # Include parquet tests

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
source "${SCRIPT_DIR}/test-e2e-lib.sh"

# Configuration
MINIKUBE_PROFILE="${MINIKUBE_PROFILE:-spark-e2e}"
MINIKUBE_CPUS="${MINIKUBE_CPUS:-6}"
MINIKUBE_MEMORY="${MINIKUBE_MEMORY:",12288"}"
MINIKUBE_DISK="${MINIKUBE_DISK:-50g}"

# Test options
SKIP_SETUP="${SKIP_SETUP:-false}"
SKIP_CLEANUP="${SKIP_CLEANUP:-false}"
ONLY_E2E="${ONLY_E2E:-false}"
ONLY_LOAD="${ONLY_LOAD:-false}"
WITH_PARQUET="${WITH_PARQUET:-false}"
SPARK_VERSIONS="${SPARK_VERSIONS:-3.5 4.1}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --skip-setup)
      SKIP_SETUP=true
      shift
      ;;
    --skip-cleanup)
      SKIP_CLEANUP=true
      shift
      ;;
    --only-e2e)
      ONLY_E2E=true
      shift
      ;;
    --only-load)
      ONLY_LOAD=true
      shift
      ;;
    --with-parquet)
      WITH_PARQUET=true
      shift
      ;;
    --spark-version)
      SPARK_VERSIONS="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Test results tracking
declare -A TEST_RESULTS
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

run_test() {
  local name="$1"
  local cmd="$2"

  ((TESTS_TOTAL++))
  echo -e "\n${BLUE}▶ Running: ${name}${NC}"
  echo "   Command: ${cmd}"

  local start_time=$(date +%s)

  if eval "${cmd}"; then
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    echo -e "${GREEN}✓ PASSED${NC} (${duration}s)"
    TEST_RESULTS["${name}"]="PASS (${duration}s)"
    ((TESTS_PASSED++))
    return 0
  else
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    echo -e "${RED}✗ FAILED${NC} (${duration}s)"
    TEST_RESULTS["${name}"]="FAIL (${duration}s)"
    ((TESTS_FAILED++))
    return 1
  fi
}

setup_minikube() {
  echo -e "\n${BLUE}=== Setting up Minikube ===${NC}"
  echo "Profile: ${MINIKUBE_PROFILE}"
  echo "CPUs: ${MINIKUBE_CPUS}"
  echo "Memory: ${MINIKUBE_MEMORY}MB"
  echo "Disk: ${MINIKUBE_DISK}"

  # Check if Minikube is installed
  if ! command -v minikube >/dev/null 2>&1; then
    echo -e "${RED}ERROR: minikube not found${NC}"
    echo "Install from: https://minikube.sigs.k8s.io/docs/start/"
    exit 1
  fi

  # Start Minikube if not running
  if ! minikube status -p "${MINIKUBE_PROFILE}" >/dev/null 2>&1; then
    echo "Starting Minikube..."
    minikube start -p "${MINIKUBE_PROFILE}" \
      --cpus="${MINIKUBE_CPUS}" \
      --memory="${MINIKUBE_MEMORY}" \
      --disk-size="${MINIKUBE_DISK}" \
      --driver=docker \
      --container-runtime=containerd \
      --kubernetes-version=v1.28.0
  else
    echo "Minikube already running"
  fi

  # Enable ingress
  minikube addons enable ingress -p "${MINIKUBE_PROFILE}" 2>/dev/null || true

  # Configure kubectl
  minikube update-context -p "${MINIKUBE_PROFILE}"

  echo -e "${GREEN}✓ Minikube ready${NC}"
}

build_images() {
  echo -e "\n${BLUE}=== Building Docker Images ===${NC}"

  for version in ${SPARK_VERSIONS}; do
    tag=$(resolve_spark_tag "${version}")
    echo "Building Spark ${version} (tag: ${tag})..."

    if [[ "${version}" == "4.1"* ]]; then
      ensure_image "spark-custom:${tag}" "${PROJECT_DIR}/docker/spark-4.1"
      ensure_image "jupyter-spark:${tag}" "${PROJECT_DIR}/docker/jupyter-4.1" "Dockerfile"
    else
      ensure_image "spark-custom:${tag}" "${PROJECT_DIR}/docker/spark"
      ensure_image "jupyter-spark:latest" "${PROJECT_DIR}/docker/jupyter"
    fi
  done

  echo -e "${GREEN}✓ Images built${NC}"
}

load_parquet_data() {
  if [[ "${WITH_PARQUET}" != "true" ]]; then
    return
  fi

  echo -e "\n${BLUE}=== Loading Parquet Test Data ===${NC}"

  # Install Spark Connect to get MinIO
  local ns="spark-test-data"
  kubectl create namespace "${ns}" 2>/dev/null || true

  helm upgrade --install test-data charts/spark-4.1 -n "${ns}" \
    --set connect.enabled=true \
    --set spark-base.minio.enabled=true \
    --set spark-base.minio.persistence.enabled=false \
    --set jupyter.enabled=false \
    --set historyServer.enabled=false \
    --set hiveMetastore.enabled=false \
    --set spark-base.postgresql.enabled=false \
    --set security.podSecurityStandards=false \
    >/dev/null 2>&1 || true

  # Wait for MinIO
  echo "Waiting for MinIO..."
  kubectl wait --for=condition=ready pod -n "${ns}" -l app=minio --timeout=120s

  # Load parquet data
  echo "Loading NYC taxi data..."
  NAMESPACE="${ns}" "${SCRIPT_DIR}/load-nyt-parquet-data.sh" nyc 3

  echo -e "${GREEN}✓ Parquet data loaded${NC}"
}

run_e2e_tests() {
  if [[ "${ONLY_E2E}" != "true" && "${ONLY_LOAD}" == "true" ]]; then
    return
  fi

  echo -e "\n${BLUE}=== Running E2E Tests ===${NC}"

  # For each Spark version and backend combination
  for version in ${SPARK_VERSIONS}; do
    for backend in k8s standalone; do
      local test_name="E2E Spark ${version} ${backend}"
      run_test "${test_name}" \
        "BACKEND_MODE=${backend} SPARK_VERSION=${version} SETUP=true CLEANUP=true ${SCRIPT_DIR}/test-e2e-jupyter-connect.sh spark-jupyter-${version}-${backend} spark-connect"
    done
  done

  # Airflow tests
  if [[ ! "${ONLY_LOAD}" == "true" ]]; then
    for version in ${SPARK_VERSIONS}; do
      local test_name="E2E Airflow ${version}"
      run_test "${test_name}" \
        "SPARK_VERSION=${version} SETUP=true CLEANUP=true ${SCRIPT_DIR}/test-e2e-airflow-connect.sh spark-airflow-${version} spark-connect"
    done
  fi
}

run_load_tests() {
  if [[ "${ONLY_E2E}" == "true" ]]; then
    return
  fi

  echo -e "\n${BLUE}=== Running Load Tests ===${NC}"

  # Install Spark Connect for load testing
  local ns="spark-load"
  kubectl create namespace "${ns}" 2>/dev/null || true

  helm upgrade --install load-test charts/spark-4.1 -n "${ns}" \
    --set connect.enabled=true \
    --set connect.backendMode=k8s \
    --set spark-base.minio.enabled=true \
    --set spark-base.minio.persistence.enabled=false \
    --set jupyter.enabled=false \
    --set historyServer.enabled=false \
    --set hiveMetastore.enabled=false \
    --set spark-base.postgresql.enabled=false \
    --set security.podSecurityStandards=false \
    >/dev/null

  kubectl wait --for=condition=ready pod -n "${ns}" -l app=spark-connect --timeout=180s

  # Range mode load tests
  run_test "Load Test Range Mode K8s" \
    "LOAD_MODE=range LOAD_ITERATIONS=2 ${SCRIPT_DIR}/test-spark-connect-k8s-load.sh ${ns} load-test"

  # Standalone load test
  run_test "Load Test Range Mode Standalone" \
    "LOAD_MODE=range LOAD_ITERATIONS=2 ${SCRIPT_DIR}/test-spark-connect-standalone-load.sh ${ns} load-test-standalone"

  # Parquet load tests
  if [[ "${WITH_PARQUET}" == "true" ]]; then
    run_test "Load Test Parquet NYC" \
      "LOAD_MODE=parquet LOAD_DATASET=nyc LOAD_ITERATIONS=2 ${SCRIPT_DIR}/test-spark-connect-k8s-load.sh ${ns} load-test"

    run_test "Load Test Parquet Standalone" \
      "LOAD_MODE=parquet LOAD_DATASET=nyc LOAD_ITERATIONS=2 ${SCRIPT_DIR}/test-spark-connect-standalone-load.sh ${ns} load-test-standalone"
  fi
}

cleanup() {
  if [[ "${SKIP_CLEANUP}" == "true" ]]; then
    echo -e "\n${YELLOW}Skipping cleanup${NC}"
    return
  fi

  echo -e "\n${BLUE}=== Cleaning Up ===${NC}"

  # Remove test namespaces
  for ns in spark-jupyter-* spark-airflow-* spark-load spark-test-data; do
    kubectl delete namespace "${ns}" >/dev/null 2>&1 || true
  done

  echo -e "${GREEN}✓ Cleanup complete${NC}"
}

generate_report() {
  local report_file="${PROJECT_DIR}/test-results-$(date +%Y%m%d-%H%M%S).txt"

  echo -e "\n${BLUE}=== Test Report ===${NC}"
  echo "Report saved to: ${report_file}"

  {
    echo "=========================================="
    echo "Spark K8s E2E Test Report"
    echo "=========================================="
    echo "Date: $(date)"
    echo "Minikube Profile: ${MINIKUBE_PROFILE}"
    echo "Spark Versions: ${SPARK_VERSIONS}"
    echo "Parquet Tests: ${WITH_PARQUET}"
    echo ""
    echo "=========================================="
    echo "Results"
    echo "=========================================="
    echo "Total: ${TESTS_TOTAL}"
    echo "Passed: ${TESTS_PASSED}"
    echo "Failed: ${TESTS_FAILED}"
    echo ""

    if [[ ${TESTS_PASSED} -gt 0 ]]; then
      echo "=========================================="
      echo "Passed Tests"
      echo "=========================================="
      for test in "${!TEST_RESULTS[@]}"; do
        if [[ "${TEST_RESULTS[$test]}" == PASS* ]]; then
          echo "✓ ${test}: ${TEST_RESULTS[$test]}"
        fi
      done
      echo ""
    fi

    if [[ ${TESTS_FAILED} -gt 0 ]]; then
      echo "=========================================="
      echo "Failed Tests"
      echo "=========================================="
      for test in "${!TEST_RESULTS[@]}"; do
        if [[ "${TEST_RESULTS[$test]}" == FAIL* ]]; then
          echo "✗ ${test}: ${TEST_RESULTS[$test]}"
        fi
      done
      echo ""
    fi

    echo "=========================================="
    echo "All Tests"
    echo "=========================================="
    for test in "${!TEST_RESULTS[@]}"; do
      if [[ "${TEST_RESULTS[$test]}" == PASS* ]]; then
        echo "✓ ${test}: ${TEST_RESULTS[$test]}"
      else
        echo "✗ ${test}: ${TEST_RESULTS[$test]}"
      fi
    done
  } | tee "${report_file}"

  # Exit with error code if any tests failed
  if [[ ${TESTS_FAILED} -gt 0 ]]; then
    echo -e "\n${RED}=== ${TESTS_FAILED} test(s) failed ===${NC}"
    return 1
  else
    echo -e "\n${GREEN}=== All tests passed! ===${NC}"
    return 0
  fi
}

# Main execution
main() {
  echo -e "${BLUE}╔═══════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║  Spark K8s Minikube E2E Test Runner  ║${NC}"
  echo -e "${BLUE}╚═══════════════════════════════════════╝${NC}"

  # Setup
  if [[ "${SKIP_SETUP}" != "true" ]]; then
    setup_minikube
    build_images
    if [[ "${WITH_PARQUET}" == "true" ]]; then
      load_parquet_data
    fi
  fi

  # Run tests
  run_e2e_tests
  run_load_tests

  # Generate report and cleanup
  local exit_code=0
  generate_report || exit_code=$?
  cleanup || true

  exit ${exit_code}
}

main
