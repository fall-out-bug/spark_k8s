#!/bin/bash
# Job Rollback Script
# Rolls back Spark job deployments

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Rollback Spark job to a previous version.

OPTIONS:
    -e, --environment ENV      Target environment (dev|staging|production)
    -t, --to-version VERSION   Target version to rollback to
    -p, --previous             Rollback to previous version
    -w, --wait                 Wait for rollback to complete
    -h, --help                 Show this help

EXAMPLES:
    $(basename "$0") --environment production --previous
    $(basename "$0") -e staging -t abc123
EOF
    exit 1
}

ENVIRONMENT=""
TO_VERSION=""
PREVIOUS=false
WAIT=false

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -e|--environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -t|--to-version)
                TO_VERSION="$2"
                shift 2
                ;;
            -p|--previous)
                PREVIOUS=true
                shift
                ;;
            -w|--wait)
                WAIT=true
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

    if [[ -z "$ENVIRONMENT" ]]; then
        echo "Error: --environment is required"
        echo ""
        usage
    fi

    if [[ "$PREVIOUS" == false ]] && [[ -z "$TO_VERSION" ]]; then
        echo "Error: --to-version or --previous is required"
        echo ""
        usage
    fi
}

get_namespace() {
    case "$ENVIRONMENT" in
        dev)
            echo "spark-dev"
            ;;
        staging)
            echo "spark-staging"
            ;;
        production)
            echo "spark-operations"
            ;;
    esac
}

get_current_version() {
    local namespace=$(get_namespace)
    kubectl get deployment spark-job -n "$namespace" \
        -o jsonpath='{.spec.template.spec.containers[0].image}' | \
        cut -d: -f2
}

get_previous_versions() {
    local namespace=$(get_namespace)

    echo "Available versions from deployments.log:"
    if [[ -f "deployments.log" ]]; then
        grep "$ENVIRONMENT" deployments.log | tail -5
    else
        echo "No deployment log found"
    fi
}

confirm_rollback() {
    local current_version=$(get_current_version)
    local target_version="$TO_VERSION"

    if [[ "$PREVIOUS" == true ]]; then
        target_version=$(get_previous_versions | tail -1 | awk '{print $NF}')
        echo "Rolling back to previous version: $target_version"
    else
        echo "Rolling back from $current_version to $target_version"
    fi

    if [[ "$ENVIRONMENT" == "production" ]]; then
        echo ""
        echo "WARNING: This will roll back PRODUCTION!"
        echo "Press Ctrl+C to cancel, or Enter to continue..."
        read
    fi
}

perform_rollback() {
    local namespace=$(get_namespace)
    local target_version="$TO_VERSION"

    if [[ "$PREVIOUS" == true ]]; then
        target_version=$(get_previous_versions | tail -1 | awk '{print $NF}')
    fi

    echo "Performing rollback to $target_version..."

    # Helm rollback
    helm rollback spark-job \
        --namespace "$namespace" \
        --reuse-values \
        --set image.tag="$target_version" \
        --wait --timeout 10m
}

wait_for_rollback() {
    local namespace=$(get_namespace)
    local timeout="${WAIT_TIMEOUT:-600}"

    echo "Waiting for rollback to complete (timeout: ${timeout}s)..."

    kubectl wait \
        --for=condition=available \
        deployment/spark-job \
        -n "$namespace" \
        --timeout="${timeout}s"
}

verify_rollback() {
    local namespace=$(get_namespace)
    local current_version=$(get_current_version)

    echo "Verifying rollback..."
    echo "Current version: $current_version"

    # Check pods
    kubectl get pods -n "$namespace" -l app=spark-job

    # Check logs for errors
    kubectl logs -n "$namespace" -l app=spark-job --tail=50 | grep -i "error\|exception" || echo "No errors found"
}

main() {
    parse_args "$@"

    echo "=== Spark Job Rollback ==="
    echo ""

    confirm_rollback
    perform_rollback

    if [[ "$WAIT" == true ]]; then
        wait_for_rollback
        verify_rollback
    fi

    echo ""
    echo "=== Rollback Complete ==="
}

main "$@"
