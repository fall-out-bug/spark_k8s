#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${1:-spark-history-compat}"
RELEASE="${2:-spark-41-history-test}"

CREATED_NAMESPACE="false"
REPORT_PATH="docs/testing/history-server-compat-report.md"

cleanup() {
  helm uninstall "${RELEASE}" -n "${NAMESPACE}" >/dev/null 2>&1 || true
  if [[ "${CREATED_NAMESPACE}" == "true" ]]; then
    kubectl delete namespace "${NAMESPACE}" >/dev/null 2>&1 || true
  fi
}

trap cleanup EXIT

echo "=== History Server Backward Compatibility Test (${NAMESPACE}) ==="

if ! kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1; then
  kubectl create namespace "${NAMESPACE}" >/dev/null
  CREATED_NAMESPACE="true"
fi

echo "1) Deploying History Server 4.1.0 (multi-prefix test)..."
cat > /tmp/history-multi-prefix.yaml <<EOF
historyServer:
  enabled: true
  logDirectory: "s3a://spark-logs/**/events"
EOF

helm install "${RELEASE}" charts/spark-4.1 \
  --namespace "${NAMESPACE}" \
  -f /tmp/history-multi-prefix.yaml \
  --set connect.enabled=false \
  --set hiveMetastore.enabled=false \
  --wait

echo "2) Running Spark 3.5.7 job..."
kubectl run spark-35-job \
  --image=spark-custom:3.5.7 \
  --restart=Never \
  --rm -i -n "${NAMESPACE}" \
  --env="AWS_ACCESS_KEY_ID=minioadmin" \
  --env="AWS_SECRET_ACCESS_KEY=minioadmin" \
  -- /opt/spark/bin/spark-submit \
  --master local[2] \
  --conf spark.eventLog.enabled=true \
  --conf spark.eventLog.dir=s3a://spark-logs/events \
  --conf spark.hadoop.fs.s3a.endpoint=http://minio:9000 \
  --class org.apache.spark.examples.SparkPi \
  local:///opt/spark/examples/jars/spark-examples.jar 100

echo "✓ Spark 3.5.7 job complete"

echo "3) Running Spark 4.1.0 job..."
kubectl run spark-41-job \
  --image=spark-custom:4.1.0 \
  --restart=Never \
  --rm -i -n "${NAMESPACE}" \
  --env="AWS_ACCESS_KEY_ID=minioadmin" \
  --env="AWS_SECRET_ACCESS_KEY=minioadmin" \
  -- /opt/spark/bin/spark-submit \
  --master local[2] \
  --conf spark.eventLog.enabled=true \
  --conf spark.eventLog.dir=s3a://spark-logs/events \
  --conf spark.hadoop.fs.s3a.endpoint=http://minio:9000 \
  --class org.apache.spark.examples.SparkPi \
  local:///opt/spark/examples/jars/spark-examples.jar 100

echo "✓ Spark 4.1.0 job complete"

echo "4) Querying History Server 4.1.0 API..."
kubectl port-forward "svc/${RELEASE}-spark-41-history" 18080:18080 -n "${NAMESPACE}" >/dev/null 2>&1 &
PF_PID=$!
sleep 5

echo "   Waiting for log parsing (30s)..."
sleep 30

APPS=$(curl -s http://localhost:18080/api/v1/applications || echo "[]")
APP_COUNT=$(echo "$APPS" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")

echo "   History Server shows $APP_COUNT application(s)"
echo "   Applications: $APPS"

kill "${PF_PID}" 2>/dev/null || true
wait "${PF_PID}" 2>/dev/null || true

echo "5) Documenting result..."

if [[ "${APP_COUNT}" -ge 2 ]]; then
  RESULT="✓ BACKWARD COMPATIBLE: History Server 4.1.0 can read Spark 3.5.7 logs"
  RECOMMENDATION="Shared History Server 4.1.0 is supported"
else
  RESULT="✗ NOT BACKWARD COMPATIBLE: History Server 4.1.0 cannot read Spark 3.5.7 logs"
  RECOMMENDATION="Use separate History Servers (default)"
fi

cat > "${REPORT_PATH}" <<EOF
# History Server Backward Compatibility Report

**Test Date:** $(date)
**History Server Version:** 4.1.0
**Spark Versions Tested:** 3.5.7, 4.1.0

## Result

$RESULT

## Recommendation

$RECOMMENDATION

## Details

- Applications found: $APP_COUNT
- API response: \`$APPS\`
EOF

echo "${RESULT}"
echo "${RECOMMENDATION}"

echo "=== Test complete ==="
