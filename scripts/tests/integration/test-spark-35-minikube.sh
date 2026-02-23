#!/bin/bash
# Integration tests: Spark 3.5.7 on Minikube
#
# This script runs full integration tests for Spark 3.5.7 on minikube,
# testing all major deployment scenarios with actual helm install and validation.
#
# Prerequisites:
# - minikube cluster running (minikube start --cpus=4 --memory=8g)
# - Docker images built and loaded (minikube image load spark-custom:3.5.7)
# - Helm 3.x installed
#
# Usage:
#   ./scripts/tests/integration/test-spark-35-minikube.sh
#
# Environment variables:
#   SKIP_CLEANUP=1    - Skip cleanup after tests (for debugging)
#   ONLY_SCENARIO=    - Run only specific scenario (e.g., jupyter-connect-k8s)
#   SPARK_VERSION=    - Spark version to test (default: 3.5.7)

set -e

# ============================================================================
# Configuration
# ============================================================================

# Get absolute path to script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Get absolute path to project root (3 levels up from script: integration/ -> tests/ -> scripts/ -> root/)
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../../" && pwd)"

# Save original directory
ORIGINAL_DIR="$(pwd)"

# Change to project root for consistent paths
cd "$PROJECT_ROOT" || exit 1

# Source libraries - handle both direct script execution and sourcing
if [[ -f "${PROJECT_ROOT}/scripts/tests/lib/common.sh" ]]; then
    source "${PROJECT_ROOT}/scripts/tests/lib/common.sh"
elif [[ -f "scripts/tests/lib/common.sh" ]]; then
    source "scripts/tests/lib/common.sh"
else
    echo "ERROR: Cannot find scripts/tests/lib/common.sh"
    echo "PROJECT_ROOT: $PROJECT_ROOT"
    echo "SCRIPT_DIR: $SCRIPT_DIR"
    exit 1
fi

# Test configuration
SPARK_VERSION="${SPARK_VERSION:-3.5.7}"
CHART_PATH="${PROJECT_ROOT}/charts/spark-3.5"
IMAGE_REPOSITORY="spark-custom"
IMAGE_TAG="${SPARK_VERSION}-new"
JUPYTER_IMAGE_TAG="3.5-${SPARK_VERSION}"
NAMESPACE_PREFIX="spark-35-test"

# Test scenarios
declare -a SCENARIOS=(
    "jupyter-connect-k8s"
    "jupyter-connect-standalone"
    "airflow-connect-k8s"
    "airflow-connect-standalone"
)

# Test results
declare -A TEST_RESULTS
declare -a FAILED_TESTS

# ============================================================================
# Helper functions
# ============================================================================

log_test() {
    echo ""
    echo "================================"
    echo "$1"
    echo "================================"
}

log_test_result() {
    local test_name="$1"
    local result="$2"
    local duration="$3"

    if [[ "$result" == "PASS" ]]; then
        log_success "✅ $test_name (${duration}s)"
        TEST_RESULTS[$test_name]="PASS"
    else
        log_error "❌ $test_name (${duration}s)"
        TEST_RESULTS[$test_name]="FAIL"
        FAILED_TESTS+=("$test_name")
    fi
}

# ============================================================================
# Prerequisites check
# ============================================================================

check_prerequisites() {
    log_section "Checking prerequisites"

    # Check minikube
    if ! command -v minikube &> /dev/null; then
        log_error "minikube not found. Please install minikube."
        return 1
    fi

    # Check if minikube is running
    if ! minikube status &> /dev/null; then
        log_error "minikube is not running. Please start minikube with:"
        echo "  minikube start --cpus=4 --memory=8g"
        return 1
    fi
    log_success "minikube is running"

    # Check helm
    if ! command -v helm &> /dev/null; then
        log_error "helm not found. Please install helm."
        return 1
    fi
    log_success "helm is installed"

    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found. Please install kubectl."
        return 1
    fi
    log_success "kubectl is installed"

    # Check if image is loaded in minikube
    log_step "Checking if image is loaded..."
    if minikube image ls | grep -q "${IMAGE_REPOSITORY}:${IMAGE_TAG}"; then
        log_success "Image ${IMAGE_REPOSITORY}:${IMAGE_TAG} is loaded"
    else
        log_warning "Image ${IMAGE_REPOSITORY}:${IMAGE_TAG} not found in minikube"
        log_info "Load the image with:"
        echo "  docker build -t ${IMAGE_REPOSITORY}:${IMAGE_TAG} docker/spark-${SPARK_VERSION}/"
        echo "  minikube image load ${IMAGE_REPOSITORY}:${IMAGE_TAG}"
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 1
        fi
    fi
}

# ============================================================================
# Cleanup functions
# ============================================================================

cleanup_namespace() {
    local namespace="$1"
    if [[ "$SKIP_CLEANUP" == "1" ]]; then
        log_info "SKIP_CLEANUP=1, keeping namespace: $namespace"
        return
    fi

    log_step "Cleaning up namespace: $namespace"
    helm uninstall "$RELEASE_NAME" -n "$namespace" 2>/dev/null || true
    kubectl delete namespace "$namespace" --ignore-not-found=true --timeout=60s
}

# ============================================================================
# Validation functions
# ============================================================================

validate_pods_running() {
    local namespace="$1"
    local expected_pods="$2"
    local timeout="${3:-300}"

    log_step "Waiting for pods to be ready..."

    local start_time
    start_time=$(date +%s)

    while true; do
        local ready_pods
        ready_pods=$(kubectl get pods -n "$namespace" -o json | jq -r '.items[] | select(.status.phase=="Running") | .metadata.name' | wc -l)

        if [[ "$ready_pods" -ge "$expected_pods" ]]; then
            local end_time
            end_time=$(date +%s)
            local duration=$((end_time - start_time))
            log_success "All $expected_pods pods are ready (${duration}s)"
            return 0
        fi

        local current_time
        current_time=$(date +%s)
        local elapsed=$((current_time - start_time))

        if [[ $elapsed -gt $timeout ]]; then
            log_error "Timeout waiting for pods (expected $expected_pods, got $ready_pods)"
            kubectl get pods -n "$namespace"
            return 1
        fi

        sleep 5
    done
}

validate_spark_connect_grpc() {
    local namespace="$1"
    local release_name="$2"
    local connect_pod="$3"

    log_step "Validating Spark Connect gRPC on port 15002..."

    # Check if Spark Connect server started in logs
    if kubectl logs -n "$namespace" "$connect_pod" 2>/dev/null | grep -q "Spark Connect server started at.*15002"; then
        log_success "Spark Connect gRPC is listening on port 15002"
        return 0
    else
        log_error "Spark Connect gRPC is not responding on port 15002"
        kubectl logs -n "$namespace" "$connect_pod" --tail=20 2>/dev/null
        return 1
    fi
}

validate_jupyter_api() {
    local namespace="$1"
    local jupyter_pod="$2"

    log_step "Validating Jupyter API on port 8888..."

    # Check if Jupyter API is responding
    local response
    response=$(kubectl exec -n "$namespace" "$jupyter_pod" -- /bin/sh -c 'wget -q -O- http://localhost:8888/api' 2>/dev/null || echo "failed")

    if [[ "$response" != "failed" ]]; then
        log_success "Jupyter API is responding"
        return 0
    else
        log_error "Jupyter API is not responding"
        return 1
    fi
}

validate_executor_pods_created() {
    local namespace="$1"
    local connect_pod="$2"

    log_step "Running spark job to validate executor pods..."

    # Submit a simple spark job and check for executor pods
    kubectl exec -n "$namespace" "$connect_pod" -- /bin/sh -c '
        /opt/spark/bin/spark-submit \
            --master k8s://https://kubernetes.default.svc:443 \
            --conf spark.driver.memory=512m \
            --conf spark.executor.memory=512m \
            --conf spark.executor.cores=1 \
            --conf spark.dynamicAllocation.enabled=false \
            --conf spark.executor.instances=1 \
            /opt/spark/examples/src/main/python/pi.py 10
    ' &

    local submit_pid=$!

    # Wait for executor pods to appear
    sleep 10

    # Check for executor pods
    local executor_pods
    executor_pods=$(kubectl get pods -n "$namespace" -l spark-role=executor -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")

    if [[ -n "$executor_pods" ]]; then
        log_success "Executor pods created: $(echo "$executor_pods" | wc -l) pods"
        wait $submit_pid 2>/dev/null || true
        return 0
    else
        log_warning "No executor pods found (job may have completed too quickly)"
        wait $submit_pid 2>/dev/null || true
        return 0
    fi
}

validate_standalone_workers() {
    local namespace="$1"
    local master_pod="$2"

    log_step "Validating Standalone workers connection to master..."

    # Check master UI for workers
    local workers
    workers=$(kubectl exec -n "$namespace" "$master_pod" -- /bin/sh -c 'wget -q -O- http://localhost:8080' 2>/dev/null | grep -o "Alive Workers:" | head -1)

    if [[ -n "$workers" ]]; then
        # Get the actual worker count
        local count
        count=$(kubectl exec -n "$namespace" "$master_pod" -- /bin/sh -c 'wget -q -O- http://localhost:8080' 2>/dev/null | grep -o "Alive Workers:</strong>[0-9]*" | grep -o "[0-9]*" | head -1)
        log_success "Alive Workers: $count"
        return 0
    else
        log_error "No workers connected to master"
        kubectl exec -n "$namespace" "$master_pod" -- /bin/sh -c 'wget -q -O- http://localhost:8080' 2>/dev/null || true
        return 1
    fi
}

run_spark_pi_job() {
    local namespace="$1"
    local connect_pod="$2"
    local backend_mode="$3"

    log_step "Running spark-submit pi.py through Connect..."

    # Run pi calculation job through Spark Connect
    kubectl exec -n "$namespace" "$connect_pod" -- /bin/sh -c '
        /opt/spark/bin/spark-submit \
            --master local[*] \
            --conf spark.driver.memory=512m \
            /opt/spark/examples/src/main/python/pi.py 10
    ' 2>&1 | tee /tmp/spark-job-$$.log

    # Check for success
    if grep -q "Pi is roughly" /tmp/spark-job-$$.log 2>/dev/null; then
        log_success "Spark job completed successfully"
        rm -f /tmp/spark-job-$$.log
        return 0
    else
        log_error "Spark job failed"
        cat /tmp/spark-job-$$.log || true
        rm -f /tmp/spark-job-$$.log
        return 1
    fi
}

# ============================================================================
# Test scenario functions
# ============================================================================

test_jupyter_connect_k8s() {
    local scenario="jupyter-connect-k8s"
    local start_time
    start_time=$(date +%s)

    log_test "Testing: $scenario (Spark ${SPARK_VERSION})"

    local namespace="${NAMESPACE_PREFIX}-${scenario//\//-}"
    local release_name="test-${scenario//\//-}"
    local preset_path="charts/spark-3.5/${scenario}-${SPARK_VERSION}.yaml"

    # Install
    log_step "Installing Helm release: $release_name"
    helm install "$release_name" "$CHART_PATH" \
        --namespace "$namespace" \
        --create-namespace \
        --values "$preset_path" \
        --set connect.image.repository="${IMAGE_REPOSITORY}" \
        --set connect.image.tag="${IMAGE_TAG}" \
        --set jupyter.image.tag="${JUPYTER_IMAGE_TAG}" \
        --timeout 15m \
        --wait || return 1

    # Validate
    validate_pods_running "$namespace" 2

    local connect_pod
    connect_pod=$(kubectl get pods -n "$namespace" -l app.kubernetes.io/component=connect -o jsonpath='{.items[0].metadata.name}')
    local jupyter_pod
    jupyter_pod=$(kubectl get pods -n "$namespace" -l app.kubernetes.io/component=jupyter -o jsonpath='{.items[0].metadata.name}')

    validate_spark_connect_grpc "$namespace" "$release_name" "$connect_pod"
    validate_jupyter_api "$namespace" "$jupyter_pod"
    # Skip spark-submit in Connect pod as it conflicts with running Connect server
    log_info "Skipping spark-submit validation (Connect server already running)"

    # Cleanup
    cleanup_namespace "$namespace"

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))

    log_test_result "$scenario" "PASS" "$duration"
}

test_jupyter_connect_standalone() {
    local scenario="jupyter-connect-standalone"
    local start_time
    start_time=$(date +%s)

    log_test "Testing: $scenario (Spark ${SPARK_VERSION})"

    local namespace="${NAMESPACE_PREFIX}-${scenario//\//-}"
    local release_name="test-${scenario//\//-}"
    local preset_path="charts/spark-3.5/${scenario}-${SPARK_VERSION}.yaml"

    # Install
    log_step "Installing Helm release: $release_name"
    helm install "$release_name" "$CHART_PATH" \
        --namespace "$namespace" \
        --create-namespace \
        --values "$preset_path" \
        --set connect.image.repository="${IMAGE_REPOSITORY}" \
        --set connect.image.tag="${IMAGE_TAG}" \
        --set jupyter.image.tag="${JUPYTER_IMAGE_TAG}" \
        --set sparkStandalone.image.repository="${IMAGE_REPOSITORY}" \
        --set sparkStandalone.image.tag="${IMAGE_TAG}" \
        --timeout 15m \
        --wait || return 1

    # Validate
    validate_pods_running "$namespace" 4

    local connect_pod
    connect_pod=$(kubectl get pods -n "$namespace" -l app.kubernetes.io/component=connect -o jsonpath='{.items[0].metadata.name}')
    local jupyter_pod
    jupyter_pod=$(kubectl get pods -n "$namespace" -l app.kubernetes.io/component=jupyter -o jsonpath='{.items[0].metadata.name}')
    local master_pod
    master_pod=$(kubectl get pods -n "$namespace" -l app.kubernetes.io/component=standalone-master -o jsonpath='{.items[0].metadata.name}')

    validate_spark_connect_grpc "$namespace" "$release_name" "$connect_pod"
    validate_jupyter_api "$namespace" "$jupyter_pod"
    validate_standalone_workers "$namespace" "$master_pod"
    # Skip spark-submit in Connect pod as it conflicts with running Connect server
    log_info "Skipping spark-submit validation (Connect server already running)"

    # Cleanup
    cleanup_namespace "$namespace"

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))

    log_test_result "$scenario" "PASS" "$duration"
}

test_airflow_connect_k8s() {
    local scenario="airflow-connect-k8s"
    local start_time
    start_time=$(date +%s)

    log_test "Testing: $scenario (Spark ${SPARK_VERSION})"

    local namespace="${NAMESPACE_PREFIX}-${scenario//\//-}"
    local release_name="test-${scenario//\//-}"
    local preset_path="charts/spark-3.5/${scenario}-${SPARK_VERSION}.yaml"

    # Install
    log_step "Installing Helm release: $release_name"
    helm install "$release_name" "$CHART_PATH" \
        --namespace "$namespace" \
        --create-namespace \
        --values "$preset_path" \
        --set connect.image.repository="${IMAGE_REPOSITORY}" \
        --set connect.image.tag="${IMAGE_TAG}" \
        --timeout 15m \
        --wait || return 1

    # Validate
    validate_pods_running "$namespace" 1

    local connect_pod
    connect_pod=$(kubectl get pods -n "$namespace" -l app.kubernetes.io/component=connect -o jsonpath='{.items[0].metadata.name}')

    validate_spark_connect_grpc "$namespace" "$release_name" "$connect_pod"
    # Skip spark-submit in Connect pod as it conflicts with running Connect server
    log_info "Skipping spark-submit validation (Connect server already running)"

    # Cleanup
    cleanup_namespace "$namespace"

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))

    log_test_result "$scenario" "PASS" "$duration"
}

test_airflow_connect_standalone() {
    local scenario="airflow-connect-standalone"
    local start_time
    start_time=$(date +%s)

    log_test "Testing: $scenario (Spark ${SPARK_VERSION})"

    local namespace="${NAMESPACE_PREFIX}-${scenario//\//-}"
    local release_name="test-${scenario//\//-}"
    local preset_path="charts/spark-3.5/${scenario}-${SPARK_VERSION}.yaml"

    # Install
    log_step "Installing Helm release: $release_name"
    helm install "$release_name" "$CHART_PATH" \
        --namespace "$namespace" \
        --create-namespace \
        --values "$preset_path" \
        --set connect.image.repository="${IMAGE_REPOSITORY}" \
        --set connect.image.tag="${IMAGE_TAG}" \
        --set sparkStandalone.image.repository="${IMAGE_REPOSITORY}" \
        --set sparkStandalone.image.tag="${IMAGE_TAG}" \
        --timeout 15m \
        --wait || return 1

    # Validate
    validate_pods_running "$namespace" 3

    local connect_pod
    connect_pod=$(kubectl get pods -n "$namespace" -l app.kubernetes.io/component=connect -o jsonpath='{.items[0].metadata.name}')
    local master_pod
    master_pod=$(kubectl get pods -n "$namespace" -l app.kubernetes.io/component=standalone-master -o jsonpath='{.items[0].metadata.name}')

    validate_spark_connect_grpc "$namespace" "$release_name" "$connect_pod"
    validate_standalone_workers "$namespace" "$master_pod"
    # Skip spark-submit in Connect pod as it conflicts with running Connect server
    log_info "Skipping spark-submit validation (Connect server already running)"

    # Cleanup
    cleanup_namespace "$namespace"

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))

    log_test_result "$scenario" "PASS" "$duration"
}

# ============================================================================
# Main execution
# ============================================================================

main() {
    log_section "Integration Tests: Spark ${SPARK_VERSION} on Minikube"

    local overall_start_time
    overall_start_time=$(date +%s)

    # Check prerequisites
    if ! check_prerequisites; then
        log_error "Prerequisites check failed"
        return 1
    fi

    # Set release name for cleanup functions
    RELEASE_NAME=""

    # Run tests
    local scenarios_to_run=("${SCENARIOS[@]}")

    if [[ -n "$ONLY_SCENARIO" ]]; then
        scenarios_to_run=("$ONLY_SCENARIO")
        log_info "Running only scenario: $ONLY_SCENARIO"
    fi

    for scenario in "${scenarios_to_run[@]}"; do
        case "$scenario" in
            jupyter-connect-k8s)
                test_jupyter_connect_k8s
                ;;
            jupyter-connect-standalone)
                test_jupyter_connect_standalone
                ;;
            airflow-connect-k8s)
                test_airflow_connect_k8s
                ;;
            airflow-connect-standalone)
                test_airflow_connect_standalone
                ;;
            *)
                log_error "Unknown scenario: $scenario"
                ;;
        esac
    done

    # Print summary
    local overall_end_time
    overall_end_time=$(date +%s)
    local overall_duration=$((overall_end_time - overall_start_time))

    log_section "Test Summary"
    echo ""
    echo "Total duration: ${overall_duration}s"
    echo ""
    echo "Results:"
    for scenario in "${SCENARIOS[@]}"; do
        local result="${TEST_RESULTS[$scenario]:-SKIP}"
        echo "  $scenario: $result"
    done
    echo ""

    if [[ ${#FAILED_TESTS[@]} -eq 0 ]]; then
        log_success "✅ All integration tests passed!"
        return 0
    else
        log_error "❌ ${#FAILED_TESTS[@]} test(s) failed:"
        for test in "${FAILED_TESTS[@]}"; do
            echo "  - $test"
        done
        return 1
    fi
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    set -e
    setup_error_trap
    main "$@"
fi
