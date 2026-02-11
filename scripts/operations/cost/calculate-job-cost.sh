#!/bin/bash
# Job Cost Calculation Script
# Calculates the cost of Spark jobs based on resource usage

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="${NAMESPACE:-spark-operations}"

# Cost rates (USD per unit)
# Adjust these based on your cloud provider pricing
VCPU_COST_PER_HOUR="${VCPU_COST_PER_HOUR:-0.0252}"     # m5.xlarge on-demand
MEMORY_COST_PER_GB_HOUR="${MEMORY_COST_PER_GB_HOUR:-0.014}"  # m5.xlarge
SPOT_VCPU_COST_PER_HOUR="${SPOT_VCPU_COST_PER_HOUR:-0.00756}"  # 70% discount
SPOT_MEMORY_COST_PER_GB_HOUR="${SPOT_MEMORY_COST_PER_GB_HOUR:-0.0042}"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Calculate the cost of Spark jobs.

OPTIONS:
    -j, --job-id ID          Spark job ID (leave empty for all jobs)
    -n, --namespace NAME     Kubernetes namespace (default: spark-operations)
    -p, --period PERIOD      Time period: 1h, 24h, 7d, 30d (default: 24h)
    -o, --output FORMAT      Output format: json|text|table (default: table)
    -s, --spot               Assume spot instances (default: false)
    -h, --help               Show this help

EXAMPLES:
    $(basename "$0") --job-id spark-app-123
    $(basename "$0") --period 7d --output json
    $(basename "$0") --spot --namespace spark-prod
EOF
    exit 1
}

JOB_ID=""
PERIOD="24h"
OUTPUT="table"
SPOT=false

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -j|--job-id)
                JOB_ID="$2"
                shift 2
                ;;
            -n|--namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            -p|--period)
                PERIOD="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT="$2"
                shift 2
                ;;
            -s|--spot)
                SPOT=true
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                echo "Unknown option: $1"
                usage
                ;;
        esac
    done
}

get_job_duration() {
    local job_id="$1"
    local duration_seconds

    # Get job duration from Prometheus
    duration_seconds=$(kubectl exec -n monitoring prometheus-0 -- \
        promtool query instant "spark_job_duration_seconds{application_name=\"$job_id\",namespace=\"$NAMESPACE\"}" \
        2>/dev/null | awk '{print $2}')

    echo "${duration_seconds:-0}"
}

get_executor_count() {
    local job_id="$1"
    local count

    # Get executor count from Prometheus
    count=$(kubectl exec -n monitoring prometheus-0 -- \
        promtool query instant "spark_executor_count{application_name=\"$job_id\",namespace=\"$NAMESPACE\"}" \
        2>/dev/null | awk '{print $2}')

    echo "${count:-0}"
}

get_executor_cores() {
    local job_id="$1"
    local cores

    # Get executor cores from Prometheus
    cores=$(kubectl exec -n monitoring prometheus-0 -- \
        promtool query instant "spark_executor_cores{application_name=\"$job_id\",namespace=\"$NAMESPACE\"}" \
        2>/dev/null | awk '{print $2}')

    echo "${cores:-0}"
}

get_executor_memory() {
    local job_id="$1"
    local memory_gb

    # Get executor memory from Prometheus
    memory_gb=$(kubectl exec -n monitoring prometheus-0 -- \
        promtool query instant "spark_executor_memory{application_name=\"$job_id\",namespace=\"$NAMESPACE\"}" \
        2>/dev/null | awk '{print $2}')

    echo "${memory_gb:-0}"
}

calculate_job_cost() {
    local job_id="$1"

    local duration_seconds=$(get_job_duration "$job_id")
    local duration_hours=$(echo "scale=4; $duration_seconds / 3600" | bc)

    local executor_count=$(get_executor_count "$job_id")
    local executor_cores=$(get_executor_cores "$job_id")
    local executor_memory_gb=$(get_executor_memory "$job_id")

    # Calculate total vCPU-seconds and GB-seconds
    local total_vcpu_hours=$(echo "scale=4; $executor_count * $executor_cores * $duration_hours" | bc)
    local total_memory_gb_hours=$(echo "scale=4; $executor_count * $executor_memory_gb * $duration_hours" | bc)

    # Calculate costs
    local vcpu_cost_rate=$VCPU_COST_PER_HOUR
    local memory_cost_rate=$MEMORY_COST_PER_GB_HOUR

    if [[ "$SPOT" == true ]]; then
        vcpu_cost_rate=$SPOT_VCPU_COST_PER_HOUR
        memory_cost_rate=$SPOT_MEMORY_COST_PER_GB_HOUR
    fi

    local vcpu_cost=$(echo "scale=4; $total_vcpu_hours * $vcpu_cost_rate" | bc)
    local memory_cost=$(echo "scale=4; $total_memory_gb_hours * $memory_cost_rate" | bc)
    local total_cost=$(echo "scale=4; $vcpu_cost + $memory_cost" | bc)

    echo "$job_id|$duration_hours|$executor_count|$total_vcpu_hours|$total_memory_gb_hours|$vcpu_cost|$memory_cost|$total_cost"
}

get_all_jobs() {
    # Get all Spark jobs from Prometheus
    kubectl exec -n monitoring prometheus-0 -- \
        promtool query label-values "spark_job_duration_seconds{namespace=\"$NAMESPACE\"}" application_name \
        2>/dev/null | grep -v "application_name" || echo ""
}

format_output() {
    case "$OUTPUT" in
        json)
            format_json
            ;;
        text)
            format_text
            ;;
        table)
            format_table
            ;;
        *)
            echo "Invalid output format: $OUTPUT"
            exit 1
            ;;
    esac
}

format_json() {
    echo "{"
    echo "  \"period\": \"$PERIOD\","
    echo "  \"spot\": $SPOT,"
    echo "  \"jobs\": ["

    local first=true
    if [[ -n "$JOB_ID" ]]; then
        local data=$(calculate_job_cost "$JOB_ID")
        [[ "$first" == true ]] || echo ","
        first=false
        format_job_json "$data"
    else
        for job in $(get_all_jobs); do
            local data=$(calculate_job_cost "$job")
            [[ "$first" == true ]] || echo ","
            first=false
            format_job_json "$data"
        done
    fi

    echo ""
    echo "  ]"
    echo "}"
}

format_job_json() {
    local data="$1"
    local job_id=$(echo "$data" | cut -d'|' -f1)
    local duration=$(echo "$data" | cut -d'|' -f2)
    local executors=$(echo "$data" | cut -d'|' -f3)
    local vcpu_hours=$(echo "$data" | cut -d'|' -f4)
    local memory_hours=$(echo "$data" | cut -d'|' -f5)
    local vcpu_cost=$(echo "$data" | cut -d'|' -f6)
    local memory_cost=$(echo "$data" | cut -d'|' -f7)
    local total_cost=$(echo "$data" | cut -d'|' -f8)

    echo "    {"
    echo "      \"job_id\": \"$job_id\","
    echo "      \"duration_hours\": $duration,"
    echo "      \"executor_count\": $executors,"
    echo "      \"vcpu_hours\": $vcpu_hours,"
    echo "      \"memory_gb_hours\": $memory_hours,"
    echo "      \"vcpu_cost\": \$$vcpu_cost,"
    echo "      \"memory_cost\": \$$memory_cost,"
    echo "      \"total_cost\": \$$total_cost"
    echo -n "    }"
}

format_text() {
    echo "Job Cost Report"
    echo "==============="
    echo "Period: $PERIOD"
    echo "Spot Instances: $SPOT"
    echo ""

    if [[ -n "$JOB_ID" ]]; then
        local data=$(calculate_job_cost "$JOB_ID")
        print_job_text "$data"
    else
        for job in $(get_all_jobs); do
            local data=$(calculate_job_cost "$job")
            print_job_text "$data"
            echo ""
        done
    fi
}

print_job_text() {
    local data="$1"
    local job_id=$(echo "$data" | cut -d'|' -f1)
    local duration=$(echo "$data" | cut -d'|' -f2)
    local executors=$(echo "$data" | cut -d'|' -f3)
    local vcpu_hours=$(echo "$data" | cut -d'|' -f4)
    local memory_hours=$(echo "$data" | cut -d'|' -f5)
    local vcpu_cost=$(echo "$data" | cut -d'|' -f6)
    local memory_cost=$(echo "$data" | cut -d'|' -f7)
    local total_cost=$(echo "$data" | cut -d'|' -f8)

    echo "Job: $job_id"
    echo "  Duration: $duration hours"
    echo "  Executors: $executors"
    echo "  vCPU Hours: $vcpu_hours"
    echo "  Memory GB-Hours: $memory_hours"
    echo "  vCPU Cost: \$$vcpu_cost"
    echo "  Memory Cost: \$$memory_cost"
    echo "  Total Cost: \$$total_cost"
}

format_table() {
    printf "%-30s %-10s %-10s %-12s %-15s %-10s %-10s %-10s\n" \
        "Job ID" "Duration" "Executors" "vCPU-Hours" "Memory-GB-Hours" "vCPU Cost" "Mem Cost" "Total Cost"
    printf "%-30s %-10s %-10s %-12s %-15s %-10s %-10s %-10s\n" \
        "-------" "--------" "---------" "----------" "---------------" "---------" "--------" "----------"

    local total_vcpu_cost=0
    local total_memory_cost=0
    local total_all_cost=0

    if [[ -n "$JOB_ID" ]]; then
        local data=$(calculate_job_cost "$JOB_ID")
        print_job_table "$data"
    else
        for job in $(get_all_jobs); do
            local data=$(calculate_job_cost "$job")
            print_job_table "$data"
            local vcpu_cost=$(echo "$data" | cut -d'|' -f6)
            local memory_cost=$(echo "$data" | cut -d'|' -f7)
            local all_cost=$(echo "$data" | cut -d'|' -f8)
            total_vcpu_cost=$(echo "$total_vcpu_cost + $vcpu_cost" | bc)
            total_memory_cost=$(echo "$total_memory_cost + $memory_cost" | bc)
            total_all_cost=$(echo "$total_all_cost + $all_cost" | bc)
        done
    fi

    echo ""
    printf "%-30s %-10s %-10s %-12s %-15s %-10s %-10s %-10s\n" \
        "" "" "" "" "" "-------" "--------" "----------"
    printf "%-30s %-10s %-10s %-12s %-15s %-10s %-10s %-10s\n" \
        "TOTAL" "" "" "" "" "\$$total_vcpu_cost" "\$$total_memory_cost" "\$$total_all_cost"
}

print_job_table() {
    local data="$1"
    local job_id=$(echo "$data" | cut -d'|' -f1)
    local duration=$(echo "$data" | cut -d'|' -f2)
    local executors=$(echo "$data" | cut -d'|' -f3)
    local vcpu_hours=$(echo "$data" | cut -d'|' -f4)
    local memory_hours=$(echo "$data" | cut -d'|' -f5)
    local vcpu_cost=$(echo "$data" | cut -d'|' -f6)
    local memory_cost=$(echo "$data" | cut -d'|' -f7)
    local total_cost=$(echo "$data" | cut -d'|' -f8)

    printf "%-30s %-10s %-10s %-12s %-15s %-10s %-10s %-10s\n" \
        "$job_id" "$duration" "$executors" "$vcpu_hours" "$memory_hours" "\$$vcpu_cost" "\$$memory_cost" "\$$total_cost"
}

main() {
    parse_args "$@"

    # Check for bc calculator
    if ! command -v bc &> /dev/null; then
        echo "Error: bc is required but not installed"
        exit 1
    fi

    # Check for kubectl
    if ! command -v kubectl &> /dev/null; then
        echo "Error: kubectl is required but not installed"
        exit 1
    fi

    format_output
}

main "$@"
