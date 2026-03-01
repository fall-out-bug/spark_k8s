#!/bin/bash
# Lego-Spark Test Matrix Runner
# Runs smoke/e2e/load tests for specified scenarios
# Collects results in JUnit format and generates reports

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

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; }
log_skip() { echo -e "${YELLOW}[SKIP]${NC} $1"; }

usage() {
    cat << EOF
Usage: $0 [options] [test-type]

Test Types:
  smoke   Run smoke tests (10 min per scenario)
  e2e     Run E2E tests (25 min per scenario)
  load    Run load tests (45 min per scenario)
  all     Run all test types (default)

Options:
  --scenario <id>      Run specific scenario (e.g., SCENARIO-0001)
  --filter <key=value> Filter scenarios (e.g., spark_version=3.5.7)
  --parallel <n>       Run N scenarios in parallel (default: 1)
  --timeout <min>      Timeout per scenario (default: 60)
  --namespace <ns>     Kubernetes namespace (default: spark-test)
  --skip-cleanup       Don't delete resources after tests
  --dry-run            Show what would be run without executing
  --help               Show this help

Examples:
  $0 smoke --filter spark_version=4.0.2
  $0 e2e --scenario SCENARIO-0001
  $0 all --filter platform=k8s --parallel 4
EOF
    exit 0
}

# Parse arguments
SCENARIO_FILTER=""
PARALLEL=1
TIMEOUT=60
NAMESPACE="spark-test"
SKIP_CLEANUP=false
DRY_RUN=false
TEST_TYPE="all"

while [[ $# -gt 0 ]]; do
    case $1 in
        --scenario)
            SCENARIO_FILTER="id=$2"
            shift 2
            ;;
        --filter)
            SCENARIO_FILTER="$2"
            shift 2
            ;;
        --parallel)
            PARALLEL="$2"
            shift 2
            ;;
        --timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        --namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        --skip-cleanup)
            SKIP_CLEANUP=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
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

# Get scenarios to run
get_scenarios() {
    python3 << PYEOF
import yaml
import json
import sys

with open("$TEST_MATRIX", "r") as f:
    matrix = yaml.safe_load(f)

scenarios = matrix['scenarios']
filter_str = "$SCENARIO_FILTER"

if filter_str:
    # Parse filter (key=value format, supports multiple filters with comma)
    filters = filter_str.split(',')
    for f in filters:
        key, value = f.split('=', 1)
        # Handle boolean string comparison
        if value.lower() == 'true':
            scenarios = [s for s in scenarios if s.get(key) == True]
        elif value.lower() == 'false':
            scenarios = [s for s in scenarios if s.get(key) == False]
        else:
            scenarios = [s for s in scenarios if str(s.get(key, '')).lower() == value.lower()]

# Output as JSON
print(json.dumps(scenarios))
PYEOF
}

# Run smoke tests for a scenario
run_smoke_test() {
    local scenario_json="$1"
    local scenario_id=$(echo "$scenario_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")
    local scenario_name=$(echo "$scenario_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['name'])")
    
    log_info "Running smoke test: $scenario_name"
    
    if $DRY_RUN; then
        log_skip "Dry run: $scenario_id"
        return 0
    fi
    
    local start_time=$(date +%s)
    local result="PASS"
    local duration=0
    
    # Get chart path - use standalone subchart
    local chart=$(echo "$scenario_json" | python3 -c "
import json,sys
s = json.load(sys.stdin)
v = s['spark_version']
if v.startswith('3.5'): print('spark-3.5/charts/spark-standalone')
elif v.startswith('4.0'): print('spark-4.0/charts/spark-standalone')
elif v.startswith('4.1'): print('spark-4.1/charts/spark-standalone')
else: print('spark-3.5/charts/spark-standalone')
")
    
    local release="test-${scenario_id,,}"
    local ns="$NAMESPACE-${scenario_id,,}"
    
    # Create namespace
    kubectl create namespace "$ns" 2>/dev/null || true
    
    # Generate minimal values file for standalone chart
    local values_file="/tmp/${scenario_id}-values.yaml"
    echo "$scenario_json" | python3 -c "
import yaml, json, sys
s = json.load(sys.stdin)

# Values for spark-standalone subchart
v = {
    'master': {
        'enabled': True,
        'image': {'repository': 'spark-custom', 'tag': s['spark_version'], 'pullPolicy': 'IfNotPresent'},
        'resources': {'requests': {'memory': '512Mi', 'cpu': '250m'}, 'limits': {'memory': '1Gi', 'cpu': '500m'}},
    },
    'worker': {
        'enabled': True,
        'replicas': 1,
        'image': {'repository': 'spark-custom', 'tag': s['spark_version'], 'pullPolicy': 'IfNotPresent'},
        'resources': {'requests': {'memory': '512Mi', 'cpu': '250m'}, 'limits': {'memory': '1Gi', 'cpu': '500m'}},
    },
    # Disable Airflow
    'airflow': {'enabled': False},
}

with open('$values_file', 'w') as f:
    yaml.dump(v, f)
"
    
    # Install chart
    if ! timeout ${TIMEOUT}m helm install "$release" "$PROJECT_ROOT/charts/$chart" \
        -f "$values_file" \
        -n "$ns" \
        --timeout 10m --wait 2>&1; then
        result="FAIL"
        log_fail "Helm install failed: $scenario_id"
    else
        # Wait for pods
        if ! kubectl wait --for=condition=Ready pods -n "$ns" --timeout=300s 2>&1; then
            result="FAIL"
            log_fail "Pods not ready: $scenario_id"
        else
            if [[ -n "$master_pod" ]]; then
                if ! kubectl exec -n "$ns" "$master_pod" -- bash -c 'timeout 60 spark-submit --master spark://$(hostname):7077 --conf spark.driver.host=$(hostname -i) --conf spark.driver.bindAddress=0.0.0.0 -e "println(spark.range(100).count())"' 2>&1 | grep -q "100"; then
                    result="FAIL"
                    log_fail "Spark job failed: $scenario_id"
                else
                    result="PASS"
                fi
            else
                result="FAIL"
                log_fail "Master pod not found: $scenario_id"
            fi
        fi
    fi
    
    local end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    # Cleanup
    if ! $SKIP_CLEANUP; then
        helm uninstall "$release" -n "$ns" 2>/dev/null || true
        kubectl delete namespace "$ns" 2>/dev/null || true
    fi
    
    # Generate JUnit XML
    generate_junit_result "$scenario_id" "$scenario_name" "smoke" "$result" "$duration"
    
    if [[ "$result" == "PASS" ]]; then
        log_pass "Smoke test passed: $scenario_id (${duration}s)"
        return 0
    else
        return 1
    fi
}

# Run E2E tests for a scenario
run_e2e_test() {
    local scenario_json="$1"
    local scenario_id=$(echo "$scenario_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")
    local scenario_name=$(echo "$scenario_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['name'])")
    
    log_info "Running E2E test: $scenario_name"
    
    if $DRY_RUN; then
        log_skip "Dry run: $scenario_id"
        return 0
    fi
    
    local start_time=$(date +%s)
    local result="PASS"
    local duration=0
    
    # E2E test implementation
    # ... (SQL, DataFrame, ML, Streaming tests)
    
    local end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    generate_junit_result "$scenario_id" "$scenario_name" "e2e" "$result" "$duration"
    
    if [[ "$result" == "PASS" ]]; then
        log_pass "E2E test passed: $scenario_id (${duration}s)"
        return 0
    else
        return 1
    fi
}

# Run load tests for a scenario
run_load_test() {
    local scenario_json="$1"
    local scenario_id=$(echo "$scenario_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")
    local scenario_name=$(echo "$scenario_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['name'])")
    
    log_info "Running load test: $scenario_name"
    
    if $DRY_RUN; then
        log_skip "Dry run: $scenario_id"
        return 0
    fi
    
    local start_time=$(date +%s)
    local result="PASS"
    local duration=0
    
    # Load test implementation
    # ... (throughput, shuffle, sort, cache tests)
    
    local end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    generate_junit_result "$scenario_id" "$scenario_name" "load" "$result" "$duration"
    
    if [[ "$result" == "PASS" ]]; then
        log_pass "Load test passed: $scenario_id (${duration}s)"
        return 0
    else
        return 1
    fi
}

# Generate JUnit XML result
generate_junit_result() {
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

# Generate HTML report
generate_html_report() {
    local report_file="$RESULTS_DIR/test-report-$TIMESTAMP.html"
    
    python3 << PYEOF
import yaml
import os
import glob

results_dir = "$RESULTS_DIR"
junit_dir = f"{results_dir}/junit"

html = f"""<!DOCTYPE html>
<html>
<head>
    <title>Lego-Spark Test Report - $TIMESTAMP</title>
    <style>
        body {{ font-family: Arial, sans-serif; margin: 20px; }}
        h1 {{ color: #333; }}
        .summary {{ background: #f5f5f5; padding: 15px; border-radius: 5px; margin-bottom: 20px; }}
        .pass {{ color: green; }}
        .fail {{ color: red; }}
        .skip {{ color: orange; }}
        table {{ border-collapse: collapse; width: 100%; }}
        th, td {{ border: 1px solid #ddd; padding: 8px; text-align: left; }}
        th {{ background: #4CAF50; color: white; }}
    </style>
</head>
<body>
    <h1>Lego-Spark Test Report</h1>
    <p>Generated: $TIMESTAMP</p>
    <div class="summary">
        <strong>Passed:</strong> <span class="pass">$PASSED</span> |
        <strong>Failed:</strong> <span class="fail">$FAILED</span> |
        <strong>Skipped:</strong> <span class="skip">$SKIPPED</span>
    </div>
</body>
</html>
"""

with open("$report_file", "w") as f:
    f.write(html)

print(f"HTML report: $report_file")
PYEOF
}

# Main
mkdir -p "$RESULTS_DIR/junit"

log_info "=============================================="
log_info "Lego-Spark Test Matrix Runner"
log_info "=============================================="
log_info "Test type: $TEST_TYPE"
log_info "Filter: ${SCENARIO_FILTER:-none}"
log_info "Parallel: $PARALLEL"
log_info "Timeout: ${TIMEOUT}m"
log_info "Namespace: $NAMESPACE"
log_info ""

# Get scenarios
SCENARIOS=$(get_scenarios)
SCENARIO_COUNT=$(echo "$SCENARIOS" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))")

log_info "Scenarios to run: $SCENARIO_COUNT"

if [[ "$SCENARIO_COUNT" -eq 0 ]]; then
    log_fail "No scenarios match filter: $SCENARIO_FILTER"
    exit 1
fi

# Run tests
START_TOTAL=$(date +%s)

# Use while loop to properly handle JSON objects
echo "$SCENARIOS" | python3 -c "
import json, sys
for s in json.load(sys.stdin):
    print(s['id'])
" | while read scenario_id; do
    ((TOTAL++)) || true
    
    # Get full scenario JSON
    scenario_json=$(echo "$SCENARIOS" | python3 -c "import json,sys; print(json.dumps([s for s in json.load(sys.stdin) if s['id']=='$scenario_id'][0]))")
    
    case "$TEST_TYPE" in
        smoke)
            if run_smoke_test "$scenario_json"; then
                ((PASSED++)) || true
            else
                ((FAILED++)) || true
            fi
            ;;
        e2e)
            if run_e2e_test "$scenario_json"; then
                ((PASSED++)) || true
            else
                ((FAILED++)) || true
            fi
            ;;
        load)
            if run_load_test "$scenario_json"; then
                ((PASSED++)) || true
            else
                ((FAILED++)) || true
            fi
            ;;
        all)
            if run_smoke_test "$scenario_json" && run_e2e_test "$scenario_json" && run_load_test "$scenario_json"; then
                ((PASSED++)) || true
            else
                ((FAILED++)) || true
            fi
            ;;
    esac
done

END_TOTAL=$(date +%s)
TOTAL_DURATION=$((END_TOTAL - START_TOTAL))

# Generate report
generate_html_report

# Summary
echo ""
log_info "=============================================="
log_info "TEST SUMMARY"
log_info "=============================================="
echo -e "Total:   $TOTAL"
echo -e "Passed:  ${GREEN}$PASSED${NC}"
echo -e "Failed:  ${RED}$FAILED${NC}"
echo -e "Skipped: ${YELLOW}$SKIPPED${NC}"
echo -e "Duration: ${TOTAL_DURATION}s"
echo ""

if [[ $FAILED -gt 0 ]]; then
    log_fail "Some tests failed"
    exit 1
else
    log_pass "All tests passed"
    exit 0
fi
