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

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
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

# Create unique namespace with retry mechanism
MAX_RETRIES=3
RETRY_DELAY=2
namespace_created=false

for attempt in $(seq 1 $MAX_RETRIES); do
    if kubectl create namespace "${NAMESPACE}" 2>/dev/null; then
        log_info "Created namespace: ${NAMESPACE} (attempt ${attempt}/${MAX_RETRIES})"
        namespace_created=true
        break
    else
        error_output=$(kubectl create namespace "${NAMESPACE}" 2>&1 || true)
        # Check if error is a conflict that might resolve with retry
        if echo "$error_output" | grep -qi "AlreadyExists\|conflict"; then
            if [[ $attempt -lt $MAX_RETRIES ]]; then
                log_warn "Namespace conflict detected (attempt ${attempt}/${MAX_RETRIES}), retrying in ${RETRY_DELAY}s..."
                sleep $RETRY_DELAY
                # Generate new namespace name for next retry
                NAMESPACE="spark-test-${SCENARIO_NAME}-${TIMESTAMP}-${RANDOM}"
                log_info "Trying new namespace: ${NAMESPACE}"
            else
                log_error "Failed to create namespace after ${MAX_RETRIES} attempts"
                echo "{\"status\": \"failed\", \"reason\": \"namespace_creation_failed\", \"attempts\": ${MAX_RETRIES}}" > "${RESULT_FILE}"
                exit 1
            fi
        else
            log_error "Failed to create namespace ${NAMESPACE}: ${error_output}"
            echo "{\"status\": \"failed\", \"reason\": \"namespace_creation_failed\", \"error\": \"${error_output}\"}" > "${RESULT_FILE}"
            exit 1
        fi
    fi
done

if [[ "$namespace_created" != "true" ]]; then
    log_error "Failed to create namespace after ${MAX_RETRIES} attempts"
    echo "{\"status\": \"failed\", \"reason\": \"namespace_creation_failed\", \"attempts\": ${MAX_RETRIES}}" > "${RESULT_FILE}"
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
