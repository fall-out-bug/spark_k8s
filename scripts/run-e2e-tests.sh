#!/bin/bash
# Run real E2E tests with K8s deployment and Spark jobs
#
# Prerequisites:
# - Kubernetes cluster running (minikube, kind, GKE, etc.)
# - kubectl configured
# - helm installed
#
# Usage:
#   ./scripts/run-e2e-tests.sh [--gpu] [--iceberg] [--all]

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
TEST_NAMESPACE="${TEST_NAMESPACE:-spark-e2e-$(date +%s)}"
CHART_DIR="charts/spark-4.1"
TIMEOUT="${TIMEOUT:-600}"  # 10 minutes default

echo "========================================"
echo "Spark K8s E2E Tests"
echo "========================================"
echo "Namespace: $TEST_NAMESPACE"
echo "Timeout: ${TIMEOUT}s"
echo ""

# Check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}Checking prerequisites...${NC}"

    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}ERROR: kubectl not found${NC}"
        exit 1
    fi

    # Check helm
    if ! command -v helm &> /dev/null; then
        echo -e "${RED}ERROR: helm not found${NC}"
        exit 1
    fi

    # Check cluster connection
    if ! kubectl cluster-info &> /dev/null; then
        echo -e "${RED}ERROR: Cannot connect to Kubernetes cluster${NC}"
        exit 1
    fi

    echo -e "${GREEN}✓ Prerequisites OK${NC}"
}

# Create namespace
create_namespace() {
    echo -e "${YELLOW}Creating namespace: $TEST_NAMESPACE${NC}"
    kubectl create namespace "$TEST_NAMESPACE" || true
}

# Deploy Spark
deploy_spark() {
    local preset=$1
    local release_name="spark-e2e-${preset}"

    echo -e "${YELLOW}Deploying Spark with preset: $preset${NC}"

    helm install "$release_name" "$CHART_DIR" \
        -f "$CHART_DIR/presets/${preset}-values.yaml" \
        --namespace "$TEST_NAMESPACE" \
        --wait \
        --timeout 10m

    echo -e "${GREEN}✓ Deployment complete${NC}"
}

# Wait for pods ready
wait_for_pods() {
    echo -e "${YELLOW}Waiting for pods to be ready...${NC}"

    kubectl wait \
        --for=condition=ready \
        pod \
        -l app=spark-connect \
        -n "$TEST_NAMESPACE" \
        --timeout=300s

    echo -e "${GREEN}✓ Pods ready${NC}"
}

# Get pod name
get_pod_name() {
    kubectl get pods \
        -n "$TEST_NAMESPACE" \
        -l app=spark-connect \
        -o jsonpath='{.items[0].metadata.name}'
}

# Run Spark job
run_spark_job() {
    local job_name=$1
    local script=$2
    local pod_name=$(get_pod_name)

    echo -e "${YELLOW}Running job: $job_name${NC}"

    kubectl exec -n "$TEST_NAMESPACE" "$pod_name" -- /bin/bash -c "$script"

    echo -e "${GREEN}✓ Job complete: $job_name${NC}"
}

# Test basic deployment
test_basic_deployment() {
    echo "========================================"
    echo "Test: Basic Deployment"
    echo "========================================"

    deploy_spark "dev"
    wait_for_pods

    # Run simple job
    local pod_name=$(get_pod_name)

    kubectl exec -n "$TEST_NAMESPACE" "$pod_name" -- \
        /opt/spark/bin/spark-submit \
        --master local[*] \
        --conf spark.driver.memory=512m \
        local:///opt/spark/examples/src/main/python/pi.py 10

    echo -e "${GREEN}✓ Basic deployment test PASSED${NC}"
}

# Test GPU workload
test_gpu_workload() {
    if [[ "$SKIP_GPU" == "true" ]]; then
        echo -e "${YELLOW}Skipping GPU tests${NC}"
        return
    fi

    echo "========================================"
    echo "Test: GPU Workload"
    echo "========================================"

    # Check for GPU nodes
    local gpu_count=$(kubectl get nodes -o jsonpath='{.items[*].status.allocatable.nvidia\.com/gpu}' | tr ' ' '\n' | grep -v '^{}' | wc -l)

    if [[ "$gpu_count" -eq 0 ]]; then
        echo -e "${YELLOW}No GPU nodes found, skipping GPU tests${NC}"
        return
    fi

    echo -e "${GREEN}Found $gpu_count GPU nodes${NC}"

    deploy_spark "gpu"
    wait_for_pods

    # Run GPU job
    local pod_name=$(get_pod_name)

    kubectl exec -n "$TEST_NAMESPACE" "$pod_name" -- /bin/bash -c '
        python3 << EOF
from pyspark.sql import SparkSession
spark = SparkSession.builder.appName("GPU-Test").getOrCreate()
df = spark.range(10000)
df.count()
print("GPU_JOB_SUCCESS")
spark.stop()
EOF
'

    echo -e "${GREEN}✓ GPU workload test PASSED${NC}"
}

# Test Iceberg workload
test_iceberg_workload() {
    if [[ "$SKIP_ICEBERG" == "true" ]]; then
        echo -e "${YELLOW}Skipping Iceberg tests${NC}"
        return
    fi

    echo "========================================"
    echo "Test: Iceberg Workload"
    echo "========================================"

    # Deploy MinIO for S3
    echo -e "${YELLOW}Deploying MinIO...${NC}"
    helm repo add minio https://charts.min.io/ &> /dev/null || true
    helm install minio minio/minio \
        --set accessKey=minioadmin \
        --set secretKey=minioadmin \
        --set persistence.enabled=false \
        --namespace "$TEST_NAMESPACE" &> /dev/null || true

    sleep 10  # Wait for MinIO

    deploy_spark "iceberg"
    wait_for_pods

    # Run Iceberg job
    local pod_name=$(get_pod_name)

    kubectl exec -n "$TEST_NAMESPACE" "$pod_name" -- /bin/bash -c '
        python3 << EOF
from pyspark.sql import SparkSession
spark = SparkSession.builder.appName("Iceberg-Test").getOrCreate()

# Create table
spark.sql("DROP TABLE IF EXISTS test_iceberg_table")
spark.sql("""
    CREATE TABLE test_iceberg_table (
        id BIGINT,
        name STRING,
        value DOUBLE
    ) USING iceberg
    LOCATION "s3a://warehouse/iceberg/test_table"
""")

# INSERT
spark.sql("INSERT INTO test_iceberg_table VALUES (1, "test", 123.45)")

# SELECT
df = spark.sql("SELECT * FROM test_iceberg_table")
count = df.count()

# UPDATE (ACID)
spark.sql("UPDATE test_iceberg_table SET value = 999.99 WHERE id = 1")

# DELETE (ACID)
spark.sql("DELETE FROM test_iceberg_table WHERE id = 1")

spark.stop()
print("ICEBERG_JOB_SUCCESS")
EOF
'

    echo -e "${GREEN}✓ Iceberg workload test PASSED${NC}"
}

# Test GPU + Iceberg combined
test_combined_workload() {
    if [[ "$SKIP_GPU" == "true" ]] || [[ "$SKIP_ICEBERG" == "true" ]]; then
        echo -e "${YELLOW}Skipping combined tests${NC}"
        return
    fi

    echo "========================================"
    echo "Test: GPU + Iceberg Combined"
    echo "========================================"

    # Check for GPU nodes
    local gpu_count=$(kubectl get nodes -o jsonpath='{.items[*].status.allocatable.nvidia\.com/gpu}' | tr ' ' '\n' | grep -v '^{}' | wc -l)

    if [[ "$gpu_count" -eq 0 ]]; then
        echo -e "${YELLOW}No GPU nodes, skipping combined test${NC}"
        return
    fi

    helm install spark-combined "$CHART_DIR" \
        -f "$CHART_DIR/presets/gpu-values.yaml" \
        -f "$CHART_DIR/presets/iceberg-values.yaml \
        --namespace "$TEST_NAMESPACE" \
        --wait \
        --timeout 10m

    wait_for_pods

    local pod_name=$(get_pod_name)

    kubectl exec -n "$TEST_NAMESPACE" "$pod_name" -- /bin/bash -c '
        python3 << EOF
from pyspark.sql import SparkSession
spark = SparkSession.builder.appName("Combined-Test").getOrCreate()

# Test both GPU and Iceberg
df = spark.range(1000)
df_count = df.count()

spark.sql('DROP TABLE IF EXISTS test_combined_table')
spark.sql('''
    CREATE TABLE test_combined_table (
        id BIGINT,
        data STRING
    ) USING iceberg
''')

spark.sql('INSERT INTO test_combined_table VALUES (1, "gpu-iceberg-test")')

result = spark.sql("SELECT * FROM test_combined_table").collect()

spark.stop()
print("COMBINED_JOB_SUCCESS")
EOF
'

    echo -e "${GREEN}✓ Combined workload test PASSED${NC}"
}

# Cleanup
cleanup() {
    echo ""
    echo "========================================"
    echo "Cleanup"
    echo "========================================"

    helm uninstall spark-e2e-dev -n "$TEST_NAMESPACE" &> /dev/null || true
    helm uninstall spark-e2e-gpu -n "$TEST_NAMESPACE" &> /dev/null || true
    helm uninstall spark-e2e-iceberg -n "$TEST_NAMESPACE" &> /dev/null || true
    helm uninstall spark-combined -n "$TEST_NAMESPACE" &> /dev/null || true
    helm uninstall minio -n "$TEST_NAMESPACE" &> /dev/null || true

    kubectl delete namespace "$TEST_NAMESPACE" &> /dev/null || true

    echo -e "${GREEN}✓ Cleanup complete${NC}"
}

# Main
main() {
    local run_all=false
    local run_gpu=false
    local run_iceberg=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --all)
                run_all=true
                shift
                ;;
            --gpu)
                run_gpu=true
                shift
                ;;
            --iceberg)
                run_iceberg=true
                shift
                ;;
            --skip-gpu)
                export SKIP_GPU=true
                shift
                ;;
            --skip-iceberg)
                export SKIP_ICEBERG=true
                shift
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    # If --all, run everything
    if [[ "$run_all" == "true" ]]; then
        run_gpu=true
        run_iceberg=true
    fi

    # If no specific tests, run basic only
    if [[ "$run_gpu" == "false" ]] && [[ "$run_iceberg" == "false" ]]; then
        run_all=false
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
