#!/bin/bash
# Smoke test: Jupyter + Spark Connect + K8s backend + GPU (Spark 4.1.0)

# @meta
# name: "jupyter-connect-k8s-gpu-410"
# type: "smoke"
# description: "Smoke test for Jupyter + Spark Connect + K8s backend + GPU (Spark 4.1.0)"
# version: "4.1.0"
# component: "jupyter"
# mode: "connect-k8s"
# features: ["gpu"]
# chart: "charts/spark-4.1"
# preset: "charts/spark-4.1/presets/test-baseline-values.yaml"
# estimated_time: "5 min"
# depends_on: []
# tags: [smoke, jupyter, connect-k8s, gpu, 4.1.0]
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
SPARK_VERSION="4.1.0"
IMAGE_TAG="4.1.0-gpu"
IMAGE_REPOSITORY="spark-custom-gpu"

# Check for GPU availability
check_gpu_available() {
    log_step "Checking GPU availability"

    local gpu_nodes
    gpu_nodes=$(kubectl get nodes -o jsonpath='{.items[*].status.allocatable.nvidia\.com/gpu}' 2>/dev/null | tr ' ' '\n' | grep -v "^$" | wc -l)

    if [[ "$gpu_nodes" -eq 0 ]]; then
        log_warning "No GPU nodes found in cluster"
        log_info "This test requires GPU nodes. Skipping..."
        return 1
    fi

    log_info "Found $gpu_nodes GPU node(s)"
    return 0
}

setup_test_environment() {
    log_section "Setting up test environment"
    check_required_commands kubectl helm

    if ! check_gpu_available; then
        exit 0  # Skip gracefully
    fi

    local env_setup
    env_setup=$(setup_test_environment "jupyter-connect-k8s-gpu" "410")
    read -r TEST_NAMESPACE RELEASE_NAME <<< "$env_setup"

    setup_cleanup_trap "$RELEASE_NAME" "$TEST_NAMESPACE"
    export TEST_NAMESPACE RELEASE_NAME
}

deploy_spark() {
    log_section "Deploying Jupyter with Spark Connect + GPU support"

    helm_install "$RELEASE_NAME" "$CHART_PATH" "$TEST_NAMESPACE" "$PRESET_PATH" \
        --set jupyter.image.repository="${IMAGE_REPOSITORY}" \
        --set jupyter.image.tag="${IMAGE_TAG}" \
        --set connect.enabled=true \
        --set connect.backendMode=k8s

    helm_wait_for_deployed "$RELEASE_NAME" "$TEST_NAMESPACE" 300
}

validate_deployment() {
    log_section "Validating deployment"

    wait_for_pods_by_label "app.kubernetes.io/component=jupyter" "$TEST_NAMESPACE" 1 300
    wait_for_pods_by_label "app.kubernetes.io/component=connect" "$TEST_NAMESPACE" 1 300

    local jupyter_pod
    jupyter_pod=$(kubectl get pods -n "$TEST_NAMESPACE" -l app.kubernetes.io/component=jupyter -o jsonpath='{.items[0].metadata.name}')

    local connect_pod
    connect_pod=$(kubectl get pods -n "$TEST_NAMESPACE" -l app.kubernetes.io/component=connect -o jsonpath='{.items[0].metadata.name}')

    validate_spark_connect "$connect_pod" "$TEST_NAMESPACE" 15002
    validate_gpu_resources "$connect_pod" "$TEST_NAMESPACE"
    log_success "All components validated with GPU"
}

run_smoke_test() {
    log_section "Running smoke test"

    local jupyter_pod
    jupyter_pod=$(kubectl get pods -n "$TEST_NAMESPACE" -l app.kubernetes.io/component=jupyter -o jsonpath='{.items[0].metadata.name}')

    kubectl exec -n "$TEST_NAMESPACE" "$jupyter_pod" -- /bin/sh -c '
        /opt/spark/bin/spark-submit \
            --master local[*] \
            --conf spark.driver.memory=512m \
            --conf spark.plugins=com.nvidia.spark.SQLPlugin \
            --conf spark.rapids.sql.enabled=true \
            /opt/spark/examples/src/main/python/pi.py 10
    '

    log_success "GPU Spark job completed successfully"
}

main() {
    log_section "Smoke Test: Jupyter + Spark Connect + GPU (4.1.0)"
    setup_test_environment
    deploy_spark
    validate_deployment
    run_smoke_test
    log_success "✅ Smoke test passed!"

    unregister_release_cleanup "$RELEASE_NAME"
    unregister_namespace_cleanup "$TEST_NAMESPACE"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_error_trap
    main "$@"
fi
