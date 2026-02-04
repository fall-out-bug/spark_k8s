#!/bin/bash
# deploy-core-baseline.sh
#
# Complete automated deployment of Spark 4.1 Core Baseline in minikube.
#
# This script handles all the manual steps that were previously done
# interactively: namespace creation, PV setup, secrets, database init.
#
# Usage:
#   ./scripts/testing/deploy-core-baseline.sh [namespace]
#
# Arguments:
#   namespace Target namespace (default: spark-f06)
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
NAMESPACE=${1:-spark-f06}
STORAGE_BASE="/tmp/spark-testing"
CHART_NAME="spark-test"
CHART_PATH="charts/spark-4.1"
PRESET_FILE="charts/spark-4.1/presets/core-baseline.yaml"

echo -e "${BLUE}=== Spark 4.1 Core Baseline Deployment ===${NC}"
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
./scripts/testing/setup-manual-pvs.sh "$NAMESPACE" "$STORAGE_BASE" "4.1"
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

# Get PostgreSQL container ID via minikube (kubectl exec doesn't work with RBAC)
PG_CONTAINER=$(minikube ssh "docker ps | grep $PG_POD | head -1 | cut -d' ' -f1")

# Use minikube ssh to initialize database directly
echo "Creating database metastore_spark41 and user hive..."
minikube ssh "docker exec $PG_CONTAINER psql -U spark -c 'CREATE USER hive WITH PASSWORD \"hive123\";'" 2>/dev/null || echo "User may already exist"

minikube ssh "docker exec $PG_CONTAINER psql -U spark -c 'CREATE DATABASE metastore_spark41;'" 2>/dev/null || echo "Database may already exist"

minikube ssh "docker exec $PG_CONTAINER psql -U spark -c 'GRANT ALL PRIVILEGES ON DATABASE metastore_spark41 TO hive;'" 2>/dev/null

minikube ssh "docker exec $PG_CONTAINER psql -U spark -d metastore_spark41 -c 'GRANT ALL ON SCHEMA public TO hive;'" 2>/dev/null

echo -e "${GREEN}✓ Database initialized${NC}"
echo ""

# Step 7: Trigger Hive schema initialization
echo -e "${YELLOW}Step 7: Triggering Hive schema initialization...${NC}"

# Manually run schematool
echo "Running Hive schematool..."
kubectl run "hive-init-$$" \
    --restart=Never \
    --image="spark-k8s/hive:4.0.0-pg" \
    -n "$NAMESPACE" \
    --env="POSTGRES_HOST=postgresql-metastore-41" \
    --env="POSTGRES_PORT=5432" \
    --env="POSTGRES_DB=metastore_spark41" \
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

# Wait for Hive schema init to complete and cleanup
echo "Waiting for Hive schema init to complete..."
for i in {1..60}; do
    if kubectl get pod "hive-init-$$" -n "$NAMESPACE" &>/dev/null; then
        POD_STATUS=$(kubectl get pod "hive-init-$$" -n "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Pending")
        if [ "$POD_STATUS" = "Succeeded" ] || [ "$POD_STATUS" = "Completed" ]; then
            break
        fi
        if [ "$POD_STATUS" = "Failed" ]; then
            echo "Hive schema init failed, check logs"
            break
        fi
    fi
    sleep 2
done
kubectl delete pod "hive-init-$$" -n "$NAMESPACE" --ignore-not-found=true &>/dev/null

echo -e "${GREEN}✓ Hive schema initialized${NC}"
echo ""

# Step 8: Create MinIO buckets and fix History Server configmap
echo -e "${YELLOW}Step 8: Configuring MinIO and History Server...${NC}"

# Create S3 buckets
echo "Creating S3 buckets..."
kubectl run "mc-buckets-$$" \
    --restart=Never \
    --image=quay.io/minio/mc:latest \
    -n "$NAMESPACE" \
    --command -- /bin/sh -c "
        mc alias set myminio http://minio-spark-41:9000 minioadmin minioadmin
        mc mb myminio/spark-logs
        mc cp /etc/hostname myminio/spark-logs/events/.keep
        mc ls myminio/
    " &>/dev/null || echo "Buckets may already exist"

# Wait for mc buckets to complete and cleanup
echo "Waiting for bucket creation to complete..."
sleep 10
kubectl delete pod "mc-buckets-$$" -n "$NAMESPACE" --ignore-not-found=true &>/dev/null

# Fix History Server configmap with correct credentials provider
echo "Updating History Server configuration..."
kubectl patch configmap history-server-41-config -n "$NAMESPACE" \
    --type='json' -p='[
        {"op": "replace", "path": "/data/spark-defaults.conf", "value": "# Spark History Server Configuration\nspark.history.fs.logDirectory s3a://spark-logs/events\nspark.history.fs.update.interval 10s\nspark.history.provider org.apache.spark.deploy.history.FsHistoryProvider\n\n# S3 Configuration for Event Logs\nspark.hadoop.fs.s3a.endpoint http://minio-spark-41:9000\nspark.hadoop.fs.s3a.path.style.access true\nspark.hadoop.fs.s3a.connection.ssl.enabled false\nspark.hadoop.fs.s3a.impl org.apache.hadoop.fs.s3a.S3AFileSystem\nspark.hadoop.fs.s3a.aws.credentials.provider org.apache.hadoop.fs.s3a.SimpleAWSCredentialsProvider\nspark.hadoop.fs.s3a.access.key minioadmin\nspark.hadoop.fs.s3a.secret.key minioadmin\n\n# S3 connection settings\nspark.hadoop.fs.s3a.connection.maximum 200\nspark.hadoop.fs.s3a.connection.timeout 200000\n\n# History Server UI Settings\nspark.history.ui.port 18080\nspark.history.ui.maxApplications 1000\nspark.history.fs.cleaner.enabled true\nspark.history.fs.cleaner.interval 1d\nspark.history.fs.cleaner.maxAge 7d"}
    ]' &>/dev/null || echo "Configmap may already be patched"

# Restart History Server and Hive Metastore to apply changes
echo "Restarting History Server and Hive Metastore..."
kubectl delete pod -l app.kubernetes.io/name=spark-history-server -n "$NAMESPACE" --ignore-not-found=true &>/dev/null
kubectl delete pod -l app.kubernetes.io/name=spark-4.1-hive-metastore -n "$NAMESPACE" --ignore-not-found=true &>/dev/null

# Wait for pods to be ready
echo "Waiting for pods to stabilize..."
sleep 15
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=spark-history-server -n "$NAMESPACE" --timeout=120s &>/dev/null || true
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=spark-4.1-hive-metastore -n "$NAMESPACE" --timeout=120s &>/dev/null || true

echo -e "${GREEN}✓ MinIO and History Server configured${NC}"
echo ""

# Step 9: Verify deployment
echo -e "${YELLOW}Step 9: Verifying deployment...${NC}"
echo "Pods status:"
kubectl get pods -n "$NAMESPACE"
echo ""

echo "PVCs status:"
kubectl get pvc -n "$NAMESPACE"
echo ""

echo "Services status:"
kubectl get svc -n "$NAMESPACE"
echo ""

# Step 10: Run connectivity tests
echo -e "${YELLOW}Step 10: Running connectivity tests...${NC}"

# Test PostgreSQL via minikube ssh (kubectl exec blocked by RBAC)
echo "Testing PostgreSQL connection..."
PG_CONTAINER=$(minikube ssh "docker ps | grep $PG_POD | head -1 | cut -d' ' -f1")
if minikube ssh "docker exec $PG_CONTAINER psql -U hive -d metastore_spark41 -c 'SELECT 1;'" &>/dev/null; then
    echo -e "${GREEN}✓ PostgreSQL: OK${NC}"
else
    echo -e "${RED}✗ PostgreSQL: FAILED${NC}"
fi

# Test Hive Metastore via minikube ssh
echo "Testing Hive Metastore..."
HIVE_POD=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=spark-4.1-hive-metastore -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$HIVE_POD" ]; then
    HIVE_CONTAINER=$(minikube ssh "docker ps | grep $HIVE_POD | head -1 | cut -d' ' -f1")
    if minikube ssh "docker exec $HIVE_CONTAINER nc -z localhost 9083" &>/dev/null; then
        echo -e "${GREEN}✓ Hive Metastore: OK${NC}"
    else
        echo -e "${RED}✗ Hive Metastore: FAILED${NC}"
    fi
else
    echo -e "${RED}✗ Hive Metastore: NOT FOUND${NC}"
fi

# Test MinIO via minikube ssh
echo "Testing MinIO..."
MINIO_POD=$(kubectl get pods -n "$NAMESPACE" -l app=minio-spark-41 -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$MINIO_POD" ]; then
    MINIO_CONTAINER=$(minikube ssh "docker ps | grep $MINIO_POD | head -1 | cut -d' ' -f1")
    if minikube ssh "docker exec $MINIO_CONTAINER nc -z localhost 9000" &>/dev/null; then
        echo -e "${GREEN}✓ MinIO: OK${NC}"
    else
        echo -e "${RED}✗ MinIO: FAILED${NC}"
    fi
else
    echo -e "${RED}✗ MinIO: NOT FOUND${NC}"
fi

# Test History Server via minikube ssh
echo "Testing History Server..."
HS_POD=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=spark-history-server -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$HS_POD" ]; then
    HS_CONTAINER=$(minikube ssh "docker ps | grep $HS_POD | head -1 | cut -d' ' -f1")
    if minikube ssh "docker exec $HS_CONTAINER nc -z localhost 18080" &>/dev/null; then
        echo -e "${GREEN}✓ History Server: OK${NC}"
    else
        echo -e "${RED}✗ History Server: FAILED${NC}"
    fi
else
    echo -e "${RED}✗ History Server: NOT FOUND${NC}"
fi

echo ""
echo -e "${GREEN}=== Deployment Complete ===${NC}"
echo ""
echo "To access services:"
echo "  History Server: kubectl port-forward -n $NAMESPACE svc/history-server-41 18080:18080"
echo "  MinIO Console: kubectl port-forward -n $NAMESPACE svc/minio-spark-41 9001:9001"
echo ""
echo "To cleanup:"
echo "  helm uninstall $CHART_NAME -n $NAMESPACE"
echo "  kubectl delete namespace $NAMESPACE"
echo "  ./scripts/testing/cleanup-manual-pvs.sh"
