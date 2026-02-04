#!/bin/bash
# Smoke test: Airflow + Iceberg + GPU (Spark 3.5.8)

# @meta
# name: "airflow-iceberg-gpu-358"
# type: "smoke"
# description: "Smoke test for Airflow with Iceberg and GPU support (Spark 3.5.8)"
# version: "3.5.8"
# component: "airflow"
# mode: "iceberg-gpu"
# features: ["iceberg", "gpu"]
# chart: "charts/spark-3.5"
# preset: "charts/spark-3.5/presets/test-baseline-values.yaml"
# estimated_time: "5 min"
# depends_on: []
# tags: [smoke, airflow, iceberg, gpu, 3.5.8]
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
SPARK_VERSION="3.5.8"
IMAGE_TAG="3.5.8-gpu"
IMAGE_REPOSITORY="spark-custom-gpu"
APP_NAME="airflow-iceberg-gpu-test-358"

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
    check_required_commands kubectl helm

    if ! check_gpu_available; then
        exit 0
    fi

    local env_setup
    env_setup=$(setup_test_environment "airflow-iceberg-gpu" "358")
    read -r TEST_NAMESPACE RELEASE_NAME <<< "$env_setup"

    log_info "Namespace: $TEST_NAMESPACE"
    log_info "Release: $RELEASE_NAME"

    setup_cleanup_trap "$RELEASE_NAME" "$TEST_NAMESPACE"
    export TEST_NAMESPACE RELEASE_NAME
}

deploy_spark() {
    log_section "Deploying Airflow with Iceberg and GPU support"

    helm_install "$RELEASE_NAME" "$CHART_PATH" "$TEST_NAMESPACE" "$PRESET_PATH" \
        --set airflow.image.repository="${IMAGE_REPOSITORY}" \
        --set airflow.image.tag="${IMAGE_TAG}" \
        --set jupyter.enabled=false \
        --set core.hiveMetastore.enabled=true
}

validate_deployment() {
    log_section "Validating deployment"

    wait_for_pods_by_label "app.kubernetes.io/component=airflow" "$TEST_NAMESPACE" 1 300
    wait_for_pods_by_label "app.kubernetes.io/component=hive-metastore" "$TEST_NAMESPACE" 1 300

    local airflow_pod
    airflow_pod=$(kubectl get pods -n "$TEST_NAMESPACE" -l app.kubernetes.io/component=airflow -o jsonpath='{.items[0].metadata.name}')

    validate_gpu_resources "$airflow_pod" "$TEST_NAMESPACE"
    log_success "Airflow pod ready with GPU and Hive Metastore: $airflow_pod"
}

run_smoke_test() {
    log_section "Running smoke test"

    local airflow_pod
    airflow_pod=$(kubectl get pods -n "$TEST_NAMESPACE" -l app.kubernetes.io/component=airflow -o jsonpath='{.items[0].metadata.name}')

    kubectl exec -n "$TEST_NAMESPACE" "$airflow_pod" -- /bin/sh -c '
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
    echo "Configuration: Spark $SPARK_VERSION, Airflow + Iceberg + GPU"
    kubectl get pods -n "$TEST_NAMESPACE" -o wide
}

main() {
    log_section "Smoke Test: Airflow + Iceberg + GPU (3.5.8)"
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
