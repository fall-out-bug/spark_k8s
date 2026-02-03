#!/bin/bash
# deploy-shared-components.sh
#
# Deploy shared infrastructure components for both Spark 3.5 and 4.1:
# - MinIO: S3-compatible object storage
# - PostgreSQL: Database for both Hive Metastores
# - History Server: UI for both Spark versions (reads from 3.5 and 4.1 logs)
#
# Usage:
#   ./scripts/testing/deploy-shared-components.sh [namespace]
#
# Arguments:
#   namespace Target namespace (default: spark-infra)

set -e

# Change to project root directory
cd "$(dirname "$0")/../.."

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE=${1:-spark-infra}
STORAGE_BASE="/tmp/spark-testing"

echo -e "${BLUE}=== Shared Components Deployment (Spark 3.5 + 4.1) ===${NC}"
echo "Namespace: $NAMESPACE"
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

# Step 2: Load required Docker images into minikube
echo -e "${YELLOW}Step 2: Loading Docker images into minikube...${NC}"
IMAGES=(
    "spark-custom:4.1.0"
    "spark-k8s/hive:4.0.0-pg"
)
for img in "${IMAGES[@]}"; do
    echo "Loading $img..."
    if minikube image ls | grep -q "$img"; then
        echo -e "${YELLOW}⚠ Image $img already loaded${NC}"
    else
        minikube image load "$img"
        echo -e "${GREEN}✓ Image $img loaded${NC}"
    fi
done
echo ""

# Step 3: Setup PVs
echo -e "${YELLOW}Step 3: Setting up PersistentVolumes...${NC}"
./scripts/testing/setup-manual-pvs.sh "$NAMESPACE" "$STORAGE_BASE" "4.1"
echo ""

# Step 6: Create secrets
echo -e "${YELLOW}Step 6: Creating secrets...${NC}"
if kubectl -n "$NAMESPACE" get secret s3-credentials &>/dev/null; then
    echo -e "${YELLOW}⚠ Secret s3-credentials already exists${NC}"
else
    kubectl create secret generic s3-credentials \
        --from-literal=access-key=minioadmin \
        --from-literal=secret-key=minioadmin \
        -n "$NAMESPACE"
    echo -e "${GREEN}✓ s3-credentials secret created${NC}"
fi

# PostgreSQL superuser secret
if kubectl -n "$NAMESPACE" get secret postgresql-credentials &>/dev/null; then
    echo -e "${YELLOW}⚠ Secret postgresql-credentials already exists${NC}"
else
    kubectl create secret generic postgresql-credentials \
        --from-literal=POSTGRES_USER=postgres \
        --from-literal=POSTGRES_PASSWORD=postgres123 \
        -n "$NAMESPACE"
    echo -e "${GREEN}✓ postgresql-credentials secret created${NC}"
fi

# Hive user secret (for both metastores)
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

# Step 5: Deploy shared components using preset
echo -e "${YELLOW}Step 5: Deploying shared components (MinIO, PostgreSQL, History Server)...${NC}"
helm upgrade --install shared charts/spark-4.1 \
    -f charts/spark-4.1/presets/shared-only.yaml \
    --namespace "$NAMESPACE" \
    --wait --timeout 15m
echo -e "${GREEN}✓ Shared components deployed${NC}"
echo ""

# Step 6: Wait for PostgreSQL and create databases
echo -e "${YELLOW}Step 6: Creating databases...${NC}"
PG_POD=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=spark-base,app=postgresql -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -z "$PG_POD" ]; then
    PG_POD=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=spark-4.1-postgresql -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
fi

if [ -z "$PG_POD" ]; then
    echo -e "${RED}Error: PostgreSQL pod not found${NC}"
    exit 1
fi

kubectl wait --for=condition=ready pod "$PG_POD" -n "$NAMESPACE" --timeout=300s

# Get PostgreSQL container and initialize databases
PG_CONTAINER=$(minikube ssh "docker ps | grep $PG_POD | head -1 | cut -d' ' -f1")

echo "Creating databases for Spark 3.5 and 4.1..."
minikube ssh "docker exec $PG_CONTAINER psql -U spark -c \"CREATE USER hive WITH PASSWORD 'hive123';\" 2>/dev/null || echo 'User exists'"

minikube ssh "docker exec $PG_CONTAINER psql -U spark -c 'CREATE DATABASE metastore_spark35;' 2>/dev/null || echo 'Database exists'"
minikube ssh "docker exec $PG_CONTAINER psql -U spark -c 'GRANT ALL PRIVILEGES ON DATABASE metastore_spark35 TO hive;' 2>/dev/null"
minikube ssh "docker exec $PG_CONTAINER psql -U spark -d metastore_spark35 -c 'GRANT ALL ON SCHEMA public TO hive;' 2>/dev/null"

minikube ssh "docker exec $PG_CONTAINER psql -U spark -c 'CREATE DATABASE metastore_spark41;' 2>/dev/null || echo 'Database exists'"
minikube ssh "docker exec $PG_CONTAINER psql -U spark -c 'GRANT ALL PRIVILEGES ON DATABASE metastore_spark41 TO hive;' 2>/dev/null"
minikube ssh "docker exec $PG_CONTAINER psql -U spark -d metastore_spark41 -c 'GRANT ALL ON SCHEMA public TO hive;' 2>/dev/null"

echo -e "${GREEN}✓ Databases created${NC}"
echo ""

# Step 7: Create S3 buckets for both versions
echo -e "${YELLOW}Step 7: Creating S3 buckets...${NC}"
kubectl run "mc-buckets-shared-$$" \
    --restart=Never \
    --image=quay.io/minio/mc:latest \
    -n "$NAMESPACE" \
    --command -- /bin/sh -c "
        mc alias set myminio http://minio:9000 minioadmin minioadmin
        mc mb myminio/spark-logs
        mc cp /etc/hostname myminio/spark-logs/3.5/events/.keep
        mc cp /etc/hostname myminio/spark-logs/4.1/events/.keep
        mc ls myminio/
    " &>/dev/null || echo "Buckets may already exist"

sleep 10
kubectl delete pod "mc-buckets-shared-$$" -n "$NAMESPACE" --ignore-not-found=true &>/dev/null
echo -e "${GREEN}✓ S3 buckets created${NC}"
echo ""

# Step 7: Verify deployment
echo -e "${YELLOW}Step 7: Verifying deployment...${NC}"
echo "Pods status:"
kubectl get pods -n "$NAMESPACE"
echo ""

echo -e "${GREEN}=== Shared Components Deployment Complete ===${NC}"
echo ""
echo "Next steps:"
echo "  1. Deploy Spark 4.1: ./scripts/testing/deploy-spark-41.sh $NAMESPACE"
echo "  2. Deploy Spark 3.5: ./scripts/testing/deploy-spark-35.sh $NAMESPACE"
echo ""
