#!/bin/bash
# Smoke test: Jupyter + Spark Connect + Standalone backend (Spark 4.1.0)

# @meta
# name: "jupyter-connect-standalone-410"
# type: "smoke"
# description: "Smoke test for Jupyter + Spark Connect + Standalone backend (Spark 4.1.0)"
# version: "4.1.0"
# component: "jupyter"
# mode: "connect-standalone"
# features: []
# chart: "charts/spark-4.1"
# preset: "charts/spark-4.1/jupyter-connect-standalone-4.1.0.yaml"
# estimated_time: "5 min"
# depends_on: []
# tags: [smoke, jupyter, connect-standalone, 4.1.0]
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
PRESET_PATH="${PROJECT_ROOT}/charts/spark-4.1/jupyter-connect-standalone-4.1.0.yaml"
SPARK_VERSION="4.1.0"
IMAGE_TAG="4.1.0"
IMAGE_REPOSITORY="spark-custom"

setup_test_environment() {
    log_section "Setting up test environment"

    # Check prerequisites
    check_required_commands kubectl helm

    # Generate test ID and create namespace
    local ns_name="${NAMESPACE_PREFIX}-410"

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
    release_name="$(create_release_name "jupyter-connect-standalone-" "$(generate_short_test_id)")"

    TEST_NAMESPACE="$ns_name"
    RELEASE_NAME="$release_name"

    log_info "Namespace: $TEST_NAMESPACE"
    log_info "Release: $RELEASE_NAME"

    # Setup cleanup trap
    setup_cleanup_trap "$RELEASE_NAME" "$TEST_NAMESPACE"

    export TEST_NAMESPACE RELEASE_NAME
}

deploy_spark() {
    log_section "Deploying Spark Connect + Jupyter (Standalone mode)"

    helm_install "$RELEASE_NAME" "$CHART_PATH" "$TEST_NAMESPACE" "$PRESET_PATH" \
        --set connect.image.repository="${IMAGE_REPOSITORY}" \
        --set connect.image.tag="${IMAGE_TAG}" \
        --set jupyter.image.tag="${IMAGE_TAG}"

    helm_wait_for_deployed "$RELEASE_NAME" "$TEST_NAMESPACE" 300
}

validate_deployment() {
    log_section "Validating deployment"

    wait_for_pods_by_label "app.kubernetes.io/component=connect" "$TEST_NAMESPACE" 1 300
    wait_for_pods_by_label "app.kubernetes.io/component=jupyter" "$TEST_NAMESPACE" 1 300

    local connect_pod
    connect_pod=$(kubectl get pods -n "$TEST_NAMESPACE" -l app.kubernetes.io/component=connect -o jsonpath='{.items[0].metadata.name}')

    validate_spark_connect "$connect_pod" "$TEST_NAMESPACE" 15002
    log_success "All components validated"
}

run_smoke_test() {
    log_section "Running smoke test"

    local connect_pod
    connect_pod=$(kubectl get pods -n "$TEST_NAMESPACE" -l app.kubernetes.io/component=connect -o jsonpath='{.items[0].metadata.name}')

    kubectl exec -n "$TEST_NAMESPACE" "$connect_pod" -- /bin/sh -c '
        /opt/spark/bin/spark-submit \
            --master local[*] \
            --conf spark.driver.memory=512m \
            /opt/spark/examples/src/main/python/pi.py 10
    ' 2>&1 | tee /tmp/spark-job.log

    if grep -q "Pi is roughly" /tmp/spark-job.log; then
        log_success "Spark job completed successfully"
    else
        log_error "Spark job failed"
        return 1
    fi
}

print_results() {
    log_section "Test Results"
    echo "Configuration: Spark $SPARK_VERSION, Jupyter + Connect + Standalone"
    kubectl get pods -n "$TEST_NAMESPACE" -o wide
}

main() {
    log_section "Smoke Test: Jupyter + Spark Connect + Standalone (4.1.0)"
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
