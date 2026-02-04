#!/bin/bash
# Smoke test: Airflow + Spark Standalone-submit mode (Spark 3.5.7)

# @meta
# name: "airflow-standalone-submit-357"
# type: "smoke"
# description: "Smoke test for Airflow + Spark Standalone-submit mode (Spark 3.5.7)"
# version: "3.5.7"
# component: "airflow"
# mode: "standalone-submit"
# features: []
# chart: "charts/spark-3.5"
# preset: "charts/spark-3.5/airflow-standalone-submit-3.5.7.yaml"
# estimated_time: "5 min"
# depends_on: []
# tags: [smoke, airflow, standalone-submit, 3.5.7]
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
PRESET_PATH="${PROJECT_ROOT}/charts/spark-3.5/airflow-standalone-submit-3.5.7.yaml"
SPARK_VERSION="3.5.7"
IMAGE_TAG="3.5.7"
IMAGE_REPOSITORY="spark-custom"

setup_test_environment() {
    log_section "Setting up test environment"
    check_required_commands kubectl helm

    local env_setup
    env_setup=$(setup_test_environment "airflow-standalone-submit" "357")
    read -r TEST_NAMESPACE RELEASE_NAME <<< "$env_setup"

    log_info "Namespace: $TEST_NAMESPACE"
    log_info "Release: $RELEASE_NAME"

    setup_cleanup_trap "$RELEASE_NAME" "$TEST_NAMESPACE"
    export TEST_NAMESPACE RELEASE_NAME
}

deploy_spark() {
    log_section "Deploying Airflow (Standalone-submit mode)"

    helm_install "$RELEASE_NAME" "$CHART_PATH" "$TEST_NAMESPACE" "$PRESET_PATH" \
        --set airflow.image.tag="${IMAGE_TAG}" \
        --set jupyter.enabled=false

    helm_wait_for_deployed "$RELEASE_NAME" "$TEST_NAMESPACE" 300
}

validate_deployment() {
    log_section "Validating deployment"

    wait_for_pods_by_label "app.kubernetes.io/component=airflow" "$TEST_NAMESPACE" 1 300

    local airflow_pod
    airflow_pod=$(kubectl get pods -n "$TEST_NAMESPACE" -l app.kubernetes.io/component=airflow -o jsonpath='{.items[0].metadata.name}')

    log_success "Airflow pod ready: $airflow_pod"
}

run_smoke_test() {
    log_section "Running smoke test"

    local airflow_pod
    airflow_pod=$(kubectl get pods -n "$TEST_NAMESPACE" -l app.kubernetes.io/component=airflow -o jsonpath='{.items[0].metadata.name}')

    kubectl exec -n "$TEST_NAMESPACE" "$airflow_pod" -- /bin/sh -c '
        /opt/spark/bin/spark-submit \
            --master local[*] \
            --conf spark.driver.memory=512m \
            /opt/spark/examples/src/main/python/pi.py 10
    '

    log_success "Spark job completed successfully"
}

print_results() {
    log_section "Test Results"
    echo "Configuration: Spark $SPARK_VERSION, Airflow + Standalone-submit"
    kubectl get pods -n "$TEST_NAMESPACE" -o wide
}

main() {
    log_section "Smoke Test: Airflow + Standalone-submit (3.5.7)"
    setup_test_environment
    deploy_spark
    validate_deployment
    run_smoke_test
    print_results
    log_success "✅ Smoke test passed!"

    unregister_release_cleanup "$RELEASE_NAME"
    unregister_namespace_cleanup "$TEST_NAMESPACE"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_error_trap
    main "$@"
fi
