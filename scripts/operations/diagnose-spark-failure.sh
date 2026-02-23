#!/bin/bash
# Diagnose Spark Application Failure
#
# Usage:
#   ./diagnose-spark-failure.sh <NAMESPACE> <APP_NAME>
#
# Example:
#   ./diagnose-spark-failure.sh spark-prod driver-crash-loop

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
    cat <<EOF
Usage: $(basename "$0") <NAMESPACE> <APP_NAME> [OPTIONS]

Diagnose Spark application failures in Kubernetes.

ARGUMENTS:
    NAMESPACE        Kubernetes namespace (required)
    APP_NAME        Spark application name (required)

OPTIONS:
    -p, --pod POD_NAME      Specific pod to diagnose (default: auto-detect)
    -c, --container CONTAINER  Container to check (default: all)
    -l, --logs LINES        Number of log lines to show (default: 100)
    --since TIME           Show logs since TIME (e.g., 5m, 1h)
    --prometheus URL       Prometheus URL (default: http://prometheus:9090)
    --dry-run              Show commands without executing

EXAMPLES:
    $(basename "$0") spark-prod driver-crash-loop
    $(basename "$0") spark-ops executor-oom --since=10m

EOF
    exit 1
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Parse arguments
NAMESPACE=""
APP_NAME=""
POD_NAME=""
CONTAINER=""
LOG_LINES=100
SINCE=""
PROMETHEUS_URL="http://prometheus:9090"
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -p|--pod)
            POD_NAME="$2"
            shift 2
            ;;
        -c|--container)
            CONTAINER="$2"
            shift 2
            ;;
        -l|--logs)
            LOG_LINES="$2"
            shift 2
            ;;
        --since)
            SINCE="$2"
            shift 2
            ;;
        --prometheus)
            PROMETHEUS_URL="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -*)
            log_error "Unknown option: $1"
            usage
            ;;
        *)
            if [[ -z "$NAMESPACE" ]]; then
                NAMESPACE="$1"
            elif [[ -z "$APP_NAME" ]]; then
                APP_NAME="$1"
            fi
            shift
            ;;
    esac
done

# Validate required arguments
if [[ -z "$NAMESPACE" || -z "$APP_NAME" ]]; then
    log_error "Missing required arguments: NAMESPACE and APP_NAME"
    usage
fi

# Auto-detect pod if not specified
if [[ -z "$POD_NAME" ]]; then
    # Try to find driver pod first
    POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l "spark-role=driver,app=$APP_NAME" -o name | head -1)
    if [[ -z "$POD_NAME" ]]; then
        # Try executor pod
        POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l "spark-role=executor,app=$APP_NAME" -o name | head -1)
    fi
fi

if [[ "$DRY_RUN" == true ]]; then
    log_info "[DRY RUN] Would diagnose pod: $POD_NAME"
    exit 0
fi

log_info "Diagnosing Spark application: $APP_NAME"
log_info "Pod: $POD_NAME"
log_info "Namespace: $NAMESPACE"

# Get pod status
log_info "=== Pod Status ==="
POD_STATUS=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.status.phase}')
log_info "Phase: $POD_STATUS"

POD_READY=false
case "$POD_STATUS" in
    Running)
        READY_REPLICAS=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' | head -1)
        if [[ "$READY_REPLICAS" == "True" ]]; then
            POD_READY=true
            log_info "Pod is Ready"
        else
            log_warn "Pod not Ready (condition: $READY_REPLICAS)"
        fi
        ;;
    Succeeded|Failed)
        log_warn "Pod has $POD_STATUS (terminal state)"
        ;;
    Pending)
        log_warn "Pod is Pending"
        ;;
    Unknown)
        log_error "Pod not found"
        ;;
esac

# Check pod events
log_info "=== Recent Events (last 5) ==="
kubectl get events -n "$NAMESPACE" --field-selector involvedObject.name=$POD_NAME --sort-by='.lastTimestamp' | tail -5

# Check resource usage
log_info "=== Resource Usage ==="
kubectl top pod "$POD_NAME" -n "$NAMESPACE" --containers || true

# Check logs for errors
log_info "=== Error Patterns in Logs ==="

if [[ -n "$CONTAINER" ]]; then
    LOG_CMD="kubectl logs $POD_NAME -n $NAMESPACE -c $CONTAINER"
else
    LOG_CMD="kubectl logs $POD_NAME -n $NAMESPACE"
fi

if [[ -n "$SINCE" ]]; then
    LOG_CMD="$LOG_CMD --since=$SINCE"
fi

# Get last N lines and search for errors
ERROR_PATTERNS=("OutOfMemoryError" "Container killed" "Exception in thread" "ERROR" "FATAL" "SparkException")

LOG_OUTPUT=$(eval "$LOG_CMD --tail=$LOG_LINES 2>&1" || true)

for pattern in "${ERROR_PATTERNS[@]}"; do
    if echo "$LOG_OUTPUT" | grep -qi "$pattern"; then
        log_error "Found pattern: $pattern"
    fi
done

# Show recent logs
log_info "=== Recent Logs (last $LOG_LINES lines) ==="
eval "$LOG_CMD --tail=$LOG_LINES" || true

# Query Prometheus for metrics
log_info "=== Prometheus Metrics ==="

# Get Spark application metrics
METRIC_QUERY="spark_driver_memory{app=\"$APP_NAME\",namespace=\"$NAMESPACE\"}"

METRIC_OUTPUT=$(curl -s "$PROMETHEUS_URL/api/v1/query?query=$METRIC_QUERY" 2>/dev/null)

if [[ -n "$METRIC_OUTPUT" ]]; then
    log_info "Driver Memory: $METRIC_OUTPUT"
else
    log_warn "No metrics found from Prometheus"
fi

# Diagnostic summary
log_info "=== Diagnostic Summary ==="

if [[ "$POD_READY" == true ]]; then
    log_info "Pod Status: Ready"
else
    log_warn "Pod Status: Not Ready ($POD_STATUS)"
fi

# Output recommendations
echo "{'=\"*60}"
echo "Diagnostic Recommendations"
echo "{'=\"*60}"

# Common issues and fixes
ISSUES_FOUND=false

if echo "$LOG_OUTPUT" | grep -qi "OutOfMemoryError"; then
    echo "- [ ] OOM Detected: Increase spark.executor.memory or spark.executor.memoryOverhead"
    ISSUES_FOUND=true
fi

if echo "$LOG_OUTPUT" | grep -qi "Container killed"; then
    echo "- [ ] Container OOM Kill: Check memory limits and GC settings"
    ISSUES_FOUND=true
fi

if echo "$LOG_OUTPUT" | grep -qi "Exception in thread.*main"; then
    echo "- [ ] Uncaught Exception: Check application logs for root cause"
    ISSUES_FOUND=true
fi

if echo "$LOG_OUTPUT" | grep -qi "Connection refused"; then
    echo "- [ ] Network Issues: Check service connectivity and DNS"
    ISSUES_FOUND=true
fi

if [[ "$ISSUES_FOUND" == false ]]; then
    echo "- No critical issues found in logs"
fi

echo "{'=\"*60}"
echo ""
log_info "Diagnostic complete. Review logs and metrics for root cause analysis."

# Exit codes
# 0: No issues found
# 1: Issues requiring attention found
exit 0
