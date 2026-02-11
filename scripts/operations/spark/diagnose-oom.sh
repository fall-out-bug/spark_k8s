#!/bin/bash
# diagnose-oom.sh - Diagnose Spark pod OOM kills
#
# Usage: diagnose-oom.sh <namespace> <pod-name>
#
# This script is idempotent and safe to re-run.

set -euo pipefail

NAMESPACE="${1:?Usage: diagnose-oom.sh <namespace> <pod-name>}"
POD_NAME="${2:?Usage: diagnose-oom.sh <pod-name>}"

echo "=== Spark OOM Diagnosis ==="
echo "Namespace: $NAMESPACE"
echo "Pod: $POD_NAME"
echo ""

# Check if pod exists
if ! kubectl get pod "$POD_NAME" -n "$NAMESPACE" &>/dev/null; then
    echo "ERROR: Pod $POD_NAME not found in namespace $NAMESPACE"
    exit 1
fi

# Function to print section header
print_section() {
    echo ""
    echo "=== $1 ==="
}

# 1. Check for OOM kill
print_section "1. OOM Kill Detection"
OOM_REASON=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}' 2>/dev/null || echo "")
TERMINATION_REASON=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.status.containerStatuses[0].state.terminated.reason}' 2>/dev/null || echo "")

echo "Last State Reason: $OOM_REASON"
echo "Current State Reason: $TERMINATION_REASON"

if [[ "$OOM_REASON" == "OOMKilled" ]] || [[ "$TERMINATION_REASON" == "OOMKilled" ]]; then
    echo "CONFIRMED: Pod was OOMKilled"
    CONFIRMED_OOM=true
else
    echo "Checking for OOM in logs..."
    if kubectl logs "$POD_NAME" -n "$NAMESPACE" --previous 2>/dev/null | grep -qi "out of memory\|oom"; then
        echo "CONFIRMED: Java OOM detected in logs"
        CONFIRMED_OOM=true
    else
        echo "No OOM indicators found (pod may have other issues)"
        CONFIRMED_OOM=false
    fi
fi

# 2. Memory Configuration
print_section "2. Memory Configuration"
echo "Container resource limits:"
kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o json | jq -r '
    .spec.containers[] | select(.name == "spark-kubernetes-driver" or .name == "executor") | {
        name: .name,
        memoryRequest: .resources.requests.memory,
        memoryLimit: .resources.limits.memory
    }'

# 3. Memory Usage Analysis
print_section "3. Memory Usage Analysis"
NODE_NAME=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.nodeName}')
echo "Node: $NODE_NAME"

# Check node memory pressure
kubectl describe node "$NODE_NAME" | grep -A 5 "MemoryPressure" || true

# 4. Log Analysis for Memory Patterns
print_section "4. Log Analysis"
echo "Checking for memory patterns in logs..."
echo ""
echo "Java heap errors:"
kubectl logs "$POD_NAME" -n "$NAMESPACE" --previous 2>/dev/null | grep -i "heap\|OutOfMemoryError" || echo "None found"

echo ""
echo "Memory GC patterns:"
kubectl logs "$POD_NAME" -n "$NAMESPACE" --previous 2>/dev/null | grep -i "gc\|garbage" | tail -20 || echo "None found"

echo ""
echo "Memory-related Spark config:"
kubectl logs "$POD_NAME" -n "$NAMESPACE" --previous 2>/dev/null | grep -E "spark.memory|spark.executor.memory|spark.driver.memory" | head -10 || echo "None found in logs"

# 5. Component Type
print_section "5. Component Identification"
POD_ROLE=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.metadata.labels.spark-role}' 2>/dev/null || echo "unknown")
echo "Pod Role: $POD_ROLE"

if [[ "$POD_ROLE" == "driver" ]]; then
    echo "This is a DRIVER pod"
    COMPONENT="driver"
elif [[ "$POD_ROLE" == "executor" ]]; then
    echo "This is an EXECUTOR pod"
    COMPONENT="executor"
else
    echo "Cannot determine role"
    COMPONENT="unknown"
fi

# 6. Get application name
APP_NAME=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.metadata.labels.spark-app-name}' 2>/dev/null || echo "")
echo "Application: $APP_NAME"

# 7. Recommendations
print_section "6. Recommendations"

if [[ "$CONFIRMED_OOM" == "true" ]]; then
    echo ""
    echo "OOM Detected - Remediation Options:"
    echo ""

    if [[ "$COMPONENT" == "driver" ]]; then
        echo "For Driver OOM:"
        cat <<'EOF'
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '{
  "spec": {
    "driver": {
      "memory": "4g",
      "memoryOverhead": "1g"
    },
    "sparkConf": {
      "spark.driver.memory": "4g",
      "spark.driver.memoryOverhead": "1g",
      "spark.memory.offHeap.enabled": "true",
      "spark.memory.offHeap.size": "512m",
      "spark.memory.fraction": "0.5"
    }
  }
}'
EOF
    elif [[ "$COMPONENT" == "executor" ]]; then
        echo "For Executor OOM:"
        cat <<'EOF'
Option 1: Increase memory per executor
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '{
  "spec": {
    "executor": {
      "memory": "6g",
      "memoryOverhead": "2g"
    }
  }
}'

Option 2: Use more, smaller executors
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '{
  "spec": {
    "executor": {
      "cores": 1,
      "memory": "3g",
      "memoryOverhead": "1g",
      "instances": 10
    }
  }
}'
EOF
    fi

    echo ""
    echo "Common OOM scenarios:"
    echo ""
    echo "- Broadcast joins: Disable with spark.sql.autoBroadcastJoinThreshold=-1"
    echo "- Large collect(): Increase spark.driver.maxResultSize"
    echo "- Cached data: Reduce spark.memory.storageFraction"
    echo "- Data skew: Enable AQE with spark.sql.adaptive.skewJoin.enabled=true"
fi

print_section "7. Quick Commands"
echo ""
echo "View detailed logs:"
echo "  kubectl logs $POD_NAME -n $NAMESPACE --previous | less"
echo ""
echo "Check SparkApplication config:"
echo "  kubectl get sparkapplication $APP_NAME -n $NAMESPACE -o yaml | grep -i memory"
echo ""
echo "Recover automatically:"
echo "  scripts/operations/spark/recover-oom.sh $NAMESPACE $POD_NAME"
