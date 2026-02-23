#!/bin/bash
# fix-shuffle-failure.sh - Remediate Spark shuffle failures
#
# Usage: fix-shuffle-failure.sh <namespace> <app-name>
#
# This script is idempotent and safe to re-run.

set -euo pipefail

NAMESPACE="${1:?Usage: fix-shuffle-failure.sh <namespace> <app-name>}"
APP_NAME="${2:?Usage: fix-shuffle-failure.sh <app-name>}"

echo "=== Spark Shuffle Failure Remediation ==="
echo "Namespace: $NAMESPACE"
echo "Application: $APP_NAME"
echo ""

# Function to print section header
print_section() {
    echo ""
    echo "=== $1 ==="
}

# Get the SparkApplication
print_section "1. Checking SparkApplication"
if ! kubectl get sparkapplication "$APP_NAME" -n "$NAMESPACE" &>/dev/null; then
    echo "ERROR: SparkApplication $APP_NAME not found in namespace $NAMESPACE"
    exit 1
fi

# Check if using Celeborn
print_section "2. Checking Shuffle Service Type"
USING_CELEBORN=$(kubectl get sparkapplication "$APP_NAME" -n "$NAMESPACE" -o json | jq -r '
    .spec.sparkConf | keys[] | select(contains("celeborn")) | length // 0')

if [[ "$USING_CELEBORN" -gt 0 ]]; then
    echo "Using: Celeborn shuffle service"
    SHUFFLE_TYPE="celeborn"
else
    echo "Using: Built-in shuffle service"
    SHUFFLE_TYPE="builtin"
fi

# 3. Diagnose based on shuffle type
if [[ "$SHUFFLE_TYPE" == "celeborn" ]]; then
    print_section "3. Celeborn Status Check"

    # Check Celeborn master
    CELEBORN_MASTER=$(kubectl get pods -n "$NAMESPACE" -l app=celeborn-master -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [[ -n "$CELEBORN_MASTER" ]]; then
        echo "Celeborn Master: $CELEBORN_MASTER"
        kubectl get pod "$CELEBORN_MASTER" -n "$NAMESPACE"

        # Check worker status
        print_section "4. Celeborn Worker Status"
        kubectl get pods -n "$NAMESPACE" -l app=celeborn-worker

        # Check for unhealthy workers
        UNHEALTHY_WORKERS=$(kubectl get pods -n "$NAMESPACE" -l app=celeborn-worker -o json | jq -r '[.items[] | select(.status.phase!="Running")] | length')
        if [[ "$UNHEALTHY_WORKERS" -gt 0 ]]; then
            echo ""
            echo "WARNING: Found $UNHEALTHY_WORKERS unhealthy workers"
            echo "Restarting unhealthy workers..."
            kubectl delete pod -n "$NAMESPACE" -l app=celeborn-worker --field-selector status.phase!=Running || true
        fi
    else
        echo "WARNING: Celeborn master not found in namespace $NAMESPACE"
    fi
else
    print_section "3. Built-in Shuffle Check"

    # Get driver pod
    DRIVER_POD=$(kubectl get pods -n "$NAMESPACE" -l spark-app-name="$APP_NAME",spark-role=driver -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

    if [[ -n "$DRIVER_POD" ]]; then
        echo "Driver Pod: $DRIVER_POD"

        # Check for shuffle fetch failures in logs
        print_section "4. Checking for Shuffle Fetch Failures"
        SHUFFLE_ERRORS=$(kubectl logs "$DRIVER_POD" -n "$NAMESPACE" --tail=1000 | grep -c "FetchFailedException" || echo "0")
        echo "Shuffle fetch errors found: $SHUFFLE_ERRORS"

        if [[ "$SHUFFLE_ERRORS" -gt 0 ]]; then
            echo ""
            echo "Shuffle fetch failures detected"
            echo ""
            echo "Recommended configuration changes:"
            echo "  spark.shuffle.fetch.retry.count: 5"
            echo "  spark.shuffle.fetch.retry.waitMs: 5000"
            echo "  spark.reducer.maxSizeInFlight: 96m"
        fi
    fi
fi

# 5. Check network connectivity
print_section "5. Network Connectivity Check"
if [[ -n "$DRIVER_POD" ]]; then
    echo "Checking executor connectivity from driver..."
    EXECUTOR_PODS=$(kubectl get pods -n "$NAMESPACE" -l spark-app-name="$APP_NAME",spark-role=executor -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | head -3)
    for EXECUTOR in $EXECUTOR_PODS; do
        if [[ -n "$EXECUTOR" ]]; then
            EXECUTOR_IP=$(kubectl get pod "$EXECUTOR" -n "$NAMESPACE" -o jsonpath='{.status.podIP}')
            echo "  Pinging executor $EXECUTOR ($EXECUTOR_IP)..."
            kubectl exec -n "$NAMESPACE" "$DRIVER_POD" -- ping -c 2 -W 2 "$EXECUTOR_IP" &>/dev/null && echo "    OK" || echo "    FAILED"
        fi
    done
fi

# 6. Check disk space on nodes with executors
print_section "6. Disk Space Check"
NODES_WITH_SHUFFLE=$(kubectl get pods -n "$NAMESPACE" -l spark-role=executor -o jsonpath='{.items[*].spec.nodeName}' | tr ' ' '\n' | sort -u)
for NODE in $NODES_WITH_SHUFFLE; do
    if kubectl exec -n "$NAMESPACE" "spark-executor-$(echo $NODE | head -c 8)" -- df -h /dev/shm &>/dev/null 2>&1; then
        echo "Node $NODE disk status:"
        # Try to get disk info from any pod on this node
        SAMPLE_POD=$(kubectl get pods -n "$NAMESPACE" -o json | jq -r --arg node "$NODE" '.items[] | select(.spec.nodeName==$node) | .metadata.name' | head -1)
        if [[ -n "$SAMPLE_POD" ]]; then
            kubectl exec -n "$NAMESPACE" "$SAMPLE_POD" -- df -h | grep -E "Filesystem|overlay|tmpfs" || true
        fi
    fi
done

# 7. Remediation steps
print_section "7. Remediation Steps"

if [[ "$SHUFFLE_TYPE" == "celeborn" ]]; then
    echo "Celeborn Shuffle Service Remediation:"
    echo ""
    echo "1. Restart unhealthy workers:"
    echo "   kubectl delete pod -n $NAMESPACE -l app=celeborn-worker --field-selector status.phase!=Running"
    echo ""
    echo "2. If all workers down, check master:"
    echo "   kubectl logs -n $NAMESPACE -l app=celeborn-master --tail=100"
    echo ""
    echo "3. Check Celeborn configuration:"
    echo "   kubectl get configmap celeborn-config -n $NAMESPACE -o yaml"
else
    echo "Built-in Shuffle Service Remediation:"
    echo ""
    echo "1. Increase shuffle retry settings:"
    cat <<'EOF'
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '{
  "spec": {
    "sparkConf": {
      "spark.shuffle.fetch.retry.count": "5",
      "spark.shuffle.fetch.retry.waitMs": "5000",
      "spark.shuffle.fetch.retry.maxWaitTimeMs": "60000",
      "spark.reducer.maxSizeInFlight": "96m",
      "spark.shuffle.maxChunksBeingTransferred": "2147483647"
    }
  }
}'
EOF
    echo ""
    echo "2. Migrate to Celeborn for better reliability:"
    echo "   scripts/operations/spark/migrate-to-celeborn.sh $NAMESPACE $APP_NAME"
fi

print_section "8. Automatic Recovery Options"
echo ""
echo "For automated remediation, choose one:"
echo ""
echo "1. Restart executors (safe, minimal disruption):"
echo "   kubectl delete pod -l spark-role=executor -n $NAMESPACE -l spark-app-name=$APP_NAME"
echo ""
echo "2. Restart application (clears all state, job restarts):"
echo "   kubectl delete sparkapplication $APP_NAME -n $NAMESPACE"
echo ""
echo "3. Apply recommended configuration and restart:"
echo "   # Apply the patch shown above, then:"
echo "   kubectl delete sparkapplication $APP_NAME -n $NAMESPACE"
