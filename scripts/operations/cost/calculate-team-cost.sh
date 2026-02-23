#!/bin/bash
# Team Cost Calculation Script
# Aggregates costs by team based on job labels

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="${NAMESPACE:-spark-operations}"
PERIOD="${PERIOD:-30d}"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Calculate costs aggregated by team.

OPTIONS:
    -n, --namespace NAME     Kubernetes namespace (default: spark-operations)
    -p, --period PERIOD      Time period: 7d, 30d, 90d (default: 30d)
    -t, --team TEAM          Specific team (leave empty for all teams)
    -o, --output FILE        Output file (default: stdout)
    -h, --help               Show this help

EXAMPLES:
    $(basename "$0") --period 30d
    $(basename "$0") --team data-science --output team-costs.json
EOF
    exit 1
}

TEAM=""
OUTPUT_FILE=""

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
            -t|--team)
                TEAM="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_FILE="$2"
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

get_teams() {
    # Get unique team labels from Spark jobs
    kubectl get sparkapplications -n "$NAMESPACE" \
        -o jsonpath='{.items[*].metadata.labels.team}' | tr ' ' '\n' | sort -u
}

get_team_jobs() {
    local team="$1"
    kubectl get sparkapplications -n "$NAMESPACE" -l "team=$team" \
        -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n'
}

get_team_cost() {
    local team="$1"

    echo "Calculating cost for team: $team..."

    local total_cost=0
    local total_jobs=0
    local total_vcpu_hours=0
    local total_memory_gb_hours=0

    for job in $(get_team_jobs "$team"); do
        local job_cost=$("$SCRIPT_DIR/calculate-job-cost.sh" \
            --job-id "$job" \
            --namespace "$NAMESPACE" \
            --period "$PERIOD" \
            --output json 2>/dev/null | jq -r '.jobs[0].total_cost // 0')

        job_cost=$(echo "$job_cost" | sed 's/[$,]//g')
        total_cost=$(echo "$total_cost + $job_cost" | bc)
        total_jobs=$((total_jobs + 1))

        # Get resource usage
        local vcpu_hours=$("$SCRIPT_DIR/calculate-job-cost.sh" \
            --job-id "$job" \
            --namespace "$NAMESPACE" \
            --period "$PERIOD" \
            --output json 2>/dev/null | jq -r '.jobs[0].vcpu_hours // 0')

        local memory_hours=$("$SCRIPT_DIR/calculate-job-cost.sh" \
            --job-id "$job" \
            --namespace "$NAMESPACE" \
            --period "$PERIOD" \
            --output json 2>/dev/null | jq -r '.jobs[0].memory_gb_hours // 0')

        total_vcpu_hours=$(echo "$total_vcpu_hours + $vcpu_hours" | bc)
        total_memory_gb_hours=$(echo "$total_memory_gb_hours + $memory_hours" | bc)
    done

    echo "$team|$total_cost|$total_jobs|$total_vcpu_hours|$total_memory_gb_hours"
}

format_output() {
    if [[ -n "$OUTPUT_FILE" ]]; then
        format_json > "$OUTPUT_FILE"
        echo "Team cost report saved to: $OUTPUT_FILE"
    else
        format_table
    fi
}

format_json() {
    echo "{"
    echo "  \"period\": \"$PERIOD\","
    echo "  \"namespace\": \"$NAMESPACE\","
    echo "  \"teams\": ["

    local first=true
    if [[ -n "$TEAM" ]]; then
        [[ "$first" == true ]] || echo ","
        first=false
        local data=$(get_team_cost "$TEAM")
        format_team_json "$data"
    else
        for team in $(get_teams); do
            [[ "$first" == true ]] || echo ","
            first=false
            local data=$(get_team_cost "$team")
            format_team_json "$data"
        done
    fi

    echo ""
    echo "  ]"
    echo "}"
}

format_team_json() {
    local data="$1"
    local team=$(echo "$data" | cut -d'|' -f1)
    local cost=$(echo "$data" | cut -d'|' -f2)
    local jobs=$(echo "$data" | cut -d'|' -f3)
    local vcpu_hours=$(echo "$data" | cut -d'|' -f4)
    local memory_hours=$(echo "$data" | cut -d'|' -f5)

    echo "    {"
    echo "      \"team\": \"$team\","
    echo "      \"total_cost\": \$$cost,"
    echo "      \"job_count\": $jobs,"
    echo "      \"vcpu_hours\": $vcpu_hours,"
    echo "      \"memory_gb_hours\": $memory_hours"
    echo -n "    }"
}

format_table() {
    printf "%-20s %-12s %-10s %-15s %-15s %-15s\n" \
        "Team" "Total Cost" "Jobs" "vCPU-Hours" "Memory-GB-Hours" "Avg Cost/Job"
    printf "%-20s %-12s %-10s %-15s %-15s %-15s\n" \
        "----" "----------" "----" "----------" "---------------" "-------------"

    local grand_total=0
    local total_jobs=0

    if [[ -n "$TEAM" ]]; then
        local data=$(get_team_cost "$TEAM")
        print_team_table "$data"
    else
        for team in $(get_teams); do
            local data=$(get_team_cost "$team")
            print_team_table "$data"
            local cost=$(echo "$data" | cut -d'|' -f2)
            local jobs=$(echo "$data" | cut -d'|' -f3)
            grand_total=$(echo "$grand_total + $cost" | bc)
            total_jobs=$((total_jobs + jobs))
        done
    fi

    echo ""
    printf "%-20s %-12s %-10s %-15s %-15s %-15s\n" \
        "" "----------" "----" "----------" "---------------" "-------------"
    printf "%-20s %-12s %-10s %-15s %-15s %-15s\n" \
        "TOTAL" "\$$grand_total" "$total_jobs" "" "" ""
}

print_team_table() {
    local data="$1"
    local team=$(echo "$data" | cut -d'|' -f1)
    local cost=$(echo "$data" | cut -d'|' -f2)
    local jobs=$(echo "$data" | cut -d'|' -f3)
    local vcpu_hours=$(echo "$data" | cut -d'|' -f4)
    local memory_hours=$(echo "$data" | cut -d'|' -f5)
    local avg_cost=0

    if [[ $jobs -gt 0 ]]; then
        avg_cost=$(echo "scale=2; $cost / $jobs" | bc)
    fi

    printf "%-20s %-12s %-10s %-15s %-15s %-15s\n" \
        "$team" "\$$cost" "$jobs" "$vcpu_hours" "$memory_hours" "\$$avg_cost"
}

main() {
    parse_args "$@"

    echo "Team Cost Report"
    echo "================"
    echo "Period: $PERIOD"
    echo "Namespace: $NAMESPACE"
    echo ""

    format_output
}

main "$@"
