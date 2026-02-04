#!/bin/bash
# Load test: Airflow (Spark 4.1.1)

# @meta
# name: "airflow-load-411"
# type: "smoke"
# description: "Load test for Airflow (Spark 4.1.1)"
# version: "4.1.1"
# component: "airflow"
# mode: "load"
# features: []
# chart: "charts/spark-4.1"
# preset: "charts/spark-4.1/presets/test-baseline-values.yaml"
# estimated_time: "5 min"
# depends_on: []
# tags: [smoke, airflow, load, 4.1.1]
# @endmeta

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

source "${PROJECT_ROOT}/scripts/tests/lib/common.sh"
source "${PROJECT_ROOT}/scripts/tests/lib/namespace.sh"
source "${PROJECT_ROOT}/scripts/tests/lib/cleanup.sh"
source "${PROJECT_ROOT}/scripts/tests/lib/helm.sh"
source "${PROJECT_ROOT}/scripts/tests/lib/validation.sh"

CHART_PATH="${PROJECT_ROOT}/charts/spark-4.1"
PRESET_PATH="${PROJECT_ROOT}/charts/spark-4.1/presets/test-baseline-values.yaml"
SPARK_VERSION="4.1.1"
IMAGE_TAG="4.1.1"
IMAGE_REPOSITORY="spark-custom"
APP_NAME="airflow-load-test-411"

setup_test_environment() {
    log_section "Setting up test environment"
    check_required_commands kubectl helm

    local env_setup
    env_setup=$(setup_test_environment "airflow-load" "411")
    read -r TEST_NAMESPACE RELEASE_NAME <<< "$env_setup"

    log_info "Namespace: $TEST_NAMESPACE"
    log_info "Release: $RELEASE_NAME"

    setup_cleanup_trap "$RELEASE_NAME" "$TEST_NAMESPACE"
    export TEST_NAMESPACE RELEASE_NAME
}

deploy_spark() {
    log_section "Deploying Airflow for load testing"

    helm_install "$RELEASE_NAME" "$CHART_PATH" "$TEST_NAMESPACE" "$PRESET_PATH" \
        --set airflow.image.tag="${IMAGE_TAG}" \
        --set jupyter.enabled=false
}

validate_deployment() {
    log_section "Validating deployment"

    wait_for_pods_by_label "app.kubernetes.io/component=airflow" "$TEST_NAMESPACE" 1 300

    local airflow_pod
    airflow_pod=$(kubectl get pods -n "$TEST_NAMESPACE" -l app.kubernetes.io/component=airflow -o jsonpath='{.items[0].metadata.name}')

    log_success "Airflow pod ready: $airflow_pod"
}

run_smoke_test() {
    log_section "Running load smoke test"

    local airflow_pod
    airflow_pod=$(kubectl get pods -n "$TEST_NAMESPACE" -l app.kubernetes.io/component=airflow -o jsonpath='{.items[0].metadata.name}')

    kubectl exec -n "$TEST_NAMESPACE" "$airflow_pod" -- /bin/sh -c '
        /opt/spark/bin/spark-submit \
            --master local[4] \
            --conf spark.driver.memory=2g \
            --conf spark.executor.memory=2g \
            --conf spark.executor.instances=2 \
            --conf spark.driver.cores=4 \
            --conf spark.executor.cores=4 \
            --conf spark.app.name="'"$APP_NAME"'" \
            /opt/spark/examples/src/main/python/pi.py 200
    '

    log_success "Load smoke test completed successfully"
}

print_results() {
    log_section "Test Results"
    echo "Configuration: Spark $SPARK_VERSION, Airflow Load"
    kubectl get pods -n "$TEST_NAMESPACE" -o wide
}

main() {
    log_section "Load Smoke Test: Airflow (4.1.1)"
    setup_test_environment
    deploy_spark
    validate_deployment
    run_smoke_test
    print_results
    log_success "✅ Load smoke test passed!"

    unregister_release_cleanup "$RELEASE_NAME"
    unregister_namespace_cleanup "$TEST_NAMESPACE"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_error_trap
    main "$@"
fi
