#!/bin/bash
# Analyze job resource usage and recommend rightsizing
#
# Usage:
#   ./rightsize-jobs.sh --namespace <ns> [--min-savings <percent>]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../operations/common.sh"

# Configuration
NAMESPACE=""
MIN_SAVINGS=${MIN_SAVINGS:-"20"}  # Minimum savings percentage
PROMETHEUS_URL=${PROMETHEUS_URL:-"http://prometheus:9090"}
TIME_WINDOW=${TIME_WINDOW:-"7d"}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        --min-savings)
            MIN_SAVINGS="$2"
            shift 2
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [[ -z "$NAMESPACE" ]]; then
    log_error "Usage: $0 --namespace <ns> [--min-savings <percent>]"
    exit 1
fi

log_info "=== Job Rightsizing Analysis ==="
log_info "Namespace: ${NAMESPACE}"
log_info "Analysis window: ${TIME_WINDOW}"
log_info "Minimum savings: ${MIN_SAVINGS}%"

# Get list of jobs
log_info "Fetching job list..."

JOBS_QUERY="group by (app_id) (spark_executor_count{namespace=\"${NAMESPACE}\"})"
JOBS=$(curl -s -G --data-urlencode "query=$JOBS_QUERY" \
    "${PROMETHEUS_URL}/api/v1/query" | \
    jq -r '.data.result[].metric.app_id' 2>/dev/null || true)

if [[ -z "$JOBS" ]]; then
    log_info "No jobs found in namespace"
    exit 0
fi

declare -i TOTAL_POTENTIAL_SAVINGS=0

log_info "=== Rightsizing Recommendations ==="

# Analyze each job
while IFS= read -r job; do
    if [[ -z "$job" ]]; then continue; fi

    log_info "--- Job: ${job} ---"

    # Get current configuration
    EXECUTORS_QUERY="avg(spark_executor_count{namespace=\"${NAMESPACE}\",app_id=\"${job}\"})"
    EXECUTOR_COUNT=$(curl -s -G --data-urlencode "query=$EXECUTORS_QUERY" \
        "${PROMETHEUS_URL}/api/v1/query" | \
        jq -r '.data.result[0].value[1]' 2>/dev/null || echo "0")

    CORES_QUERY="avg(spark_executor_cores{namespace=\"${NAMESPACE}\",app_id=\"${job}\"})"
    CORES_PER_EXEC=$(curl -s -G --data-urlencode "query=$CORES_QUERY" \
        "${PROMETHEUS_URL}/api/v1/query" | \
        jq -r '.data.result[0].value[1]' 2>/dev/null || echo "4")

    MEMORY_QUERY="avg(spark_executor_memory_bytes{namespace=\"${NAMESPACE}\",app_id=\"${job}\"}) / 1024 / 1024 / 1024"
    MEMORY_PER_EXEC=$(curl -s -G --data-urlencode "query=$MEMORY_QUERY" \
        "${PROMETHEUS_URL}/api/v1/query" | \
        jq -r '.data.result[0].value[1]' 2>/dev/null || echo "8")

    log_info "Current config: ${EXECUTOR_COUNT} executors × ${CORES_PER_EXEC} cores × ${MEMORY_PER_EXEC}GB"

    # Get utilization metrics
    CPU_AVG_QUERY="avg(rate(spark_executor_cpu_time_seconds_total{namespace=\"${NAMESPACE}\",app_id=\"${job}\"}[1h]) / spark_executor_cores{namespace=\"${NAMESPACE}\",app_id=\"${job}\"}) * 100"
    CPU_AVG=$(curl -s -G --data-urlencode "query=$CPU_AVG_QUERY" \
        "${PROMETHEUS_URL}/api/v1/query" | \
        jq -r '.data.result[0].value[1]' 2>/dev/null || echo "null")

    MEMORY_AVG_QUERY="avg(spark_executor_memory_used_bytes{namespace=\"${NAMESPACE}\",app_id=\"${job}\"} / spark_executor_memory_bytes{namespace=\"${NAMESPACE}\",app_id=\"${job}\"}) * 100"
    MEMORY_AVG=$(curl -s -G --data-urlencode "query=$MEMORY_AVG_QUERY" \
        "${PROMETHEUS_URL}/api/v1/query" | \
        jq -r '.data.result[0].value[1]' 2>/dev/null || echo "null")

    log_info "Avg CPU utilization: ${CPU_AVG}%"
    log_info "Avg memory utilization: ${MEMORY_AVG}%"

    # Determine if rightsizing is needed
    RECOMMENDATION=""
    SAVINGS_PERCENT=0

    # CPU underutilization
    if [[ "$CPU_AVG" != "null" ]]; then
        if [[ $(echo "$CPU_AVG < 20" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
            RECOMMENDATION="Reduce executor count or cores"
            SAVINGS_PERCENT=$((100 - $(echo "$CPU_AVG" / 1 | bc 2>/dev/null || echo "0")))
        fi
    fi

    # Memory underutilization
    if [[ "$MEMORY_AVG" != "null" ]]; then
        if [[ $(echo "$MEMORY_AVG < 30" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
            if [[ -z "$RECOMMENDATION" ]]; then
                RECOMMENDATION="Reduce executor memory"
            fi
            MEMORY_SAVINGS=$((100 - $(echo "$MEMORY_AVG" / 1 | bc 2>/dev/null || echo "0")))
            if [[ $MEMORY_SAVINGS -gt $SAVINGS_PERCENT ]]; then
                SAVINGS_PERCENT=$MEMORY_SAVINGS
            fi
        fi
    fi

    # Check for GC issues (may need more memory)
    GC_TIME_QUERY="avg(rate(jvm_gc_time_seconds{namespace=\"${NAMESPACE}\",app_id=\"${job}\"}[5m])) * 100"
    GC_TIME=$(curl -s -G --data-urlencode "query=$GC_TIME_QUERY" \
        "${PROMETHEUS_URL}/api/v1/query" | \
        jq -r '.data.result[0].value[1]' 2>/dev/null || echo "0")

    if [[ $(echo "$GC_TIME > 20" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
        log_warn "High GC time: ${GC_TIME}% - may need MORE memory, not less"
        RECOMMENDATION="Increase executor memory to reduce GC"
        SAVINGS_PERCENT=0
    fi

    # Check for shuffle spill (may need more memory)
    SPILL_QUERY="sum(increase(spark_task_disk_bytes_spilled{namespace=\"${NAMESPACE}\",app_id=\"${job}\"}[1h]))"
    SPILL=$(curl -s -G --data-urlencode "query=$SPILL_QUERY" \
        "${PROMETHEUS_URL}/api/v1/query" | \
        jq -r '.data.result[0].value[1]' 2>/dev/null || echo "0")

    if [[ $(echo "$SPILL > 1000000000" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
        SPILL_GB=$(echo "scale=2; $SPILL / 1024 / 1024 / 1024" | bc 2>/dev/null || echo "0")
        log_warn "High shuffle spill: ${SPILL_GB}GB - consider increasing memory"
        if [[ -z "$RECOMMENDATION" ]]; then
            RECOMMENDATION="Increase memory to reduce shuffle spill"
        fi
        SAVINGS_PERCENT=0
    fi

    # Show recommendation
    if [[ -n "$RECOMMENDATION" && $SAVINGS_PERCENT -ge $MIN_SAVINGS ]]; then
        log_error "⚠ RECOMMEND: ${RECOMMENDATION}"
        log_error "   Potential savings: ~${SAVINGS_PERCENT}%"
        TOTAL_POTENTIAL_SAVINGS=$((TOTAL_POTENTIAL_SAVINGS + SAVINGS_PERCENT))

        # Calculate suggested config
        if [[ $SAVINGS_PERCENT -gt 50 ]]; then
            NEW_EXECUTORS=$(echo "${EXECUTOR_COUNT} * 0.5" | bc 2>/dev/null || echo "$EXECUTOR_COUNT")
        elif [[ $SAVINGS_PERCENT -gt 30 ]]; then
            NEW_EXECUTORS=$(echo "${EXECUTOR_COUNT} * 0.7" | bc 2>/dev/null || echo "$EXECUTOR_COUNT")
        else
            NEW_EXECUTORS=$(echo "${EXECUTOR_COUNT} * 0.8" | bc 2>/dev/null || echo "$EXECUTOR_COUNT")
        fi
        NEW_EXECUTORS=$(printf "%.0f" "$NEW_EXECUTORS")
        if [[ $NEW_EXECUTORS -lt 1 ]]; then NEW_EXECUTORS=1; fi

        echo "   Suggested: ${NEW_EXECUTORS} executors × ${CORES_PER_EXEC} cores × ${MEMORY_PER_EXEC}GB"
        echo ""
        echo "   Command to update:"
        echo "   kubectl patch sparkapplication ${job} -n ${NAMESPACE} --type=json -p='["
        echo "     {\"op\": \"replace\", \"path\": \"/spec/executor/instances\", \"value\": ${NEW_EXECUTORS}}"
        echo "   ]'"
        echo ""
    else
        log_info "✓ Well-provisioned"
    fi

done <<< "$JOBS"

# Summary
log_info "=== Summary ==="
log_info "Total potential savings: ${TOTAL_POTENTIAL_SAVINGS}%"

if [[ $TOTAL_POTENTIAL_SAVINGS -gt 0 ]]; then
    log_error "⚠ Found opportunities for cost optimization"

    # Generate commands file
    COMMANDS_FILE="/tmp/rightsize-commands-${NAMESPACE}.sh"
    echo "#!/bin/bash" > "$COMMANDS_FILE"
    echo "# Auto-generated rightsizing commands for ${NAMESPACE}" >> "$COMMANDS_FILE"
    echo "# Review and execute manually" >> "$COMMANDS_FILE"
    echo "" >> "$COMMANDS_FILE"

    log_info "Commands saved to: ${COMMANDS_FILE}"
fi

exit 0
