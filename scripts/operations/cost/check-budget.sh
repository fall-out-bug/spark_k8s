#!/bin/bash
# Budget Check Script
# Checks budget status and alerts on thresholds

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="${NAMESPACE:-spark-operations}"
PERIOD="${1:-daily}"

# Threshold percentages
WARNING_THRESHOLD="${WARNING_THRESHOLD:-70}"
CRITICAL_THRESHOLD="${CRITICAL_THRESHOLD:-90}"
EXCEED_THRESHOLD="${EXCEED_THRESHOLD:-100}"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Check budget status and alert on thresholds.

OPTIONS:
    -p, --period PERIOD      Check period: daily|weekly|monthly (default: daily)
    -n, --namespace NAME     Kubernetes namespace (default: spark-operations)
    -o, --output FILE        Output file (default: stdout)
    -w, --warning NUM        Warning threshold % (default: 70)
    -c, --critical NUM       Critical threshold % (default: 90)
    -e, --exceed NUM         Exceed threshold % (default: 100)
    -h, --help               Show this help

EXAMPLES:
    $(basename "$0") --period weekly
    $(basename "$0") -o budget-status.json
EOF
    exit 1
}

OUTPUT_FILE=""

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--period)
                PERIOD="$2"
                shift 2
                ;;
            -n|--namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            -w|--warning)
                WARNING_THRESHOLD="$2"
                shift 2
                ;;
            -c|--critical)
                CRITICAL_THRESHOLD="$2"
                shift 2
                ;;
            -e|--exceed)
                EXCEED_THRESHOLD="$2"
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

get_budget_config() {
    kubectl get configmap -n "$NAMESPACE" cost-budgets -o jsonpath='{.data.budgets\.yaml}' 2>/dev/null || echo ""
}

get_team_budget() {
    local team="$1"
    local config=$(get_budget_config)
    echo "$config" | yq eval ".teams.$team.monthly_budget" -
}

get_team_spending() {
    local team="$1"
    "$SCRIPT_DIR/calculate-team-cost.sh" \
        --team "$team" \
        --namespace "$NAMESPACE" \
        --period "$PERIOD" \
        --output json 2>/dev/null | jq -r '.teams[0].total_cost // 0' | sed 's/[$,]//g'
}

calculate_percentage() {
    local spending="$1"
    local budget="$2"

    if [[ "$budget" -eq 0 ]]; then
        echo "0"
    else
        echo "scale=2; ($spending / $budget) * 100" | bc
    fi
}

get_status() {
    local percentage="$1"
    local percent_int=$(echo "$percentage" | cut -d. -f1)

    if [[ $percent_int -ge $EXCEED_THRESHOLD ]]; then
        echo "EXCEED"
    elif [[ $percent_int -ge $CRITICAL_THRESHOLD ]]; then
        echo "CRITICAL"
    elif [[ $percent_int -ge $WARNING_THRESHOLD ]]; then
        echo "WARNING"
    else
        echo "OK"
    fi
}

check_team_budget() {
    local team="$1"

    local budget=$(get_team_budget "$team")
    local spending=$(get_team_spending "$team")
    local percentage=$(calculate_percentage "$spending" "$budget")
    local status=$(get_status "$percentage")

    echo "$team|$budget|$spending|$percentage|$status"
}

format_output() {
    if [[ -n "$OUTPUT_FILE" ]]; then
        format_json > "$OUTPUT_FILE"
        echo "Budget status saved to: $OUTPUT_FILE"
    else
        format_table
    fi
}

format_json() {
    echo "{"
    echo "  \"period\": \"$PERIOD\","
    echo "  \"namespace\": \"$NAMESPACE\","
    echo "  \"thresholds\": {"
    echo "    \"warning\": $WARNING_THRESHOLD,"
    echo "    \"critical\": $CRITICAL_THRESHOLD,"
    echo "    \"exceed\": $EXCEED_THRESHOLD"
    echo "  },"
    echo "  \"teams\": ["

    local first=true
    local config=$(get_budget_config)
    local teams=$(echo "$config" | yq eval '.teams | keys | .[]' -)

    for team in $teams; do
        [[ "$first" == true ]] || echo ","
        first=false
        local data=$(check_team_budget "$team")
        format_team_json "$data"
    done

    echo ""
    echo "  ]"
    echo "}"
}

format_team_json() {
    local data="$1"
    local team=$(echo "$data" | cut -d'|' -f1)
    local budget=$(echo "$data" | cut -d'|' -f2)
    local spending=$(echo "$data" | cut -d'|' -f3)
    local percentage=$(echo "$data" | cut -d'|' -f4)
    local status=$(echo "$data" | cut -d'|' -f5)

    echo "    {"
    echo "      \"team\": \"$team\","
    echo "      \"budget\": \$$budget,"
    echo "      \"spending\": \$$spending,"
    echo "      \"percentage\": $percentage%,"
    echo "      \"status\": \"$status\""
    echo -n "    }"
}

format_table() {
    printf "%-20s %-12s %-12s %-12s %-12s\n" \
        "Team" "Budget" "Spending" "Percentage" "Status"
    printf "%-20s %-12s %-12s %-12s %-12s\n" \
        "----" "------" "--------" "-----------" "------"

    local config=$(get_budget_config)
    local teams=$(echo "$config" | yq eval '.teams | keys | .[]' -)

    for team in $teams; do
        local data=$(check_team_budget "$team")
        print_team_table "$data"
    done
}

print_team_table() {
    local data="$1"
    local team=$(echo "$data" | cut -d'|' -f1)
    local budget=$(echo "$data" | cut -d'|' -f2)
    local spending=$(echo "$data" | cut -d'|' -f3)
    local percentage=$(echo "$data" | cut -d'|' -f4)
    local status=$(echo "$data" | cut -d'|' -f5)

    local status_color=""
    case "$status" in
        EXCEED)
            status_color="\033[31m"  # Red
            ;;
        CRITICAL)
            status_color="\033[33m"  # Yellow
            ;;
        WARNING)
            status_color="\033[36m"  # Cyan
            ;;
        *)
            status_color="\033[32m"  # Green
            ;;
    esac

    printf "%-20s %-12s %-12s %-12s ${status_color}%-12s\033[0m\n" \
        "$team" "\$$budget" "\$$spending" "$percentage%" "$status"
}

send_alerts() {
    local config=$(get_budget_config)
    local teams=$(echo "$config" | yq eval '.teams | keys | .[]' -)

    for team in $teams; do
        local data=$(check_team_budget "$team")
        local status=$(echo "$data" | cut -d'|' -f5)
        local team_name=$(echo "$data" | cut -d'|' -f1)
        local percentage=$(echo "$data" | cut -d'|' -f4)

        if [[ "$status" == "WARNING" ]] || [[ "$status" == "CRITICAL" ]] || [[ "$status" == "EXCEED" ]]; then
            echo "Sending $status alert for team $team_name ($percentage%)"
            # Send to Slack
            # Send email
        fi
    done
}

main() {
    parse_args "$@"

    echo "Budget Status Report"
    echo "==================="
    echo "Period: $PERIOD"
    echo "Namespace: $NAMESPACE"
    echo "Thresholds: Warning=$WARNING_THRESHOLD%, Critical=$CRITICAL_THRESHOLD%, Exceed=$EXCEED_THRESHOLD%"
    echo ""

    format_output
    send_alerts
}

main "$@"
