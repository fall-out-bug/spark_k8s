#!/bin/bash
# Direct Load Test Execution for WS-025-11
# Simplified version that directly runs load tests without complex test infrastructure

set +e  # Don't exit on error

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
RESULTS_DIR="${RESULTS_DIR:-/tmp/load-test-results}"
MINIO_NAMESPACE="${MINIO_NAMESPACE:-spark-load-test}"
CHART_PATH="${PROJECT_ROOT}/charts/spark-3.5"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_section() { echo ""; echo "========================================"; echo "$1"; echo "========================================"; echo ""; }

# Create results directory
mkdir -p "$RESULTS_DIR"

# Results tracking
declare -A RESULTS
TOTAL_SCENARIOS=0
PASSED_SCENARIOS=0
FAILED_SCENARIOS=0

# ============================================================================
# Scenario Definitions
# ============================================================================

# Scenarios: name:preset_file:namespace_suffix
SCENARIOS=(
    "jupyter-connect-k8s-357:jupyter-connect-k8s-3.5.7.yaml:jck8s357"
    "jupyter-connect-standalone-357:jupyter-connect-standalone-3.5.7.yaml:jcsa357"
    "airflow-connect-k8s-357:airflow-connect-k8s-3.5.7.yaml:ack8s357"
    "airflow-connect-standalone-357:airflow-connect-standalone-3.5.7.yaml:acsa357"
)

# Workloads to run
WORKLOADS=("read" "aggregate" "join" "window" "write")

# ============================================================================
# Helper Functions
# ============================================================================

generate_test_id() {
    echo "ws$(date +%Y%m%d%H%M%S)"
}

wait_for_pods() {
    local namespace="$1"
    local timeout="${2:-600}"
    local elapsed=0

    log_info "Waiting for pods in namespace $namespace (timeout: ${timeout}s)"

    while [[ $elapsed -lt $timeout ]]; do
        local not_ready=$(kubectl get pods -n "$namespace" --no-headers 2>/dev/null | grep -v "Running\|Completed\|Succeeded" | wc -l)
        if [[ $not_ready -eq 0 ]]; then
            log_success "All pods ready in $namespace"
            return 0
        fi
        echo -n "."
        sleep 5
        elapsed=$((elapsed + 5))
    done
    echo ""
    log_error "Timeout waiting for pods in $namespace"
    return 1
}

get_minio_endpoint() {
    # Get MinIO service endpoint
    local minio_svc=$(kubectl get svc -n "$MINIO_NAMESPACE" minio -o jsonpath='{.spec.clusterIP}:{.spec.ports[0].port}' 2>/dev/null)
    if [[ -n "$minio_svc" ]]; then
        echo "http://$minio_svc"
    else
        echo "http://minio:9000"
    fi
}

run_workload() {
    local scenario_name="$1"
    local namespace="$2"
    local workload="$3"
    local connect_url="$4"

    log_info "Running workload: $workload for scenario $scenario_name"

    # Find a pod to execute from
    local exec_pod
    if [[ "$scenario_name" == jupyter-* ]]; then
        # Try multiple label selectors for jupyter
        exec_pod=$(kubectl get pods -n "$namespace" -l app.kubernetes.io/component=jupyter -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
        if [[ -z "$exec_pod" ]]; then
            exec_pod=$(kubectl get pods -n "$namespace" -l app=jupyter -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
        fi
        if [[ -z "$exec_pod" ]]; then
            exec_pod=$(kubectl get pods -n "$namespace" -l component=jupyter -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
        fi
    fi

    # If still no pod or not jupyter, try connect labels
    if [[ -z "$exec_pod" ]]; then
        exec_pod=$(kubectl get pods -n "$namespace" -l app.kubernetes.io/component=connect -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
        if [[ -z "$exec_pod" ]]; then
            exec_pod=$(kubectl get pods -n "$namespace" -l app=connect -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
        fi
        if [[ -z "$exec_pod" ]]; then
            exec_pod=$(kubectl get pods -n "$namespace" -l component=connect -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
        fi
    fi

    # Last resort: get any running pod
    if [[ -z "$exec_pod" ]]; then
        exec_pod=$(kubectl get pods -n "$namespace" -o jsonpath='{.items[?(@.status.phase=="Running")].metadata.name}' 2>/dev/null | head -1)
    fi

    if [[ -z "$exec_pod" ]]; then
        log_error "No pod found to execute workload"
        return 1
    fi

    log_info "Using pod: $exec_pod"

    # Create a simple Python script to run the workload
    local minio_endpoint=$(get_minio_endpoint)

    # Build workload script based on type
    local workload_code=""

    case "$workload" in
        read)
            workload_code="
import time
from pyspark.sql import SparkSession
spark = SparkSession.builder.remote('${connect_url}').config('spark.hadoop.fs.s3a.endpoint', '${minio_endpoint}').config('spark.hadoop.fs.s3a.access.key', 'minioadmin').config('spark.hadoop.fs.s3a.secret.key', 'minioadmin').config('spark.hadoop.fs.s3a.path.style.access', 'true').appName('load-test-read').getOrCreate()
start = time.time()
df = spark.read.parquet('s3a://raw-data/*.parquet')
count = df.count()
duration = time.time() - start
print(f'SUCCESS|{duration}|{count}')
spark.stop()
"
            ;;
        aggregate)
            workload_code="
import time
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, count, spark_sum, avg
spark = SparkSession.builder.remote('${connect_url}').config('spark.hadoop.fs.s3a.endpoint', '${minio_endpoint}').config('spark.hadoop.fs.s3a.access.key', 'minioadmin').config('spark.hadoop.fs.s3a.secret.key', 'minioadmin').config('spark.hadoop.fs.s3a.path.style.access', 'true').config('spark.sql.shuffle.partitions', '200').appName('load-test-aggregate').getOrCreate()
start = time.time()
df = spark.read.parquet('s3a://raw-data/*.parquet')
result = df.groupBy('PULocationID').agg(count('*').alias('trip_count'), spark_sum('fare_amount').alias('total_fare'), avg('trip_distance').alias('avg_distance'))
count = result.count()
duration = time.time() - start
print(f'SUCCESS|{duration}|{count}')
spark.stop()
"
            ;;
        join)
            workload_code="
import time
from pyspark.sql import SparkSession
spark = SparkSession.builder.remote('${connect_url}').config('spark.hadoop.fs.s3a.endpoint', '${minio_endpoint}').config('spark.hadoop.fs.s3a.access.key', 'minioadmin').config('spark.hadoop.fs.s3a.secret.key', 'minioadmin').config('spark.hadoop.fs.s3a.path.style.access', 'true').config('spark.sql.shuffle.partitions', '200').appName('load-test-join').getOrCreate()
start = time.time()
df = spark.read.parquet('s3a://raw-data/*.parquet')
df_cached = df.cache()
df_cached.count()
joined = df_cached.alias('a').join(df_cached.alias('b'), col('a.PULocationID') == col('b.PULocationID'), 'inner')
count = joined.count()
duration = time.time() - start
print(f'SUCCESS|{duration}|{count}')
spark.stop()
"
            ;;
        window)
            workload_code="
import time
from pyspark.sql import SparkSession
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, avg, row_number
from pyspark.sql.window import Window
spark = SparkSession.builder.remote('${connect_url}').config('spark.hadoop.fs.s3a.endpoint', '${minio_endpoint}').config('spark.hadoop.fs.s3a.access.key', 'minioadmin').config('spark.hadoop.fs.s3a.secret.key', 'minioadmin').config('spark.hadoop.fs.s3a.path.style.access', 'true').config('spark.sql.shuffle.partitions', '200').appName('load-test-window').getOrCreate()
start = time.time()
df = spark.read.parquet('s3a://raw-data/*.parquet')
window_spec = Window.partitionBy('PULocationID').orderBy('tpep_pickup_datetime')
result = df.select('PULocationID', 'fare_amount', row_number().over(window_spec).alias('row_num'))
count = result.count()
duration = time.time() - start
print(f'SUCCESS|{duration}|{count}')
spark.stop()
"
            ;;
        write)
            workload_code="
import time
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, count, spark_sum, avg
spark = SparkSession.builder.remote('${connect_url}').config('spark.hadoop.fs.s3a.endpoint', '${minio_endpoint}').config('spark.hadoop.fs.s3a.access.key', 'minioadmin').config('spark.hadoop.fs.s3a.secret.key', 'minioadmin').config('spark.hadoop.fs.s3a.path.style.access', 'true').config('spark.sql.shuffle.partitions', '200').appName('load-test-write').getOrCreate()
start = time.time()
df = spark.read.parquet('s3a://raw-data/*.parquet')
summary = df.groupBy('PULocationID').agg(count('*').alias('trip_count'), spark_sum('fare_amount').alias('total_fare'), avg('trip_distance').alias('avg_distance'))
summary.write.mode('overwrite').parquet('s3a://processed-data/trip_summary/')
duration = time.time() - start
print(f'SUCCESS|{duration}|written')
spark.stop()
"
            ;;
        *)
            log_error "Unknown workload: $workload"
            return 1
            ;;
    esac

    # Execute the workload
    local result=$(kubectl exec -n "$namespace" "$exec_pod" -- python3 -c "$workload_code" 2>&1 || echo "FAILED|0|0")

    if echo "$result" | grep -q "^SUCCESS"; then
        local duration=$(echo "$result" | cut -d'|' -f2)
        local rows=$(echo "$result" | cut -d'|' -f3)
        log_success "Workload $workload completed in ${duration}s (${rows} rows)"
        echo "${workload}:${duration}:${rows}" >> "${RESULTS_DIR}/${scenario_name}.txt"
        return 0
    else
        log_error "Workload $workload failed: $result"
        echo "${workload}:FAILED:0" >> "${RESULTS_DIR}/${scenario_name}.txt"
        return 1
    fi
}

run_scenario() {
    local scenario_name="$1"
    local preset_file="$2"
    local namespace_suffix="$3"

    local namespace="ws-load-${namespace_suffix}"
    local release_name="${namespace_suffix}-$(generate_test_id)"

    log_section "Scenario: $scenario_name"

    # Create namespace
    log_info "Creating namespace: $namespace"
    kubectl create namespace "$namespace" 2>/dev/null || log_info "Namespace already exists"

    # Deploy using Helm
    log_info "Deploying with Helm"
    local preset_path="${CHART_PATH}/${preset_file}"
    if [[ ! -f "$preset_path" ]]; then
        log_error "Preset file not found: $preset_path"
        return 1
    fi

    helm install "$release_name" "$CHART_PATH" \
        --namespace "$namespace" \
        --values "$preset_path" \
        --timeout 15m \
        --wait 2>&1 | head -20

    if [[ $? -ne 0 ]]; then
        log_error "Helm install failed"
        kubectl delete namespace "$namespace" --ignore-not-found
        return 1
    fi

    # Wait for pods
    if ! wait_for_pods "$namespace" 600; then
        log_error "Pods not ready"
        helm uninstall "$release_name" -n "$namespace" 2>/dev/null || true
        kubectl delete namespace "$namespace" --ignore-not-found
        return 1
    fi

    # Get Connect URL
    local connect_url="sc://${release_name}-spark-35-connect:15002"

    # Run workloads
    local passed=0
    local failed=0

    for workload in "${WORKLOADS[@]}"; do
        log_info "Running workload: $workload"
        if run_workload "$scenario_name" "$namespace" "$workload" "$connect_url"; then
            ((passed++))
        else
            ((failed++))
        fi
    done

    # Cleanup
    log_info "Cleaning up..."
    helm uninstall "$release_name" -n "$namespace" 2>/dev/null || true
    kubectl delete namespace "$namespace" --ignore-not-found --timeout=60s

    log_info "Scenario $scenario_name: $passed passed, $failed failed"

    if [[ $failed -eq 0 ]]; then
        RESULTS["${scenario_name}"]="PASSED"
        ((PASSED_SCENARIOS++))
        return 0
    else
        RESULTS["${scenario_name}"]="PARTIAL"
        ((FAILED_SCENARIOS++))
        return 1
    fi
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    log_section "WS-025-11: Load Test Execution"
    log_info "MinIO Namespace: $MINIO_NAMESPACE"
    log_info "Chart Path: $CHART_PATH"
    log_info "Results Directory: $RESULTS_DIR"

    # Check prerequisites
    log_info "Checking MinIO..."
    if ! kubectl get svc -n "$MINIO_NAMESPACE" minio &>/dev/null; then
        log_error "MinIO not found in namespace $MINIO_NAMESPACE"
        exit 1
    fi
    log_success "MinIO found"

    log_info "Checking Helm..."
    if ! command -v helm &>/dev/null; then
        log_error "Helm not found"
        exit 1
    fi
    log_success "Helm found"

    # Execute scenarios
    local total_scenarios=${#SCENARIOS[@]}
    local current=0

    for scenario_entry in "${SCENARIOS[@]}"; do
        ((current++))
        IFS=':' read -r name preset suffix <<< "$scenario_entry"

        log_info "Starting scenario $current/$total_scenarios: $name"

        if run_scenario "$name" "$preset" "$suffix"; then
            log_success "Scenario $name PASSED"
        else
            log_error "Scenario $name FAILED"
        fi
    done

    # Print summary
    log_section "Load Test Summary"
    echo ""
    echo "Total Scenarios: $total_scenarios"
    echo "Passed: $PASSED_SCENARIOS"
    echo "Failed: $FAILED_SCENARIOS"
    echo ""

    for scenario_entry in "${SCENARIOS[@]}"; do
        IFS=':' read -r name preset suffix <<< "$scenario_entry"
        local result="${RESULTS[$name]:-UNKNOWN}"
        local status_icon
        case "$result" in
            "PASSED") status_icon="[OK]" ;;
            "PARTIAL") status_icon="[PARTIAL]" ;;
            "FAILED") status_icon="[FAIL]" ;;
            *) status_icon="[?]"
        esac
        echo "  $status_icon $name: $result"

        # Show workload details
        local results_file="${RESULTS_DIR}/${name}.txt"
        if [[ -f "$results_file" ]]; then
            while IFS=':' read -r workload duration rows; do
                printf "    - %-20s %8ss  %s\n" "$workload" "$duration" "$rows"
            done < "$results_file"
        fi
    done
    echo ""

    if [[ $FAILED_SCENARIOS -eq 0 ]]; then
        log_success "All load tests PASSED!"
        exit 0
    else
        log_error "Some load tests FAILED"
        exit 1
    fi
}

main "$@"
