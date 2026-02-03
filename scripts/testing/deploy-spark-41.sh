#!/bin/bash
# deploy-spark-41.sh
#
# Deploy Spark 4.1 Hive Metastore in shared infrastructure namespace.
# Assumes MinIO, PostgreSQL, and History Server are already deployed.
#
# Usage:
#   ./scripts/testing/deploy-spark-41.sh [namespace]
#
# Arguments:
#   namespace Target namespace (default: spark-infra)

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE=${1:-spark-infra}
CHART_NAME="spark-41"
PRESET_FILE="charts/spark-4.1/presets/shared-infrastructure.yaml"

echo -e "${BLUE}=== Spark 4.1 Deployment (Shared Infrastructure) ===${NC}"
echo "Namespace: $NAMESPACE"
echo ""

# Check if namespace exists
if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    echo -e "${RED}Error: Namespace $NAMESPACE does not exist${NC}"
    echo "Please run: ./scripts/testing/deploy-shared-components.sh $NAMESPACE"
    exit 1
fi

# Step 1: Deploy Spark 4.1 Helm chart (only Hive Metastore)
echo -e "${YELLOW}Step 1: Deploying Spark 4.1 Hive Metastore...${NC}"
helm upgrade --install "$CHART_NAME" charts/spark-4.1 \
    -f "$PRESET_FILE" \
    --namespace "$NAMESPACE" \
    --wait --timeout 15m
echo -e "${GREEN}✓ Spark 4.1 deployed${NC}"
echo ""

# Step 2: Verify Hive Metastore is running
echo -e "${YELLOW}Step 2: Verifying Hive Metastore...${NC}"
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=hive-metastore-41 -n "$NAMESPACE" --timeout=120s
echo -e "${GREEN}✓ Hive Metastore is running${NC}"
echo ""

echo -e "${GREEN}=== Spark 4.1 Deployment Complete ===${NC}"
echo ""

echo "Status:"
kubectl get pods -n "$NAMESPACE" | grep -E "NAME|hive|postgresql|minio|history"
echo ""
