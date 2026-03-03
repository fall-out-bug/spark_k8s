#!/bin/bash
# Lego-Spark Test Matrix Runner
# Runs tests for each scenario in isolated namespace, cleans up after
# shellcheck disable=SC2034,SC2155

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_MATRIX="$SCRIPT_DIR/test-matrix.yaml"
RESULTS_DIR="$SCRIPT_DIR/results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
PASSED=0
FAILED=0
SKIPPED=0
TOTAL=0

# Defaults
TIMEOUT=10
TEST_TYPE="smoke"
SCENARIO_FILTER=""

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; }
log_skip() { echo -e "${YELLOW}[SKIP]${NC} $1"; }

usage() {
    cat << EOF
Usage: $0 [test-type] [options]

Test Types:
  smoke   Run smoke tests only (default, ~3 min per scenario)
  e2e     Run e2e tests (~10 min per scenario)
  load    Run load tests (~15 min per scenario)
  all     Run all test types

Options:
  --filter "key=value,key=value"  Filter scenarios (e.g. id=SCENARIO-0009)
  --timeout <min>                 Timeout per scenario (default: 10)
  --help                          Show this help

Examples:
  $0 smoke --filter "id=SCENARIO-0009"
  $0 smoke --filter "spark_version=3.5.7,platform=k8s,gpu=false"
  $0 e2e --filter "gpu=false"
  $0 all
EOF
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --filter)
            SCENARIO_FILTER="$2"
            shift 2
            ;;
        --timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        --help|-h)
            usage
            ;;
        smoke|e2e|load|all)
            TEST_TYPE="$1"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Get scenarios from matrix
get_scenarios() {
    python3 << PYEOF
import yaml
import json

with open("$TEST_MATRIX", "r") as f:
    matrix = yaml.safe_load(f)

scenarios = matrix['scenarios']
filter_str = "$SCENARIO_FILTER"

if filter_str:
    filters = filter_str.split(',')
    for f in filters:
        key, value = f.split('=', 1)
        if value.lower() == 'true':
            scenarios = [s for s in scenarios if s.get(key) == True]
        elif value.lower() == 'false':
            scenarios = [s for s in scenarios if s.get(key) == False]
        else:
            scenarios = [s for s in scenarios if str(s.get(key, '')).lower() == value.lower()]

print(json.dumps(scenarios))
PYEOF
}

# Map scenario to runtime image (spark-custom for local minikube, spark-k8s-runtime for CI)
MATRIX_IMAGE_REPO="${MATRIX_IMAGE_REPO:-spark-custom}"

get_runtime_image() {
    local spark_version="$1"
    local gpu="$2"
    local iceberg="$3"

    case "$spark_version" in
        3.5.7|3.5.8) echo "${MATRIX_IMAGE_REPO}:3.5.7" ;;
        4.1.0) echo "${MATRIX_IMAGE_REPO}:4.1.0" ;;
        4.1.1) echo "spark-k8s-runtime:4.1-4.1.1-baseline" ;;
        *) echo "${MATRIX_IMAGE_REPO}:3.5.7" ;;
    esac
}

# Run single scenario
run_scenario() {
    local scenario_json="$1"
    local scenario_id=$(echo "$scenario_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")
    local scenario_name=$(echo "$scenario_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['name'])")
    local spark_version=$(echo "$scenario_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['spark_version'])")
    local gpu=$(echo "$scenario_json" | python3 -c "import json,sys; print(str(json.load(sys.stdin).get('gpu', False)).lower())")
    local iceberg=$(echo "$scenario_json" | python3 -c "import json,sys; print(str(json.load(sys.stdin).get('iceberg', False)).lower())")

    local ns="test-${scenario_id,,}"
    local release="spark"
    local result="PASS"
    local start_time=$(date +%s)

    # Get runtime image
    local runtime_image=$(get_runtime_image "$spark_version" "$gpu" "$iceberg")

    log_info "Scenario: $scenario_name"
    log_info "Image: $runtime_image"

    # Check if image exists
    if ! docker image inspect "$runtime_image" &>/dev/null; then
        log_skip "$scenario_id - Image not found: $runtime_image"
        ((SKIPPED++)) || true
        return 0
    fi

    # Create namespace (delete if leftover from previous run)
    kubectl delete namespace "$ns" --ignore-not-found --wait=false >/dev/null 2>&1 || true
    sleep 3
    kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f - >/dev/null 2>&1

    # Deploy Spark using spark-standalone chart with custom image
    local chart="spark-3.5/charts/spark-standalone"
    if [[ "$spark_version" == 4.1* ]]; then
        chart="spark-4.1/charts/spark-standalone"
    fi

    # Extract image repo and tag from runtime image
    local image_repo=$(echo "$runtime_image" | cut -d: -f1)
    local image_tag=$(echo "$runtime_image" | cut -d: -f2)

    if ! timeout ${TIMEOUT}m helm install "$release" "$PROJECT_ROOT/charts/$chart" \
        --namespace "$ns" \
        --set master.image.repository="$image_repo" \
        --set master.image.tag="$image_tag" \
        --set worker.image.repository="$image_repo" \
        --set worker.image.tag="$image_tag" \
        --set master.resources.requests.cpu=500m \
        --set master.resources.requests.memory=512Mi \
        --set worker.resources.requests.cpu=200m \
        --set worker.resources.requests.memory=512Mi \
        --set airflow.enabled=false \
        --timeout 5m --wait >/dev/null 2>&1; then
        result="FAIL"
        log_fail "Deploy failed: $scenario_id"
    else
        # Wait for master
        if ! kubectl wait --for=condition=Ready pod -l app.kubernetes.io/component=spark-master -n "$ns" --timeout=180s >/dev/null 2>&1; then
            result="FAIL"
            log_fail "Master not ready: $scenario_id"
        else
            local master_pod=$(kubectl get pod -n "$ns" -l app.kubernetes.io/component=spark-master -o jsonpath='{.items[0].metadata.name}')
            local master_service="${release}-spark-standalone-master"

            # Run test
            case "$TEST_TYPE" in
                smoke)
                    if ! run_smoke_test "$ns" "$master_pod" "$master_service"; then
                        result="FAIL"
                    fi
                    ;;
                e2e)
                    if ! run_e2e_test "$ns" "$master_pod" "$master_service"; then
                        result="FAIL"
                    fi
                    ;;
                load)
                    if ! run_load_test "$ns" "$master_pod" "$master_service"; then
                        result="FAIL"
                    fi
                    ;;
                all)
                    if ! run_smoke_test "$ns" "$master_pod" "$master_service" || \
                       ! run_e2e_test "$ns" "$master_pod" "$master_service" || \
                       ! run_load_test "$ns" "$master_pod" "$master_service"; then
                        result="FAIL"
                    fi
                    ;;
            esac
        fi
    fi

    # Cleanup - sync delete namespace after each scenario
    helm uninstall "$release" -n "$ns" --wait >/dev/null 2>&1 || true
    kubectl delete namespace "$ns" --ignore-not-found --wait=false >/dev/null 2>&1 || true
    local wait_count=0
    while kubectl get namespace "$ns" >/dev/null 2>&1 && [[ $wait_count -lt 30 ]]; do
        sleep 2
        ((wait_count++)) || true
    done

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    if [[ "$result" == "PASS" ]]; then
        ((PASSED++)) || true
        log_pass "$scenario_id (${duration}s)"
    else
        ((FAILED++)) || true
        log_fail "$scenario_id (${duration}s)"
    fi

    generate_junit "$scenario_id" "$scenario_name" "$TEST_TYPE" "$result" "$duration"
}

# Copy NYC Taxi pipeline script to pod
copy_nyc_pipeline() {
    local ns="$1"
    local master_pod="$2"
    kubectl cp "$PROJECT_ROOT/tests/scripts/nyc_taxi_pipeline.py" "$ns/$master_pod:/tmp/nyc_taxi_pipeline.py" 2>/dev/null || true
}

# Smoke test - NYC Taxi pipeline (1K rows, no SparkPi)
run_smoke_test() {
    local ns="$1"
    local master_pod="$2"
    local master_service="$3"
    local driver_host
    driver_host=$(kubectl get pod -n "$ns" "$master_pod" -o jsonpath='{.status.podIP}' 2>/dev/null || echo "")
    copy_nyc_pipeline "$ns" "$master_pod"
    kubectl exec -n "$ns" "$master_pod" -- env \
        TEST_LEVEL=smoke \
        MASTER_URL="spark://${master_service}:7077" \
        DRIVER_HOST="${driver_host}" \
        python3 /tmp/nyc_taxi_pipeline.py 2>&1 | grep -q "SMOKE_SUCCESS"
}

# E2E test - NYC Taxi pipeline (10K rows, aggregations, joins)
run_e2e_test() {
    local ns="$1"
    local master_pod="$2"
    local master_service="$3"
    local driver_host
    driver_host=$(kubectl get pod -n "$ns" "$master_pod" -o jsonpath='{.status.podIP}' 2>/dev/null || echo "")
    copy_nyc_pipeline "$ns" "$master_pod"
    kubectl exec -n "$ns" "$master_pod" -- env \
        TEST_LEVEL=e2e \
        MASTER_URL="spark://${master_service}:7077" \
        DRIVER_HOST="${driver_host}" \
        python3 /tmp/nyc_taxi_pipeline.py 2>&1 | grep -q "E2E_SUCCESS"
}

# Load test - NYC Taxi pipeline (S3 or 100K in-memory)
run_load_test() {
    local ns="$1"
    local master_pod="$2"
    local master_service="$3"
    local driver_host
    driver_host=$(kubectl get pod -n "$ns" "$master_pod" -o jsonpath='{.status.podIP}' 2>/dev/null || echo "")
    copy_nyc_pipeline "$ns" "$master_pod"
    kubectl exec -n "$ns" "$master_pod" -- env \
        TEST_LEVEL=load \
        MASTER_URL="spark://${master_service}:7077" \
        DRIVER_HOST="${driver_host}" \
        S3_ENDPOINT="http://minio.spark-infra.svc.cluster.local:9000" \
        python3 /tmp/nyc_taxi_pipeline.py 2>&1 | grep -q "LOAD_SUCCESS"
}

# Generate JUnit XML
generate_junit() {
    local scenario_id="$1"
    local scenario_name="$2"
    local test_type="$3"
    local result="$4"
    local duration="$5"

    local junit_dir="$RESULTS_DIR/junit"
    mkdir -p "$junit_dir"

    cat > "$junit_dir/${scenario_id}-${test_type}.xml" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="${scenario_id}" tests="1" failures="$([ "$result" = "FAIL" ] && echo 1 || echo 0)" time="${duration}">
  <testcase name="${test_type}" classname="${scenario_name}" time="${duration}">
$([ "$result" = "FAIL" ] && echo "    <failure message=\"Test failed\"/>" || echo "")
  </testcase>
</testsuite>
EOF
}

# Main
mkdir -p "$RESULTS_DIR/junit"

log_info "=============================================="
log_info "Lego-Spark Test Matrix Runner"
log_info "=============================================="
log_info "Test type: $TEST_TYPE"
log_info "Filter: ${SCENARIO_FILTER:-none}"
log_info "Timeout: ${TIMEOUT}m per scenario"
log_info ""

# Get scenarios
SCENARIOS=$(get_scenarios)
SCENARIO_COUNT=$(echo "$SCENARIOS" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))")

log_info "Scenarios to run: $SCENARIO_COUNT"

if [[ "$SCENARIO_COUNT" -eq 0 ]]; then
    log_fail "No scenarios match filter: $SCENARIO_FILTER"
    exit 1
fi

# Estimate time
ESTIMATED_MIN=$((SCENARIO_COUNT * 3))
log_info "Estimated time: ~${ESTIMATED_MIN}min"
echo ""

# Run scenarios
START_TOTAL=$(date +%s)

while read -r scenario_id; do
    ((TOTAL++)) || true
    scenario_json=$(SID="$scenario_id" python3 -c "
import json, sys, os
sid = os.environ.get('SID', '')
data = json.load(sys.stdin)
for s in data:
    if s.get('id') == sid:
        print(json.dumps(s))
        break
" <<< "$SCENARIOS")
    run_scenario "$scenario_json"
done < <(echo "$SCENARIOS" | python3 -c "
import json, sys
for s in json.load(sys.stdin):
    print(s['id'])
")

END_TOTAL=$(date +%s)
TOTAL_DURATION=$((END_TOTAL - START_TOTAL))

# Summary
echo ""
log_info "=============================================="
log_info "TEST SUMMARY"
log_info "=============================================="
echo -e "Total:   $TOTAL"
echo -e "Passed:  ${GREEN}$PASSED${NC}"
echo -e "Failed:  ${RED}$FAILED${NC}"
echo -e "Skipped: ${YELLOW}$SKIPPED${NC}"
echo -e "Duration: ${TOTAL_DURATION}s ($((TOTAL_DURATION / 60))m)"
echo ""

if [[ $FAILED -gt 0 ]]; then
    log_fail "Some tests failed"
    exit 1
else
    log_pass "All tests passed"
    exit 0
fi
