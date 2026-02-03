#!/bin/bash
# @meta
name: "pss-baseline-41"
type: "security"
description: "PSS baseline compliance for Spark 4.1"
category: "pss"
profile: "baseline"
spark_version: "4.1"
# @endmeta

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/security-validation.sh
source "${SCRIPT_DIR}/../lib/security-validation.sh"

# Configuration
CHART="${CHART:-charts/spark-4.1}"
RELEASE_NS="${RELEASE_NS:-pss-baseline-41-test}"
RELEASE_NAME="${RELEASE_NAME:-spark-41-baseline-test}"

cleanup() {
    echo "Cleaning up..."
    helm uninstall "$RELEASE_NAME" -n "$RELEASE_NS" 2>/dev/null || true
    kubectl delete namespace "$RELEASE_NS" 2>/dev/null || true
}

trap cleanup EXIT

setup_test_environment() {
    echo "Setting up test environment..."
    kubectl create namespace "$RELEASE_NS" --dry-run=client -o yaml | kubectl apply -f -
}

deploy_spark() {
    echo "Deploying Spark 4.1 with PSS baseline..."
    helm upgrade --install "$RELEASE_NAME" "$CHART" \
        -n "$RELEASE_NS" \
        --set security.createNamespace=false \
        --set security.podSecurityStandards=true \
        --set security.pssProfile=baseline \
        --set connect.enabled=true \
        --set connect.replicas=1 \
        --set core.minio.enabled=true \
        --set core.postgresql.enabled=false \
        --set core.hiveMetastore.enabled=false \
        --wait \
        --timeout 5m
}

validate_pss_compliance() {
    echo "Validating PSS compliance..."

    local pod_name
    pod_name=$(kubectl get pods -n "$RELEASE_NS" -l app.kubernetes.io/component=connect -o jsonpath='{.items[0].metadata.name}')

    if [[ -z "$pod_name" ]]; then
        echo "ERROR: No connect pod found"
        return 1
    fi

    echo "Checking pod: $pod_name"

    if ! wait_for_pod_ready "$pod_name" "$RELEASE_NS" 120; then
        echo "ERROR: Pod did not become ready"
        kubectl describe pod "$pod_name" -n "$RELEASE_NS"
        return 1
    fi

    if ! validate_pss_baseline "$pod_name" "$RELEASE_NS"; then
        echo "ERROR: PSS baseline validation failed"
        return 1
    fi
}

run_spark_job() {
    echo "Running test Spark job..."

    local pod_name
    pod_name=$(kubectl get pods -n "$RELEASE_NS" -l app.kubernetes.io/component=connect -o jsonpath='{.items[0].metadata.name}')

    kubectl exec -n "$RELEASE_NS" "$pod_name" -- spark-shell --version
}

main() {
    echo "=== PSS Baseline Test for Spark 4.1 ==="

    setup_test_environment
    deploy_spark
    validate_pss_compliance
    run_spark_job

    echo "=== All tests passed! ==="
}

main
