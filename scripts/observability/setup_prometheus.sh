#!/bin/bash
# Setup Prometheus for Spark monitoring on Kubernetes
#
# Usage:
#   ./setup_prometheus.sh --namespace spark-operations

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

Setup Prometheus for Spark monitoring.

OPTIONS:
    -n, --namespace NAME      Kubernetes namespace (default: spark-operations)
    --dry-run                 Show what would be done without executing
    -v, --verbose              Enable verbose output
    -h, --help                 Show this help

EXAMPLES:
    $(basename "$0") --namespace spark-operations
    $(basename "$0") --dry-run --verbose

EOF
    exit 1
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
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

    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_error "Namespace $NAMESPACE does not exist"
        exit 1
    fi

    log_info "Prerequisites check passed"
}

add_helm_repo() {
    log_info "Adding Prometheus Community Helm repository..."

    local repo_add_cmd="helm repo add prometheus-community https://prometheus-community.github.io/helm-charts"

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would run: $repo_add_cmd"
    else
        eval "$repo_add_cmd"
    fi

    local repo_update_cmd="helm repo update prometheus-community"

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would run: $repo_update_cmd"
    else
        eval "$repo_update_cmd"
    fi

    log_info "Helm repository added and updated"
}

deploy_prometheus_operator() {
    log_info "Deploying Prometheus Operator..."

    local helm_cmd="helm install prometheus-operator prometheus-community/prometheus-operator \\
        --namespace $NAMESPACE \\
        --set prometheusOperator.enabled=true"

    if [[ "$VERBOSE" == true ]]; then
        helm_cmd="$helm_cmd --debug"
    fi

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would run: $helm_cmd"
        return
    fi

    eval "$helm_cmd"

    log_info "Waiting for Prometheus Operator to be ready..."
    kubectl wait --for condition=available pod -l app.kubernetes.io/name=prometheus-operator -n "$NAMESPACE" --timeout=300s

    log_info "Prometheus Operator deployed successfully"
}

create_spark_servicemonitors() {
    log_info "Creating Spark ServiceMonitors..."

    local manifest="$SCRIPT_DIR/../manifests/spark-servicemonitors.yaml"

    cat > "$manifest" <<EOF
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: spark-driver
  namespace: $NAMESPACE
  labels:
    app: spark
spec:
  selector:
    matchLabels:
      app: spark
      spark-role: driver
  endpoints:
    - port: metrics
      path: /metrics/prometheus
      scheme: http
      namespaceSelector:
        matchNames:
          - $NAMESPACE
      query: '{__name__="spark_driver_metrics"}'
      interval: 30s
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: spark-executor
  namespace: $NAMESPACE
  labels:
    app: spark
spec:
  selector:
    matchLabels:
      app: spark
      spark-role: executor
  endpoints:
    - port: metrics
      path: /metrics/prometheus
      scheme: http
      namespaceSelector:
        matchNames:
          - $NAMESPACE
      query: '{__name__="spark_executor_metrics"}'
      interval: 30s
EOF

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would apply: $manifest"
        return
    fi

    kubectl apply -f "$manifest"

    log_info "Spark ServiceMonitors created successfully"
}

main() {
    parse_args "$@"

    log_info "=== Prometheus Setup for Spark ==="
    log_info "Namespace: $NAMESPACE"

    check_prerequisites
    add_helm_repo
    deploy_prometheus_operator
    create_spark_servicemonitors

    log_info "=== Setup Complete ==="
    log_info "Prometheus will scrape metrics from Spark pods at:"
    log_info "  - http://spark-driver-svc:$NAMESPACE:15002/metrics/prometheus"
    log_info "  - http://spark-executor-svc:$NAMESPACE:15002/metrics/prometheus"
}

main "$@"
