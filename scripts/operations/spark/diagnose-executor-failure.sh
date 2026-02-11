#!/bin/bash
# diagnose-executor-failure.sh - Diagnose Spark executor failures
#
# Usage: diagnose-executor-failure.sh <namespace> <app-name>
#
# This script is idempotent and safe to re-run.

set -euo pipefail

NAMESPACE="${1:?Usage: diagnose-executor-failure.sh <namespace> <app-name>}"
APP_NAME="${2:?Usage: diagnose-executor-failure.sh <app-name>}"

echo "=== Spark Executor Failure Diagnosis ==="
echo "Namespace: $NAMESPACE"
echo "Application: $APP_NAME"
echo ""

# Function to print section header
print_section() {
    echo ""
    echo "=== $1 ==="
}

# Get driver pod
print_section "Finding Driver Pod"
DRIVER_POD=$(kubectl get pods -n "$NAMESPACE" -l spark-app-name="$APP_NAME",spark-role=driver -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [[ -z "$DRIVER_POD" ]]; then
    echo "ERROR: Driver pod not found for application $APP_NAME"
    exit 1
fi
echo "Driver Pod: $DRIVER_POD"

# 1. Executor Pod Status
print_section "1. Executor Pod Status"
kubectl get pods -n "$NAMESPACE" -l spark-app-name="$APP_NAME",spark-role=executor

# 2. Count Failed Executors
print_section "2. Failed Executor Count"
FAILED_COUNT=$(kubectl get pods -n "$NAMESPACE" -l spark-app-name="$APP_NAME",spark-role=executor -o json | jq -r '[.items[] | select(.status.phase=="Failed")] | length')
TERMINATED_COUNT=$(kubectl get pods -n "$NAMESPACE" -l spark-app-name="$APP_NAME",spark-role=executor -o json | jq -r '[.items[] | select(.status.containerStatuses!=null and .status.containerStatuses[0].lastState.terminated!=null)] | length')
echo "Failed executors: $FAILED_COUNT"
echo "Terminated executors: $TERMINATED_COUNT"

# 3. Recent Events
print_section "3. Recent Executor Events"
kubectl get events -n "$NAMESPACE" --field-selector involvedObject.name~"$APP_NAME.*executor" --sort-by='.lastTimestamp' | tail -30

# 4. Get a sample failed executor pod
print_section "4. Failed Executor Analysis"
FAILED_POD=$(kubectl get pods -n "$NAMESPACE" -l spark-app-name="$APP_NAME",spark-role=executor -o json | jq -r '.items[] | select(.status.phase=="Failed") | .metadata.name' | head -1)
if [[ -n "$FAILED_POD" ]]; then
    echo "Sample failed pod: $FAILED_POD"

    echo ""
    echo "Pod details:"
    kubectl describe pod "$FAILED_POD" -n "$NAMESPACE" | grep -A 10 "State:" || true

    echo ""
    echo "Logs:"
    kubectl logs "$FAILED_POD" -n "$NAMESPACE" --tail=100 || true

    # Check termination reason
    TERMINATION_REASON=$(kubectl get pod "$FAILED_POD" -n "$NAMESPACE" -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}')
    EXIT_CODE=$(kubectl get pod "$FAILED_POD" -n "$NAMESPACE" -o jsonpath='{.status.containerStatuses[0].lastState.terminated.exitCode}')
    echo ""
    echo "Termination Reason: $TERMINATION_REASON"
    echo "Exit Code: $EXIT_CODE"
else
    echo "No failed executor pods found (checking for terminated pods instead)"

    TERMINATED_POD=$(kubectl get pods -n "$NAMESPACE" -l spark-app-name="$APP_NAME",spark-role=executor -o json | jq -r '.items[] | select(.status.containerStatuses!=null and .status.containerStatuses[0].lastState.terminated!=null) | .metadata.name' | head -1)
    if [[ -n "$TERMINATED_POD" ]]; then
        echo "Sample terminated pod: $TERMINATED_POD"
        kubectl logs "$TERMINATED_POD" -n "$NAMESPACE" --tail=100 || true
    fi
fi

# 5. Check Spark UI for executor stats
print_section "5. Spark UI Executor Stats"
if kubectl exec -n "$NAMESPACE" "$DRIVER_POD" -- curl -s http://localhost:4040/api/v1/applications/*/executors &>/dev/null; then
    kubectl exec -n "$NAMESPACE" "$DRIVER_POD" -- curl -s http://localhost:4040/api/v1/applications/*/executors | jq -r '
        [
            .[] | {
                id: .id,
                activeTasks: .activeTasks,
                failedTasks: .failedTasks,
                completedTasks: .completedTasks,
                totalDuration: .totalDuration
            }
        ] | group_by(.failedTasks > 0) | map({
                status: (if .[0].failedTasks > 0 then "has_failures" else "healthy" end),
                count: length,
                failed_tasks: map(.failedTasks) | add
            })'
fi

# 6. Error Pattern Analysis
print_section "6. Error Pattern Analysis"
echo "Checking for common error patterns..."

# Get a current or recent executor pod for log analysis
SAMPLE_POD=$(kubectl get pods -n "$NAMESPACE" -l spark-app-name="$APP_NAME",spark-role=executor -o json | jq -r '.items[0].metadata.name')
if [[ -n "$SAMPLE_POD" ]]; then
    echo ""
    echo "Checking pod: $SAMPLE_POD"

    echo "OOM indicators:"
    kubectl logs "$SAMPLE_POD" -n "$NAMESPACE" --previous 2>/dev/null | grep -i "oom\|out of memory" || echo "None found in previous logs"

    echo ""
    echo "Heartbeat/lost executor indicators:"
    kubectl logs "$SAMPLE_POD" -n "$NAMESPACE" --previous 2>/dev/null | grep -i "heartbeat\|lost.*executor\|disassociated" || echo "None found in previous logs"

    echo ""
    echo "Connection/shuffle errors:"
    kubectl logs "$SAMPLE_POD" -n "$NAMESPACE" --previous 2>/dev/null | grep -i "connection.*refused\|fetch.*fail\|shuffle" || echo "None found in previous logs"
fi

# 7. Node Health Check
print_section "7. Node Health Check"
NODES_WITH_EXECUTORS=$(kubectl get pods -n "$NAMESPACE" -l spark-app-name="$APP_NAME",spark-role=executor -o jsonpath='{.items[*].spec.nodeName}' | tr ' ' '\n' | sort -u)
for NODE in $NODES_WITH_EXECUTORS; do
    echo "Node: $NODE"
    kubectl describe node "$NODE" | grep -E "Conditions:|MemoryPressure|DiskPressure|PIDPressure|NetworkUnavailable" || true
    echo ""
done

# 8. Root Cause Summary
print_section "8. Root Cause Summary"

if [[ "$TERMINATION_REASON" == "OOMKilled" ]] || kubectl logs "$SAMPLE_POD" -n "$NAMESPACE" --previous 2>/dev/null | grep -qi "oom"; then
    echo "ROOT CAUSE: Out of Memory (OOM)"
    echo "RECOMMENDATION: Increase executor.memory and executor.memoryOverhead"
    echo "Or reduce executor.cores to have more smaller executors"
elif kubectl logs "$SAMPLE_POD" -n "$NAMESPACE" --previous 2>/dev/null | grep -qi "heartbeat\|lost.*executor"; then
    echo "ROOT CAUSE: Executor Lost (Network/Node Issue)"
    echo "RECOMMENDATION: Check network connectivity and node health"
    echo "Consider increasing heartbeat timeout: spark.executor.heartbeatInterval"
elif kubectl logs "$SAMPLE_POD" -n "$NAMESPACE" --previous 2>/dev/null | grep -qi "fetch.*fail\|shuffle"; then
    echo "ROOT CAUSE: Shuffle Fetch Failure"
    echo "RECOMMENDATION: See Shuffle Failure runbook"
    echo "Consider enabling Celeborn shuffle service"
elif [[ "$EXIT_CODE" == "137" ]]; then
    echo "ROOT CAUSE: Container Killed (Exit 137 = OOM)"
    echo "RECOMMENDATION: Increase executor memory limits"
else
    echo "ROOT CAUSE: Unable to determine from available logs"
    echo "RECOMMENDATION: Review full executor logs manually"
fi

print_section "9. Next Steps"
echo "1. Review the error pattern analysis above"
echo "2. Apply remediation based on root cause"
echo "3. Delete failed executor pods to trigger recreation:"
echo "   kubectl delete pod -l spark-role=executor -n $NAMESPACE -l spark-app-name=$APP_NAME"
echo ""
echo "Or recover automatically:"
echo "   scripts/operations/spark/recover-executor-failures.sh $NAMESPACE $APP_NAME"
