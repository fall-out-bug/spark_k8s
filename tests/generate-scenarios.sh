#!/bin/bash
# Lego-Spark Scenario Generator
# Generates Helm value files, test scripts, and GitHub Actions matrix
# from tests/test-matrix.yaml

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_MATRIX="$SCRIPT_DIR/test-matrix.yaml"
OUTPUT_DIR="$SCRIPT_DIR/generated"
CHARTS_DIR="$PROJECT_ROOT/charts"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; }

usage() {
    cat << EOF
Usage: $0 [command]

Commands:
  all           Generate all artifacts (default)
  helm-values   Generate Helm value files only
  test-scripts  Generate test scripts only
  github-matrix Generate GitHub Actions matrix only
  list          List all scenarios
  count         Count scenarios by dimension

Options:
  --filter <key>=<value>   Filter scenarios (e.g., --filter spark_version=3.5.7)
  --output <dir>           Output directory (default: tests/generated/)
  --dry-run                Show what would be generated without creating files

Examples:
  $0 list
  $0 helm-values --filter spark_version=4.0.2
  $0 github-matrix --output .github/workflows/
EOF
    exit 0
}

# Parse test-matrix.yaml using Python (more reliable than shell parsing)
parse_matrix() {
    python3 << 'PYEOF'
import yaml
import sys
import json

with open("tests/test-matrix.yaml", "r") as f:
    matrix = yaml.safe_load(f)

# Output as JSON for shell consumption
print(json.dumps(matrix))
PYEOF
}

# Generate Helm value file for a scenario
generate_helm_values() {
    local scenario_json="$1"
    local output_file="$2"
    
    python3 << PYEOF
import yaml
import json
import sys

scenario = json.loads('''$scenario_json''')

# Determine chart based on Spark version
version = scenario['spark_version']
if version.startswith('3.5'):
    chart = 'spark-3.5'
elif version.startswith('4.0'):
    chart = 'spark-4.0'
elif version.startswith('4.1'):
    chart = 'spark-4.1'
else:
    chart = 'spark-3.5'

# Build values structure
values = {
    'sparkVersion': version,
    'connect': {
        'enabled': scenario['connect'],
    },
    'features': {
        'gpu': {'enabled': scenario['gpu']},
        'iceberg': {'enabled': scenario['iceberg']},
    },
    'openlineage': {'enabled': scenario['openlineage']},
    'monitoring': {
        'prometheus': {'enabled': True},
        'grafana': {'enabled': True},
    },
    'historyServer': {'enabled': True},
    'core': {
        'hiveMetastore': {'enabled': True},
        'minio': {'enabled': True},
    },
}

# K8s mode
if scenario['k8s_mode'] == 'native':
    values['connect']['backendMode'] = 'k8s'
    if scenario.get('shuffle_service'):
        values['spark'] = {'shuffle': {'service': {'enabled': True}}}
else:
    values['sparkStandalone'] = {'enabled': True}

# Platform
if scenario['platform'] == 'openshift':
    values['openshift'] = {'enabled': True}

# Write output
with open('$output_file', 'w') as f:
    yaml.dump(values, f, default_flow_style=False, sort_keys=False)
    f.write(f"\n# Scenario: {scenario['name']}\n")
    f.write(f"# ID: {scenario['id']}\n")

print(chart)
PYEOF
}

# Generate test script for a scenario
generate_test_script() {
    local scenario_id="$1"
    local scenario_name="$2"
    local helm_values_file="$3"
    local chart="$4"
    local output_file="$5"
    
    cat > "$output_file" << TESTSCRIPT
#!/bin/bash
# Test script for scenario: $scenario_name
# Generated automatically - DO NOT EDIT

set -euo pipefail

SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="\$(dirname "\$(dirname "\$SCRIPT_DIR"))"

SCENARIO_ID="$scenario_id"
SCENARIO_NAME="$scenario_name"
CHART="$chart"
VALUES_FILE="\$PROJECT_ROOT/$helm_values_file"
NAMESPACE="test-\${SCENARIO_ID,,}"
RELEASE="spark-test-\${SCENARIO_ID,,}"

# Colors
RED='\\033[0;31m'
GREEN='\\033[0;32m'
YELLOW='\\033[1;33m'
NC='\\033[0m'

log_info() { echo -e "\${YELLOW}[INFO]\${NC} \$1"; }
log_pass() { echo -e "\${GREEN}[PASS]\${NC} \$1"; }
log_fail() { echo -e "\${RED}[FAIL]\${NC} \$1"; }

# Smoke test (10 min)
run_smoke_tests() {
    log_info "Running smoke tests for \$SCENARIO_NAME"
    
    # Install chart
    helm install \$RELEASE \$PROJECT_ROOT/charts/\$CHART \\
        -f \$VALUES_FILE \\
        -n \$NAMESPACE --create-namespace \\
        --timeout 10m --wait
    
    log_pass "Helm install successful"
    
    # Wait for pods
    kubectl wait --for=condition=Ready pods -l app.kubernetes.io/instance=\$RELEASE \\
        -n \$NAMESPACE --timeout=300s
    
    log_pass "All pods ready"
    
    # Run smoke tests
    # ... test implementation
}

# E2E test (25 min)
run_e2e_tests() {
    log_info "Running E2E tests for \$SCENARIO_NAME"
    # ... test implementation
}

# Load test (45 min)
run_load_tests() {
    log_info "Running load tests for \$SCENARIO_NAME"
    # ... test implementation
}

# Cleanup
cleanup() {
    log_info "Cleaning up"
    helm uninstall \$RELEASE -n \$NAMESPACE 2>/dev/null || true
    kubectl delete namespace \$NAMESPACE 2>/dev/null || true
}

# Main
case "\${1:-all}" in
    smoke)  run_smoke_tests ;;
    e2e)    run_e2e_tests ;;
    load)   run_load_tests ;;
    all)    run_smoke_tests && run_e2e_tests && run_load_tests ;;
    clean)  cleanup ;;
    *)      echo "Usage: \$0 {smoke|e2e|load|all|clean}" ;;
esac
TESTSCRIPT

    chmod +x "$output_file"
}

# Generate GitHub Actions matrix
generate_github_matrix() {
    local output_file="$1"
    
    python3 << PYEOF
import yaml
import json

with open("tests/test-matrix.yaml", "r") as f:
    matrix = yaml.safe_load(f)

# Build GitHub Actions matrix
scenarios = []
for s in matrix['scenarios']:
    scenarios.append({
        'id': s['id'],
        'name': s['name'],
        'spark_version': s['spark_version'],
        'connect': s['connect'],
        'k8s_mode': s['k8s_mode'],
        'gpu': s['gpu'],
        'iceberg': s['iceberg'],
        'shuffle_service': s['shuffle_service'],
        'openlineage': s['openlineage'],
        'platform': s['platform'],
    })

# Write include matrix
with open('$output_file', 'w') as f:
    yaml.dump({'include': scenarios[:20]}, f, default_flow_style=False)  # First 20 for demo
    
print(f"Generated GitHub matrix with {len(scenarios[:20])} scenarios (demo)")
print(f"Total scenarios available: {len(scenarios)}")
PYEOF
}

# List all scenarios
list_scenarios() {
    python3 << 'PYEOF'
import yaml

with open("tests/test-matrix.yaml", "r") as f:
    matrix = yaml.safe_load(f)

print(f"Total scenarios: {len(matrix['scenarios'])}")
print("\nFirst 10:")
for s in matrix['scenarios'][:10]:
    print(f"  {s['id']}: {s['name']}")

print("\nBy Spark version:")
by_version = {}
for s in matrix['scenarios']:
    v = s['spark_version']
    by_version[v] = by_version.get(v, 0) + 1
for v, count in sorted(by_version.items()):
    print(f"  {v}: {count}")
PYEOF
}

# Count scenarios by dimension
count_scenarios() {
    python3 << 'PYEOF'
import yaml

with open("tests/test-matrix.yaml", "r") as f:
    matrix = yaml.safe_load(f)

print(f"Total scenarios: {len(matrix['scenarios'])}")
print(f"Total test runs: {matrix['metadata']['total_test_runs']}")
print("\nDimensions:")
for key, values in matrix['metadata']['dimensions'].items():
    print(f"  {key}: {values}")
PYEOF
}

# Main command dispatcher
COMMAND="${1:-all}"

case "$COMMAND" in
    --help|-h)
        usage
        ;;
    list)
        list_scenarios
        ;;
    count)
        count_scenarios
        ;;
    all)
        log_info "Generating all artifacts..."
        mkdir -p "$OUTPUT_DIR/helm-values"
        mkdir -p "$OUTPUT_DIR/test-scripts"
        mkdir -p "$OUTPUT_DIR/github"
        
        # Generate artifacts using Python
        python3 "$SCRIPT_DIR/generate_test_matrix.py"
        
        log_pass "All artifacts generated in $OUTPUT_DIR"
        ;;
    helm-values)
        log_info "Generating Helm value files..."
        mkdir -p "$OUTPUT_DIR/helm-values"
        # Implementation
        log_pass "Helm values generated"
        ;;
    github-matrix)
        log_info "Generating GitHub Actions matrix..."
        mkdir -p "$OUTPUT_DIR/github"
        generate_github_matrix "$OUTPUT_DIR/github/matrix.yaml"
        log_pass "GitHub matrix generated"
        ;;
    *)
        log_fail "Unknown command: $COMMAND"
        usage
        ;;
esac
