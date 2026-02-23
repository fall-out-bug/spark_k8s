#!/bin/bash
# Setup Load Testing Infrastructure using Helm
# Replaces duplicate YAML files with proper Helm chart deployment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

source "${PROJECT_ROOT}/scripts/tests/lib/common.sh"
source "${PROJECT_ROOT}/scripts/tests/lib/helm.sh"

# Configuration
NAMESPACE="${NAMESPACE:-load-testing}"
RELEASE_NAME="${RELEASE_NAME:-spark-load-infra}"
CHART_PATH="${PROJECT_ROOT}/charts/spark-4.1"
PRESET_PATH="${PROJECT_ROOT}/charts/spark-4.1/presets/load-testing-infra.yaml"

log_section "Load Testing Infrastructure Setup"
log_info "Namespace: $NAMESPACE"
log_info "Release: $RELEASE_NAME"
log_info "Chart: $CHART_PATH"

# Check prerequisites
check_required_commands kubectl helm

# Create namespace if it doesn't exist
if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    log_step "Creating namespace: $NAMESPACE"
    kubectl create namespace "$NAMESPACE"
    log_success "Namespace created: $NAMESPACE"
else
    log_info "Namespace already exists: $NAMESPACE"
fi

# Check if release exists
if helm list -n "$NAMESPACE" | grep -q "^$RELEASE_NAME"; then
    log_warning "Release $RELEASE_NAME already exists in namespace $NAMESPACE"
    read -p "Upgrade existing release? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_step "Upgrading release..."
        helm upgrade "$RELEASE_NAME" "$CHART_PATH" \
            --namespace "$NAMESPACE" \
            --values "$PRESET_PATH" \
            --wait --timeout 10m
        log_success "Release upgraded: $RELEASE_NAME"
    else
        log_info "Skipping deployment"
    fi
else
    # Install fresh release
    log_step "Installing Helm release..."
    helm install "$RELEASE_NAME" "$CHART_PATH" \
        --namespace "$NAMESPACE" \
        --values "$PRESET_PATH" \
        --wait --timeout 10m
    log_success "Release installed: $RELEASE_NAME"
fi

# Wait for all pods to be ready
log_section "Waiting for pods to be ready"
wait_for_pods "$NAMESPACE" 300

# Print status
log_section "Infrastructure Status"
kubectl get pods -n "$NAMESPACE"
kubectl get svc -n "$NAMESPACE"

log_success "✅ Load testing infrastructure is ready!"
log_info "Minio: http://minio.$NAMESPACE.svc.cluster.local:9000"
log_info "Hive Metastore: thrift://hive-metastore.$NAMESPACE.svc.cluster.local:9083"
log_info "History Server: http://spark-history-server.$NAMESPACE.svc.cluster.local:18080"

# Instructions for Minio access
echo ""
log_info "Minio Console: Port-forward with:"
echo "  kubectl port-forward -n $NAMESPACE svc/minio-console 9001:9001"
echo "  Open: http://localhost:9001"
echo "  Username: minioadmin / Password: minioadmin"
