#!/bin/bash
# diagnose-connect-issue.sh - Diagnose Spark Connect server issues
#
# Usage: diagnose-connect-issue.sh <namespace> <service-name>
#
# This script is idempotent and safe to re-run.

set -euo pipefail

NAMESPACE="${1:?Usage: diagnose-connect-issue.sh <namespace> <service-name>}"
SERVICE_NAME="${2:?Usage: diagnose-connect-issue.sh <service-name>}"

echo "=== Spark Connect Issue Diagnosis ==="
echo "Namespace: $NAMESPACE"
echo "Service: $SERVICE_NAME"
echo ""

# Function to print section header
print_section() {
    echo ""
    echo "=== $1 ==="
}

# Check if service exists
print_section "1. Service Status"
if ! kubectl get svc "$SERVICE_NAME" -n "$NAMESPACE" &>/dev/null; then
    echo "ERROR: Service $SERVICE_NAME not found in namespace $NAMESPACE"
    echo ""
    echo "Looking for Spark Connect services..."
    kubectl get svc -n "$NAMESPACE" -l app=spark-connect
    exit 1
fi

kubectl get svc "$SERVICE_NAME" -n "$NAMESPACE"

# 2. Get Spark Connect pods
print_section "2. Spark Connect Pods"
CONNECT_PODS=$(kubectl get pods -n "$NAMESPACE" -l app=spark-connect -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || "")
if [[ -z "$CONNECT_PODS" ]]; then
    echo "WARNING: No Spark Connect pods found"
    echo "Checking for SparkApplications with Connect enabled..."

    # Look for driver pods that might be running Connect server
    DRIVER_PODS=$(kubectl get pods -n "$NAMESPACE" -l spark-role=driver -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || "")
    if [[ -n "$DRIVER_PODS" ]]; then
        echo "Found driver pods - checking for Connect server..."
        CONNECT_PODS=$DRIVER_PODS
    else
        exit 1
    fi
fi

for POD in $CONNECT_PODS; do
    echo ""
    echo "Pod: $POD"
    kubectl get pod "$POD" -n "$NAMESPACE"
done

# 3. Check pod status and events
print_section "3. Pod Status and Events"
for POD in $CONNECT_PODS; do
    echo ""
    echo "Events for $POD:"
    kubectl describe pod "$POD" -n "$NAMESPACE" | grep -A 20 "Events:" || true
done

# 4. Check logs for errors
print_section "4. Error Analysis in Logs"
for POD in $CONNECT_PODS; do
    echo ""
    echo "Checking $POD for errors..."
    echo ""
    echo "Server errors:"
    kubectl logs "$POD" -n "$NAMESPACE" --tail=500 | grep -i "error\|exception" | head -20 || echo "None found"

    echo ""
    echo "Connection errors:"
    kubectl logs "$POD" -n "$NAMESPACE" --tail=500 | grep -i "connection.*refused\|connection.*reset" | head -10 || echo "None found"

    echo ""
    echo "Session errors:"
    kubectl logs "$POD" -n "$NAMESPACE" --tail=500 | grep -i "session.*fail\|session.*error" | head -10 || echo "None found"
done

# 5. Test connectivity
print_section "5. Connectivity Test"
echo "Testing connection to $SERVICE_NAME on port 15002..."

# Test from within cluster (create a test pod)
TEST_POD="spark-connect-test-$(date +%s)"
kubectl run "$TEST_POD" -n "$NAMESPACE" --image=curlimages/curl --rm -i --restart=Never -- \
    curl -v "http://${SERVICE_NAME}.${NAMESPACE}.svc:15002" 2>&1 | head -30 || echo "Connection test failed"

# 6. Check resource usage
print_section "6. Resource Usage"
for POD in $CONNECT_PODS; do
    echo ""
    echo "Resource usage for $POD:"
    kubectl top pod "$POD" -n "$NAMESPACE" 2>/dev/null || echo "Metrics server not available"

    # Check resource limits
    kubectl get pod "$POD" -n "$NAMESPACE" -o jsonpath='{.spec.containers[0].resources}'
    echo ""
done

# 7. Check session status (if accessible)
print_section "7. Session Status"
for POD in $CONNECT_PODS; do
    echo ""
    echo "Checking sessions for $POD..."
    if kubectl exec -n "$NAMESPACE" "$POD" -- curl -s http://localhost:15002/api/v1/sessions &>/dev/null; then
        SESSION_COUNT=$(kubectl exec -n "$NAMESPACE" "$POD" -- curl -s http://localhost:15002/api/v1/sessions | jq 'length' 2>/dev/null || echo "0")
        echo "Active sessions: $SESSION_COUNT"
    else
        echo "Session endpoint not accessible"
    fi
done

# 8. Root cause analysis
print_section "8. Root Cause Analysis"

# Check for common issues
ISSUE_FOUND=false

for POD in $CONNECT_PODS; do
    POD_PHASE=$(kubectl get pod "$POD" -n "$NAMESPACE" -o jsonpath='{.status.phase}')

    if [[ "$POD_PHASE" != "Running" ]]; then
        echo ""
        echo "ISSUE: Pod $POD is not running (status: $POD_PHASE)"
        ISSUE_FOUND=true
    fi

    # Check for OOM
    OOM_REASON=$(kubectl get pod "$POD" -n "$NAMESPACE" -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}')
    if [[ "$OOM_REASON" == "OOMKilled" ]]; then
        echo ""
        echo "ISSUE: Pod $POD was OOMKilled - increase memory limits"
        ISSUE_FOUND=true
    fi

    # Check for crash loop
    RESTART_COUNT=$(kubectl get pod "$POD" -n "$NAMESPACE" -o jsonpath='{.status.containerStatuses[0].restartCount}')
    if [[ "$RESTART_COUNT" -gt 3 ]]; then
        echo ""
        echo "ISSUE: Pod $POD has restarted $RESTART_COUNT times - check logs for errors"
        ISSUE_FOUND=true
    fi
done

if [[ "$ISSUE_FOUND" == "false" ]]; then
    echo ""
    echo "No obvious issues found in pod status"
    echo ""
    echo "Checking for client-side issues..."
    echo ""
    echo "Common client-side problems:"
    echo "- Version mismatch (client and server must match minor version)"
    echo "- Network connectivity from client to cluster"
    echo "- Authentication token missing or invalid"
    echo "- Firewall blocking port 15002"
fi

# 9. Recommendations
print_section "9. Recommendations"

echo ""
echo "Common fixes for Spark Connect issues:"
echo ""
echo "1. For connection refused:"
cat <<'EOF'
   - Check service is running: kubectl get pods -l app=spark-connect -n <namespace>
   - Check service endpoint: kubectl get endpoints spark-connect -n <namespace>
   - Test from pod: kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- curl http://spark-connect.<namespace>.svc:15002
EOF

echo ""
echo "2. For session creation failures:"
cat <<'EOF'
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '{
  "spec": {
    "sparkConf": {
      "spark.connect.server.sessionManager.timeout": "30d",
      "spark.connect.server.sessionManager.maxSessions": "1000"
    }
  }
}'
EOF

echo ""
echo "3. For high latency:"
cat <<'EOF'
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '{
  "spec": {
    "driver": {
      "cores": 4,
      "memory": "8g"
    },
    "sparkConf": {
      "spark.connect.result.arrow.maxRecordsPerBatch": "10000"
    }
  }
}'
EOF

print_section "10. Next Steps"
echo ""
echo "1. Review the analysis above"
echo "2. Apply appropriate remediation"
echo "3. Test connection from client:"
echo "   python -c 'from pyspark.sql import SparkSession; spark = SparkSession.builder.remote(\"sc://<host>:15002\").getOrCreate(); print(spark.version)'"
echo ""
echo "Or recover automatically:"
echo "   scripts/operations/spark/recover-connect.sh $NAMESPACE $SERVICE_NAME"
