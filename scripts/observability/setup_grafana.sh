#!/bin/bash
# Setup Grafana for Spark dashboards on Kubernetes
#
# Usage:
#   ./setup_grafana.sh --namespace spark-operations

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="${NAMESPACE:-spark-operations}"
DRY_RUN=false
VERBOSE=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Setup Grafana for Spark monitoring dashboards.

OPTIONS:
    -n, --namespace NAME      Kubernetes namespace (default: spark-operations)
    --dry-run                 Show what would be done without executing
    -v, --verbose              Enable verbose output
    -h, --help                 Show this help

EXAMPLES:
    $(basename "$0") --namespace spark-operations

EOF
    exit 1
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                ;;
        esac
    done
}

check_prerequisites() {
    log_info "Checking prerequisites..."

    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found"
        exit 1
    fi

    log_info "Prerequisites check passed"
}

deploy_grafana() {
    log_info "Deploying Grafana..."

    local helm_cmd="helm upgrade --install grafana-spark \\
        --repo grafana \\
        --namespace $NAMESPACE \\
        --create-namespace \\
        -f $SCRIPT_DIR/../../charts/observability/grafana/values.yaml"

    if [[ "$VERBOSE" == true ]]; then
        helm_cmd="$helm_cmd --debug"
    fi

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would run: $helm_cmd"
        return
    fi

    eval "$helm_cmd"

    log_info "Waiting for Grafana to be ready..."
    kubectl wait --for condition=available pod -l app.kubernetes.io/name=grafana -n "$NAMESPACE" --timeout=300s

    log_info "Grafana deployed successfully"
}

main() {
    parse_args "$@"

    log_info "=== Grafana Setup for Spark ==="
    log_info "Namespace: $NAMESPACE"

    check_prerequisites
    deploy_grafana

    log_info "=== Setup Complete ==="
    log_info "Grafana available at: http://grafana.$NAMESPACE.svc.cluster.local:3000"
    log_info "Dashboards:"
    log_info "  - Spark Overview"
    log_info "  - Spark Executors"
    log_info "  - Spark Jobs"
    log_info "  - Spark Performance"
}

main "$@"
