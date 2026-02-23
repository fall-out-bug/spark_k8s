#!/bin/bash
# Dry-run validation for Spark jobs using helm template
#
# Usage:
#   ./dry-run-spark-job.sh --chart <path> --values <path>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../operations/common.sh"

# Configuration
CHART_PATH=""
VALUES_PATH=""
NAMESPACE="dry-run"
RELEASE_NAME="spark-dryrun"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --chart)
            CHART_PATH="$2"
            shift 2
            ;;
        --values)
            VALUES_PATH="$2"
            shift 2
            ;;
        --release)
            RELEASE_NAME="$2"
            shift 2
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [[ -z "$CHART_PATH" || -z "$VALUES_PATH" ]]; then
    log_error "Usage: $0 --chart <path> --values <path>"
    exit 1
fi

log_info "=== Spark Job Dry-Run Validation ==="
log_info "Chart: ${CHART_PATH}"
log_info "Values: ${VALUES_PATH}"

# Validate chart exists
if [[ ! -d "$CHART_PATH" ]]; then
    log_error "Chart not found: ${CHART_PATH}"
    exit 1
fi

# Validate values file exists
if [[ ! -f "$VALUES_PATH" ]]; then
    log_error "Values file not found: ${VALUES_PATH}"
    exit 1
fi

# Run helm template (dry-run)
log_info "Running helm template..."

HELM_OUTPUT=$(helm template "$RELEASE_NAME" "$CHART_PATH" \
    --namespace "$NAMESPACE" \
    --values "$VALUES_PATH" \
    --debug 2>&1)

HELM_EXIT=$?

if [[ $HELM_EXIT -ne 0 ]]; then
    log_error "Helm template failed!"
    echo "$HELM_OUTPUT" | tail -20
    exit 1
fi

# Validate output
log_info "Validating rendered templates..."

# Check for required Kubernetes resources
REQUIRED_RESOURCES=("Deployment" "Service" "ConfigMap" "Secret")

for resource in "${REQUIRED_RESOURCES[@]}"; do
    if echo "$HELM_OUTPUT" | grep -q "kind: $resource"; then
        log_info "✓ Found $resource"
    else
        log_warn "Missing $resource (may be optional)"
    fi
done

# Validate Spark configuration
log_info "Validating Spark configuration..."

if echo "$HELM_OUTPUT" | grep -q "spark.executor.memory"; then
    log_info "✓ Executor memory configured"
else
    log_warn "Executor memory not set"
fi

if echo "$HELM_OUTPUT" | grep -q "spark.executor.cores"; then
    log_info "✓ Executor cores configured"
else
    log_warn "Executor cores not set"
fi

# Check for resource limits
if echo "$HELM_OUTPUT" | grep -q "resources:"; then
    log_info "✓ Resource limits defined"
else
    log_warn "No resource limits found"
fi

# Validate YAML syntax
log_info "Validating YAML syntax..."

if echo "$HELM_OUTPUT" | kubectl apply --dry-run=client -f - &>/dev/null; then
    log_info "✓ Kubernetes manifests valid"
else
    log_error "Kubernetes manifests invalid"
    exit 1
fi

# Save rendered output for review
OUTPUT_DIR="${SCRIPT_DIR}/../.dry-run"
mkdir -p "$OUTPUT_DIR"

echo "$HELM_OUTPUT" > "${OUTPUT_DIR}/rendered-${RELEASE_NAME}.yaml"
log_info "Rendered output saved to: ${OUTPUT_DIR}/rendered-${RELEASE_NAME}.yaml"

log_info "=== Dry-Run Validation Complete ==="
log_info "✓ Job is ready for deployment"

exit 0
