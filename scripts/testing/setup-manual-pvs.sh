#!/bin/bash
# setup-manual-pvs.sh
#
# Create manual PersistentVolumes for Spark testing in minikube.
#
# This is a testing-only workaround for minikube (WSL2 + docker driver)
# where dynamic provisioning doesn't work due to filesystem limitations.
#
# Usage:
#   ./scripts/testing/setup-manual-pvs.sh [namespace] [storage_base] [spark_version]
#
# Arguments:
#   namespace     Kubernetes namespace (default: default)
#   storage_base  Base path for storage (default: /tmp/spark-testing)
#   spark_version Spark version: 3.5 or 4.1 (default: 4.1)
#
# Production: Use cloud-specific StorageClass with dynamic provisioning.
#
# Related: issue-001, WS-TESTING-001, WS-TESTING-002

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Parse arguments
NAMESPACE=${1:-default}
STORAGE_BASE=${2:-/tmp/spark-testing}
SPARK_VERSION=${3:-4.1}

# Validate minikube is running
if ! minikube status &>/dev/null; then
    echo -e "${RED}Error: minikube is not running${NC}"
    echo "Please start minikube first: minikube start"
    exit 1
fi

# Validate kubectl can connect
if ! kubectl get nodes &>/dev/null; then
    echo -e "${RED}Error: kubectl cannot connect to cluster${NC}"
    echo "Please check your kubeconfig"
    exit 1
fi

echo -e "${GREEN}=== Spark Testing: Manual PV Setup ===${NC}"
echo "Namespace: $NAMESPACE"
echo "Storage base: $STORAGE_BASE"
echo ""

# Step 1: Create directories in minikube
echo -e "${YELLOW}Step 1: Creating storage directories in minikube...${NC}"
minikube ssh "mkdir -p $STORAGE_BASE/minio $STORAGE_BASE/postgresql" || {
    echo -e "${RED}Failed to create directories in minikube${NC}"
    exit 1
}
echo -e "${GREEN}✓ Directories created${NC}"
echo ""

# Step 2: Check if PVs already exist
echo -e "${YELLOW}Step 2: Checking existing PVs...${NC}"
EXISTING_MINIO=$(kubectl get pv minio-pv --ignore-not-found 2>/dev/null)
EXISTING_PG=$(kubectl get pv data-postgresql-metastore-${SPARK_VERSION}-0 --ignore-not-found 2>/dev/null)

if [ -n "$EXISTING_MINIO" ]; then
    echo -e "${YELLOW}⚠ minio-pv already exists, skipping...${NC}"
else
    kubectl apply -f templates/testing/pv-minio.yaml
    echo -e "${GREEN}✓ minio-pv created${NC}"
fi

if [ -n "$EXISTING_PG" ]; then
    echo -e "${YELLOW}⚠ data-postgresql-metastore-${SPARK_VERSION}-0 already exists, skipping...${NC}"
else
    # Create PV dynamically based on Spark version
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: data-postgresql-metastore-${SPARK_VERSION}-0
spec:
  capacity:
    storage: 8Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: standard
  volumeMode: Filesystem
  hostPath:
    path: ${STORAGE_BASE}/postgresql
    type: DirectoryOrCreate
EOF
    echo -e "${GREEN}✓ data-postgresql-metastore-${SPARK_VERSION}-0 created${NC}"
fi
echo ""

# Step 3: Verify PVs are available
echo -e "${YELLOW}Step 3: Verifying PVs...${NC}"
kubectl get pv minio-pv data-postgresql-metastore-${SPARK_VERSION}-0
echo ""

# Step 4: Summary
echo -e "${GREEN}=== Setup Complete ===${NC}"
echo "PVs created and available for binding."
echo ""
echo "Next steps:"
echo "  1. Deploy Spark chart: helm install spark charts/spark-4.1 -f presets/core-baseline.yaml"
echo "  2. PVCs will automatically bind to these PVs"
echo "  3. To cleanup: ./scripts/testing/cleanup-manual-pvs.sh"
echo ""
echo -e "${YELLOW}Note: This is a testing-only workaround for minikube (WSL2).${NC}"
echo -e "${YELLOW}      Production should use cloud StorageClasses.${NC}"
