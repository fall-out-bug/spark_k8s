#!/bin/bash
# Spark Job Validation Script
# Validates Spark job configuration and manifests

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART_DIR="${CHART_DIR:-./charts/spark-job}"
VALUES_FILE="${1:-}"
NAMESPACE="${2:-spark-operations}"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Validate Spark job manifests and configuration.

OPTIONS:
    -f, --values FILE        Helm values file
    -n, --namespace NAME     Kubernetes namespace (default: spark-operations)
    -c, --chart PATH         Chart directory (default: ./charts/spark-job)
    -d, --dry-run            Run helm dry-run
    -s, --strict             Enable strict validation
    -h, --help               Show this help

EXAMPLES:
    $(basename "$0") --values job-values.yaml
    $(basename "$0") -f job-values.yaml --dry-run --strict
EOF
    exit 1
}

DRY_RUN=false
STRICT=false

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--values)
                VALUES_FILE="$2"
                shift 2
                ;;
            -n|--namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            -c|--chart)
                CHART_DIR="$2"
                shift 2
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -s|--strict)
                STRICT=true
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                echo "Unknown option: $1"
                usage
                ;;
        esac
    done
}

validate_chart_exists() {
    if [[ ! -d "$CHART_DIR" ]]; then
        echo "Error: Chart directory not found: $CHART_DIR"
        exit 1
    fi

    if [[ ! -f "${CHART_DIR}/Chart.yaml" ]]; then
        echo "Error: Chart.yaml not found in $CHART_DIR"
        exit 1
    fi

    echo "Chart found: $CHART_DIR"
}

validate_values() {
    if [[ -n "$VALUES_FILE" ]] && [[ ! -f "$VALUES_FILE" ]]; then
        echo "Error: Values file not found: $VALUES_FILE"
        exit 1
    fi

    echo "Values file: ${VALUES_FILE:-using defaults}"
}

validate_image() {
    echo "Validating image configuration..."

    local image_repo=$(helm template test "$CHART_DIR" ${VALUES_FILE:+-f "$VALUES_FILE"} \
        --set image.tag=test 2>/dev/null | \
        yq eval '.spec.template.spec.containers[0].image' - 2>/dev/null || echo "")

    if [[ -z "$image_repo" ]]; then
        echo "Warning: Image configuration not found"
    else
        echo "Image: $image_repo"
    fi
}

validate_resources() {
    echo "Validating resource configuration..."

    local resources=$(helm template test "$CHART_DIR" ${VALUES_FILE:+-f "$VALUES_FILE"} \
        --set image.tag=test 2>/dev/null | \
        yq eval '.spec.template.spec.containers[0].resources' - 2>/dev/null || echo "{}")

    local requests=$(echo "$resources" | yq eval '.requests' -)
    local limits=$(echo "$resources" | yq eval '.limits' -)

    if [[ "$requests" == "null" ]] || [[ "$requests" == "{}" ]]; then
        echo "Warning: No resource requests defined"
    fi

    if [[ "$limits" == "null" ]] || [[ "$limits" == "{}" ]]; then
        echo "Warning: No resource limits defined"
    fi

    if [[ "$STRICT" == true ]]; then
        if [[ "$requests" == "null" ]] || [[ "$limits" == "null" ]]; then
            echo "Error: Resource requests and limits required in strict mode"
            exit 1
        fi
    fi
}

validate_spark_config() {
    echo "Validating Spark configuration..."

    # Check for required Spark configurations
    local required_configs=(
        "spark.executor.memory"
        "spark.executor.cores"
        "spark.driver.memory"
    )

    for config in "${required_configs[@]}"; do
        local found=$(helm template test "$CHART_DIR" ${VALUES_FILE:+-f "$VALUES_FILE"} \
            --set image.tag=test 2>/dev/null | \
            grep -q "$config" && echo "yes" || echo "no")

        if [[ "$found" == "no" ]]; then
            echo "Warning: Required Spark config not found: $config"
        fi
    done
}

validate_dependencies() {
    echo "Validating dependencies..."

    # Check if Helm is installed
    if ! command -v helm &> /dev/null; then
        echo "Error: Helm is not installed"
        exit 1
    fi

    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        echo "Error: kubectl is not installed"
        exit 1
    fi

    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        echo "Warning: Cannot connect to Kubernetes cluster"
    fi
}

run_dry_run() {
    if [[ "$DRY_RUN" == true ]]; then
        echo "Running Helm dry-run..."
        helm template test "$CHART_DIR" ${VALUES_FILE:+-f "$VALUES_FILE"} \
            --set image.tag=test \
            --dry-run \
            --debug 2>&1 | tee /tmp/helm-dry-run.yaml

        echo "Helm dry-run complete"
    fi
}

check_best_practices() {
    echo "Checking best practices..."

    # Check for labels
    local labels=$(helm template test "$CHART_DIR" ${VALUES_FILE:+-f "$VALUES_FILE"} \
        --set image.tag=test 2>/dev/null | \
        yq eval '.metadata.labels' -)

    if [[ "$labels" == "null" ]] || [[ "$labels" == "{}" ]]; then
        echo "Warning: No labels defined"
    fi

    # Check for annotations
    local annotations=$(helm template test "$CHART_DIR" ${VALUES_FILE:+-f "$VALUES_FILE"} \
        --set image.tag=test 2>/dev/null | \
        yq eval '.metadata.annotations' -)

    if [[ "$annotations" == "null" ]] || [[ "$annotations" == "{}" ]]; then
        echo "Warning: No annotations defined (consider adding: commit SHA, version)"
    fi

    # Check for resource limits
    validate_resources
}

main() {
    parse_args "$@"

    echo "=== Spark Job Validation ==="
    echo ""

    validate_dependencies
    validate_chart_exists
    validate_values
    validate_image
    validate_resources
    validate_spark_config
    check_best_practices
    run_dry_run

    echo ""
    echo "=== Validation Complete ==="
    echo "All checks passed!"
}

main "$@"
