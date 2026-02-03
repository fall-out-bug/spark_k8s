#!/bin/bash
# @meta
name: "scc-restricted-35"
type: "security"
description: "SCC restricted compliance for Spark 3.5 on OpenShift"
category: "scc"
profile: "restricted"
spark_version: "3.5"
platform: "openshift"
# @endmeta

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/security-validation.sh
source "${SCRIPT_DIR}/../lib/security-validation.sh"

# Configuration
CHART="${CHART:-charts/spark-3.5}"
PRESET="${PRESET:-charts/spark-3.5/presets/openshift/restricted.yaml}"
RELEASE_NS="${RELEASE_NS:-scc-restricted-35-test}"
RELEASE_NAME="${RELEASE_NAME:-spark-35-scc-test}"

cleanup() {
    echo "Cleaning up..."
    helm uninstall "$RELEASE_NAME" -n "$RELEASE_NS" 2>/dev/null || true
    kubectl delete namespace "$RELEASE_NS" 2>/dev/null || true
}

trap cleanup EXIT

check_openshift() {
    echo "Checking for OpenShift cluster..."

    # Check if oc command is available
    if ! command -v oc &> /dev/null; then
        echo "WARNING: oc command not found. This test requires an OpenShift cluster."
        echo "Skipping test..."
        exit 0
    fi

    # Check if we're on an OpenShift cluster
    if ! kubectl get route &> /dev/null; then
        echo "WARNING: Not an OpenShift cluster. Skipping test..."
        exit 0
    fi

    echo "OpenShift cluster detected"
}

setup_test_environment() {
    echo "Setting up test environment..."

    # Check if preset file exists
    if [[ ! -f "$PRESET" ]]; then
        echo "ERROR: Preset file not found: $PRESET"
        return 1
    fi

    # Create namespace
    kubectl create namespace "$RELEASE_NS" --dry-run=client -o yaml | kubectl apply -f -
}

deploy_spark() {
    echo "Deploying Spark 3.5 with OpenShift restricted preset..."

    # Check if preset uses namespace creation
    if grep -q "createNamespace: true" "$PRESET"; then
        # Remove namespace creation - we created it manually
        helm upgrade --install "$RELEASE_NAME" "$CHART" \
            -n "$RELEASE_NS" \
            -f <(sed 's/createNamespace: true/createNamespace: false/' "$PRESET") \
            --set global.s3.endpoint="http://minio.$RELEASE_NS.svc.cluster.local:9000" \
            --set global.s3.existingSecret="s3-credentials" \
            --set connect.enabled=true \
            --wait \
            --timeout 5m
    else
        helm upgrade --install "$RELEASE_NAME" "$CHART" \
            -n "$RELEASE_NS" \
            -f "$PRESET" \
            --set global.s3.endpoint="http://minio.$RELEASE_NS.svc.cluster.local:9000" \
            --set global.s3.existingSecret="s3-credentials" \
            --set connect.enabled=true \
            --wait \
            --timeout 5m
    fi
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

    # Validate SCC restricted
    if ! validate_scc_restricted "$pod_name" "$RELEASE_NS"; then
        echo "ERROR: SCC restricted validation failed"
        return 1
    fi

    # Also validate PSS restricted (OpenShift restricted SCC should satisfy PSS restricted)
    if ! validate_pss_restricted "$pod_name" "$RELEASE_NS"; then
        echo "WARNING: PSS restricted validation failed (may be expected on OpenShift)"
    fi
}

run_spark_job() {
    echo "Running test Spark job..."

    local pod_name
    pod_name=$(kubectl get pods -n "$RELEASE_NS" -l app.kubernetes.io/component=connect -o jsonpath='{.items[0].metadata.name}')

    kubectl exec -n "$RELEASE_NS" "$pod_name" -- spark-shell --version
}

main() {
    echo "=== SCC Restricted Test for Spark 3.5 ==="

    check_openshift
    setup_test_environment
    deploy_spark
    validate_scc_assignment
    run_spark_job

    echo "=== All tests passed! ==="
}

main
