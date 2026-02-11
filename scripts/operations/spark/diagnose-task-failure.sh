#!/bin/bash
# diagnose-task-failure.sh - Diagnose Spark task failures
#
# Usage: diagnose-task-failure.sh <namespace> <app-name>
#
# This script is idempotent and safe to re-run.

set -euo pipefail

NAMESPACE="${1:?Usage: diagnose-task-failure.sh <namespace> <app-name>}"
APP_NAME="${2:?Usage: diagnose-task-failure.sh <app-name>}"

echo "=== Spark Task Failure Diagnosis ==="
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

# Check if Spark UI is accessible
print_section "Checking Spark UI Availability"
if ! kubectl exec -n "$NAMESPACE" "$DRIVER_POD" -- curl -s http://localhost:4040/api/v1 &>/dev/null; then
    echo "WARNING: Spark UI not accessible"
    echo "Checking logs for task failure information instead..."

    # Check driver logs for task failures
    print_section "Task Failures in Driver Logs"
    kubectl logs "$DRIVER_POD" -n "$NAMESPACE" --tail=1000 | grep -i "task.*fail\|failed.*task" | head -20

    print_section "Common Error Patterns"
    echo "Network errors:"
    kubectl logs "$DRIVER_POD" -n "$NAMESPACE" --tail=1000 | grep -i "connection.*refused\|unknownhost\|network" | head -10 || echo "None found"

    echo ""
    echo "Serialization errors:"
    kubectl logs "$DRIVER_POD" -n "$NAMESPACE" --tail=1000 | grep -i "notserializable\|classnotfound" | head -10 || echo "None found"

    exit 0
fi

# 1. Get application info
print_section "1. Application Information"
APP_ID=$(kubectl exec -n "$NAMESPACE" "$DRIVER_POD" -- curl -s http://localhost:4040/api/v1/applications | jq -r '.[0].id' 2>/dev/null || echo "")
if [[ -z "$APP_ID" ]]; then
    echo "No application found in Spark UI"
    exit 1
fi
echo "Application ID: $APP_ID"

# 2. Check job status
print_section "2. Job Status"
kubectl exec -n "$NAMESPACE" "$DRIVER_POD" -- curl -s "http://localhost:4040/api/v1/applications/$APP_ID/jobs" | jq -r '
    [
        .[] | {
            jobId: .jobId,
            name: .name,
            status: .status,
            numTasks: .numTasks,
            numCompletedTasks: .numCompletedTasks,
            numFailedTasks: .numFailedTasks
        } | select(.numFailedTasks > 0 or .status == "RUNNING")
    ]' 2>/dev/null || echo "Unable to fetch job information"

# 3. Check stage status
print_section "3. Stage Status (Failed Tasks)"
kubectl exec -n "$NAMESPACE" "$DRIVER_POD" -- curl -s "http://localhost:4040/api/v1/applications/$APP_ID/stages" | jq -r '
    [
        .[] | {
            stageId: .stageId,
            name: .name,
            status: .status,
            numTasks: .numTasks,
            numActiveTasks: .numActiveTasks,
            numFailedTasks: .numFailedTasks
        } | select(.numFailedTasks > 0 or .status == "ACTIVE")
    ]' 2>/dev/null || echo "Unable to fetch stage information"

# 4. Get failed stage details
print_section "4. Failed Stage Analysis"
FAILED_STAGE=$(kubectl exec -n "$NAMESPACE" "$DRIVER_POD" -- curl -s "http://localhost:4040/api/v1/applications/$APP_ID/stages" | jq -r '[.[] | select(.numFailedTasks > 0)] | max_by(.numFailedTasks) | .stageId' 2>/dev/null || echo "")

if [[ -n "$FAILED_STAGE" && "$FAILED_STAGE" != "null" ]]; then
    echo "Failed Stage ID: $FAILED_STAGE"

    # Get tasks for failed stage
    ATTEMPT=0
    echo ""
    echo "Failed tasks in stage $FAILED_STAGE:"
    kubectl exec -n "$NAMESPACE" "$DRIVER_POD" -- curl -s "http://localhost:4040/api/v1/applications/$APP_ID/stages/$FAILED_STAGE/$ATTEMPT/taskList" | jq -r '
        [
            .[] | select(.failed == true) | {
                taskId: .taskId,
                attempt: .attempt,
                index: .index,
                duration: .duration,
                errorMessage: .errorMessage
            }
        ] | .[0:5]' 2>/dev/null || echo "Unable to fetch task details"
fi

# 5. Error pattern analysis from logs
print_section "5. Error Pattern Analysis"

# Get executor pods for log analysis
EXECUTOR_PODS=$(kubectl get pods -n "$NAMESPACE" -l spark-app-name="$APP_NAME",spark-role=executor -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || "")
SAMPLE_EXECUTOR=$(echo "$EXECUTOR_PODS" | awk '{print $1}')

if [[ -n "$SAMPLE_EXECUTOR" ]]; then
    echo "Checking executor $SAMPLE_EXECUTOR for errors..."

    echo ""
    echo "Network errors:"
    kubectl logs "$SAMPLE_EXECUTOR" -n "$NAMESPACE" --tail=500 2>/dev/null | grep -i "connection.*refused\|unknownhost\|network.*timeout" | head -5 || echo "None found"

    echo ""
    echo "Shuffle fetch errors:"
    kubectl logs "$SAMPLE_EXECUTOR" -n "$NAMESPACE" --tail=500 2>/dev/null | grep -i "fetchfailed\|shuffle.*fail" | head -5 || echo "None found"

    echo ""
    echo "Serialization errors:"
    kubectl logs "$SAMPLE_EXECUTOR" -n "$NAMESPACE" --tail=500 2>/dev/null | grep -i "notserializable\|classnotfound" | head -5 || echo "None found"

    echo ""
    echo "OOM indicators:"
    kubectl logs "$SAMPLE_EXECUTOR" -n "$NAMESPACE" --tail=500 2>/dev/null | grep -i "out of memory\|oom" | head -5 || echo "None found"
fi

# 6. Root cause analysis
print_section "6. Root Cause Analysis"

# Check for specific error patterns
TASK_FAILURE_COUNT=$(kubectl exec -n "$NAMESPACE" "$DRIVER_POD" -- curl -s "http://localhost:4040/api/v1/applications/$APP_ID/stages" | jq '[.[] | .numFailedTasks] | add // 0' 2>/dev/null || echo "0")

if [[ "$TASK_FAILURE_COUNT" -gt 100 ]]; then
    echo "HIGH FAILURE RATE: $TASK_FAILURE_COUNT failed tasks"
    echo ""
    echo "Likely causes:"
    echo "- Data skew: Some partitions much larger than others"
    echo "- Resource exhaustion: Executors running out of memory/CPU"
    echo "- Network issues: Shuffle failures across executors"
elif [[ "$TASK_FAILURE_COUNT" -gt 0 ]]; then
    echo "MODERATE FAILURE RATE: $TASK_FAILURE_COUNT failed tasks"
    echo ""
    echo "Likely causes:"
    echo "- Transient errors: Network timeouts, temporary resource issues"
    echo "- Data issues: Bad records in specific partitions"
    echo "- External service issues: Database/S3 connectivity"
else
    echo "No task failures detected in completed stages"
    echo "Check running stages for active issues"
fi

# 7. Recommendations
print_section "7. Recommendations"

if [[ "$TASK_FAILURE_COUNT" -gt 0 ]]; then
    echo ""
    echo "General remediation options:"
    echo ""
    echo "1. Increase retry attempts:"
    cat <<'EOF'
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '{
  "spec": {
    "sparkConf": {
      "spark.task.maxFailures": "8",
      "spark.stage.maxConsecutiveAttempts": "4"
    }
  }
}'
EOF
    echo ""
    echo "2. Enable speculation for straggler tasks:"
    cat <<'EOF'
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '{
  "spec": {
    "sparkConf": {
      "spark.speculation": "true",
      "spark.speculation.quantile": "0.9",
      "spark.speculation.multiplier": "2"
    }
  }
}'
EOF
    echo ""
    echo "3. For shuffle issues, see Shuffle Failure runbook"
    echo "4. For OOM issues, see OOM Kill Mitigation runbook"
    echo "5. For executor issues, see Executor Failures runbook"
fi

print_section "8. Next Steps"
echo ""
echo "1. Review the error patterns above"
echo "2. Apply appropriate remediation"
echo "3. Monitor Spark UI for improvement:"
echo "   kubectl port-forward $DRIVER_POD 4040:4040 -n $NAMESPACE"
echo ""
echo "Or recover automatically:"
echo "   scripts/operations/spark/recover-task-failure.sh $NAMESPACE $APP_NAME"
