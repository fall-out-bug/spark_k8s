#!/bin/bash
# Argo Workflows Installation Script
# Part of WS-013-09: Argo Workflows Integration
#
# Installs Argo Workflows and configures RBAC for load test execution.

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
NAMESPACE="${ARGO_NAMESPACE:-argo}"
VERSION="${ARGO_VERSION:-v3.4.16}"

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_step() {
    echo ""
    echo -e "${GREEN}==>${NC} $1"
}

check_prerequisites() {
    print_step "Checking prerequisites"

    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found"
        exit 1
    fi

    if ! command -v helm &> /dev/null; then
        log_error "helm not found"
        exit 1
    fi

    log_success "Prerequisites check passed"
}

install_argo_workflows() {
    print_step "Installing Argo Workflows"

    # Create namespace
    kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

    # Add Argo Helm repository
    helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true

    # Install Argo Workflows
    helm upgrade --install argo-workflows argo/argo-workflows \
        --namespace "$NAMESPACE" \
        --set controller.containerRuntimeExecutor: docker \
        --set controller.workflowTTLSeconds: 86400 \
        --set controller.podGCWorkflowRetention: 100 \
        --set server.enabled: true \
        --set server.serviceType: ClusterIP \
        --set executor.resources.requests.memory: "512Mi" \
        --set executor.resources.requests.cpu: "250m" \
        --set executor.resources.limits.memory: "1Gi" \
        --set executor.resources.limits.cpu: "500m" \
        --wait \
        --timeout 5m

    log_success "Argo Workflows installed"
}

install_argo_cli() {
    print_step "Installing Argo CLI"

    if command -v argo &> /dev/null; then
        log_info "Argo CLI already installed: $(argo version --short 2>/dev/null || echo 'unknown')"
        return 0
    fi

    # Download and install Argo CLI
    log_info "Downloading Argo CLI $VERSION..."
    curl -sSL -o argo-linux-amd64 "https://github.com/argoproj/argo-workflows/releases/download/$VERSION/argo-linux-amd64"
    chmod +x argo-linux-amd64
    sudo mv argo-linux-amd64 /usr/local/bin/argo

    log_success "Argo CLI installed: $(argo version --short 2>/dev/null || echo 'unknown')"
}

setup_rbac() {
    print_step "Setting up RBAC"

    # Create service account for workflow submission
    kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: workflow-runner
  namespace: $NAMESPACE
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: workflow-runner
  namespace: $NAMESPACE
rules:
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: workflow-runner
  namespace: $NAMESPACE
subjects:
  - kind: ServiceAccount
    name: workflow-runner
    namespace: $NAMESPACE
roleRef:
  kind: Role
  name: workflow-runner
  apiGroup: rbac.authorization.k8s.io
EOF

    log_success "RBAC configured"
}

create_resource_mutex() {
    print_step "Creating resource synchronization mutex"

    kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: mutex-config
  namespace: $NAMESPACE
data:
  mutex: "minikube-load-test-mutex"
EOF

    log_success "Resource mutex created"
}

verify_installation() {
    print_step "Verifying installation"

    # Wait for controller
    log_info "Waiting for Argo Workflows controller..."
    kubectl wait --for=condition=ready pod \
        -l app.kubernetes.io/name=argo-workflows \
        -n "$NAMESPACE" \
        --timeout=300s

    log_success "Argo Workflows controller is ready"

    # List workflows
    kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=argo-workflows

    log_info "Argo Workflows UI:"
    log_info "  kubectl port-forward -n $NAMESPACE svc/argo-workflows-server 2746:2746"
    log_info "  Open: http://localhost:2746"
}

print_summary() {
    print_step "Installation complete"

    echo ""
    echo "Argo Workflows installed successfully!"
    echo ""
    echo "Next steps:"
    echo "  1. Port-forward UI: kubectl port-forward -n $NAMESPACE svc/argo-workflows-server 2746:2746"
    echo "  2. Open browser: http://localhost:2746"
    echo "  3. Submit workflow: ./scripts/tests/load/orchestrator/submit-workflow.sh p0_smoke"
    echo ""
}

# Main execution
main() {
    log_info "Installing Argo Workflows"

    check_prerequisites
    install_argo_workflows
    install_argo_cli
    setup_rbac
    create_resource_mutex
    verify_installation
    print_summary

    log_success "Argo Workflows installation complete!"
}

main "$@"
