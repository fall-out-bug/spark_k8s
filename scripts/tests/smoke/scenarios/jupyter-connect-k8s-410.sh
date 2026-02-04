#!/bin/bash
# Smoke test: Jupyter + Spark Connect + K8s backend (Spark 4.1.0)

# @meta
# name: "jupyter-connect-k8s-410"
# type: "smoke"
# description: "Smoke test for Jupyter + Spark Connect + K8s backend (Spark 4.1.0)"
# version: "4.1.0"
# component: "jupyter"
# mode: "connect-k8s"
# features: []
# chart: "charts/spark-4.1"
# preset: "charts/spark-4.1/presets/test-baseline-values.yaml"
# estimated_time: "5 min"
# depends_on: []
# tags: [smoke, jupyter, connect-k8s, 4.1.0]
# @endmeta

set -e

# ============================================================================
# Configuration
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

# Source libraries
# shellcheck source=scripts/tests/lib/common.sh
source "${PROJECT_ROOT}/scripts/tests/lib/common.sh"
# shellcheck source=scripts/tests/lib/namespace.sh
source "${PROJECT_ROOT}/scripts/tests/lib/namespace.sh"
# shellcheck source=scripts/tests/lib/cleanup.sh
source "${PROJECT_ROOT}/scripts/tests/lib/cleanup.sh"
# shellcheck source=scripts/tests/lib/helm.sh
source "${PROJECT_ROOT}/scripts/tests/lib/helm.sh"
# shellcheck source=scripts/tests/lib/validation.sh
source "${PROJECT_ROOT}/scripts/tests/lib/validation.sh"

# Test configuration
CHART_PATH="${PROJECT_ROOT}/charts/spark-4.1"
PRESET_PATH="${PROJECT_ROOT}/charts/spark-4.1/presets/test-baseline-values.yaml"
SPARK_VERSION="4.1.0"
IMAGE_TAG="4.1.0"
IMAGE_REPOSITORY="spark-custom"

# Dataset configuration
DATASET_SIZE="${DATASET_SIZE:-small}"  # small, medium, large
case "$DATASET_SIZE" in
    small)
        DATASET_FILE="data/nyc_taxi_sample.parquet"
        ;;
    medium)
        DATASET_FILE="data/nyc_taxi_medium.parquet"
        ;;
    large)
        DATASET_FILE="s3a://nyc-taxi/full/yellow_tripdata_*.parquet"
        ;;
esac

# ============================================================================
# Setup
# ============================================================================

setup_test_environment() {
    log_section "Setting up test environment"

    # Check prerequisites
    check_required_commands kubectl helm

    # Create unique namespace and release name
    local env_setup
    env_setup=$(setup_test_environment "jupyter-connect-k8s" "410")
    read -r TEST_NAMESPACE RELEASE_NAME <<< "$env_setup"

    log_info "Namespace: $TEST_NAMESPACE"
    log_info "Release: $RELEASE_NAME"

    # Setup cleanup trap
    setup_cleanup_trap "$RELEASE_NAME" "$TEST_NAMESPACE"

    export TEST_NAMESPACE RELEASE_NAME
}

# ============================================================================
# Deployment
# ============================================================================

deploy_spark() {
    log_section "Deploying Spark Connect + Jupyter"

    # Prepare Helm values
    local helm_values=(
        "--set connect.image.repository=${IMAGE_REPOSITORY}"
        "--set connect.image.tag=${IMAGE_TAG}"
        "--set jupyter.image.tag=${IMAGE_TAG}"
        "--set global.s3.enabled=false"
        "--set global.minio.enabled=false"
        "--set global.postgresql.enabled=false"
        "--set connect.dynamicAllocation.enabled=false"
        "--set connect.dynamicAllocation.minExecutors=1"
        "--set connect.dynamicAllocation.maxExecutors=2"
        "--set connect.resources.requests.cpu=0"
        "--set connect.resources.requests.memory=512Mi"
        "--set connect.resources.limits.cpu=500m"
        "--set connect.resources.limits.memory=2Gi"
        "--set jupyter.resources.requests.cpu=0"
        "--set jupyter.resources.requests.memory=256Mi"
        "--set jupyter.resources.limits.cpu=500m"
        "--set jupyter.resources.limits.memory=1Gi"
    )

    # Deploy with preset file
    if [[ -f "$PRESET_PATH" ]]; then
        helm_install "$RELEASE_NAME" "$CHART_PATH" "$TEST_NAMESPACE" "$PRESET_PATH" \
            --set connect.image.repository="${IMAGE_REPOSITORY}" \
            --set connect.image.tag="${IMAGE_TAG}" \
            --set jupyter.image.tag="${IMAGE_TAG}"
    else
        # Fallback to inline values
        helm_install_with_values "$RELEASE_NAME" "$CHART_PATH" "$TEST_NAMESPACE" \
            "connect.enabled=true,jupyter.enabled=true,hiveMetastore.enabled=false,historyServer.enabled=false"
    fi

    # Wait for deployment
    log_step "Waiting for deployment to complete..."
    helm_wait_for_deployed "$RELEASE_NAME" "$TEST_NAMESPACE" 300
}

# ============================================================================
# Validation
# ============================================================================

validate_deployment() {
    log_section "Validating deployment"

    # Check Spark Connect pods
    log_step "Checking Spark Connect pods..."
    wait_for_pods_by_label "app.kubernetes.io/component=connect" "$TEST_NAMESPACE" 1 300

    # Check Jupyter pods
    log_step "Checking Jupyter pods..."
    wait_for_pods_by_label "app.kubernetes.io/component=jupyter" "$TEST_NAMESPACE" 1 300

    # Validate Spark Connect server
    local connect_pod
    connect_pod=$(kubectl get pods -n "$TEST_NAMESPACE" -l app.kubernetes.io/component=connect -o jsonpath='{.items[0].metadata.name}')

    validate_spark_connect "$connect_pod" "$TEST_NAMESPACE" 15002

    log_success "All components validated"
}

# ============================================================================
# Test execution
# ============================================================================

run_smoke_test() {
    log_section "Running smoke test"

    local connect_pod
    connect_pod=$(kubectl get pods -n "$TEST_NAMESPACE" -l app.kubernetes.io/component=connect -o jsonpath='{.items[0].metadata.name}')

    log_step "Running simple Spark job..."

    # Run pi calculation example
    kubectl exec -n "$TEST_NAMESPACE" "$connect_pod" -- /bin/sh -c '
        /opt/spark/bin/spark-submit \
            --master local[*] \
            --conf spark.driver.memory=512m \
            --conf spark.executor.memory=512m \
            /opt/spark/examples/src/main/python/pi.py \
            10
    ' 2>&1 | tee /tmp/spark-job.log

    # Check for success
    if grep -q "Pi is roughly" /tmp/spark-job.log; then
        log_success "Spark job completed successfully"
        return 0
    else
        log_error "Spark job failed"
        cat /tmp/spark-job.log
        return 1
    fi
}

run_data_test() {
    log_section "Running data processing test"

    local connect_pod
    connect_pod=$(kubectl get pods -n "$TEST_NAMESPACE" -l app.kubernetes.io/component=connect -o jsonpath='{.items[0].metadata.name}')

    log_step "Testing data processing with NYC Taxi dataset..."

    # For small dataset, use local file
    if [[ "$DATASET_SIZE" == "small" ]] || [[ "$DATASET_SIZE" == "medium" ]]; then
        kubectl exec -n "$TEST_NAMESPACE" "$connect_pod" -- /bin/sh -c '
            # Create sample data
            /opt/spark/bin/spark-shell <<EOF
val data = spark.range(1000).toDF("id")
val count = data.count()
println(s"Data count: $count")
assert(count == 1000)
sys.exit(0)
EOF
        '
    fi

    log_success "Data test completed"
}

# ============================================================================
# Results reporting
# ============================================================================

print_results() {
    log_section "Test Results"

    echo ""
    echo "Configuration:"
    echo "  Spark Version: $SPARK_VERSION"
    echo "  Component: Jupyter + Spark Connect"
    echo "  Mode: K8s backend"
    echo "  Dataset: $DATASET_SIZE"
    echo ""

    echo "Resources:"
    kubectl get pods -n "$TEST_NAMESPACE" -o wide
    echo ""

    echo "To explore:"
    echo "  kubectl exec -it -n $TEST_NAMESPACE $connect_pod -- /bin/bash"
    echo ""

    echo "To cleanup:"
    echo "  helm uninstall $RELEASE_NAME -n $TEST_NAMESPACE"
    echo "  kubectl delete namespace $TEST_NAMESPACE"
    echo ""
}

# ============================================================================
# Main execution
# ============================================================================

main() {
    log_section "Smoke Test: Jupyter + Spark Connect + K8s (4.1.0)"

    local start_time
    start_time=$(date +%s)

    # Setup
    setup_test_environment

    # Deploy
    deploy_spark

    # Validate
    validate_deployment

    # Run tests
    run_smoke_test
    run_data_test

    # Print results
    print_results

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))

    log_success "✅ Smoke test passed! (Duration: ${duration}s)"

    # Unregister from cleanup on success
    unregister_release_cleanup "$RELEASE_NAME"
    unregister_namespace_cleanup "$TEST_NAMESPACE"
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_error_trap
    main "$@"
fi
