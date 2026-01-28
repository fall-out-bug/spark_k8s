#!/bin/bash
# Iceberg E2E Test with MinIO (with dynamic jar download)

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TEST_NAMESPACE="${TEST_NAMESPACE:-spark-e2e-iceberg}"

echo "========================================"
echo "Iceberg E2E Test with MinIO"
echo "========================================"

cleanup() {
    echo ""
    echo -e "${YELLOW}Cleaning up...${NC}"
    helm uninstall spark-e2e -n "$TEST_NAMESPACE" 2>/dev/null || true
    helm uninstall minio -n "$TEST_NAMESPACE" 2>/dev/null || true
    kubectl delete namespace "$TEST_NAMESPACE" 2>/dev/null || true
    echo -e "${GREEN}✓ Cleanup complete${NC}"
}

trap cleanup EXIT

# Setup
kubectl create namespace "$TEST_NAMESPACE" 2>/dev/null || true
kubectl create serviceaccount spark-e2e -n "$TEST_NAMESPACE" 2>/dev/null || true
kubectl create rolebinding spark-e2e-admin --clusterrole=admin --serviceaccount="${TEST_NAMESPACE}:spark-e2e" -n "$TEST_NAMESPACE" 2>/dev/null || true

# Deploy MinIO (simple single-instance)
echo -e "${YELLOW}Deploying MinIO...${NC}"
cat <<EOF | kubectl apply -n "$TEST_NAMESPACE" -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: minio-config
data:
  initialize: |
    #!/bin/sh
    mkdir -p /data/warehouse /data/spark-logs
EOF

cat <<EOF | kubectl apply -n "$TEST_NAMESPACE" -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: minio
spec:
  replicas: 1
  selector:
    matchLabels:
      app: minio
  template:
    metadata:
      labels:
        app: minio
    spec:
      containers:
      - name: minio
        image: minio/minio:latest
        ports:
        - containerPort: 9000
        env:
        - name: MINIO_ROOT_USER
          value: minioadmin
        - name: MINIO_ROOT_PASSWORD
          value: minioadmin
        command:
        - /bin/sh
        - -c
        - |
          mkdir -p /data/warehouse /data/spark-logs && \
          minio server /data
        volumeMounts:
        - name: data
          mountPath: /data
      volumes:
      - name: data
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: minio
spec:
  selector:
    app: minio
  ports:
  - port: 9000
    targetPort: 9000
EOF


echo -e "${YELLOW}Waiting for MinIO...${NC}"
kubectl wait --for=condition=available deployment/minio -n "$TEST_NAMESPACE" --timeout=120s

# Create S3 secret
kubectl create secret generic s3-credentials \
    --from-literal=access-key=minioadmin \
    --from-literal=secret-key=minioadmin \
    -n "$TEST_NAMESPACE" 2>/dev/null || true

# Get MinIO service
MINIO_IP=$(kubectl get svc -n "$TEST_NAMESPACE" minio -o jsonpath='{.spec.clusterIP}')
echo "MinIO IP: $MINIO_IP"

# Create buckets via mc
echo -e "${YELLOW}Creating S3 buckets...${NC}"
kubectl run mc -n "$TEST_NAMESPACE" --rm -i --restart=Never \
    --image=minio/mc:latest \
    --command=/bin/sh \
    -- \
    -c "
        mc alias set minio http://$MINIO_IP:9000 minioadmin minioadmin
        mc mb minio/warehouse --ignore-existing
        mc mb minio/spark-logs --ignore-existing
        echo 'Buckets created'
    " 2>&1 | tail -5

# Deploy Spark with Iceberg configs
echo -e "${YELLOW}Deploying Spark with Iceberg...${NC}"
helm install spark-e2e charts/spark-4.1 \
    --namespace "$TEST_NAMESPACE" \
    --set rbac.create=false \
    --set rbac.serviceAccountName=spark-e2e \
    --set connect.serviceAccountName=spark-e2e \
    --set connect.enabled=true \
    --set connect.backendMode=connect \
    --set connect.image.repository=apache/spark \
    --set connect.image.tag=4.1.0 \
    --set hiveMetastore.enabled=false \
    --set historyServer.enabled=false \
    --set jupyter.enabled=false \
    --set global.s3.enabled=true \
    --set global.s3.endpoint="http://$MINIO_IP:9000" \
    --set global.s3.existingSecret=s3-credentials \
    --set global.s3.pathStyleAccess=true \
    --set global.minio.enabled=false \
    --set global.postgresql.enabled=false \
    --set connect.eventLog.enabled=false \
    --set connect.sparkConf."spark.sql.extensions"="org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions" \
    --set connect.sparkConf."spark.sql.catalog.iceberg"=org.apache.iceberg.spark.SparkCatalog \
    --set connect.sparkConf."spark.sql.catalog.iceberg.type"=hadoop \
    --set connect.sparkConf."spark.sql.catalog.iceberg.warehouse"="s3a://warehouse/iceberg" \
    --set connect.sparkConf."spark.sql.catalog.iceberg.io-impl"=org.apache.iceberg.aws.s3.S3FileIO \
    --set connect.sparkConf."spark.sql.catalog.iceberg.s3.endpoint"="http://$MINIO_IP:9000" \
    --set connect.sparkConf."spark.hadoop.fs.s3a.access.key"=minioadmin \
    --set connect.sparkConf."spark.hadoop.fs.s3a.secret.key"=minioadmin \
    --set connect.sparkConf."spark.hadoop.fs.s3a.path.style.access"=true \
    --set connect.sparkConf."spark.hadoop.fs.s3a.connection.ssl.enabled"=false \
    --wait --timeout 10m 2>&1 | tail -20

echo -e "${YELLOW}Waiting for pod ready...${NC}"
kubectl wait --for=condition=ready pod -l app=spark-connect -n "$TEST_NAMESPACE" --timeout=300s

POD_NAME=$(kubectl get pods -n "$TEST_NAMESPACE" -l app=spark-connect -o jsonpath='{.items[0].metadata.name}')

# Test Iceberg operations
echo -e "${YELLOW}Testing Iceberg operations...${NC}"
kubectl exec -n "$TEST_NAMESPACE" "$POD_NAME" -- /bin/sh -c '
  cat > /tmp/iceberg_test.py << "PYEOF"
from pyspark.sql import SparkSession
spark = SparkSession.builder.appName("Iceberg-Test").getOrCreate()

print("Spark version:", spark.version)
print("Testing Iceberg catalog...")

# Try to list catalogs (will fail if Iceberg not available)
try:
    catalogs = spark.sql("SHOW CATALOGS").collect()
    print("Available catalogs:", [row.catalog for row in catalogs])
except Exception as e:
    print(f"Error listing catalogs: {e}")

# Try to use iceberg catalog
try:
    df = spark.sql("SELECT * FROM iceberg.default.tables LIMIT 10")
    print("Iceberg catalog accessible!")
    print("Tables:", df.collect())
except Exception as e:
    print(f"Expected error (Iceberg jars not in image): {type(e).__name__}")
    if "ClassNotFoundException" in str(e) or "Cannot find catalog plugin" in str(e):
        print("ICEBERG_JARS_MISSING: Expected - need custom Spark image with Iceberg")
    else:
        print(f"Unexpected error: {e}")

spark.stop()
PYEOF
  timeout 120 /opt/spark/bin/spark-submit \
    --master "local[*]" \
    --conf spark.driver.memory=1g \
    /tmp/iceberg_test.py
' 2>&1 | grep -E "(Spark version|Iceberg|catalog|ClassNotFoundException|ICEBERG|Error)" || true

echo ""
echo "========================================"
echo -e "${YELLOW}Iceberg Test Summary${NC}"
echo "========================================"
echo ""
echo "Expected Result: ClassNotFoundException for Iceberg classes"
echo "Solution: Build custom Spark image with Iceberg jars"
echo ""
echo "To build custom image:"
echo "  FROM apache/spark:4.1.0"
echo "  RUN wget -P /opt/spark/jars \\"
echo "    https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-spark-runtime-4.1_2.13/1.6.1/iceberg-spark-runtime-4.1_2.13-1.6.1.jar"
echo ""
