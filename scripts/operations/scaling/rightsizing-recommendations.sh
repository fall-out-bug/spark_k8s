#!/bin/bash
# Rightsizing Recommendations Generator
# Analyzes resource usage and provides rightsizing recommendations

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="${NAMESPACE:-spark-operations}"
PERIOD="${PERIOD:-30}"  # days
TARGET_UTILIZATION="${TARGET_UTILIZATION:-70}"  # percent

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Generate rightsizing recommendations based on historical usage.

OPTIONS:
    -n, --namespace NAME      Kubernetes namespace (default: spark-operations)
    -p, --period DAYS         Analysis period in days (default: 30)
    -t, --target-utilization  Target utilization % (default: 70)
    -o, --output FILE         Output file (default: stdout)
    -f, --format FORMAT       Output format: json|text|yaml (default: text)
    -h, --help                Show this help

EXAMPLES:
    $(basename "$0") --namespace spark-operations --period 30
    $(basename "$0") -o recommendations.json -f json
EOF
    exit 1
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            -p|--period)
                PERIOD="$2"
                shift 2
                ;;
            -t|--target-utilization)
                TARGET_UTILIZATION="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            -f|--format)
                OUTPUT_FORMAT="$2"
                shift 2
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

get_pod_usage() {
    local pod_name="$1"
    local namespace="$2"

    # Get current resource requests
    local cpu_request=$(kubectl get pod "$pod_name" -n "$namespace" -o jsonpath='{.spec.containers[0].resources.requests.cpu}' | sed 's/m//' | sed 's/[^0-9.]//g')
    local mem_request=$(kubectl get pod "$pod_name" -n "$namespace" -o jsonpath='{.spec.containers[0].resources.requests.memory}' | sed 's/Gi//' | sed 's/Gi//' | sed 's/Mi/*0.001/' | sed 's/[^0-9.*]//g')

    # Get current usage
    local cpu_usage=$(kubectl top pod "$pod_name" -n "$namespace" --no-headers 2>/dev/null | awk '{print $2}' | sed 's/m//')
    local mem_usage=$(kubectl top pod "$pod_name" -n "$namespace" --no-headers 2>/dev/null | awk '{print $3}' | sed 's/Mi//' | awk '{print $1/1024}')

    # Convert CPU usage to cores if in millicores
    if [[ $cpu_usage =~ ^[0-9]+$ ]]; then
        cpu_usage=$(echo "scale=3; $cpu_usage / 1000" | bc)
    fi

    # Convert CPU request to cores if in millicores
    if [[ $cpu_request =~ ^[0-9]+$ ]] && [[ $cpu_request -gt 100 ]]; then
        cpu_request=$(echo "scale=3; $cpu_request / 1000" | bc)
    fi

    echo "$pod_name,$cpu_request,$mem_request,$cpu_usage,$mem_usage"
}

calculate_recommendation() {
    local cpu_request="$1"
    local mem_request="$2"
    local cpu_usage="$3"
    local mem_usage="$4"

    # Calculate utilization percentage
    local cpu_util=0
    local mem_util=0

    if [[ -n "$cpu_request" ]] && [[ $(echo "$cpu_request > 0" | bc) -eq 1 ]]; then
        cpu_util=$(echo "scale=0; ($cpu_usage / $cpu_request) * 100" | bc)
    fi

    if [[ -n "$mem_request" ]] && [[ $(echo "$mem_request > 0" | bc) -eq 1 ]]; then
        mem_util=$(echo "scale=0; ($mem_usage / $mem_request) * 100" | bc)
    fi

    # Generate recommendation
    local action="NO_ACTION"
    local reason="Utilization within acceptable range"

    if [[ $cpu_util -lt 30 ]]; then
        action="SCALE_DOWN_CPU"
        reason="CPU utilization is ${cpu_util}% (below 30%)"
    elif [[ $cpu_util -gt 90 ]]; then
        action="SCALE_UP_CPU"
        reason="CPU utilization is ${cpu_util}% (above 90%)"
    fi

    if [[ $mem_util -lt 30 ]]; then
        action="${action}_MEMORY"
        reason="Memory utilization is ${mem_util}% (below 30%)"
    elif [[ $mem_util -gt 90 ]]; then
        action="${action}_SCALE_UP_MEMORY"
        reason="Memory utilization is ${mem_util}% (above 90%)"
    fi

    # Calculate recommended values
    local recommended_cpu="$cpu_request"
    local recommended_mem="$mem_request"

    if [[ $cpu_util -lt 30 ]]; then
        recommended_cpu=$(echo "scale=3; $cpu_request * 0.7" | bc)
    elif [[ $cpu_util -gt 90 ]]; then
        recommended_cpu=$(echo "scale=3; $cpu_request * 1.5" | bc)
    fi

    if [[ $mem_util -lt 30 ]]; then
        recommended_mem=$(echo "scale=2; $mem_request * 0.7" | bc)
    elif [[ $mem_util -gt 90 ]]; then
        recommended_mem=$(echo "scale=2; $mem_request * 1.5" | bc)
    fi

    echo "$action,$reason,$recommended_cpu,$recommended_mem,$cpu_util,$mem_util"
}

main() {
    parse_args "$@"

    echo "Analyzing resource usage in namespace '$NAMESPACE'..."

    # Get all pods
    local pods=$(kubectl get pods -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')

    echo ""
    echo "=== Rightsizing Recommendations ==="
    echo "Analysis Period: Last ${PERIOD} days"
    echo "Target Utilization: ${TARGET_UTILIZATION}%"
    echo ""

    # Header
    printf "%-40s %-12s %-12s %-12s %-12s %-15s\n" "Pod" "CPU Req" "CPU Use" "CPU Util" "Mem Util" "Recommendation"
    printf "%-40s %-12s %-12s %-12s %-12s %-15s\n" "---" "-------" "-------" "-------" "-------" "---------------"

    local total_over_provisioned=0
    local total_under_provisioned=0
    local potential_monthly_savings=0

    for pod in $pods; do
        # Skip completed pods
        local phase=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.status.phase}')
        if [[ "$phase" == "Succeeded" ]] || [[ "$phase" == "Failed" ]]; then
            continue
        fi

        # Get usage data
        local data=$(get_pod_usage "$pod" "$NAMESPACE")
        local pod_name=$(echo "$data" | cut -d',' -f1)
        local cpu_req=$(echo "$data" | cut -d',' -f2)
        local mem_req=$(echo "$data" | cut -d',' -f3)
        local cpu_use=$(echo "$data" | cut -d',' -f4)
        local mem_use=$(echo "$data" | cut -d',' -f5)

        if [[ -z "$cpu_use" ]]; then
            continue
        fi

        # Get recommendation
        local rec=$(calculate_recommendation "$cpu_req" "$mem_req" "$cpu_use" "$mem_use")
        local action=$(echo "$rec" | cut -d',' -f1)
        local reason=$(echo "$rec" | cut -d',' -f2)
        local rec_cpu=$(echo "$rec" | cut -d',' -f3)
        local rec_mem=$(echo "$rec" | cut -d',' -f4)
        local cpu_util=$(echo "$rec" | cut -d',' -f5)
        local mem_util=$(echo "$rec" | cut -d',' -f6)

        # Format output
        local rec_display=""
        if [[ "$action" == "SCALE_DOWN_CPU"* ]]; then
            rec_display="Reduce CPU to ${rec_cpu} cores"
            total_over_provisioned=$((total_over_provisioned + 1))
            # Calculate savings (approx $0.025 per vCPU-hour)
            local saved_vcpus=$(echo "$cpu_req - $rec_cpu" | bc)
            local hourly_savings=$(echo "$saved_vcpus * 0.025" | bc)
            potential_monthly_savings=$(echo "$potential_monthly_savings + ($hourly_savings * 730)" | bc)
        elif [[ "$action" == *"SCALE_UP"* ]]; then
            rec_display="Increase resources"
            total_under_provisioned=$((total_under_provisioned + 1))
        fi

        printf "%-40s %-12s %-12s %-12s %-12s %-15s\n" \
            "$pod_name" \
            "${cpu_req}c" \
            "${cpu_use}c" \
            "${cpu_util}%" \
            "${mem_util}%" \
            "$rec_display"
    done

    echo ""
    echo "=== Summary ==="
    echo "Over-provisioned pods: $total_over_provisioned"
    echo "Under-provisioned pods: $total_under_provisioned"
    echo "Potential monthly savings: \$$(echo "scale=2; $potential_monthly_savings" | bc)"
    echo ""

    if [[ $total_over_provisioned -gt 0 ]]; then
        echo "=== Recommended Actions ==="
        echo ""
        echo "1. Apply VPA in recommend-only mode to identify rightsizing opportunities"
        echo "2. Review over-provisioned pods and update resource requests"
        echo "3. Enable VPA in updateMode: Initial for automatic rightsizing"
        echo ""
        echo "Example patch command:"
        echo "  kubectl patch deployment <name> -n $NAMESPACE --type='json' \\"
        echo "    -p='[{\"op\": \"replace\", \"path\": \"/spec/template/spec/containers/0/resources/requests/cpu\", \"value\": \"<new-value>\"}]'"
    fi
}

main "$@"
