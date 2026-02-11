#!/bin/bash
# diagnose-driver-crash.sh - Diagnose Spark driver crash loop
#
# Usage: diagnose-driver-crash.sh <namespace> <driver-pod>
#
# This script is idempotent and safe to re-run.

set -euo pipefail

NAMESPACE="${1:?Usage: diagnose-driver-crash.sh <namespace> <driver-pod>}"
DRIVER_POD="${2:?Usage: diagnose-driver-crash.sh <driver-pod>}"

echo "=== Spark Driver Crash Loop Diagnosis ==="
echo "Namespace: $NAMESPACE"
echo "Driver Pod: $DRIVER_POD"
echo ""

# Check if pod exists
if ! kubectl get pod "$DRIVER_POD" -n "$NAMESPACE" &>/dev/null; then
    echo "ERROR: Pod $DRIVER_POD not found in namespace $NAMESPACE"
    exit 1
fi

# Function to print section header
print_section() {
    echo ""
    echo "=== $1 ==="
}

# 1. Pod Status
print_section "1. Pod Status"
kubectl get pod "$DRIVER_POD" -n "$NAMESPACE" -o json | jq -r '
    {
        name: .metadata.name,
        phase: .status.phase,
        restartCount: .status.containerStatuses[0].restartCount,
        lastState: .status.containerStatuses[0].lastState,
        state: .status.containerStatuses[0].state
    }'

# 2. Pod Events
print_section "2. Recent Events"
kubectl get events -n "$NAMESPACE" --field-selector involvedObject.name="$DRIVER_POD" --sort-by='.lastTimestamp' | tail -20

# 3. Previous Container Logs (if crashed)
print_section "3. Previous Container Logs (Last 500 lines)"
if kubectl logs "$DRIVER_POD" -n "$NAMESPACE" --previous &>/dev/null; then
    kubectl logs "$DRIVER_POD" -n "$NAMESPACE" --previous --tail=500 || true
else
    echo "No previous container logs available"
fi

# 4. Current Container Logs (if running)
print_section "4. Current Container Logs (Last 500 lines)"
kubectl logs "$DRIVER_POD" -n "$NAMESPACE" --tail=500 || true

# 5. Search for Error Patterns
print_section "5. Error Pattern Analysis"
echo "Checking for OOM errors..."
kubectl logs "$DRIVER_POD" -n "$NAMESPACE" --previous --tail=500 2>/dev/null | grep -i "out of memory\|oom" || echo "None found"

echo ""
echo "Checking for classpath errors..."
kubectl logs "$DRIVER_POD" -n "$NAMESPACE" --previous --tail=500 2>/dev/null | grep -i "classnotfound\|noclassdeffound" || echo "None found"

echo ""
echo "Checking for configuration errors..."
kubectl logs "$DRIVER_POD" -n "$NAMESPACE" --previous --tail=500 2>/dev/null | grep -i "illegalargument\|configuration" || echo "None found"

echo ""
echo "Checking for container kill signals..."
kubectl logs "$DRIVER_POD" -n "$NAMESPACE" --previous --tail=500 2>/dev/null | grep -i "killed\|exit\|terminated" || echo "None found"

# 6. Resource Configuration
print_section "6. Resource Configuration"
kubectl get pod "$DRIVER_POD" -n "$NAMESPACE" -o json | jq -r '
    .spec.containers[] | select(.name == "spark-kubernetes-driver") | {
        name: .name,
        resources: .resources
    }'

# 7. Node Status
print_section "7. Node Status"
NODE_NAME=$(kubectl get pod "$DRIVER_POD" -n "$NAMESPACE" -o jsonpath='{.spec.nodeName}')
echo "Node: $NODE_NAME"
kubectl describe node "$NODE_NAME" | grep -A 5 "Conditions:" || true

# 8. Exit Code Analysis
print_section "8. Exit Code Analysis"
EXIT_CODE=$(kubectl get pod "$DRIVER_POD" -n "$NAMESPACE" -o jsonpath='{.status.containerStatuses[0].lastState.terminated.exitCode}')
echo "Exit Code: $EXIT_CODE"
echo ""
echo "Common exit codes:"
echo "  1   - General error"
echo "  137 - OOM Killed"
echo "  125 - Container error"
echo "  126 - Command not executable"
echo "  127 - Command not found"
echo "  1   - Application error"

# 9. Root Cause Summary
print_section "9. Root Cause Summary"

# Detect OOM
if kubectl get pod "$DRIVER_POD" -n "$NAMESPACE" -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}' 2>/dev/null | grep -qi "oom"; then
    echo "ROOT CAUSE: Out of Memory (OOM)"
    echo "RECOMMENDATION: Increase driver.memory and driver.memoryOverhead"
elif kubectl logs "$DRIVER_POD" -n "$NAMESPACE" --previous 2>/dev/null | grep -qi "out of memory"; then
    echo "ROOT CAUSE: Java Out of Memory Error"
    echo "RECOMMENDATION: Increase driver.memory or tune spark.memory settings"
elif kubectl logs "$DRIVER_POD" -n "$NAMESPACE" --previous 2>/dev/null | grep -qi "classnotfound\|noclassdeffound"; then
    echo "ROOT CAUSE: Classpath/Missing Dependency Issue"
    echo "RECOMMENDATION: Add missing dependencies to application JAR or classpath"
elif kubectl logs "$DRIVER_POD" -n "$NAMESPACE" --previous 2>/dev/null | grep -qi "illegalargument\|illegalstate\|configuration"; then
    echo "ROOT CAUSE: Configuration Error"
    echo "RECOMMENDATION: Review and fix application configuration"
elif kubectl get events -n "$NAMESPACE" --field-selector involvedObject.name="$DRIVER_POD" | grep -qi "failedscheduling\|insufficient"; then
    echo "ROOT CAUSE: Resource Scheduling Issue"
    echo "RECOMMENDATION: Check cluster resources and quotas"
else
    echo "ROOT CAUSE: Unable to determine from logs"
    echo "RECOMMENDATION: Review full logs and events manually"
fi

print_section "10. Next Steps"
echo "1. Review the error pattern analysis above"
echo "2. Apply remediation based on root cause"
echo "3. Delete the pod to restart with new configuration:"
echo "   kubectl delete pod $DRIVER_POD -n $NAMESPACE"
echo ""
echo "Or recover automatically:"
echo "   scripts/operations/spark/recover-driver-crash.sh $NAMESPACE $DRIVER_POD"
