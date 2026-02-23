#!/bin/bash
# Run real E2E tests with K8s deployment and Spark jobs
#
# Usage:
#   ./scripts/run-e2e-tests.sh [--gpu] [--iceberg] [--all]

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TEST_NAMESPACE="${TEST_NAMESPACE:-spark-e2e-test}"
TIMEOUT="${TIMEOUT:-1200}"  # 20 minutes for image pull

echo "========================================"
echo "Spark K8s E2E Tests"
echo "========================================"

check_prerequisites() {
    echo -e "${YELLOW}Checking prerequisites...${NC}"

    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}ERROR: kubectl not found${NC}"
        exit 1
    fi

    if ! command -v helm &> /dev/null; then
        echo -e "${RED}ERROR: helm not found${NC}"
        exit 1
    fi

    if ! kubectl cluster-info &> /dev/null; then
        echo -e "${RED}ERROR: Cannot connect to Kubernetes cluster${NC}"
        exit 1
    fi

    echo -e "${GREEN}✓ Prerequisites OK${NC}"
}

create_namespace() {
    echo -e "${YELLOW}Creating namespace: $TEST_NAMESPACE${NC}"
    kubectl create namespace "$TEST_NAMESPACE" || true
}

deploy_spark() {
    local preset=$1
    local release_name="spark-e2e-${preset}"
    local sa_name="spark-${preset}"

    echo -e "${YELLOW}Deploying Spark with preset: $preset${NC}"

    # Create service account manually first
    kubectl create serviceaccount "$sa_name" -n "$TEST_NAMESPACE" 2>/dev/null || true

    # Use dev environment for base
    if [[ "$preset" == "dev" ]]; then
        helm install "$release_name" charts/spark-4.1 \
            -f charts/spark-4.1/environments/dev/values.yaml \
            --namespace "$TEST_NAMESPACE" \
            --set rbac.create=false \
            --set rbac.serviceAccountName="$sa_name" \
            --set connect.serviceAccountName="$sa_name" \
            --set jupyter.serviceAccountName="$sa_name" \
            --set connect.image.repository=apache/spark \
            --set connect.image.tag="4.1.0" \
            --wait \
            --timeout 20m
    else
        helm install "$release_name" charts/spark-4.1 \
            -f charts/spark-4.1/presets/${preset}-values.yaml \
            --namespace "$TEST_NAMESPACE" \
            --set rbac.create=false \
            --set rbac.serviceAccountName="$sa_name" \
            --set connect.serviceAccountName="$sa_name" \
            --set jupyter.serviceAccountName="$sa_name" \
            --wait \
            --timeout 20m
    fi

    echo -e "${GREEN}✓ Deployment complete${NC}"
}

wait_for_pods() {
    echo -e "${YELLOW}Waiting for pods to be ready...${NC}"

    for i in {1..30}; do
        ready=$(kubectl get pods -n "$TEST_NAMESPACE" -l app=spark-connect -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | tr ' ' '\n' | grep True | wc -l)
        if [[ "$ready" -ge "1" ]]; then
            echo -e "${GREEN}✓ Pods ready${NC}"
            return
        fi
        echo "Waiting for pods... ($i/30)"
        sleep 10
    done

    echo "Pods not ready after 5 minutes"
    kubectl get pods -n "$TEST_NAMESPACE"
    exit 1
}

get_pod_name() {
    kubectl get pods -n "$TEST_NAMESPACE" -l app=spark-connect -o jsonpath='{.items[0].metadata.name}'
}

test_basic_deployment() {
    echo "========================================"
    echo "Test: Basic Deployment"
    echo "========================================"

    deploy_spark "dev"
    wait_for_pods

    local pod_name=$(get_pod_name)

    echo "Running simple Spark job..."
    kubectl exec -n "$TEST_NAMESPACE" "$pod_name" -- \
        /opt/spark/bin/spark-submit \
        --master local[*] \
        --conf spark.driver.memory=512m \
        local:///opt/spark/examples/src/main/python/pi.py 10

    echo -e "${GREEN}✓ Basic deployment test PASSED${NC}"
}

test_gpu_workload() {
    if [[ "$SKIP_GPU" == "true" ]]; then
        echo -e "${YELLOW}Skipping GPU tests${NC}"
        return
    fi

    echo "========================================"
    echo "Test: GPU Workload"
    echo "========================================"

    local gpu_count=$(kubectl get nodes -o jsonpath='{.items[*].status.allocatable.nvidia\.com/gpu}' 2>/dev/null | tr ' ' '\n' | grep -v '^{}' | wc -l)

    if [[ "$gpu_count" -eq 0 ]]; then
        echo -e "${YELLOW}No GPU nodes found, skipping GPU tests${NC}"
        export SKIP_GPU=true
        return
    fi

    echo -e "${GREEN}Found $gpu_count GPU nodes${NC}"

    deploy_spark "gpu"
    wait_for_pods

    local pod_name=$(get_pod_name)

    echo "Running GPU test job..."
    kubectl exec -n "$TEST_NAMESPACE" "$pod_name" -- python3 -c "
from pyspark.sql import SparkSession
spark = SparkSession.builder.appName('GPU-Test').getOrCreate()
df = spark.range(10000)
df.count()
print('GPU_JOB_SUCCESS')
spark.stop()
"

    echo -e "${GREEN}✓ GPU workload test PASSED${NC}"
}

test_iceberg_workload() {
    if [[ "$SKIP_ICEBERG" == "true" ]]; then
        echo -e "${YELLOW}Skipping Iceberg tests${NC}"
        return
    fi

    echo "========================================"
    echo "Test: Iceberg Workload"
    echo "========================================"

    echo "Deploying MinIO..."
    helm repo add minio https://charts.min.io/ &> /dev/null || true
    helm install minio minio/minio \
        --set accessKey=minioadmin \
        --set secretKey=minioadmin \
        --set persistence.enabled=false \
        --namespace "$TEST_NAMESPACE" &> /dev/null || true

    sleep 10

    deploy_spark "iceberg"
    wait_for_pods

    local pod_name=$(get_pod_name)

    echo "Running Iceberg test job..."
    kubectl exec -n "$TEST_NAMESPACE" "$pod_name" -- python3 -c '
from pyspark.sql import SparkSession
spark = SparkSession.builder.appName(\"Iceberg-Test\").getOrCreate()
spark.sql(\"DROP TABLE IF EXISTS test_iceberg_table\")
spark.sql(\"CREATE TABLE test_iceberg_table (id BIGINT, name STRING, value DOUBLE) USING iceberg\")
spark.sql(\"INSERT INTO test_iceberg_table VALUES (1, \"test\", 123.45)\")
df = spark.sql(\"SELECT * FROM test_iceberg_table\")
count = df.count()
spark.sql(\"UPDATE test_iceberg_table SET value = 999.99 WHERE id = 1\")
spark.sql(\"DELETE FROM test_iceberg_table WHERE id = 1\")
spark.stop()
print(\"ICEBERG_JOB_SUCCESS\")
'

    echo -e "${GREEN}✓ Iceberg workload test PASSED${NC}"
}

test_combined_workload() {
    if [[ "$SKIP_GPU" == "true" ]] || [[ "$SKIP_ICEBERG" == "true" ]]; then
        echo -e "${YELLOW}Skipping combined tests${NC}"
        return
    fi

    echo "========================================"
    echo "Test: GPU + Iceberg Combined"
    echo "========================================"

    local gpu_count=$(kubectl get nodes -o jsonpath='{.items[*].status.allocatable.nvidia\.com/gpu}' 2>/dev/null | tr ' ' '\n' | grep -v '^{}' | wc -l)

    if [[ "$gpu_count" -eq 0 ]]; then
        echo -e "${YELLOW}No GPU nodes, skipping combined test${NC}"
        return
    fi

    # Deploy with both presets (need to create combined values first)
    helm install spark-combined charts/spark-4.1 \
        -f charts/spark-4.1/presets/gpu-values.yaml \
        -f charts/spark-4.1/presets/iceberg-values.yaml \
        --namespace "$TEST_NAMESPACE" \
        --wait \
        --timeout 10m

    wait_for_pods

    local pod_name=$(get_pod_name)

    kubectl exec -n "$TEST_NAMESPACE" "$pod_name" -- python3 -c '
from pyspark.sql import SparkSession
spark = SparkSession.builder.appName(\"Combined-Test\").getOrCreate()
df = spark.range(1000)
df.count()
spark.sql(\"DROP TABLE IF EXISTS test_combined_table\")
spark.sql(\"CREATE TABLE test_combined_table (id BIGINT, data STRING) USING iceberg\")
spark.sql(\"INSERT INTO test_combined_table VALUES (1, \"gpu-iceberg-test\")\")
spark.stop()
print(\"COMBINED_JOB_SUCCESS\")
'

    echo -e "${GREEN}✓ Combined workload test PASSED${NC}"
}

cleanup() {
    echo ""
    echo "========================================"
    echo "Cleanup"
    echo "========================================"

    # Delete service accounts first
    for preset in dev gpu iceberg combined; do
        kubectl delete serviceaccount "spark-${preset}-spark-e2e-${TEST_NAMESPACE}" -n "$TEST_NAMESPACE" &> /dev/null || true
        kubectl delete rolebinding "spark-${preset}-spark-e2e-${TEST_NAMESPACE}" -n "$TEST_NAMESPACE" &> /dev/null || true
        kubectl delete role "spark-${preset}-spark-e2e-${TEST_NAMESPACE}" -n "$TEST_NAMESPACE" &> /dev/null || true
    done

    for release in spark-e2e-dev spark-e2e-gpu spark-e2e-iceberg spark-combined minio; do
        helm uninstall "$release" -n "$TEST_NAMESPACE" &> /dev/null || true
    done

    kubectl delete namespace "$TEST_NAMESPACE" &> /dev/null || true

    echo -e "${GREEN}✓ Cleanup complete${NC}"
}

main() {
    local run_all=false
    local run_gpu=false
    local run_iceberg=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --all) run_all=true; shift ;;
            --gpu) run_gpu=true; shift ;;
            --iceberg) run_iceberg=true; shift ;;
            --skip-gpu) export SKIP_GPU=true; shift ;;
            --skip-iceberg) export SKIP_ICEBERG=true; shift ;;
            *) echo "Unknown option: $1"; exit 1 ;;
        esac
    done

    if [[ "$run_all" == "true" ]]; then
        run_gpu=true
        run_iceberg=true
    fi

    trap cleanup EXIT

    check_prerequisites
    create_namespace

    test_basic_deployment

    if [[ "$run_gpu" == "true" ]]; then
        test_gpu_workload
    fi

    if [[ "$run_iceberg" == "true" ]]; then
        test_iceberg_workload
    fi

    if [[ "$run_gpu" == "true" ]] && [[ "$run_iceberg" == "true" ]]; then
        test_combined_workload
    fi

    echo ""
    echo "========================================"
    echo -e "${GREEN}All E2E tests PASSED!${NC}"
    echo "========================================"
}

main "$@"
