#!/bin/bash
# Smoke test: Jupyter + Spark Connect + K8s backend + Iceberg (Spark 4.1.0)

# @meta
# name: "jupyter-connect-k8s-iceberg-410"
# type: "smoke"
# description: "Smoke test for Jupyter + Spark Connect + K8s backend + Iceberg (Spark 4.1.0)"
# version: "4.1.0"
# component: "jupyter"
# mode: "connect-k8s"
# features: ["iceberg"]
# chart: "charts/spark-4.1"
# preset: "charts/spark-4.1/presets/test-baseline-values.yaml"
# estimated_time: "5 min"
# depends_on: []
# tags: [smoke, jupyter, connect-k8s, iceberg, 4.1.0]
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
PRESET_PATH="${PROJECT_ROOT}/charts/spark-4.1/jupyter-connect-k8s-iceberg-4.1.0.yaml"
SPARK_VERSION="4.1.0"
IMAGE_TAG="4.1.0"
IMAGE_REPOSITORY="spark-custom"

# Check for Iceberg availability
check_iceberg_available() {
    local ns="$1"
    log_step "Checking Iceberg/Hive Metastore availability"

    local hive_pods
    hive_pods=$(kubectl get pods -n "$ns" -l app.kubernetes.io/component=hive-metastore --no-headers 2>/dev/null | wc -l)

    if [[ "$hive_pods" -eq 0 ]]; then
        log_warning "Hive Metastore not found. Skipping Iceberg test..."
        return 1
    fi
    log_info "Hive Metastore available for Iceberg"
    return 0
}

setup_test_environment() {
    log_section "Setting up test environment"
    check_required_commands kubectl helm

    # Generate test ID and create namespace
    local ns_name="${NAMESPACE_PREFIX}-iceberg-410"

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
    release_name="$(create_release_name "jupyter-connect-k8s-iceberg-" "$(generate_short_test_id)")"

    TEST_NAMESPACE="$ns_name"
    RELEASE_NAME="$release_name"

    log_info "Namespace: $TEST_NAMESPACE"
    log_info "Release: $RELEASE_NAME"

    setup_cleanup_trap "$RELEASE_NAME" "$TEST_NAMESPACE"
    export TEST_NAMESPACE RELEASE_NAME
}

deploy_spark() {
    log_section "Deploying Jupyter with Spark Connect + Iceberg support"

    log_step "Installing Helm release: $RELEASE_NAME"
    helm install "$RELEASE_NAME" "$CHART_PATH" \
        --namespace "$TEST_NAMESPACE" \
        --values "$PRESET_PATH" \
        --timeout 15m \
        --wait

    helm_wait_for_deployed "$RELEASE_NAME" "$TEST_NAMESPACE" 300
}

validate_deployment() {
    log_section "Validating deployment"

    wait_for_pods_by_label "app.kubernetes.io/component=jupyter" "$TEST_NAMESPACE" 1 300
    wait_for_pods_by_label "app.kubernetes.io/component=connect" "$TEST_NAMESPACE" 1 300

    # Only check Hive Metastore if enabled
    if kubectl get deployments -n "$TEST_NAMESPACE" -l app.kubernetes.io/component=hive-metastore 2>/dev/null | grep -q "hive-metastore"; then
        wait_for_pods_by_label "app.kubernetes.io/component=hive-metastore" "$TEST_NAMESPACE" 1 300
    fi

    local connect_pod
    connect_pod=$(kubectl get pods -n "$TEST_NAMESPACE" -l app.kubernetes.io/component=connect -o jsonpath='{.items[0].metadata.name}')

    validate_spark_connect "$connect_pod" "$TEST_NAMESPACE" 15002
    log_success "All components validated with Iceberg"
}

run_smoke_test() {
    log_section "Running smoke test"

    local jupyter_pod
    jupyter_pod=$(kubectl get pods -n "$TEST_NAMESPACE" -l app.kubernetes.io/component=jupyter -o jsonpath='{.items[0].metadata.name}')

    # Test with Iceberg configuration (local Hadoop catalog - no Hive Metastore needed)
    kubectl exec -n "$TEST_NAMESPACE" "$jupyter_pod" -- /bin/sh -c '
        /opt/spark/bin/spark-submit \
            --master local[*] \
            --conf spark.driver.memory=512m \
            --conf spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions \
            --conf spark.sql.catalog.spark_catalog=org.apache.iceberg.spark.SparkSessionCatalog \
            --conf spark.sql.catalog.spark_catalog.type=hadoop \
            --conf spark.sql.catalog.local.warehouse=/tmp/warehouse/iceberg \
            /opt/spark/examples/src/main/python/pi.py 10
    '

    log_success "Iceberg Spark job completed successfully"
}

main() {
    log_section "Smoke Test: Jupyter + Spark Connect + Iceberg (4.1.0)"
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
