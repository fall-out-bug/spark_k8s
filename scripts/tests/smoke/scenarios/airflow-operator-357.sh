#!/bin/bash
# Smoke test: Airflow + Spark Operator (Spark 3.5.7)

# @meta
# name: "airflow-operator-357"
# type: "smoke"
# description: "Smoke test for Airflow with Spark Operator (Spark 3.5.7)"
# version: "3.5.7"
# component: "airflow"
# mode: "operator"
# features: []
# chart: "charts/spark-3.5"
# preset: "charts/spark-3.5/presets/test-baseline-values.yaml"
# estimated_time: "5 min"
# depends_on: []
# tags: [smoke, airflow, operator, 3.5.7]
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
SPARK_VERSION="3.5.7"
IMAGE_TAG="3.5.7"
IMAGE_REPOSITORY="spark-custom"
APP_NAME="airflow-operator-test-357"

setup_test_environment() {
    log_section "Setting up test environment"
    check_required_commands kubectl helm

    local env_setup
    env_setup=$(setup_test_environment "airflow-operator" "357")
    read -r TEST_NAMESPACE RELEASE_NAME <<< "$env_setup"

    log_info "Namespace: $TEST_NAMESPACE"
    log_info "Release: $RELEASE_NAME"

    setup_cleanup_trap "$RELEASE_NAME" "$TEST_NAMESPACE"
    export TEST_NAMESPACE RELEASE_NAME
}

deploy_spark() {
    log_section "Deploying Airflow with Spark Operator"

    helm_install "$RELEASE_NAME" "$CHART_PATH" "$TEST_NAMESPACE" "$PRESET_PATH" \
        --set airflow.image.tag="${IMAGE_TAG}" \
        --set jupyter.enabled=false \
        --set operator.enabled=true
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

    # Run Spark job via Airflow with Spark Operator
    kubectl exec -n "$TEST_NAMESPACE" "$airflow_pod" -- /bin/sh -c '
        /opt/spark/bin/spark-submit \
            --master k8s://https://kubernetes.default.svc:443 \
            --conf spark.driver.memory=512m \
            --conf spark.executor.memory=512m \
            --conf spark.kubernetes.container.image='"${IMAGE_REPOSITORY}:${IMAGE_TAG}"' \
            --conf spark.kubernetes.namespace='"${TEST_NAMESPACE}"' \
            --conf spark.kubernetes.driver.label.app=spark-driver \
            --conf spark.kubernetes.executor.label.app=spark-executor \
            --conf spark.app.name="'"$APP_NAME"'" \
            --deploy-mode cluster \
            --conf spark.executor.instances=1 \
            /opt/spark/examples/src/main/python/pi.py 10
    '

    log_success "Spark Operator job completed successfully"
}

print_results() {
    log_section "Test Results"
    echo "Configuration: Spark $SPARK_VERSION, Airflow + Operator"
    kubectl get pods -n "$TEST_NAMESPACE" -o wide
}

main() {
    log_section "Smoke Test: Airflow + Operator (3.5.7)"
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
