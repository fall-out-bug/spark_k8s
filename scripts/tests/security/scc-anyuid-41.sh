#!/bin/bash
# @meta
# name: "scc-anyuid-41"
# type: "security"
# description: "SCC anyuid compliance for Spark 4.1 on OpenShift"
# category: "scc"
# profile: "anyuid"
# spark_version: "4.1"
# platform: "openshift"

# @endmeta

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/security-validation.sh
source "${SCRIPT_DIR}/../lib/security-validation.sh"

# Configuration
CHART="${CHART:-charts/spark-4.1}"
PRESET="${PRESET:-charts/spark-4.1/presets/openshift/anyuid.yaml}"
RELEASE_NS="${RELEASE_NS:-scc-anyuid-41-test}"
RELEASE_NAME="${RELEASE_NAME:-spark-41-anyuid-test}"

cleanup() {
    echo "Cleaning up..."
    helm uninstall "$RELEASE_NAME" -n "$RELEASE_NS" 2>/dev/null || true
    kubectl delete namespace "$RELEASE_NS" 2>/dev/null || true
}

trap cleanup EXIT

check_openshift() {
    echo "Checking for OpenShift cluster..."

    if ! command -v oc &> /dev/null; then
        echo "WARNING: oc command not found. This test requires an OpenShift cluster."
        echo "Skipping test..."
        exit 0
    fi

    if ! kubectl get route &> /dev/null; then
        echo "WARNING: Not an OpenShift cluster. Skipping test..."
        exit 0
    fi

    echo "OpenShift cluster detected"
}

setup_test_environment() {
    echo "Setting up test environment..."

    if [[ ! -f "$PRESET" ]]; then
        echo "ERROR: Preset file not found: $PRESET"
        return 1
    fi

    kubectl create namespace "$RELEASE_NS" --dry-run=client -o yaml | kubectl apply -f -
}

deploy_spark() {
    echo "Deploying Spark 4.1 with OpenShift anyuid preset..."

    helm upgrade --install "$RELEASE_NAME" "$CHART" \
        -n "$RELEASE_NS" \
        -f "$PRESET" \
        --set global.s3.existingSecret="" \
        --set connect.enabled=true \
        --timeout 5m
}

validate_scc_assignment() {
    echo "Validating SCC assignment..."

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

    if ! validate_scc_anyuid "$pod_name" "$RELEASE_NS"; then
        echo "ERROR: SCC anyuid validation failed"
        return 1
    fi

    echo "NOTE: PSS validation skipped (anyuid SCC bypasses PSS)"
}

run_spark_job() {
    echo "Running test Spark job..."

    local pod_name
    pod_name=$(kubectl get pods -n "$RELEASE_NS" -l app.kubernetes.io/component=connect -o jsonpath='{.items[0].metadata.name}')

    kubectl exec -n "$RELEASE_NS" "$pod_name" -- spark-shell --version
}

main() {
    echo "=== SCC Anyuid Test for Spark 4.1 ==="

    check_openshift
    setup_test_environment
    deploy_spark
    validate_scc_assignment
    run_spark_job

    echo "=== All tests passed! ==="
}

main
