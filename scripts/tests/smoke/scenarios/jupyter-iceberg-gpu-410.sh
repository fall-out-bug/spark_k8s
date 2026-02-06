#!/bin/bash
# Smoke test: Jupyter + Iceberg + GPU (Spark 4.1.0)

# @meta
# name: "jupyter-iceberg-gpu-410"
# type: "smoke"
# description: "Smoke test for Jupyter with Iceberg and GPU support (Spark 4.1.0)"
# version: "4.1.0"
# component: "jupyter"
# mode: "iceberg-gpu"
# features: ["iceberg", "gpu"]
# chart: "charts/spark-4.1"
# preset: "charts/spark-4.1/presets/test-baseline-values.yaml"
# estimated_time: "5 min"
# depends_on: []
# tags: [smoke, jupyter, iceberg, gpu, 4.1.0]
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
APP_NAME="jupyter-iceberg-gpu-test-410"

check_gpu_available() {
    log_step "Checking GPU availability"

    local gpu_nodes
    gpu_nodes=$(kubectl get nodes -o jsonpath='{.items[*].status.allocatable.nvidia\\.com/gpu}' 2>/dev/null | tr ' ' '\n' | grep -v "^$" | wc -l)

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
    release_name="$(create_release_name "jupyter-iceberg-gpu-" "$(generate_short_test_id)")"

    TEST_NAMESPACE="$ns_name"
    RELEASE_NAME="$release_name"

    log_info "Namespace: $TEST_NAMESPACE"
    log_info "Release: $RELEASE_NAME"

    # Setup cleanup trap
    setup_cleanup_trap "$RELEASE_NAME" "$TEST_NAMESPACE"

    export TEST_NAMESPACE RELEASE_NAME
}

deploy_spark() {
    log_section "Deploying Jupyter with Iceberg and GPU support"

    helm_install "$RELEASE_NAME" "$CHART_PATH" "$TEST_NAMESPACE" "$PRESET_PATH" \
        --set jupyter.image.repository="${IMAGE_REPOSITORY}" \
        --set jupyter.image.tag="${IMAGE_TAG}" \
        --set airflow.enabled=false \
        --set core.hiveMetastore.enabled=true
}

validate_deployment() {
    log_section "Validating deployment"

    wait_for_pods_by_label "app.kubernetes.io/component=jupyter" "$TEST_NAMESPACE" 1 300
    wait_for_pods_by_label "app.kubernetes.io/component=hive-metastore" "$TEST_NAMESPACE" 1 300

    local jupyter_pod
    jupyter_pod=$(kubectl get pods -n "$TEST_NAMESPACE" -l app.kubernetes.io/component=jupyter -o jsonpath='{.items[0].metadata.name}')

    validate_gpu_resources "$jupyter_pod" "$TEST_NAMESPACE"
    log_success "Jupyter pod ready with GPU and Hive Metastore: $jupyter_pod"
}

run_smoke_test() {
    log_section "Running smoke test"

    local jupyter_pod
    jupyter_pod=$(kubectl get pods -n "$TEST_NAMESPACE" -l app.kubernetes.io/component=jupyter -o jsonpath='{.items[0].metadata.name}')

    kubectl exec -n "$TEST_NAMESPACE" "$jupyter_pod" -- /bin/sh -c '
        /opt/spark/bin/spark-submit \
            --master local[*] \
            --conf spark.driver.memory=512m \
            --conf spark.executor.memory=512m \
            --conf spark.plugins=com.nvidia.spark.SQLPlugin \
            --conf spark.rapids.sql.enabled=true \
            --conf spark.sql.catalog.local=org.apache.iceberg.spark.SparkCatalog \
            --conf spark.sql.catalog.local.type=hadoop \
            --conf spark.sql.catalog.local.warehouse=/tmp/iceberg-warehouse \
            --conf spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions \
            --conf spark.app.name="'"$APP_NAME"'" \
            /opt/spark/examples/src/main/python/pi.py 10
    '

    log_success "GPU + Iceberg Spark job completed successfully"
}

print_results() {
    log_section "Test Results"
    echo "Configuration: Spark $SPARK_VERSION, Jupyter + Iceberg + GPU"
    kubectl get pods -n "$TEST_NAMESPACE" -o wide
}

main() {
    log_section "Smoke Test: Jupyter + Iceberg + GPU (4.1.0)"
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
