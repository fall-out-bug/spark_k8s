#!/bin/bash
# deploy-spark-35.sh
#
# Deploy Spark 3.5 Hive Metastore in shared infrastructure namespace.
# Assumes MinIO, PostgreSQL, and History Server are already deployed.
#
# Usage:
#   ./scripts/testing/deploy-spark-35.sh [namespace]
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
CHART_NAME="spark-35"
PRESET_FILE="charts/spark-3.5/presets/shared-infrastructure.yaml"

echo -e "${BLUE}=== Spark 3.5 Deployment (Shared Infrastructure) ===${NC}"
echo "Namespace: $NAMESPACE"
echo ""

# Check if namespace exists
if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    echo -e "${RED}Error: Namespace $NAMESPACE does not exist${NC}"
    echo "Please run: ./scripts/testing/deploy-shared-components.sh $NAMESPACE"
    exit 1
fi

# Step 1: Deploy Spark 3.5 Helm chart (only Hive Metastore)
echo -e "${YELLOW}Step 1: Deploying Spark 3.5 Hive Metastore...${NC}"
helm upgrade --install "$CHART_NAME" charts/spark-3.5 \
    -f "$PRESET_FILE" \
    --namespace "$NAMESPACE" \
    --wait --timeout 15m
echo -e "${GREEN}✓ Spark 3.5 deployed${NC}"
echo ""

# Step 2: Initialize Hive schema
echo -e "${YELLOW}Step 2: Initializing Hive schema...${NC}"
# Create ConfigMap with hive-site.xml
kubectl create configmap hive-init-35 -n "$NAMESPACE" \
  --from-literal=hive-site.xml='<?xml version="1.0" encoding="UTF-8"?>
<configuration>
  <property>
    <name>javax.jdo.option.ConnectionURL</name>
    <value>jdbc:postgresql://shared-spark-base-postgresql:5432/metastore_spark35</value>
  </property>
  <property>
    <name>javax.jdo.option.ConnectionDriverName</name>
    <value>org.postgresql.Driver</value>
  </property>
  <property>
    <name>javax.jdo.option.ConnectionUserName</name>
    <value>hive</value>
  </property>
  <property>
    <name>javax.jdo.option.ConnectionPassword</name>
    <value>hive123</value>
  </property>
</configuration>' &>/dev/null || echo "ConfigMap exists"

# Run schematool
kubectl run "hive-init-35-$$" \
    --restart=Never \
    --image=spark-k8s/hive:4.0.0-pg \
    -n "$NAMESPACE" \
    --env="HIVE_CONF_DIR=/tmp/hive-conf" \
    --overrides='{"spec":{"volumes":[{"name":"hive-config","configMap":{"name":"hive-init-35"}}],"containers":[{"name":"hive-init-35-$$","volumeMounts":[{"name":"hive-config","mountPath":"/etc/hive-config"}]}]}}' \
    --command -- /bin/bash -lc "
        mkdir -p /tmp/hive-conf
        cat /etc/hive-config/hive-site.xml > /tmp/hive-conf/hive-site.xml
        /opt/hive/bin/schematool -dbType postgres -initSchema
    " &>/dev/null

# Wait for completion
for i in {1..60}; do
    if kubectl get pod "hive-init-35-$$" -n "$NAMESPACE" &>/dev/null; then
        PHASE=$(kubectl get pod "hive-init-35-$$" -n "$NAMESPACE" -o jsonpath='{.status.phase}')
        if [ "$PHASE" = "Succeeded" ]; then
            break
        fi
        if [ "$PHASE" = "Failed" ]; then
            echo -e "${RED}✗ Schema initialization failed${NC}"
            kubectl logs "hive-init-35-$$" -n "$NAMESPACE" | tail -20
            kubectl delete pod "hive-init-35-$$" -n "$NAMESPACE" --ignore-not-found=true &>/dev/null
            exit 1
        fi
    fi
    sleep 2
done

kubectl delete pod "hive-init-35-$$" -n "$NAMESPACE" --ignore-not-found=true &>/dev/null
kubectl delete configmap hive-init-35 -n "$NAMESPACE" --ignore-not-found=true &>/dev/null
echo -e "${GREEN}✓ Hive schema initialized${NC}"
echo ""

# Step 3: Verify Hive Metastore is running
echo -e "${YELLOW}Step 3: Verifying Hive Metastore...${NC}"
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=spark-3.5 -n "$NAMESPACE" --timeout=120s
echo -e "${GREEN}✓ Hive Metastore is running${NC}"
echo ""

echo -e "${GREEN}=== Spark 3.5 Deployment Complete ===${NC}"
echo ""

echo "Status:"
kubectl get pods -n "$NAMESPACE" | grep -E "NAME|hive|postgresql|minio|history|spark-35"
echo ""
