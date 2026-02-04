#!/bin/bash
# Smoke test: Airflow + Spark Connect + K8s backend + Iceberg (Spark 4.1.0)

# @meta
# name: "airflow-iceberg-connect-k8s-410"
# type: "smoke"
# description: "Smoke test for Airflow + Spark Connect + K8s backend + Iceberg (Spark 4.1.0)"
# version: "4.1.0"
# component: "airflow"
# mode: "connect-k8s"
# features: ["iceberg"]
# chart: "charts/spark-4.1"
# preset: "charts/spark-4.1/airflow-iceberg-connect-k8s-4.1.0.yaml"
# estimated_time: "5 min"
# depends_on: []
# tags: [smoke, airflow, connect-k8s, iceberg, 4.1.0]
# @endmeta

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "${PROJECT_ROOT}/scripts/tests/lib/common.sh"
source "${PROJECT_ROOT}/scripts/tests/lib/namespace.sh"
source "${PROJECT_ROOT}/scripts/tests/lib/cleanup.sh"
source "${PROJECT_ROOT}/scripts/tests/lib/helm.sh"
source "${PROJECT_ROOT}/scripts/tests/lib/validation.sh"

CHART_PATH="${PROJECT_ROOT}/charts/spark-4.1"
PRESET_PATH="${PROJECT_ROOT}/charts/spark-4.1/airflow-iceberg-connect-k8s-4.1.0.yaml"
SPARK_VERSION="4.1.0"
IMAGE_TAG="4.1.0"
IMAGE_REPOSITORY="spark-custom-iceberg"

setup_test_environment() {
    log_section "Setting up test environment"
    check_required_commands kubectl helm

    local env_setup
    env_setup=$(setup_test_environment "airflow-iceberg-connect" "410")
    read -r TEST_NAMESPACE RELEASE_NAME <<< "$env_setup"

    setup_cleanup_trap "$RELEASE_NAME" "$TEST_NAMESPACE"
    export TEST_NAMESPACE RELEASE_NAME
}

deploy_spark() {
    log_section "Deploying Spark Connect with Iceberg support"

    helm_install "$RELEASE_NAME" "$CHART_PATH" "$TEST_NAMESPACE" "$PRESET_PATH" \
        --set connect.image.repository="${IMAGE_REPOSITORY}" \
        --set connect.image.tag="${IMAGE_TAG}" \
        --set global.s3.enabled=false \
        --set global.minio.enabled=true \
        --set hiveMetastore.enabled=true

    helm_wait_for_deployed "$RELEASE_NAME" "$TEST_NAMESPACE" 300
}

validate_deployment() {
    log_section "Validating deployment"

    wait_for_pods_by_label "app.kubernetes.io/component=connect" "$TEST_NAMESPACE" 1 300

    if kubectl get deployments -n "$TEST_NAMESPACE" -l app.kubernetes.io/component=hive-metastore &>/dev/null; then
        wait_for_pods_by_label "app.kubernetes.io/component=hive-metastore" "$TEST_NAMESPACE" 1 300
    fi

    local connect_pod
    connect_pod=$(kubectl get pods -n "$TEST_NAMESPACE" -l app.kubernetes.io/component=connect -o jsonpath='{.items[0].metadata.name}')

    validate_spark_connect "$connect_pod" "$TEST_NAMESPACE" 15002
    log_success "All components validated with Iceberg"
}

run_smoke_test() {
    log_section "Running smoke test"

    local connect_pod
    connect_pod=$(kubectl get pods -n "$TEST_NAMESPACE" -l app.kubernetes.io/component=connect -o jsonpath='{.items[0].metadata.name}')

    kubectl exec -n "$TEST_NAMESPACE" "$connect_pod" -- /bin/sh -c '
        /opt/spark/bin/spark-submit \
            --master local[*] \
            --conf spark.driver.memory=512m \
            --conf spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions \
            --conf spark.sql.catalog.spark_catalog=org.apache.iceberg.spark.SparkSessionCatalog \
            /opt/spark/examples/src/main/python/pi.py 10
    '

    log_success "Iceberg Spark job completed successfully"
}

main() {
    log_section "Smoke Test: Airflow + Spark Connect + Iceberg (4.1.0)"
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
