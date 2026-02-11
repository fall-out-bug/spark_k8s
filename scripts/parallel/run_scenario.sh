#!/bin/bash
# Run a single test scenario in isolated namespace
#
# Usage: (internal - called by run_parallel.sh)
#   ./run_scenario.sh <scenario_script> <results_dir> <timestamp>

set -euo pipefail

SCENARIO_SCRIPT=$1
RESULTS_DIR=$2
TIMESTAMP=$3

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

SCENARIO_NAME=$(basename "${SCENARIO_SCRIPT}" .sh)
NAMESPACE="spark-test-${SCENARIO_NAME}-${TIMESTAMP}-${RANDOM}"
RELEASE_NAME="spark-${SCENARIO_NAME}-${RANDOM}"
RESULT_FILE="${RESULTS_DIR}/${SCENARIO_NAME}.json"
LOG_FILE="${RESULTS_DIR}/${SCENARIO_NAME}.log"

# Redirect output to log file
exec > >(tee -a "${LOG_FILE}") 2>&1

echo "========================================"
log_info "Running scenario: ${SCENARIO_NAME}"
echo "Namespace: ${NAMESPACE}"
echo "Release: ${RELEASE_NAME}"
echo "========================================"

# Create unique namespace
if kubectl create namespace "${NAMESPACE}" 2>/dev/null; then
    log_info "Created namespace: ${NAMESPACE}"
else
    log_error "Failed to create namespace ${NAMESPACE}"
    echo "{\"status\": \"failed\", \"reason\": \"namespace_creation_failed\"}" > "${RESULT_FILE}"
    exit 1
fi

# Track namespace for cleanup
echo "${NAMESPACE}" >> "${RESULTS_DIR}/namespaces.txt"

# Run scenario
exit_code=0
START_TIME=$(date +%s)

if "${SCENARIO_SCRIPT}" "${NAMESPACE}" "${RELEASE_NAME}"; then
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    cat > "${RESULT_FILE}" <<EOF
{
  "scenario": "${SCENARIO_NAME}",
  "namespace": "${NAMESPACE}",
  "status": "passed",
  "exit_code": 0,
  "duration": ${DURATION},
  "timestamp": $(date +%s)
}
EOF
    log_info "Scenario PASSED (${DURATION}s)"
else
    exit_code=$?
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    cat > "${RESULT_FILE}" <<EOF
{
  "scenario": "${SCENARIO_NAME}",
  "namespace": "${NAMESPACE}",
  "status": "failed",
  "exit_code": ${exit_code},
  "duration": ${DURATION},
  "timestamp": $(date +%s)
}
EOF
    log_error "Scenario FAILED (exit code: ${exit_code}, ${DURATION}s)"
fi

echo "========================================"
exit ${exit_code}
