#!/bin/bash
# Load test: Jupyter (Spark 4.1.0)

# @meta
# name: "jupyter-load-410"
# type: "smoke"
# description: "Load test for Jupyter (Spark 4.1.0)"
# version: "4.1.0"
# component: "jupyter"
# mode: "load"
# features: []
# chart: "charts/spark-4.1"
# preset: "charts/spark-4.1/presets/test-baseline-values.yaml"
# estimated_time: "5 min"
# depends_on: []
# tags: [smoke, jupyter, load, 4.1.0]
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
PRESET_PATH="${PROJECT_ROOT}/charts/spark-4.1/presets/core-baseline.yaml"
SPARK_VERSION="4.1.0"
IMAGE_TAG="4.1.0"
IMAGE_REPOSITORY="spark-custom"
APP_NAME="jupyter-load-test-410"

setup_local_environment() {
    log_section "Setting up test environment"
    check_required_commands kubectl helm

    # Call the function from namespace.sh (capture only the last line which contains results)

    log_info "Namespace: $TEST_NAMESPACE"
    log_info "Release: $RELEASE_NAME"

    setup_cleanup_trap "$RELEASE_NAME" "$TEST_NAMESPACE"
    export TEST_NAMESPACE RELEASE_NAME
}

deploy_spark() {
    log_section "Deploying Jupyter for load testing"

    # Create temporary values file for overrides
    local temp_values
    temp_values=$(mktemp)
    cat > "$temp_values" <<EOF
jupyter:
  image:
    tag: "${IMAGE_TAG}"
airflow:
  enabled: false
EOF

    helm_install "$RELEASE_NAME" "$CHART_PATH" "$TEST_NAMESPACE" "$PRESET_PATH" "$temp_values"

    # Clean up temp file
    rm -f "$temp_values"
}

validate_deployment() {
    log_section "Validating deployment"

    wait_for_pods_by_label "app.kubernetes.io/component=jupyter" "$TEST_NAMESPACE" 1 300

    local jupyter_pod
    jupyter_pod=$(kubectl get pods -n "$TEST_NAMESPACE" -l app.kubernetes.io/component=jupyter -o jsonpath='{.items[0].metadata.name}')

    log_success "Jupyter pod ready: $jupyter_pod"
}

run_smoke_test() {
    log_section "Running load smoke test"

    local jupyter_pod
    jupyter_pod=$(kubectl get pods -n "$TEST_NAMESPACE" -l app.kubernetes.io/component=jupyter -o jsonpath='{.items[0].metadata.name}')

    # Run load-oriented Spark job
    kubectl exec -n "$TEST_NAMESPACE" "$jupyter_pod" -- /bin/sh -c '
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
    echo "Configuration: Spark $SPARK_VERSION, Jupyter Load"
    kubectl get pods -n "$TEST_NAMESPACE" -o wide
}

main() {
    log_section "Load Smoke Test: Jupyter (4.1.0)"
    setup_local_environment
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
