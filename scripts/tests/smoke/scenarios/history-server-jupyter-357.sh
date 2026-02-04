#!/bin/bash
# Smoke test: History Server validation for Jupyter (Spark 3.5.7)

# @meta
# name: "history-server-jupyter-357"
# type: "smoke"
# description: "History Server validation for Jupyter scenarios (Spark 3.5.7)"
# version: "3.5.7"
# component: "history-server"
# mode: "validation"
# features: []
# chart: "charts/spark-3.5"
# preset: "charts/spark-3.5/presets/test-baseline-values.yaml"
# estimated_time: "5 min"
# depends_on: []
# tags: [smoke, history-server, jupyter, 3.5.7]
# @endmeta

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

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
APP_NAME="jupyter-history-test-357"

setup_test_environment() {
    log_section "Setting up test environment"
    check_required_commands kubectl helm

    local env_setup
    env_setup=$(setup_test_environment "hs-jupyter" "357")
    read -r TEST_NAMESPACE RELEASE_NAME <<< "$env_setup"

    log_info "Namespace: $TEST_NAMESPACE"
    log_info "Release: $RELEASE_NAME"

    setup_cleanup_trap "$RELEASE_NAME" "$TEST_NAMESPACE"
    export TEST_NAMESPACE RELEASE_NAME
}

deploy_spark() {
    log_section "Deploying Spark with History Server (Jupyter)"

    helm_install "$RELEASE_NAME" "$CHART_PATH" "$TEST_NAMESPACE" "$PRESET_PATH" \
        --set jupyter.image.tag="${IMAGE_TAG}" \
        --set historyServer.enabled=true \
        --set historyServer.logDirectory="file:///tmp/spark-events" \
        --set sparkOperator.enabled=false
}

validate_deployment() {
    log_section "Validating deployment"

    wait_for_pods_by_label "app.kubernetes.io/component=jupyter" "$TEST_NAMESPACE" 1 300
    wait_for_pods_by_label "app.kubernetes.io/component=history-server" "$TEST_NAMESPACE" 1 300

    local jupyter_pod
    jupyter_pod=$(kubectl get pods -n "$TEST_NAMESPACE" -l app.kubernetes.io/component=jupyter -o jsonpath='{.items[0].metadata.name}')

    local hs_pod
    hs_pod=$(kubectl get pods -n "$TEST_NAMESPACE" -l app.kubernetes.io/component=history-server -o jsonpath='{.items[0].metadata.name}')

    log_success "Jupyter pod ready: $jupyter_pod"
    log_success "History Server pod ready: $hs_pod"
}

run_smoke_test() {
    log_section "Running smoke test with History Server"

    local jupyter_pod
    jupyter_pod=$(kubectl get pods -n "$TEST_NAMESPACE" -l app.kubernetes.io/component=jupyter -o jsonpath='{.items[0].metadata.name}')

    local hs_pod
    hs_pod=$(kubectl get pods -n "$TEST_NAMESPACE" -l app.kubernetes.io/component=history-server -o jsonpath='{.items[0].metadata.name}')

    # Run Spark job with event logging enabled
    kubectl exec -n "$TEST_NAMESPACE" "$jupyter_pod" -- /bin/sh -c '
        /opt/spark/bin/spark-submit \
            --master local[*] \
            --conf spark.driver.memory=512m \
            --conf spark.eventLog.enabled=true \
            --conf spark.eventLog.dir=file:///tmp/spark-events \
            --conf spark.history.fs.logDirectory.file:///tmp/spark-events \
            --conf spark.app.name="'$APP_NAME'" \
            /opt/spark/examples/src/main/python/pi.py 10
    '

    log_success "Spark job completed"

    # Validate History Server
    validate_history_server "$hs_pod" "$TEST_NAMESPACE" "$APP_NAME"
}

print_results() {
    log_section "Test Results"
    echo "Configuration: Spark $SPARK_VERSION, History Server + Jupyter"
    kubectl get pods -n "$TEST_NAMESPACE" -o wide
}

main() {
    log_section "Smoke Test: History Server + Jupyter (3.5.7)"
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
