#!/bin/bash
# collect-logs.sh - Collect Spark application logs for troubleshooting
#
# Usage: collect-logs.sh <namespace> <app-name> [output-dir]
#
# This script is idempotent and safe to re-run.

set -euo pipefail

NAMESPACE="${1:?Usage: collect-logs.sh <namespace> <app-name> [output-dir]}"
APP_NAME="${2:?Usage: collect-logs.sh <app-name> [output-dir]}"
OUTPUT_DIR="${3:-/tmp/spark-logs-$APP_NAME-$(date +%Y%m%d-%H%M%S)}"

echo "=== Spark Log Collection ==="
echo "Namespace: $NAMESPACE"
echo "Application: $APP_NAME"
echo "Output Directory: $OUTPUT_DIR"
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Function to print section header
print_section() {
    echo ""
    echo "=== $1 ==="
}

# Get driver pod
print_section "Finding Spark Resources"
DRIVER_POD=$(kubectl get pods -n "$NAMESPACE" -l spark-app-name="$APP_NAME",spark-role=driver -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [[ -z "$DRIVER_POD" ]]; then
    echo "WARNING: Driver pod not found for application $APP_NAME"
    echo "The application may not be running or has a different name."
    echo "Looking for any Spark pods in namespace..."
    kubectl get pods -n "$NAMESPACE" -l spark-role=driver
    exit 1
fi
echo "Driver Pod: $DRIVER_POD"

# 1. Collect driver logs
print_section "1. Collecting Driver Logs"
kubectl logs "$DRIVER_POD" -n "$NAMESPACE" > "$OUTPUT_DIR/driver-logs.txt" 2>/dev/null || true
echo "  Saved: $OUTPUT_DIR/driver-logs.txt"

# Previous driver logs if available
kubectl logs "$DRIVER_POD" -n "$NAMESPACE" --previous > "$OUTPUT_DIR/driver-logs-previous.txt" 2>/dev/null || true
echo "  Saved: $OUTPUT_DIR/driver-logs-previous.txt (if exists)"

# 2. Collect executor logs
print_section "2. Collecting Executor Logs"
EXECUTOR_PODS=$(kubectl get pods -n "$NAMESPACE" -l spark-app-name="$APP_NAME",spark-role=executor -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || "")
if [[ -n "$EXECUTOR_PODS" ]]; then
    EXECUTOR_COUNT=0
    for EXECUTOR in $EXECUTOR_PODS; do
        if [[ -n "$EXECUTOR" ]]; then
            kubectl logs "$EXECUTOR" -n "$NAMESPACE" > "$OUTPUT_DIR/executor-${EXECUTOR}.txt" 2>/dev/null || true
            kubectl logs "$EXECUTOR" -n "$NAMESPACE" --previous > "$OUTPUT_DIR/executor-${EXECUTOR}-previous.txt" 2>/dev/null || true
            ((EXECUTOR_COUNT++))
        fi
    done
    echo "  Collected logs from $EXECUTOR_COUNT executor(s)"
else
    echo "  No executor pods found"
fi

# 3. Collect events
print_section "3. Collecting Events"
kubectl get events -n "$NAMESPACE" --field-selector involvedObject.name="$DRIVER_POD" -o yaml > "$OUTPUT_DIR/events-driver.txt" 2>/dev/null || true
echo "  Saved: $OUTPUT_DIR/events-driver.txt"

kubectl get events -n "$NAMESPACE" --field-selector involvedObject.name~"$APP_NAME" -o yaml > "$OUTPUT_DIR/events-app.txt" 2>/dev/null || true
echo "  Saved: $OUTPUT_DIR/events-app.txt"

# All recent events
kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' -o yaml > "$OUTPUT_DIR/events-all.txt" 2>/dev/null || true
echo "  Saved: $OUTPUT_DIR/events-all.txt"

# 4. Collect pod descriptions
print_section "4. Collecting Pod Descriptions"
kubectl describe pod "$DRIVER_POD" -n "$NAMESPACE" > "$OUTPUT_DIR/driver-describe.txt" 2>/dev/null || true
echo "  Saved: $OUTPUT_DIR/driver-describe.txt"

for EXECUTOR in $EXECUTOR_PODS; do
    if [[ -n "$EXECUTOR" ]]; then
        kubectl describe pod "$EXECUTOR" -n "$NAMESPACE" > "$OUTPUT_DIR/executor-${EXECUTOR}-describe.txt" 2>/dev/null || true
    fi
done
echo "  Saved executor descriptions"

# 5. Collect SparkApplication spec
print_section "5. Collecting Application Configuration"
kubectl get sparkapplication "$APP_NAME" -n "$NAMESPACE" -o yaml > "$OUTPUT_DIR/sparkapplication.yaml" 2>/dev/null || true
echo "  Saved: $OUTPUT_DIR/sparkapplication.yaml"

# 6. Collect Spark UI metrics if available
print_section "6. Collecting Spark UI Metrics"
if kubectl exec -n "$NAMESPACE" "$DRIVER_POD" -- curl -s http://localhost:4040/api/v1 &>/dev/null; then
    # Get application ID
    APP_ID=$(kubectl exec -n "$NAMESPACE" "$DRIVER_POD" -- curl -s http://localhost:4040/api/v1/applications | jq -r '.[0].id' 2>/dev/null || echo "")

    if [[ -n "$APP_ID" ]]; then
        echo "  Application ID: $APP_ID"

        # Jobs
        kubectl exec -n "$NAMESPACE" "$DRIVER_POD" -- curl -s "http://localhost:4040/api/v1/applications/$APP_ID/jobs" > "$OUTPUT_DIR/ui-jobs.json" 2>/dev/null || true
        echo "  Saved: $OUTPUT_DIR/ui-jobs.json"

        # Stages
        kubectl exec -n "$NAMESPACE" "$DRIVER_POD" -- curl -s "http://localhost:4040/api/v1/applications/$APP_ID/stages" > "$OUTPUT_DIR/ui-stages.json" 2>/dev/null || true
        echo "  Saved: $OUTPUT_DIR/ui-stages.json"

        # Executors
        kubectl exec -n "$NAMESPACE" "$DRIVER_POD" -- curl -s "http://localhost:4040/api/v1/applications/$APP_ID/executors" > "$OUTPUT_DIR/ui-executors.json" 2>/dev/null || true
        echo "  Saved: $OUTPUT_DIR/ui-executors.json"

        # Environment
        kubectl exec -n "$NAMESPACE" "$DRIVER_POD" -- curl -s "http://localhost:4040/api/v1/applications/$APP_ID/environment" > "$OUTPUT_DIR/ui-environment.json" 2>/dev/null || true
        echo "  Saved: $OUTPUT_DIR/ui-environment.json"
    fi
else
    echo "  Spark UI not accessible"
fi

# 7. Collect resource usage
print_section "7. Collecting Resource Usage"
kubectl top pod -n "$NAMESPACE" -l spark-app-name="$APP_NAME" > "$OUTPUT_DIR/resource-usage.txt" 2>/dev/null || true
echo "  Saved: $OUTPUT_DIR/resource-usage.txt"

kubectl get pods -n "$NAMESPACE" -l spark-app-name="$APP_NAME" -o wide > "$OUTPUT_DIR/pods-list.txt" 2>/dev/null || true
echo "  Saved: $OUTPUT_DIR/pods-list.txt"

# 8. Collect node information
print_section "8. Collecting Node Information"
NODE_NAME=$(kubectl get pod "$DRIVER_POD" -n "$NAMESPACE" -o jsonpath='{.spec.nodeName}')
kubectl describe node "$NODE_NAME" > "$OUTPUT_DIR/node-${NODE_NAME}.txt" 2>/dev/null || true
echo "  Saved: $OUTPUT_DIR/node-${NODE_NAME}.txt"

# 9. Create summary
print_section "9. Creating Summary"
cat > "$OUTPUT_DIR/summary.txt" <<EOF
Spark Log Collection Summary
============================
Date: $(date)
Namespace: $NAMESPACE
Application: $APP_NAME
Driver Pod: $DRIVER_POD

Files Collected:
- driver-logs.txt: Current driver container logs
- driver-logs-previous.txt: Previous driver container logs (if applicable)
- executor-*.txt: Executor logs
- events-*.txt: Kubernetes events
- driver-describe.txt: Driver pod description
- executor-*-describe.txt: Executor pod descriptions
- sparkapplication.yaml: SparkApplication configuration
- ui-*.json: Spark UI metrics (if available)
- resource-usage.txt: Pod resource usage
- pods-list.txt: List of application pods
- node-*.txt: Node information

Quick Diagnosis:
EOF

# Add quick diagnosis
echo "" >> "$OUTPUT_DIR/summary.txt"
echo "Error Patterns:" >> "$OUTPUT_DIR/summary.txt"
grep -i "error\|exception\|fail" "$OUTPUT_DIR/driver-logs.txt" | head -20 >> "$OUTPUT_DIR/summary.txt" 2>/dev/null || echo "No errors found in driver logs" >> "$OUTPUT_DIR/summary.txt"

echo "" >> "$OUTPUT_DIR/summary.txt"
echo "OOM Indicators:" >> "$OUTPUT_DIR/summary.txt"
grep -i "oom\|out of memory" "$OUTPUT_DIR/driver-logs.txt" >> "$OUTPUT_DIR/summary.txt" 2>/dev/null || echo "No OOM indicators found" >> "$OUTPUT_DIR/summary.txt"

echo "" >> "$OUTPUT_DIR/summary.txt"
echo "Exit Code:" >> "$OUTPUT_DIR/summary.txt"
kubectl get pod "$DRIVER_POD" -n "$NAMESPACE" -o jsonpath='{.status.containerStatuses[0].lastState.terminated.exitCode}' >> "$OUTPUT_DIR/summary.txt" 2>/dev/null || echo "N/A" >> "$OUTPUT_DIR/summary.txt"

echo ""
echo "Summary created: $OUTPUT_DIR/summary.txt"

# 10. Create archive
print_section "10. Creating Archive"
tar -czf "${OUTPUT_DIR}.tar.gz" -C "$(dirname "$OUTPUT_DIR")" "$(basename "$OUTPUT_DIR")" 2>/dev/null || true
echo "Archive created: ${OUTPUT_DIR}.tar.gz"

print_section "Collection Complete"
echo ""
echo "All logs collected to: $OUTPUT_DIR"
echo "Archive: ${OUTPUT_DIR}.tar.gz"
echo ""
echo "To review the summary:"
echo "  cat $OUTPUT_DIR/summary.txt"
echo ""
echo "To extract archive:"
echo "  tar -xzf ${OUTPUT_DIR}.tar.gz"
echo ""
echo "To search for errors:"
echo "  grep -i error $OUTPUT_DIR/driver-logs.txt"
