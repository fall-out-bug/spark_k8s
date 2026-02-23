#!/bin/bash
# deploy-core-baseline-35.sh
#
# Complete automated deployment of Spark 3.5 Core Baseline in minikube.
#
# This script handles all the manual steps that were previously done
# interactively: namespace creation, PV setup, secrets, database init.
#
# Usage:
#   ./scripts/testing/deploy-core-baseline-35.sh [namespace]
#
# Arguments:
#   namespace Target namespace (default: spark-f35)
#
# Related: F06, WS-TESTING-003

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
NAMESPACE=${1:-spark-f35}
STORAGE_BASE="/tmp/spark-testing"
CHART_NAME="spark-test"
CHART_PATH="charts/spark-3.5"
PRESET_FILE="charts/spark-3.5/presets/core-baseline.yaml"

echo -e "${BLUE}=== Spark 3.5 Core Baseline Deployment ===${NC}"
echo "Namespace: $NAMESPACE"
echo "Storage: $STORAGE_BASE"
echo ""

# Step 1: Create namespace
echo -e "${YELLOW}Step 1: Creating namespace...${NC}"
if kubectl get namespace "$NAMESPACE" &>/dev/null; then
    echo -e "${YELLOW}⚠ Namespace $NAMESPACE already exists${NC}"
    read -p "Delete and recreate? (yes/no): " -n 3 -r
    echo
    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        kubectl delete namespace "$NAMESPACE"
        echo -e "${GREEN}✓ Namespace deleted${NC}"
        kubectl create namespace "$NAMESPACE"
        echo -e "${GREEN}✓ Namespace created${NC}"
    fi
else
    kubectl create namespace "$NAMESPACE"
    echo -e "${GREEN}✓ Namespace created${NC}"
fi
echo ""

# Step 2: Setup PVs
echo -e "${YELLOW}Step 2: Setting up PersistentVolumes...${NC}"
./scripts/testing/setup-manual-pvs.sh "$NAMESPACE" "$STORAGE_BASE" "3.5"
echo ""

# Step 3: Create secrets
echo -e "${YELLOW}Step 3: Creating secrets...${NC}"

# S3 credentials secret
if kubectl -n "$NAMESPACE" get secret s3-credentials &>/dev/null; then
    echo -e "${YELLOW}⚠ Secret s3-credentials already exists${NC}"
else
    kubectl create secret generic s3-credentials \
        --from-literal=access-key=minioadmin \
        --from-literal=secret-key=minioadmin \
        -n "$NAMESPACE"
    echo -e "${GREEN}✓ s3-credentials secret created${NC}"
fi

# Hive metastore database secret
if kubectl -n "$NAMESPACE" get secret "${CHART_NAME}-metastore-db" &>/dev/null; then
    echo -e "${YELLOW}⚠ Secret ${CHART_NAME}-metastore-db already exists${NC}"
else
    kubectl create secret generic "${CHART_NAME}-metastore-db" \
        --from-literal=POSTGRES_USER=hive \
        --from-literal=POSTGRES_PASSWORD=hive123 \
        -n "$NAMESPACE"
    echo -e "${GREEN}✓ metastore-db secret created${NC}"
fi
echo ""

# Step 4: Deploy Helm chart (without waiting for post-install hooks)
echo -e "${YELLOW}Step 4: Deploying Helm chart...${NC}"
if helm list -n "$NAMESPACE" | grep -q "^$CHART_NAME"; then
    echo -e "${YELLOW}⚠ Release $CHART_NAME already exists${NC}"
    read -p "Upgrade? (yes/no): " -n 3 -r
    echo
    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        helm upgrade "$CHART_NAME" "$CHART_PATH" \
            -f "$PRESET_FILE" \
            --namespace "$NAMESPACE" \
            --wait --timeout 15m
        echo -e "${GREEN}✓ Release upgraded${NC}"
    fi
else
    # Install with --wait but --no-hooks to avoid post-install failures
    helm install "$CHART_NAME" "$CHART_PATH" \
        -f "$PRESET_FILE" \
        --namespace "$NAMESPACE" \
        --wait --timeout 15m \
        --no-hooks
    echo -e "${GREEN}✓ Release installed${NC}"
fi
echo ""

# Step 5: Wait for PostgreSQL to be ready
echo -e "${YELLOW}Step 5: Waiting for PostgreSQL to be ready...${NC}"
echo "Waiting for PostgreSQL pod to be created..."
for i in {1..60}; do
  PG_POD=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=spark-4.1-postgresql -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
  if [ -n "$PG_POD" ]; then
    echo "PostgreSQL pod found: $PG_POD"
    break
  fi
  if [ $i -eq 60 ]; then
    echo -e "${RED}Timeout waiting for PostgreSQL pod${NC}"
    exit 1
  fi
  sleep 2
done
kubectl wait --for=condition=ready pod "$PG_POD" -n "$NAMESPACE" --timeout=300s
echo -e "${GREEN}✓ PostgreSQL is ready${NC}"
echo ""

# Step 6: Create database and user (BEFORE Hive init)
echo -e "${YELLOW}Step 6: Initializing database...${NC}"
echo "Using PostgreSQL pod: $PG_POD"

# Get PostgreSQL service name
PG_SVC="postgresql-metastore-35"

# Use kubectl exec to initialize database directly
echo "Creating database metastore_spark35 and user hive..."
kubectl exec -n "$NAMESPACE" "$PG_POD" -- psql -U spark -c "CREATE USER hive WITH PASSWORD 'hive123';" 2>/dev/null || echo "User may already exist"

kubectl exec -n "$NAMESPACE" "$PG_POD" -- psql -U spark -c "CREATE DATABASE metastore_spark35;" 2>/dev/null || echo "Database may already exist"

kubectl exec -n "$NAMESPACE" "$PG_POD" -- psql -U spark -c "GRANT ALL PRIVILEGES ON DATABASE metastore_spark35 TO hive;" 2>/dev/null

kubectl exec -n "$NAMESPACE" "$PG_POD" -- psql -U spark -d metastore_spark35 -c "GRANT ALL ON SCHEMA public TO hive;" 2>/dev/null

echo -e "${GREEN}✓ Database initialized${NC}"
echo ""

# Step 7: Trigger Hive schema initialization
echo -e "${YELLOW}Step 7: Triggering Hive schema initialization...${NC}"

# Manually run schematool
echo "Running Hive schematool..."
kubectl run "hive-init-$$" \
    --rm --restart=Never \
    --image="spark-k8s/hive:4.0.0-pg" \
    -n "$NAMESPACE" \
    --env="POSTGRES_HOST=postgresql-metastore-35" \
    --env="POSTGRES_PORT=5432" \
    --env="POSTGRES_DB=metastore_spark35" \
    --env="POSTGRES_USER=hive" \
    --env="POSTGRES_PASSWORD=hive123" \
    --command -- /bin/bash -c "
        mkdir -p /tmp/hive-conf
        cat > /tmp/hive-conf/hive-site.xml <<'EOF'
<?xml version=\"1.0\"?>
<configuration>
  <property>
    <name>javax.jdo.option.ConnectionURL</name>
    <value>jdbc:postgresql://HOST_PLACEHOLDER:PORT_PLACEHOLDER/DB_PLACEHOLDER</value>
  </property>
  <property>
    <name>javax.jdo.option.ConnectionUserName</name>
    <value>USER_PLACEHOLDER</value>
  </property>
  <property>
    <name>javax.jdo.option.ConnectionPassword</name>
    <value>PASS_PLACEHOLDER</value>
  </property>
  <property>
    <name>javax.jdo.option.ConnectionDriverName</name>
    <value>org.postgresql.Driver</value>
  </property>
</configuration>
EOF
        sed -i \"s/HOST_PLACEHOLDER/\$POSTGRES_HOST/g\" /tmp/hive-conf/hive-site.xml
        sed -i \"s/PORT_PLACEHOLDER/\$POSTGRES_PORT/g\" /tmp/hive-conf/hive-site.xml
        sed -i \"s/DB_PLACEHOLDER/\$POSTGRES_DB/g\" /tmp/hive-conf/hive-site.xml
        sed -i \"s/USER_PLACEHOLDER/\$POSTGRES_USER/g\" /tmp/hive-conf/hive-site.xml
        sed -i \"s/PASS_PLACEHOLDER/\$POSTGRES_PASSWORD/g\" /tmp/hive-conf/hive-site.xml
        export HIVE_CONF_DIR=/tmp/hive-conf
        /opt/hive/bin/schematool -dbType postgres -initSchema -verbose
    "

echo -e "${GREEN}✓ Hive schema initialized${NC}"
echo ""

# Step 8: Verify deployment
echo -e "${YELLOW}Step 8: Verifying deployment...${NC}"
echo "Pods status:"
kubectl get pods -n "$NAMESPACE"
echo ""

echo "PVCs status:"
kubectl get pvc -n "$NAMESPACE"
echo ""

echo "Services status:"
kubectl get svc -n "$NAMESPACE"
echo ""

# Step 9: Run connectivity tests
echo -e "${YELLOW}Step 9: Running connectivity tests...${NC}"

# Test PostgreSQL
echo "Testing PostgreSQL connection..."
if kubectl exec -n "$NAMESPACE" "$PG_POD" -- psql -U hive -d metastore_spark35 -c "SELECT 1;" &>/dev/null; then
    echo -e "${GREEN}✓ PostgreSQL: OK${NC}"
else
    echo -e "${RED}✗ PostgreSQL: FAILED${NC}"
fi

# Test Hive Metastore
echo "Testing Hive Metastore..."
HIVE_POD=$(kubectl get pods -n "$NAMESPACE" -l app=hive-metastore-35 -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$HIVE_POD" ]; then
    if kubectl exec -n "$NAMESPACE" "$HIVE_POD" -- nc -z localhost 9083; then
        echo -e "${GREEN}✓ Hive Metastore: OK${NC}"
    else
        echo -e "${RED}✗ Hive Metastore: FAILED${NC}"
    fi
fi

# Test MinIO
echo "Testing MinIO..."
MINIO_POD=$(kubectl get pods -n "$NAMESPACE" -l app=minio-spark-35 -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$MINIO_POD" ]; then
    if kubectl exec -n "$NAMESPACE" "$MINIO_POD" -- nc -z localhost 9000; then
        echo -e "${GREEN}✓ MinIO: OK${NC}"
    else
        echo -e "${RED}✗ MinIO: FAILED${NC}"
    fi
fi

echo ""
echo -e "${GREEN}=== Deployment Complete ===${NC}"
echo ""
echo "To access services:"
echo "  History Server: kubectl port-forward -n $NAMESPACE svc/history-server-35 18080:18080"
echo "  MinIO Console: kubectl port-forward -n $NAMESPACE svc/minio-spark-35 9001:9001"
echo ""
echo "To cleanup:"
echo "  helm uninstall $CHART_NAME -n $NAMESPACE"
echo "  kubectl delete namespace $NAMESPACE"
echo "  ./scripts/testing/cleanup-manual-pvs.sh"
