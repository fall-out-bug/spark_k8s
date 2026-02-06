#!/bin/bash
# Performance test: MLflow basic (Spark 3.5.8)

# @meta
# name: "mlflow-perf-358"
# type: "smoke"
# description: "Performance test for MLflow basic workload (Spark 3.5.8)"
# version: "3.5.8"
# component: "mlflow"
# mode: "performance"
# features: []
# chart: "charts/spark-3.5"
# preset: "charts/spark-3.5/presets/test-baseline-values.yaml"
# estimated_time: "5 min"
# depends_on: []
# tags: [smoke, mlflow, performance, 3.5.8]
# @endmeta

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

source "${PROJECT_ROOT}/scripts/tests/lib/common.sh"
source "${PROJECT_ROOT}/scripts/tests/lib/namespace.sh"
source "${PROJECT_ROOT}/scripts/tests/lib/cleanup.sh"
source "${PROJECT_ROOT}/scripts/tests/lib/helm.sh"
source "${PROJECT_ROOT}/scripts/tests/lib/validation.sh"

CHART_PATH="${PROJECT_ROOT}/charts/spark-3.5"
PRESET_PATH="${PROJECT_ROOT}/charts/spark-3.5/presets/test-baseline-values.yaml"
SPARK_VERSION="3.5.8"
IMAGE_TAG="3.5.8"
IMAGE_REPOSITORY="spark-custom"
APP_NAME="mlflow-perf-test-358"

setup_test_environment() {
    log_section "Setting up test environment"

    # Check prerequisites
    check_required_commands kubectl helm

    # Generate test ID and create namespace
    local ns_name="${NAMESPACE_PREFIX}-358"

    log_step "Creating namespace: $ns_name"
    if kubectl create namespace "$ns_name" 2>/dev/null; then
        log_success "Namespace created: $ns_name"
    elif kubectl get namespace "$ns_name" &>/dev/null; then
        log_info "Namespace already exists: $ns_name"
    else
        log_error "Failed to create namespace: $ns_name"
        return 1
    fi

    # Create release name
    local release_name
    release_name="$(create_release_name "mlflow-perf-" "$(generate_short_test_id)")"

    TEST_NAMESPACE="$ns_name"
    RELEASE_NAME="$release_name"

    log_info "Namespace: $TEST_NAMESPACE"
    log_info "Release: $RELEASE_NAME"

    # Setup cleanup trap
    setup_cleanup_trap "$RELEASE_NAME" "$TEST_NAMESPACE"

    export TEST_NAMESPACE RELEASE_NAME
}

deploy_spark() {
    log_section "Deploying MLflow for performance testing"

    helm_install "$RELEASE_NAME" "$CHART_PATH" "$TEST_NAMESPACE" "$PRESET_PATH" \
        --set mlflow.image.tag="${IMAGE_TAG}" \
        --set jupyter.enabled=false \
        --set airflow.enabled=false
}

validate_deployment() {
    log_section "Validating deployment"

    wait_for_pods_by_label "app.kubernetes.io/component=mlflow" "$TEST_NAMESPACE" 1 300

    local mlflow_pod
    mlflow_pod=$(kubectl get pods -n "$TEST_NAMESPACE" -l app.kubernetes.io/component=mlflow -o jsonpath='{.items[0].metadata.name}')

    log_success "MLflow pod ready: $mlflow_pod"
}

run_smoke_test() {
    log_section "Running performance smoke test"

    local mlflow_pod
    mlflow_pod=$(kubectl get pods -n "$TEST_NAMESPACE" -l app.kubernetes.io/component=mlflow -o jsonpath='{.items[0].metadata.name}')

    kubectl exec -n "$TEST_NAMESPACE" "$mlflow_pod" -- /bin/sh -c '
        /opt/spark/bin/spark-submit \
            --master local[*] \
            --conf spark.driver.memory=1g \
            --conf spark.executor.memory=1g \
            --conf spark.driver.cores=2 \
            --conf spark.executor.cores=2 \
            --conf spark.app.name="'"$APP_NAME"'" \
            /opt/spark/examples/src/main/python/pi.py 100
    '

    log_success "Performance smoke test completed successfully"
}

print_results() {
    log_section "Test Results"
    echo "Configuration: Spark $SPARK_VERSION, MLflow Performance"
    kubectl get pods -n "$TEST_NAMESPACE" -o wide
}

main() {
    log_section "Performance Smoke Test: MLflow (3.5.8)"
    setup_test_environment
    deploy_spark
    validate_deployment
    run_smoke_test
    print_results
    log_success "✅ Performance smoke test passed!"

    unregister_release_cleanup "$RELEASE_NAME"
    unregister_namespace_cleanup "$TEST_NAMESPACE"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_error_trap
    main "$@"
fi
