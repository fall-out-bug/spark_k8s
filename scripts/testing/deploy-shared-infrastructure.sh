#!/bin/bash
# deploy-shared-infrastructure.sh
#
# Deploy shared infrastructure components for both Spark 3.5 and 4.1:
# - MinIO: S3-compatible object storage (shared)
# - PostgreSQL: Database for Hive Metastore (shared)
# - History Server: UI for both Spark versions (shared)
#
# Each Spark version will have its own Hive Metastore database in the same PostgreSQL.
#
# Usage:
#   ./scripts/testing/deploy-shared-infrastructure.sh [namespace]
#
# Arguments:
#   namespace Target namespace (default: spark-infra)

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
NAMESPACE=${1:-spark-infra}
STORAGE_BASE="/tmp/spark-testing"

echo -e "${BLUE}=== Shared Infrastructure Deployment (Spark 3.5 + 4.1) ===${NC}"
echo "Namespace: $NAMESPACE"
echo "Storage: $STORAGE_BASE"
echo ""

# Step 1: Create namespace
echo -e "${YELLOW}Step 1: Creating namespace...${NC}"
if kubectl get namespace "$NAMESPACE" &>/dev/null; then
    echo -e "${YELLOW}⚠ Namespace $NAMESPACE already exists${NC}"
else
    kubectl create namespace "$NAMESPACE"
    echo -e "${GREEN}✓ Namespace created${NC}"
fi
echo ""

# Step 2: Setup PVs for both versions
echo -e "${YELLOW}Step 2: Setting up PersistentVolumes...${NC}"
./scripts/testing/setup-manual-pvs.sh "$NAMESPACE" "$STORAGE_BASE" "4.1"

# Create additional PV for Spark 3.5 if needed
EXISTING_PG_35=$(kubectl get pv data-postgresql-metastore-3.5-0 --ignore-not-found 2>/dev/null)
if [ -z "$EXISTING_PG_35" ]; then
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: data-postgresql-metastore-3.5-0
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
    echo -e "${GREEN}✓ Additional PV for Spark 3.5 created${NC}"
fi
echo ""

# Step 3: Create secrets
echo -e "${YELLOW}Step 3: Creating secrets...${NC}"
if kubectl -n "$NAMESPACE" get secret s3-credentials &>/dev/null; then
    echo -e "${YELLOW}⚠ Secret s3-credentials already exists${NC}"
else
    kubectl create secret generic s3-credentials \
        --from-literal=access-key=minioadmin \
        --from-literal=secret-key=minioadmin \
        -n "$NAMESPACE"
    echo -e "${GREEN}✓ s3-credentials secret created${NC}"
fi

# Create PostgreSQL password secret for both databases
if kubectl -n "$NAMESPACE" get secret postgresql-credentials &>/dev/null; then
    echo -e "${YELLOW}⚠ Secret postgresql-credentials already exists${NC}"
else
    kubectl create secret generic postgresql-credentials \
        --from-literal=POSTGRES_USER=postgres \
        --from-literal=POSTGRES_PASSWORD=postgres123 \
        -n "$NAMESPACE"
    echo -e "${GREEN}✓ postgresql-credentials secret created${NC}"
fi

# Create Hive user secrets
if kubectl -n "$NAMESPACE" get secret hive-credentials &>/dev/null; then
    echo -e "${YELLOW}⚠ Secret hive-credentials already exists${NC}"
else
    kubectl create secret generic hive-credentials \
        --from-literal=POSTGRES_USER=hive \
        --from-literal=POSTGRES_PASSWORD=hive123 \
        -n "$NAMESPACE"
    echo -e "${GREEN}✓ hive-credentials secret created${NC}"
fi
echo ""

echo -e "${GREEN}=== Shared Infrastructure Setup Complete ===${NC}"
echo ""
echo "Next steps:"
echo "  1. Deploy Spark 4.1: ./scripts/testing/deploy-spark-41.sh"
echo "  2. Deploy Spark 3.5: ./scripts/testing/deploy-spark-35.sh"
echo ""
echo "Shared components will be deployed by these scripts."
echo ""
