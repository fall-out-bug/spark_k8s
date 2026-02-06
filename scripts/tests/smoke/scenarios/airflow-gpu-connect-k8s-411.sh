#!/bin/bash
# Smoke test: Airflow + Spark Connect + K8s backend + GPU (Spark 4.1.1)

# @meta
# name: "airflow-gpu-connect-k8s-411"
# type: "smoke"
# description: "Smoke test for Airflow + Spark Connect + K8s backend + GPU (Spark 4.1.1)"
# version: "4.1.1"
# component: "airflow"
# mode: "connect-k8s"
# features: ["gpu"]
# chart: "charts/spark-4.1"
# preset: "charts/spark-4.1/airflow-gpu-connect-k8s-4.1.1.yaml"
# estimated_time: "5 min"
# depends_on: []
# tags: [smoke, airflow, connect-k8s, gpu, 4.1.1]
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
PRESET_PATH="${PROJECT_ROOT}/charts/spark-4.1/airflow-gpu-connect-k8s-4.1.1.yaml"
SPARK_VERSION="4.1.1"
IMAGE_TAG="4.1.1-gpu"
IMAGE_REPOSITORY="spark-custom-gpu"

check_gpu_available() {
    log_step "Checking GPU availability"

    local gpu_nodes
    gpu_nodes=$(kubectl get nodes -o jsonpath='{.items[*].status.allocatable.nvidia\.com/gpu}' 2>/dev/null | tr ' ' '\n' | grep -v "^$" | wc -l)

    if [[ "$gpu_nodes" -eq 0 ]]; then
        log_warning "No GPU nodes found in cluster. Skipping..."
        return 1
    fi

    log_info "Found $gpu_nodes GPU node(s)"
    return 0
}

setup_test_environment() {
    log_section "Setting up test environment"
    check_required_commands kubectl helm

    if ! check_gpu_available; then
        exit 0
    fi


    setup_cleanup_trap "$RELEASE_NAME" "$TEST_NAMESPACE"
    export TEST_NAMESPACE RELEASE_NAME
}

deploy_spark() {
    log_section "Deploying Spark Connect with GPU support"

    helm_install "$RELEASE_NAME" "$CHART_PATH" "$TEST_NAMESPACE" "$PRESET_PATH" \
        --set connect.image.repository="${IMAGE_REPOSITORY}" \
        --set connect.image.tag="${IMAGE_TAG}"

    helm_wait_for_deployed "$RELEASE_NAME" "$TEST_NAMESPACE" 300
}

validate_deployment() {
    log_section "Validating deployment"

    wait_for_pods_by_label "app.kubernetes.io/component=connect" "$TEST_NAMESPACE" 1 300

    local connect_pod
    connect_pod=$(kubectl get pods -n "$TEST_NAMESPACE" -l app.kubernetes.io/component=connect -o jsonpath='{.items[0].metadata.name}')

    validate_spark_connect "$connect_pod" "$TEST_NAMESPACE" 15002
    validate_gpu_resources "$connect_pod" "$TEST_NAMESPACE"
    log_success "All components validated with GPU"
}

run_smoke_test() {
    log_section "Running smoke test"

    local connect_pod
    connect_pod=$(kubectl get pods -n "$TEST_NAMESPACE" -l app.kubernetes.io/component=connect -o jsonpath='{.items[0].metadata.name}')

    kubectl exec -n "$TEST_NAMESPACE" "$connect_pod" -- /bin/sh -c '
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
    log_section "Smoke Test: Airflow + Spark Connect + GPU (4.1.1)"
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
