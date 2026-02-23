#!/bin/bash
# diagnose-stuck-job.sh - Diagnose stuck/progressing Spark jobs
#
# Usage: diagnose-stuck-job.sh <namespace> <app-name>
#
# This script is idempotent and safe to re-run.

set -euo pipefail

NAMESPACE="${1:?Usage: diagnose-stuck-job.sh <namespace> <app-name>}"
APP_NAME="${2:?Usage: diagnose-stuck-job.sh <app-name>}"

echo "=== Spark Stuck Job Diagnosis ==="
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
    echo "WARNING: Spark UI not accessible - checking logs..."

    # Check for common stuck patterns
    print_section "Checking Logs for Stuck Patterns"
    echo "Waiting/blocking patterns:"
    kubectl logs "$DRIVER_POD" -n "$NAMESPACE" --tail=500 | grep -i "wait\|block\|hang" | head -10 || echo "None found"

    echo ""
    echo "Executor issues:"
    kubectl logs "$DRIVER_POD" -n "$NAMESPACE" --tail=500 | grep -i "executor.*lost\|no active executor" | head -10 || echo "None found"

    # Check executor pod status
    print_section "Executor Pod Status"
    kubectl get pods -n "$NAMESPACE" -l spark-app-name="$APP_NAME",spark-role=executor

    exit 0
fi

# Get application ID
APP_ID=$(kubectl exec -n "$NAMESPACE" "$DRIVER_POD" -- curl -s http://localhost:4040/api/v1/applications | jq -r '.[0].id' 2>/dev/null || echo "")
if [[ -z "$APP_ID" ]]; then
    echo "No application found in Spark UI"
    exit 1
fi
echo "Application ID: $APP_ID"

# 1. Check running jobs
print_section "1. Running Jobs"
kubectl exec -n "$NAMESPACE" "$DRIVER_POD" -- curl -s "http://localhost:4040/api/v1/applications/$APP_ID/jobs" | jq -r '
    [
        .[] | select(.status == "RUNNING") | {
            jobId: .jobId,
            name: .name,
            submissionTime: .submissionTime,
            numTasks: .numTasks,
            numCompletedTasks: .numCompletedTasks,
            numActiveTasks: .numActiveTasks
        }
    ]' 2>/dev/null || echo "No running jobs"

# 2. Check active stages
print_section "2. Active Stages"
kubectl exec -n "$NAMESPACE" "$DRIVER_POD" -- curl -s "http://localhost:4040/api/v1/applications/$APP_ID/stages" | jq -r '
    [
        .[] | select(.status == "ACTIVE" or .status == "PENDING") | {
            stageId: .stageId,
            name: .name,
            status: .status,
            numTasks: .numTasks,
            numActiveTasks: .numActiveTasks,
            numCompletedTasks: .numCompletedTasks
        }
    ]' 2>/dev/null || echo "No active stages"

# 3. Check executor status
print_section "3. Executor Status"
kubectl exec -n "$NAMESPACE" "$DRIVER_POD" -- curl -s "http://localhost:4040/api/v1/applications/$APP_ID/executors" | jq -r '
    [
        .[] | {
            id: .id,
            activeTasks: .activeTasks,
            runningTasks: .runningTasks,
            completedTasks: .completedTasks,
            failedTasks: .failedTasks
        }
    ]' 2>/dev/null || echo "Unable to fetch executor info"

ACTIVE_EXECUTORS=$(kubectl exec -n "$NAMESPACE" "$DRIVER_POD" -- curl -s "http://localhost:4040/api/v1/applications/$APP_ID/executors" | jq '[.[] | select(.active != false)] | length' 2>/dev/null || echo "0")
echo ""
echo "Active Executors: $ACTIVE_EXECUTORS"

if [[ "$ACTIVE_EXECUTORS" -lt 2 ]]; then
    echo "WARNING: Very few active executors - job may be waiting for resources"
fi

# 4. Check for stuck tasks
print_section "4. Long-Running Tasks"
kubectl exec -n "$NAMESPACE" "$DRIVER_POD" -- curl -s "http://localhost:4040/api/v1/applications/$APP_ID/stages" | jq -r '
    [
        .[] | select(.status == "ACTIVE") | .stageId
    ] | .[0]' 2>/dev/null | while read -r STAGE_ID; do
    if [[ -n "$STAGE_ID" && "$STAGE_ID" != "null" ]]; then
        echo "Tasks for active stage $STAGE_ID:"
        kubectl exec -n "$NAMESPACE" "$DRIVER_POD" -- curl -s "http://localhost:4040/api/v1/applications/$APP_ID/stages/$STAGE_ID/0/taskList" | jq -r '
            [
                .[] | select(.status == "RUNNING") | {
                    taskId: .taskId,
                    index: .index,
                    duration: .duration,
                    host: .host
                }
            ] | sort_by(.duration) | reverse | .[0:5]' 2>/dev/null || echo "Unable to fetch task list"
    fi
done

# 5. Check for waiting stages
print_section "5. Pending Stages"
kubectl exec -n "$NAMESPACE" "$DRIVER_POD" -- curl -s "http://localhost:4040/api/v1/applications/$APP_ID/stages" | jq -r '
    [
        .[] | select(.status == "PENDING") | {
            stageId: .stageId,
            name: .name,
            submissionTime: .submissionTime
        }
    ]' 2>/dev/null || echo "No pending stages"

# 6. Check executor pods
print_section "6. Executor Pod Status"
kubectl get pods -n "$NAMESPACE" -l spark-app-name="$APP_NAME",spark-role=executor

PENDING_EXECUTORS=$(kubectl get pods -n "$NAMESPACE" -l spark-app-name="$APP_NAME",spark-role=executor -o json | jq '[.items[] | select(.status.phase=="Pending")] | length' 2>/dev/null || echo "0")
if [[ "$PENDING_EXECUTORS" -gt 0 ]]; then
    echo ""
    echo "WARNING: $PENDING_EXECUTORS executor pods pending"
    echo ""
    echo "Sample pending pod events:"
    PENDING_POD=$(kubectl get pods -n "$NAMESPACE" -l spark-app-name="$APP_NAME",spark-role=executor -o json | jq -r '.items[] | select(.status.phase=="Pending") | .metadata.name' | head -1)
    if [[ -n "$PENDING_POD" ]]; then
        kubectl describe pod "$PENDING_POD" -n "$NAMESPACE" | grep -A 10 "Events:" || true
    fi
fi

# 7. Resource availability
print_section "7. Cluster Resource Status"
echo "Node status:"
kubectl top nodes 2>/dev/null || echo "Metrics server not available"

echo ""
echo "Resource quotas:"
kubectl get resourcequota -n "$NAMESPACE" -o json | jq -r '
    [
        .items[] | {
            name: .metadata.name,
            hard: .status.hard,
            used: .status.used
        }
    ]' 2>/dev/null || echo "No resource quotas"

# 8. Analysis and recommendations
print_section "8. Analysis and Recommendations"

if [[ "$ACTIVE_EXECUTORS" -lt 2 ]]; then
    echo ""
    echo "ISSUE: No active executors - job cannot progress"
    echo ""
    echo "Possible causes:"
    echo "- Dynamic allocation disabled and executors died"
    echo "- Cluster out of resources"
    echo "- Executor pods cannot be scheduled"
    echo ""
    echo "Remediation:"
    echo "1. Enable dynamic allocation:"
    cat <<'EOF'
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '{
  "spec": {
    "sparkConf": {
      "spark.dynamicAllocation.enabled": "true",
      "spark.dynamicAllocation.minExecutors": "2",
      "spark.dynamicAllocation.maxExecutors": "10"
    }
  }
}'
EOF
elif [[ "$PENDING_EXECUTORS" -gt 0 ]]; then
    echo ""
    echo "ISSUE: Executors pending - waiting for resources"
    echo ""
    echo "Possible causes:"
    echo "- Cluster autoscaler not scaling"
    echo "- Node has insufficient resources"
    echo "- Resource quota limits reached"
    echo ""
    echo "Remediation:"
    echo "1. Check cluster autoscaler: kubectl logs -n kube-system -l k8s-app=cluster-autoscaler"
    echo "2. Check node resources: kubectl describe node"
    echo "3. Review resource quotas: kubectl get resourcequota -n $NAMESPACE"
else
    echo ""
    echo "ISSUE: Job running but not progressing - checking for data skew or slow tasks"
    echo ""
    echo "Possible causes:"
    echo "- Data skew causing few long-running tasks"
    echo "- External service bottleneck (database, S3)"
    echo "- Lock contention or deadlock"
    echo ""
    echo "Remediation:"
    echo "1. Enable adaptive query execution:"
    cat <<'EOF'
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '{
  "spec": {
    "sparkConf": {
      "spark.sql.adaptive.enabled": "true",
      "spark.sql.adaptive.skewJoin.enabled": "true",
      "spark.sql.adaptive.coalescePartitions.enabled": "true"
    }
  }
}'
EOF
fi

print_section "9. Next Steps"
echo ""
echo "1. Apply the remediation based on analysis above"
echo "2. Monitor job progress in Spark UI:"
echo "   kubectl port-forward $DRIVER_POD 4040:4040 -n $NAMESPACE"
echo ""
echo "3. If job still stuck after 15 minutes, consider restarting:"
echo "   kubectl delete sparkapplication $APP_NAME -n $NAMESPACE"
echo ""
echo "Or recover automatically:"
echo "   scripts/operations/spark/recover-stuck-job.sh $NAMESPACE $APP_NAME"
