#!/bin/bash
# Detect and clean up idle Spark resources
#
# Usage:
#   ./cleanup-idle-resources.sh --namespace <ns> [--dry-run] [--minutes <threshold>]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../operations/common.sh"

# Configuration
NAMESPACE=""
DRY_RUN=${DRY_RUN:-"true"}
IDLE_MINUTES=${IDLE_MINUTES:-"10"}
PROMETHEUS_URL=${PROMETHEUS_URL:-"http://prometheus:9090"}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN="$2"
            shift 2
            ;;
        --minutes)
            IDLE_MINUTES="$2"
            shift 2
            ;;
        --execute)
            DRY_RUN="false"
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [[ -z "$NAMESPACE" ]]; then
    log_error "Usage: $0 --namespace <ns> [--dry-run true|false] [--minutes <threshold>]"
    exit 1
fi

log_info "=== Idle Resource Detection ==="
log_info "Namespace: ${NAMESPACE}"
log_info "Idle threshold: ${IDLE_MINUTES} minutes"
log_info "Dry run: ${DRY_RUN}"

declare -i RESOURCES_CLEANED=0

# 1. Detect idle executors
log_info "=== Checking for Idle Executors ==="

IDLE_EXECUTORS_QUERY="spark_executor_active_tasks{namespace=\"${NAMESPACE}\"} == 0"
IDLE_TIME_QUERY="time() - spark_executor_registered_time_seconds{namespace=\"${NAMESPACE}\"}"

# Get idle executors
IDLE_EXECUTORS=$(curl -s -G --data-urlencode "query=$IDLE_EXECUTORS_QUERY" \
    "${PROMETHEUS_URL}/api/v1/query" | \
    jq -r '.data.result[] | "\(.metric.app_id) \(.metric.executor_id)"' 2>/dev/null || true)

if [[ -n "$IDLE_EXECUTORS" ]]; then
    while IFS=' ' read -r app_id executor_id; do
        # Check how long it's been idle
        REGISTER_TIME=$(curl -s -G --data-urlencode "query=spark_executor_registered_time_seconds{namespace=\"${NAMESPACE}\",app_id=\"${app_id}\",executor_id=\"${executor_id}\"}" \
            "${PROMETHEUS_URL}/api/v1/query" | \
            jq -r '.data.result[0].value[1]' 2>/dev/null || echo "0")

        if [[ "$REGISTER_TIME" != "0" ]]; then
            IDLE_SECONDS=$(echo "$(date +%s) - $REGISTER_TIME" | bc 2>/dev/null || echo "0")
            IDLE_MINS=$(echo "$IDLE_SECONDS / 60" | bc 2>/dev/null || echo "0")

            if [[ $IDLE_MINS -ge $IDLE_MINUTES ]]; then
                log_warn "Idle executor: ${app_id}/${executor_id} (idle for ${IDLE_MINS} minutes)"

                if [[ "$DRY_RUN" == "false" ]]; then
                    # Get pod name for this executor
                    POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l "spark-app-id=${app_id},spark-role=executor" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

                    if [[ -n "$POD_NAME" ]]; then
                        log_info "Deleting pod: ${POD_NAME}"
                        kubectl delete pod "$POD_NAME" -n "$NAMESPACE" 2>/dev/null || true
                        ((RESOURCES_CLEANED++))
                    fi
                else
                    log_info "[DRY RUN] Would delete executor pod for ${app_id}/${executor_id}"
                fi
            fi
        fi
    done <<< "$IDLE_EXECUTORS"
else
    log_info "No idle executors detected"
fi

# 2. Detect unused drivers (no active jobs)
log_info "=== Checking for Unused Drivers ==="

UNUSED_DRIVERS_QUERY="sum by (app_id) (spark_job_running_tasks{namespace=\"${NAMESPACE}\"}) == 0"
UNUSED_DRIVERS=$(curl -s -G --data-urlencode "query=$UNUSED_DRIVERS_QUERY" \
    "${PROMETHEUS_URL}/api/v1/query" | \
    jq -r '.data.result[].metric.app_id' 2>/dev/null || true)

if [[ -n "$UNUSED_DRIVERS" ]]; then
    while IFS= read -r app_id; do
        if [[ -z "$app_id" ]]; then continue; fi

        # Check completion status
        APP_STATUS=$(kubectl get sparkapplication "$app_id" -n "$NAMESPACE" -o jsonpath='{.status.applicationState.state}' 2>/dev/null || echo "UNKNOWN")

        if [[ "$APP_STATUS" == "COMPLETED" || "$APP_STATUS" == "FAILED" ]]; then
            log_warn "Completed driver still exists: ${app_id} (${APP_STATUS})"

            if [[ "$DRY_RUN" == "false" ]]; then
                log_info "Deleting SparkApplication: ${app_id}"
                kubectl delete sparkapplication "$app_id" -n "$NAMESPACE" 2>/dev/null || true
                ((RESOURCES_CLEANED++))
            else
                log_info "[DRY RUN] Would delete SparkApplication: ${app_id}"
            fi
        fi
    done <<< "$UNUSED_DRIVERS"
else
    log_info "No unused drivers detected"
fi

# 3. Detect orphaned pods (no matching SparkApplication)
log_info "=== Checking for Orphaned Pods ==="

# Get all Spark pods
SPARK_PODS=$(kubectl get pods -n "$NAMESPACE" -l "spark-app-selector" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)

if [[ -n "$SPARK_PODS" ]]; then
    for pod in $SPARK_PODS; do
        APP_ID=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.labels.spark-app-id}' 2>/dev/null || true)

        if [[ -n "$APP_ID" ]]; then
            # Check if SparkApplication exists
            if ! kubectl get sparkapplication "$APP_ID" -n "$NAMESPACE" &>/dev/null; then
                log_warn "Orphaned pod: ${pod} (app ${APP_ID} not found)"

                if [[ "$DRY_RUN" == "false" ]]; then
                    log_info "Deleting orphaned pod: ${pod}"
                    kubectl delete pod "$pod" -n "$NAMESPACE" 2>/dev/null || true
                    ((RESOURCES_CLEANED++))
                else
                    log_info "[DRY RUN] Would delete orphaned pod: ${pod}"
                fi
            fi
        fi
    done
else
    log_info "No orphaned pods detected"
fi

# 4. Detect old completed pods
log_info "=== Checking for Old Completed Pods ==="

OLD_COMPLETED_PODS=$(kubectl get pods -n "$NAMESPACE" --field-selector=status.phase==Succeeded -o json | \
    jq -r '.items[] | select(.status.startTime | fromdateiso8601 < now - 3600) | .metadata.name' 2>/dev/null || true)

if [[ -n "$OLD_COMPLETED_PODS" ]]; then
    while IFS= read -r pod; do
        if [[ -z "$pod" ]]; then continue; fi

        log_warn "Old completed pod: ${pod}"

        if [[ "$DRY_RUN" == "false" ]]; then
            log_info "Deleting old completed pod: ${pod}"
            kubectl delete pod "$pod" -n "$NAMESPACE" 2>/dev/null || true
            ((RESOURCES_CLEANED++))
        else
            log_info "[DRY RUN] Would delete old completed pod: ${pod}"
        fi
    done <<< "$OLD_COMPLETED_PODS"
else
    log_info "No old completed pods detected"
fi

# Summary
log_info "=== Cleanup Summary ==="

if [[ $RESOURCES_CLEANED -gt 0 ]]; then
    log_info "Resources cleaned: ${RESOURCES_CLEANED}"
else
    log_info "No resources required cleanup"
fi

if [[ "$DRY_RUN" == "true" ]]; then
    log_info "This was a dry run. Use --execute to perform actual cleanup."
fi

exit 0
