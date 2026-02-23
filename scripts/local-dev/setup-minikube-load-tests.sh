#!/bin/bash
# Minikube Auto-Setup Infrastructure for Load Testing
# Part of WS-013-06: Minikube Auto-Setup Infrastructure
#
# This script provisions a complete load testing environment with:
# - Minio (S3-compatible storage)
# - Postgres (database backend)
# - Hive Metastore (metadata catalog)
# - Spark History Server (event log analysis)
# - Test data generation and loading
#
# Usage: ./setup-minikube-load-tests.sh [--recreate] [--cpus 8] [--memory 16384] [--disk 524288]

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MINIKUBE_DEFAULT_CPUS=8
MINIKUBE_DEFAULT_MEMORY=16384  # 16GB in MB
MINIKUBE_DEFAULT_DISK=524288  # 500GB in MB
MINIKUBE_RECREATE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --recreate)
            MINIKUBE_RECREATE=true
            shift
            ;;
        --cpus)
            MINIKUBE_CPUS="$2"
            shift 2
            ;;
        --memory)
            MINIKUBE_MEMORY="$2"
            shift 2
            ;;
        --disk)
            MINIKUBE_DISK="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --recreate    Delete and recreate Minikube cluster"
            echo "  --cpus N      Number of CPUs (default: 8)"
            echo "  --memory N    Memory in MB (default: 16384)"
            echo "  --disk N      Disk size in MB (default: 524288)"
            echo "  -h, --help    Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Use defaults if not set
MINIKUBE_CPUS=${MINIKUBE_CPUS:-$MINIKUBE_DEFAULT_CPUS}
MINIKUBE_MEMORY=${MINIKUBE_MEMORY:-$MINIKUBE_DEFAULT_MEMORY}
MINIKUBE_DISK=${MINIKUBE_DISK:-$MINIKUBE_DEFAULT_DISK}

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo ""
    echo -e "${BLUE}==>${NC} $1"
}

check_prerequisites() {
    print_step "Checking prerequisites"

    # Check minikube
    if ! command -v minikube &> /dev/null; then
        log_error "minikube not found. Install from: https://minikube.sigs.k8s.io/"
        exit 1
    fi
    log_success "minikube found: $(minikube version --short)"

    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found. Install from: https://kubernetes.io/docs/tasks/tools/"
        exit 1
    fi
    log_success "kubectl found: $(kubectl version --client --short 2>/dev/null || echo 'unknown')"

    # Check helm
    if ! command -v helm &> /dev/null; then
        log_error "helm not found. Install from: https://helm.sh/docs/intro/install/"
        exit 1
    fi
    log_success "helm found: $(helm version --short 2>/dev/null || echo 'unknown')"

    # Check docker
    if ! docker ps &> /dev/null 2>&1; then
        log_error "Docker not running. Start Docker and try again."
        exit 1
    fi
    log_success "Docker is running"
}

setup_minikube() {
    print_step "Setting up Minikube"

    # Check if minikube exists
    if minikube status &> /dev/null; then
        if [[ "$MINIKUBE_RECREATE" == "true" ]]; then
            log_warning "Minikube exists. Recreating..."
            minikube delete
        else
            log_info "Minikube exists. Use --recreate to rebuild."
            log_info "Current profile: $(minikube profile)"
            return 0
        fi
    fi

    log_info "Starting Minikube with ${MINIKUBE_CPUS} CPUs, ${MINIKUBE_MEMORY}MB RAM, ${MINIKUBE_DISK}MB disk"

    minikube start \
        --cpus="$MINIKUBE_CPUS" \
        --memory="$MINIKUBE_MEMORY" \
        --disk-size="$MINIKUBE_DISK" \
        --driver=docker \
        --container-runtime=docker \
        --dns-proxy=false \
        --extra-config=kubelet.max-pods=500

    log_success "Minikube started"

    # Enable ingress
    log_info "Enabling ingress..."
    minikube addons enable ingress || true

    # Verify cluster
    log_info "Verifying cluster..."
    kubectl get nodes

    log_success "Minikube is ready"
}

install_infrastructure() {
    print_step "Installing infrastructure components"

    # Create namespace
    kubectl create namespace load-testing --dry-run=client -o yaml | kubectl apply -f -

    # Install Minio
    log_info "Installing Minio..."
    helm repo add minio https://charts.min.io/ --force-update 2>/dev/null || true
    helm upgrade --install minio minio/minio \
        --namespace load-testing \
        --set replicas=1 \
        --set persistence.size=20Gi \
        --set resources.requests.memory=1Gi \
        --set resources.requests.cpu=500m \
        --set resources.limits.memory=2Gi \
        --set resources.limits.cpu=1000m \
        --set buckets[0].name=spark-logs \
        --set buckets[1].name=test-data \
        --set buckets[2].name=iceberg-warehouse \
        --set rootUser=minioadmin \
        --set rootPassword=minioadmin \
        --wait \
        --timeout 5m

    log_success "Minio installed"

    # Install Postgres
    log_info "Installing Postgres..."
    helm repo add bitnami https://charts.bitnami.com/bitnami --force-update 2>/dev/null || true
    helm upgrade --install postgres bitnami/postgresql \
        --namespace load-testing \
        --set auth.database=spark_db \
        --set auth.password=sparktest \
        --set auth.postgresPassword=postgres \
        --set persistence.size=10Gi \
        --set primary.resources.requests.memory=512Mi \
        --set primary.resources.requests.cpu=250m \
        --wait \
        --timeout 5m

    log_success "Postgres installed"
}

setup_hive_metastore() {
    print_step "Setting up Hive Metastore"

    # Deploy Hive Metastore
    kubectl apply -f "$PROJECT_ROOT/scripts/tests/load/infrastructure/hive-metastore.yaml" --dry-run=client -o yaml | kubectl apply -f -

    log_info "Waiting for Hive Metastore to be ready..."
    kubectl wait --for=condition=ready pod -l app=hive-metastore -n load-testing --timeout=300s

    log_success "Hive Metastore deployed"
}

setup_history_server() {
    print_step "Setting up Spark History Server"

    # Deploy History Server
    kubectl apply -f "$PROJECT_ROOT/scripts/tests/load/infrastructure/history-server.yaml" --dry-run=client -o yaml | kubectl apply -f -

    log_info "Waiting for History Server to be ready..."
    kubectl wait --for=condition=ready pod -l app=spark-history-server -n load-testing --timeout=300s

    log_success "Spark History Server deployed"
}

generate_test_data() {
    print_step "Generating test data"

    log_info "Generating NYC taxi 1GB dataset..."
    python3 "$PROJECT_ROOT/scripts/tests/load/data/generate-nyc-taxi.py" --size 1gb --upload

    log_info "Generating NYC taxi 11GB dataset..."
    python3 "$PROJECT_ROOT/scripts/tests/load/data/generate-nyc-taxi.py" --size 11gb --upload

    log_success "Test data generated and uploaded"
}

print_summary() {
    print_step "Setup complete"

    echo ""
    echo "Infrastructure components deployed:"
    echo "  - Minio (S3):"
    echo "    kubectl port-forward -n load-testing svc/minio 9000:9000"
    echo "    URL: http://localhost:9000"
    echo "    Credentials: minioadmin/minioadmin"
    echo ""
    echo "  - Postgres:"
    echo "    kubectl port-forward -n load-testing svc/postgres-load-testing 5432:5432"
    echo "    URL: jdbc:postgresql://localhost:5432/spark_db"
    echo "    Credentials: postgres / sparktest"
    echo ""
    echo "  - Spark History Server:"
    echo "    kubectl port-forward -n load-testing svc/spark-history-server 18080:18080"
    echo "    URL: http://localhost:18080"
    echo ""
    echo "Next steps:"
    echo "  1. Verify: ./scripts/local-dev/verify-load-test-env.sh"
    echo "  2. Run tests: ./scripts/tests/load/run-load-tests.sh"
    echo ""
}

# Main execution
main() {
    log_info "Starting Minikube load test infrastructure setup"
    log_info "Configuration: ${MINIKUBE_CPUS} CPUs, ${MINIKUBE_MEMORY}MB RAM, ${MINIKUBE_DISK}MB disk"

    check_prerequisites
    setup_minikube
    install_infrastructure
    setup_hive_metastore
    setup_history_server
    generate_test_data
    print_summary

    log_success "Load test infrastructure setup complete!"
}

# Run main
main "$@"
