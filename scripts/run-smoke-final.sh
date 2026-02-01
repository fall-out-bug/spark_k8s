#!/bin/bash
# Final smoke test script with spark-custom images
# Tests all scenarios across all Spark versions

set -e

CHARTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../charts" && pwd)"
NAMESPACE="${NAMESPACE:-spark-test}"
TIMEOUT="${TIMEOUT:-300}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results tracking
declare -A RESULTS
TOTAL=0
PASSED=0
FAILED=0

# Print header
echo -e "${BLUE}=========================================="
echo "   Full Testing Matrix Smoke Tests"
echo "   (spark-custom images)"
echo "==========================================${NC}"
echo "Namespace: $NAMESPACE"
echo "Timeout: ${TIMEOUT}s per test"
echo ""

# Function to run single smoke test
run_smoke_test() {
    local chart="$1"
    local version="$2"
    local scenario="$3"
    local preset_file="$4"
    # Create release name without dots and underscores (DNS-1035 compliant)
    local version_safe="${version//./-}"
    local scenario_safe="${scenario//./-}"
    local scenario_safe="${scenario_safe//_/-}"
    local chart_safe="${chart//spark-/}"
    local chart_safe="${chart_safe//./-}"
    local chart_safe="${chart_safe//_/-}"
    local release_name="test-${chart_safe}-${scenario_safe}-${version_safe}"
    local test_name="${chart}/${scenario}/${version}"

    echo -e "${YELLOW}Testing: $test_name${NC}"
    echo "  Release: $release_name"
    echo "  Preset: $preset_file"

    ((TOTAL++))

    # Clean up any existing release and resources
    helm uninstall "$release_name" -n "$NAMESPACE" 2>/dev/null || true
    kubectl delete serviceaccount "spark-41" -n "$NAMESPACE" 2>/dev/null || true
    kubectl delete serviceaccount "spark-35" -n "$NAMESPACE" 2>/dev/null || true
    kubectl delete clusterrolebinding "${release_name}-spark-41-spark-cluster-rolebinding" 2>/dev/null || true
    kubectl delete clusterrole "${release_name}-spark-41-spark-cluster-role" 2>/dev/null || true
    kubectl delete clusterrolebinding "${release_name}-spark-35-spark-cluster-rolebinding" 2>/dev/null || true
    kubectl delete clusterrole "${release_name}-spark-35-spark-cluster-role" 2>/dev/null || true
    sleep 3

    # Install chart
    if ! helm install "$release_name" "$CHARTS_DIR/$chart" \
        -n "$NAMESPACE" \
        -f "$preset_file" \
        --wait \
        --timeout "${TIMEOUT}s" \
        --debug 2>&1 | tail -30; then
        echo -e "  ${RED}FAIL: Installation failed${NC}"
        RESULTS["$test_name"]="FAIL"
        ((FAILED++))
        helm uninstall "$release_name" -n "$NAMESPACE" 2>/dev/null || true
        kubectl delete pods -l "app.kubernetes.io/instance=$release_name" -n "$NAMESPACE" --force --grace-period=0 2>/dev/null || true
        return 1
    fi

    # Wait for pods to be ready (skip if no pods expected)
    sleep 5
    local pod_count=$(kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/instance=$release_name" --no-headers 2>/dev/null | wc -l)

    if [[ $pod_count -gt 0 ]]; then
        echo "  Waiting for pods to be ready ($pod_count pods)..."
        if ! kubectl wait --for=condition=ready pod \
            -l "app.kubernetes.io/instance=$release_name" \
            -n "$NAMESPACE" \
            --timeout="${TIMEOUT}s" 2>/dev/null; then

            # Show pod status for debugging
            echo "  Pod status:"
            kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/instance=$release_name" -o wide || true

            # Show events
            echo "  Events:"
            kubectl get events -n "$NAMESPACE" --field-selector involvedObject.name="$release_name" --sort-by='.lastTimestamp' | tail -10 || true

            echo -e "  ${RED}FAIL: Pods not ready${NC}"
            RESULTS["$test_name"]="FAIL"
            ((FAILED++))
            helm uninstall "$release_name" -n "$NAMESPACE" 2>/dev/null || true
            kubectl delete pods -l "app.kubernetes.io/instance=$release_name" -n "$NAMESPACE" --force --grace-period=0 2>/dev/null || true
            return 1
        fi

        # Check pod count
        local ready_count=$(kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/instance=$release_name" --no-headers 2>/dev/null | grep -c "Running" || echo "0")
        echo "  Pods ready: $ready_count/$pod_count"
    fi

    echo -e "  ${GREEN}PASS${NC}"
    RESULTS["$test_name"]="PASS"
    ((PASSED++))

    # Cleanup
    helm uninstall "$release_name" -n "$NAMESPACE" 2>/dev/null || true
    kubectl delete serviceaccount "spark-41" -n "$NAMESPACE" 2>/dev/null || true
    kubectl delete serviceaccount "spark-35" -n "$NAMESPACE" 2>/dev/null || true
    kubectl delete clusterrolebinding "${release_name}"*"-spark-cluster-rolebinding" 2>/dev/null || true
    kubectl delete clusterrole "${release_name}"*"-spark-cluster-role" 2>/dev/null || true
    sleep 3

    return 0
}

# Create namespace if not exists
kubectl create namespace "$NAMESPACE" 2>/dev/null || true

# Pre-flight check: verify spark-custom images exist
echo -e "${BLUE}Checking for required images...${NC}"
for image in "spark-custom:3.5.7" "spark-custom:3.5.8" "spark-custom:4.1.0" "spark-custom:4.1.1" "jupyter-spark:latest"; do
    if minikube image ls 2>/dev/null | grep -q "$image"; then
        echo -e "  ${GREEN}✓${NC} $image"
    else
        echo -e "  ${RED}✗${NC} $image - NOT FOUND!"
        echo ""
        echo "ERROR: Required image $image not found in minikube."
        echo "Please build images first:"
        echo "  minikube image build -p minikube -t spark-custom:3.5.7 docker/spark"
        echo "  minikube image build -p minikube -t spark-custom:3.5.8 docker/spark --build-arg SPARK_VERSION=3.5.8"
        echo "  minikube image build -p minikube -t spark-custom:4.1.0 docker/spark-4.1"
        echo "  minikube image build -p minikube -t spark-custom:4.1.1 docker/spark-4.1 --build-arg SPARK_VERSION=4.1.1"
        echo "  minikube image build -p minikube -t jupyter-spark:latest docker/jupyter"
        exit 1
    fi
done

echo ""

# Matrix of tests
# Spark 3.5 tests
echo -e "${BLUE}=========================================="
echo "   Testing Spark 3.5.7"
echo "==========================================${NC}"

for scenario in "jupyter-k8s"; do
    preset="${CHARTS_DIR}/spark-3.5/${scenario}-3.5.7.yaml"
    if [[ -f "$preset" ]]; then
        run_smoke_test "spark-3.5" "3.5.7" "$scenario" "$preset" || true
    else
        echo "  ${YELLOW}SKIP: $preset not found${NC}"
    fi
done

echo ""
echo -e "${BLUE}=========================================="
echo "   Testing Spark 3.5.8"
echo "==========================================${NC}"

for scenario in "jupyter-k8s"; do
    preset="${CHARTS_DIR}/spark-3.5/${scenario}-3.5.8.yaml"
    if [[ -f "$preset" ]]; then
        run_smoke_test "spark-3.5" "3.5.8" "$scenario" "$preset" || true
    else
        echo "  ${YELLOW}SKIP: $preset not found${NC}"
    fi
done

# Spark 4.1 tests
echo ""
echo -e "${BLUE}=========================================="
echo "   Testing Spark 4.1.0"
echo "==========================================${NC}"

for scenario in "jupyter-connect-k8s" "jupyter-connect-standalone" "airflow-connect-k8s" "airflow-connect-standalone" "airflow-gpu-connect-k8s" "airflow-iceberg-connect-k8s"; do
    preset="${CHARTS_DIR}/spark-4.1/${scenario}-4.1.0.yaml"
    if [[ -f "$preset" ]]; then
        run_smoke_test "spark-4.1" "4.1.0" "$scenario" "$preset" || true
    else
        echo "  ${YELLOW}SKIP: $preset not found${NC}"
    fi
done

echo ""
echo -e "${BLUE}=========================================="
echo "   Testing Spark 4.1.1"
echo "==========================================${NC}"

for scenario in "jupyter-connect-k8s" "jupyter-connect-standalone" "airflow-connect-k8s" "airflow-connect-standalone" "airflow-gpu-connect-k8s" "airflow-iceberg-connect-k8s"; do
    preset="${CHARTS_DIR}/spark-4.1/${scenario}-4.1.1.yaml"
    if [[ -f "$preset" ]]; then
        run_smoke_test "spark-4.1" "4.1.1" "$scenario" "$preset" || true
    else
        echo "  ${YELLOW}SKIP: $preset not found${NC}"
    fi
done

# Print summary
echo ""
echo -e "${BLUE}=========================================="
echo "   Test Summary"
echo "==========================================${NC}"
echo "Total:  $TOTAL"
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"
echo ""

# List failed tests
if [[ $FAILED -gt 0 ]]; then
    echo "Failed tests:"
    for test in "${!RESULTS[@]}"; do
        if [[ "${RESULTS[$test]}" == "FAIL" ]]; then
            echo -e "  ${RED}- $test${NC}"
        fi
    done
fi

echo ""

exit $FAILED
