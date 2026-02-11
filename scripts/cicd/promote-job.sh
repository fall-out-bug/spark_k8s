#!/bin/bash
# Job Promotion Script
# Promotes Spark jobs between environments

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART_DIR="${CHART_DIR:-./charts/spark-job}"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Promote Spark job to a new environment.

OPTIONS:
    -e, --environment ENV      Target environment (dev|staging|production)
    -i, --image IMAGE         Docker image to deploy
    -v, --version VERSION     Version tag/commit SHA
    -c, --chart PATH          Chart directory
    -w, --wait                Wait for deployment to complete
    -d, --dry-run             Dry run only
    -h, --help                Show this help

EXAMPLES:
    $(basename "$0") --environment staging --image ghcr.io/org/spark-job:abc123
    $(basename "$0") -e production -i spark-job:v1.2.3 --wait
EOF
    exit 1
}

ENVIRONMENT=""
IMAGE=""
VERSION=""
WAIT=false
DRY_RUN=false

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -e|--environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -i|--image)
                IMAGE="$2"
                shift 2
                ;;
            -v|--version)
                VERSION="$2"
                shift 2
                ;;
            -c|--chart)
                CHART_DIR="$2"
                shift 2
                ;;
            -w|--wait)
                WAIT=true
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=true
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

    if [[ -z "$IMAGE" ]] && [[ -z "$VERSION" ]]; then
        echo "Error: --image or --version is required"
        echo ""
        usage
    fi
}

validate_environment() {
    case "$ENVIRONMENT" in
        dev|staging|production)
            echo "Environment: $ENVIRONMENT"
            ;;
        *)
            echo "Error: Invalid environment: $ENVIRONMENT"
            echo "Valid environments: dev, staging, production"
            exit 1
            ;;
    esac
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

check_approval() {
    if [[ "$ENVIRONMENT" == "production" ]]; then
        echo "Checking for production deployment approval..."
        if [[ ! -f ".approved-for-production" ]]; then
            echo "Error: Production deployment requires approval"
            echo "Create .approved-for-production file with approval details"
            exit 1
        fi
        echo "Production approval found"
    fi
}

deploy_job() {
    local namespace=$(get_namespace)
    local full_image="${IMAGE:-spark-job}:${VERSION}"

    echo "Deploying to $ENVIRONMENT ($namespace)..."
    echo "Image: $full_image"

    if [[ "$DRY_RUN" == true ]]; then
        echo "DRY RUN: Would deploy $full_image to $namespace"
        return
    fi

    # Build helm upgrade command
    local helm_cmd="helm upgrade --install spark-job $CHART_DIR \
        --namespace $namespace \
        --create-namespace \
        --set image.repository=$(echo "$full_image" | cut -d: -f1) \
        --set image.tag=$(echo "$full_image" | cut -d: -f2) \
        --set environment=$ENVIRONMENT \
        --wait --timeout 10m"

    echo "Executing: $helm_cmd"
    eval "$helm_cmd"
}

verify_deployment() {
    local namespace=$(get_namespace)

    echo "Verifying deployment in $namespace..."

    # Check pods are running
    kubectl get pods -n "$namespace" -l app=spark-job

    # Check deployment status
    kubectl get deployment spark-job -n "$namespace" -o yaml | \
        grep -A 5 "conditions:"
}

wait_for_ready() {
    local namespace=$(get_namespace)
    local timeout="${WAIT_TIMEOUT:-600}"

    echo "Waiting for deployment to be ready (timeout: ${timeout}s)..."

    kubectl wait \
        --for=condition=available \
        deployment/spark-job \
        -n "$namespace" \
        --timeout="${timeout}s"
}

post_deployment_checks() {
    local namespace=$(get_namespace)

    echo "Running post-deployment checks..."

    # Check pod status
    local pods=$(kubectl get pods -n "$namespace" -l app=spark-job)
    echo "Pods:"
    echo "$pods"

    # Check for errors in logs
    local errors=$(kubectl logs -n "$namespace" -l app=spark-job --tail=50 | grep -i "error\|exception" || echo "")

    if [[ -n "$errors" ]]; then
        echo "Warning: Errors found in logs:"
        echo "$errors"
    fi

    # Check resource usage
    echo "Resource usage:"
    kubectl top pods -n "$namespace" -l app=spark-job
}

record_deployment() {
    local namespace=$(get_namespace)
    local timestamp=$(date -Iseconds)
    local full_image="${IMAGE:-spark-job}:${VERSION}"

    echo "Recording deployment..."

    # Create deployment record
    cat >> "deployments.log" <<EOF
$timestamp | $ENVIRONMENT | $namespace | $full_image | $USER
EOF

    echo "Deployment recorded in deployments.log"
}

main() {
    parse_args "$@"

    echo "=== Spark Job Promotion ==="
    echo ""

    validate_environment
    check_approval
    deploy_job

    if [[ "$WAIT" == true ]] && [[ "$DRY_RUN" == false ]]; then
        wait_for_ready
        verify_deployment
        post_deployment_checks
        record_deployment
    fi

    echo ""
    echo "=== Deployment Complete ==="
    echo "Environment: $ENVIRONMENT"
    echo "Namespace: $(get_namespace)"
    echo "Image: ${IMAGE:-spark-job}:${VERSION}"
}

main "$@"
