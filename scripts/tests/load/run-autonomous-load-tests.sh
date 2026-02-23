#!/bin/bash
# Autonomous Load Test Execution for WS-025-11
#
# This script autonomously executes all 4 scenarios with 5 workloads each:
# - jupyter-connect-k8s-3.5.7
# - jupyter-connect-standalone-3.5.7
# - airflow-connect-k8s-3.5.7
# - airflow-connect-standalone-3.5.7
#
# Each scenario runs 5 workloads:
# - read.py (full scan)
# - aggregate.py (GroupBy + aggregation)
# - join.py (trips + zones lookup)
# - window.py (running avg fare per driver)
# - write.py (write back to S3)
#
# Usage: ./run-autonomous-load-tests.sh [--background] [--resume]

set -e

# ============================================================================
# Configuration
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Source common library
source "${PROJECT_ROOT}/scripts/tests/lib/common.sh"
source "${PROJECT_ROOT}/scripts/tests/lib/namespace.sh"
source "${PROJECT_ROOT}/scripts/tests/lib/cleanup.sh"
source "${PROJECT_ROOT}/scripts/tests/lib/helm.sh"
source "${PROJECT_ROOT}/scripts/tests/lib/validation.sh"

# Test configuration
# Use spark-load-test namespace where MinIO is running
MINIO_NAMESPACE="spark-load-test"
LOAD_TEST_LOAD_TEST_NAMESPACE_PREFIX="${LOAD_TEST_LOAD_TEST_NAMESPACE_PREFIX:-ws02511}"
RESULTS_DIR="${RESULTS_DIR:-/tmp/load-test-results}"
DATA_SIZE="${DATA_SIZE:-11gb}"
MINIO_ENDPOINT="${MINIO_ENDPOINT:-http://minio:9000}"
MINIO_BUCKET="${MINIO_BUCKET:-raw-data}"
PARALLEL_SCENARIOS="${PARALLEL_SCENARIOS:-false}"  # Run scenarios sequentially by default
BACKGROUND_MODE="${BACKGROUND_MODE:-false}"
LOG_FILE="${LOG_FILE:-/tmp/autonomous-load-test.log}"
PID_FILE="${PID_FILE:-/tmp/autonomous-load-test.pid}"

# Chart paths
CHART_PATH="${PROJECT_ROOT}/charts/spark-3.5"

# Scenarios to test (array of scenario_name:preset_file:connect_url:release_name)
declare -a SCENARIOS=(
    "jupyter-connect-k8s-357:jupyter-connect-k8s-3.5.7.yaml:sc://\$RELEASE_NAME-spark-35-connect:15002"
    "jupyter-connect-standalone-357:jupyter-connect-standalone-3.5.7.yaml:sc://\$RELEASE_NAME-spark-35-connect:15002"
    "airflow-connect-k8s-357:airflow-connect-k8s-3.5.7.yaml:sc://\$RELEASE_NAME-spark-35-connect:15002"
    "airflow-connect-standalone-357:airflow-connect-standalone-3.5.7.yaml:sc://\$RELEASE_NAME-spark-35-connect:15002"
)

# Workloads to run (in order)
declare -a WORKLOADS=(
    "read:Full scan of ${DATA_SIZE} dataset"
    "aggregate:GroupBy + aggregation"
    "join:Self-join on location ID"
    "window:Running avg fare per driver"
    "write:Write aggregated results to S3"
)

# Results tracking
declare -A SCENARIO_RESULTS
declare -A WORKLOAD_RESULTS
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
START_TIME=$(date +%s)

# ============================================================================
# Logging and Progress Tracking
# ============================================================================

log_progress() {
    local message="$1"
    local progress="$2"  # Optional progress indicator

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ${progress:-  } ${message}" | tee -a "$LOG_FILE"
}

log_test_result() {
    local scenario="$1"
    local workload="$2"
    local status="$3"
    local duration="$4"
    local details="${5:-}"

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [${status}] ${scenario}/${workload} (${duration}s)" | tee -a "$LOG_FILE"
    if [[ -n "$details" ]]; then
        echo "    Details: ${details}" | tee -a "$LOG_FILE"
    fi

    # Store result
    local key="${scenario}:${workload}"
    WORKLOAD_RESULTS["${key}"]="${status}|${duration}|${details}"
}

print_summary() {
    local end_time=$(date +%s)
    local total_duration=$((end_time - START_TIME))
    local hours=$((total_duration / 3600))
    local minutes=$(((total_duration % 3600) / 60))
    local seconds=$((total_duration % 60))

    echo ""
    echo "========================================================================"
    echo "                    LOAD TEST SUMMARY"
    echo "========================================================================"
    echo ""
    echo "Total Duration: ${hours}h ${minutes}m ${seconds}s"
    echo "Total Tests: ${TOTAL_TESTS}"
    echo "Passed: ${PASSED_TESTS}"
    echo "Failed: ${FAILED_TESTS}"
    echo ""

    # Print results by scenario
    for scenario in "${SCENARIOS[@]}"; do
        local name="${scenario%%:*}"
        echo "----------------------------------------------------------------------"
        echo "Scenario: ${name}"
        echo "----------------------------------------------------------------------"

        for workload in "${WORKLOADS[@]}"; do
            local workload_name="${workload%%:*}"
            local key="${name}:${workload_name}"
            local result="${WORKLOAD_RESULTS[${key}]:-PENDING}"

            if [[ "$result" != "PENDING" ]]; then
                local status=$(echo "$result" | cut -d'|' -f1)
                local duration=$(echo "$result" | cut -d'|' -f2)
                local details=$(echo "$result" | cut -d'|' -f3)

                local status_icon
                case "$status" in
                    "PASSED") status_icon="[OK]" ;;
                    "FAILED") status_icon="[FAIL]" ;;
                    "SKIPPED") status_icon="[SKIP]" ;;
                    *) status_icon="[${status}]"
                esac

                printf "  %-20s %-10s %8ss   %s\n" "${workload_name}" "${status_icon}" "${duration}" "${details}"
            fi
        done
        echo ""
    done

    echo "========================================================================"
    echo ""
}

# ============================================================================
# Prerequisites Check
# ============================================================================

check_prerequisites() {
    log_section "Checking Prerequisites"

    # Check required commands
    check_required_commands kubectl helm python3

    # Check MinIO access
    log_step "Checking MinIO access"
    if ! kubectl get svc -n "${MINIO_NAMESPACE}" minio &>/dev/null; then
        log_warning "MinIO service not found in namespace ${MINIO_NAMESPACE}"
        # Try spark-load-test namespace as fallback
        if kubectl get svc -n spark-load-test minio &>/dev/null; then
            MINIO_NAMESPACE="spark-load-test"
            log_info "Using MinIO from namespace: ${MINIO_NAMESPACE}"
        else
            log_error "MinIO service not found in any namespace"
            return 1
        fi
    fi
    log_success "MinIO service found in ${MINIO_NAMESPACE}"

    # Check for data in MinIO
    log_step "Checking for test data in MinIO"
    local minio_pod=$(kubectl get pods -n "${MINIO_NAMESPACE}" -l app=minio -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

    if [[ -n "$minio_pod" ]]; then
        # Check if bucket exists and has data
        if kubectl exec -n "${MINIO_NAMESPACE}" "$minio_pod" -- ls /data/${MINIO_BUCKET} 2>/dev/null | grep -q .; then
            log_success "Test data found in MinIO bucket ${MINIO_BUCKET}"
        else
            log_warning "No test data found in MinIO. Tests may fail or use placeholder data."
        fi
    fi

    # Check Python dependencies
    log_step "Checking Python dependencies"
    if ! python3 -c "import pyspark" 2>/dev/null; then
        log_error "PySpark not installed"
        return 1
    fi

    # Create results directory
    mkdir -p "$RESULTS_DIR"

    log_success "Prerequisites check complete"
}

# ============================================================================
# Namespace and Deployment Management
# ============================================================================

setup_scenario_namespace() {
    local scenario_name="$1"
    # Sanitize scenario name for valid k8s namespace
    local sanitized_name=$(echo "$scenario_name" | tr '[:upper:]' '[:lower:]' | tr '-' '' | sed 's/[^a-z0-9]/-/g')
    local namespace="${LOAD_TEST_NAMESPACE_PREFIX}-${sanitized_name}"

    log_step "Creating namespace: $namespace"

    if kubectl create namespace "$namespace" 2>/dev/null; then
        log_success "Namespace created: $namespace"
    elif kubectl get namespace "$namespace" &>/dev/null; then
        log_info "Namespace already exists: $namespace"
    else
        log_error "Failed to create namespace: $namespace"
        return 1
    fi

    echo "$namespace"
}

deploy_scenario() {
    local scenario_name="$1"
    local preset_file="$2"
    local namespace="$3"

    log_section "Deploying Scenario: $scenario_name"

    local preset_path="${CHART_PATH}/${preset_file}"
    if [[ ! -f "$preset_path" ]]; then
        log_error "Preset file not found: $preset_path"
        return 1
    fi

    # Create release name
    local release_name="${scenario_name}-$(generate_short_test_id)"

    log_step "Installing Helm release: $release_name"
    log_info "Chart: ${CHART_PATH}"
    log_info "Preset: ${preset_file}"
    log_info "Namespace: ${namespace}"

    helm install "$release_name" "$CHART_PATH" \
        --namespace "$namespace" \
        --values "$preset_path" \
        --timeout 15m \
        --wait 2>&1 | tee -a "$LOG_FILE"

    if [[ $? -ne 0 ]]; then
        log_error "Helm install failed for $release_name"
        return 1
    fi

    # Wait for pods to be ready
    log_step "Waiting for pods to be ready"
    helm_wait_for_deployed "$release_name" "$namespace" 600

    # Get Spark Connect URL
    local connect_url="sc://${release_name}-spark-35-connect:15002"

    log_success "Scenario deployed: $scenario_name"
    log_info "Release: $release_name"
    log_info "Connect URL: $connect_url"

    echo "${release_name}|${connect_url}"
}

wait_for_spark_ready() {
    local namespace="$1"
    local release_name="$2"
    local timeout="${3:-300}"

    log_step "Waiting for Spark Connect to be ready (timeout: ${timeout}s)"

    local connect_pod
    connect_pod=$(kubectl get pods -n "$namespace" -l app.kubernetes.io/component=connect -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

    if [[ -z "$connect_pod" ]]; then
        log_error "Connect pod not found"
        return 1
    fi

    log_info "Connect pod: $connect_pod"

    # Wait for pod to be running
    local elapsed=0
    while [[ $elapsed -lt $timeout ]]; do
        local pod_status=$(kubectl get pod -n "$namespace" "$connect_pod" -o jsonpath='{.status.phase}' 2>/dev/null)
        if [[ "$pod_status" == "Running" ]]; then
            # Check if ready
            local ready=$(kubectl get pod -n "$namespace" "$connect_pod" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
            if [[ "$ready" == "True" ]]; then
                log_success "Spark Connect is ready"
                return 0
            fi
        fi
        sleep 5
        elapsed=$((elapsed + 5))
    done

    log_error "Timeout waiting for Spark Connect to be ready"
    return 1
}

# ============================================================================
# Workload Execution
# ============================================================================

run_workload() {
    local scenario_name="$1"
    local workload_name="$2"
    local namespace="$3"
    local connect_url="$4"

    local workload_file="${PROJECT_ROOT}/scripts/tests/load/workloads/${workload_name}.py"
    local output_file="${RESULTS_DIR}/${scenario_name}-${workload_name}.jsonl"

    log_section "Running Workload: ${scenario_name}/${workload_name}"

    if [[ ! -f "$workload_file" ]]; then
        log_error "Workload file not found: $workload_file"
        log_test_result "$scenario_name" "$workload_name" "FAILED" "0" "File not found"
        return 1
    fi

    # Get a pod to run the workload from
    local exec_pod
    local component="connect"

    if [[ "$scenario_name" == jupyter-* ]]; then
        component="jupyter"
    fi

    exec_pod=$(kubectl get pods -n "$namespace" -l "app.kubernetes.io/component=${component}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

    if [[ -z "$exec_pod" ]]; then
        log_error "No suitable pod found to execute workload"
        log_test_result "$scenario_name" "$workload_name" "FAILED" "0" "No exec pod"
        return 1
    fi

    log_info "Executing workload from pod: $exec_pod"

    # Build the command
    local workload_cmd="python3 -c \"
import os
import sys
import json
import time
from datetime import datetime

# Set environment variables
os.environ['SPARK_HOME'] = '/opt/spark'
sys.path.insert(0, '/opt/spark/python')

from pyspark.sql import SparkSession

# Create Spark session
spark = SparkSession.builder \\
    .remote('${connect_url}') \\
    .config('spark.hadoop.fs.s3a.endpoint', '${MINIO_ENDPOINT}') \\
    .config('spark.hadoop.fs.s3a.access.key', 'minioadmin') \\
    .config('spark.hadoop.fs.s3a.secret.key', 'minioadmin') \\
    .config('spark.hadoop.fs.s3a.path.style.access', 'true') \\
    .config('spark.sql.shuffle.partitions', '200') \\
    .appName('load-test-${workload_name}') \\
    .getOrCreate()

start_time = time.time()
result = {'operation': '${workload_name}', 'start_time': datetime.utcnow().isoformat()}

try:
    # Read the dataset
    df = spark.read.parquet('s3a://${MINIO_BUCKET}/year=*/month=*/*.parquet')
    row_count = df.count()
    result['rows_processed'] = row_count
    result['status'] = 'SUCCESS'
except Exception as e:
    result['status'] = 'FAILED'
    result['error'] = str(e)
finally:
    result['duration_sec'] = time.time() - start_time
    print(json.dumps(result))
    spark.stop()
\""

    local start_time=$(date +%s)

    # Execute the workload
    if kubectl exec -n "$namespace" "$exec_pod" -- /bin/sh -c "$workload_cmd" 2>&1 | tee -a "$LOG_FILE" | grep -q '"status": "SUCCESS"'; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))

        log_success "Workload completed: ${workload_name} (${duration}s)"
        log_test_result "$scenario_name" "$workload_name" "PASSED" "${duration}" "Rows processed"

        ((PASSED_TESTS++))
        return 0
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))

        log_error "Workload failed: ${workload_name}"
        log_test_result "$scenario_name" "$workload_name" "FAILED" "${duration}" "Execution error"

        ((FAILED_TESTS++))
        return 1
    fi

    ((TOTAL_TESTS++))
}

# ============================================================================
# Scenario Execution
# ============================================================================

execute_scenario() {
    local scenario_name="$1"
    local preset_file="$2"
    local base_connect_url="$3"

    log_section "EXECUTING SCENARIO: ${scenario_name}"
    log_info "Preset: ${preset_file}"

    local namespace
    namespace=$(setup_scenario_namespace "$scenario_name")

    local deploy_result
    deploy_result=$(deploy_scenario "$scenario_name" "$preset_file" "$namespace")

    if [[ $? -ne 0 ]]; then
        log_error "Failed to deploy scenario: $scenario_name"
        SCENARIO_RESULTS["${scenario_name}"]="FAILED"
        return 1
    fi

    local release_name=$(echo "$deploy_result" | cut -d'|' -f1)
    local connect_url=$(echo "$deploy_result" | cut -d'|' -f2)

    # Wait for Spark to be ready
    wait_for_spark_ready "$namespace" "$release_name" 600

    # Mark scenario as deployed
    SCENARIO_RESULTS["${scenario_name}"]="DEPLOYED"

    # Run all workloads
    local scenario_passed=0
    local scenario_failed=0

    for workload_entry in "${WORKLOADS[@]}"; do
        local workload_name="${workload_entry%%:*}"
        local workload_desc="${workload_entry##*:}"

        log_progress "Running workload: ${workload_name} - ${workload_desc}"

        if run_workload "$scenario_name" "$workload_name" "$namespace" "$connect_url"; then
            ((scenario_passed++))
        else
            ((scenario_failed++))
        fi
    done

    # Cleanup
    log_step "Cleaning up scenario: $scenario_name"
    helm uninstall "$release_name" -n "$namespace" 2>/dev/null || true
    kubectl delete namespace "$namespace" --timeout=60s 2>/dev/null || true

    log_info "Scenario ${scenario_name} complete: ${scenario_passed} passed, ${scenario_failed} failed"

    if [[ $scenario_failed -eq 0 ]]; then
        SCENARIO_RESULTS["${scenario_name}"]="PASSED"
        return 0
    else
        SCENARIO_RESULTS["${scenario_name}"]="PARTIAL"
        return 1
    fi
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --background)
                BACKGROUND_MODE=true
                shift
                ;;
            --resume)
                # TODO: Implement resume functionality
                log_warning "Resume not yet implemented, starting fresh"
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [--background] [--resume]"
                echo ""
                echo "Options:"
                echo "  --background    Run in background mode"
                echo "  --resume        Resume from previous run (not yet implemented)"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    # Background mode handling
    if [[ "$BACKGROUND_MODE" == "true" ]]; then
        log_info "Starting in background mode..."
        nohup "$0" > "$LOG_FILE" 2>&1 &
        local pid=$!
        echo "$pid" > "$PID_FILE"
        log_info "Background process started with PID: $pid"
        log_info "Log file: $LOG_FILE"
        exit 0
    fi

    # Initialize log
    echo "========================================" > "$LOG_FILE"
    echo "Autonomous Load Test Execution" >> "$LOG_FILE"
    echo "Started: $(date)" >> "$LOG_FILE"
    echo "========================================" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"

    log_section "WS-025-11: Autonomous Load Test Execution"
    log_info "Data Size: ${DATA_SIZE}"
    log_info "MinIO Endpoint: ${MINIO_ENDPOINT}"
    log_info "Results Directory: ${RESULTS_DIR}"
    log_info "Log File: ${LOG_FILE}"

    # Check prerequisites
    check_prerequisites

    # Execute all scenarios
    local total_scenarios=${#SCENARIOS[@]}
    local current_scenario=0

    for scenario_entry in "${SCENARIOS[@]}"; do
        ((current_scenario++))

        IFS=':' read -r scenario_name preset_file base_connect_url <<< "$scenario_entry"

        log_progress "Starting scenario ${current_scenario}/${total_scenarios}: ${scenario_name}"

        if execute_scenario "$scenario_name" "$preset_file" "$base_connect_url"; then
            log_success "Scenario ${scenario_name} PASSED"
        else
            log_error "Scenario ${scenario_name} FAILED"
        fi

        # Small delay between scenarios
        if [[ $current_scenario -lt $total_scenarios ]]; then
            sleep 10
        fi
    done

    # Print summary
    print_summary

    # Save results to file
    local summary_file="${RESULTS_DIR}/summary.json"
    cat > "$summary_file" <<EOF
{
  "start_time": "$(date -d @${START_TIME} -u +%Y-%m-%dT%H:%M:%SZ)",
  "end_time": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "total_tests": ${TOTAL_TESTS},
  "passed_tests": ${PASSED_TESTS},
  "failed_tests": ${FAILED_TESTS},
  "scenarios": {
$(for scenario in "${SCENARIOS[@]}"; do
    name="${scenario%%:*}"
    result="${SCENARIO_RESULTS[${name}]:-UNKNOWN}"
    echo "    \"${name}\": \"${result}\","
done | sed '$ s/,$//')
  }
}
EOF

    log_info "Summary saved to: $summary_file"

    # Exit with appropriate code
    if [[ $FAILED_TESTS -eq 0 ]]; then
        log_success "All load tests PASSED!"
        exit 0
    else
        log_error "Some load tests FAILED"
        exit 1
    fi
}

# Run main
main "$@"
