#!/bin/bash
# Workflow Monitoring Script
# Part of WS-013-09: Argo Workflows Integration
#
# Monitors workflow execution with real-time status updates.

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
NAMESPACE="${ARGO_NAMESPACE:-argo}"
REFRESH_INTERVAL="${REFRESH_INTERVAL:-5}"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Workflow status colors
color_status() {
    local status="$1"
    case "$status" in
        Succeeded)
            echo -e "${GREEN}$status${NC}"
            ;;
        Running|Pending)
            echo -e "${BLUE}$status${NC}"
            ;;
        Failed|Error)
            echo -e "${RED}$status${NC}"
            ;;
        *)
            echo "$status"
            ;;
    esac
}

# Get workflow status
get_workflow_status() {
    local workflow_name="$1"
    argo get "$workflow_name" -n "$NAMESPACE" -o json 2>/dev/null || echo '{}'
}

# Parse status from JSON
parse_status() {
    local json="$1"
    echo "$json" | jq -r '.status.phase // "Unknown"'
}

# Parse progress
parse_progress() {
    local json="$1"
    local total_steps
    local completed_steps

    total_steps=$(echo "$json" | jq -r '.status.nodes | length // 0')
    completed_steps=$(echo "$json" | jq -r '[.status.nodes[] | select(.phase == "Succeeded")] | length // 0')

    echo "${completed_steps}/${total_steps}"
}

# Print workflow header
print_header() {
    local workflow_name="$1"
    local status="$2"
    local progress="$3"

    clear
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Workflow Monitor${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Workflow: $workflow_name"
    echo "Status: $(color_status "$status")"
    echo "Progress: $progress"
    echo ""
    echo -e "${BLUE}───────────────────────────────────────────────────────────${NC}"
    echo ""
}

# Print node status
print_nodes() {
    local json="$1"
    local nodes
    nodes=$(echo "$json" | jq -r '.status.nodes // {}')

    echo "Workflow Steps:"
    echo ""

    # Get all nodes with names
    echo "$json" | jq -r '.status.nodes | to_entries[] | select(.value.displayName != null) |
        "\(.key | .[0:8]) \(.value.phase | .[0:15]) \(.value.displayName // "Unknown")"' |
    while IFS=' ' read -r node_id phase display_name; do
        color_phase=$(color_status "$phase")
        printf "%-12s %-20s %s\n" "[$node_id]" "$color_phase" "$display_name"
    done
}

# Print active pod logs
print_pod_logs() {
    local workflow_name="$1"

    echo ""
    echo -e "${BLUE}───────────────────────────────────────────────────────────${NC}"
    echo "Active Pod Logs (last 10 lines):"
    echo ""

    # Get workflow pods
    local pods
    pods=$(kubectl get pods -n "$NAMESPACE" \
        -l "workflows.argoproj.io/workflow=$workflow_name" \
        -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")

    if [ -z "$pods" ]; then
        echo "No active pods found"
        return
    fi

    # Get first running pod
    for pod in $pods; do
        local pod_status
        pod_status=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")

        if [ "$pod_status" = "Running" ]; then
            echo "--- $pod ($pod_status) ---"
            kubectl logs "$pod" -n "$NAMESPACE" --tail=10 2>/dev/null || echo "No logs available"
            return
        fi
    done

    echo "No running pods found"
}

# Monitor workflow
monitor_workflow() {
    local workflow_name="$1"

    log_info "Monitoring workflow: $workflow_name"
    log_info "Press Ctrl+C to stop monitoring (workflow continues)"
    echo ""

    while true; do
        # Get workflow status
        local json
        json=$(get_workflow_status "$workflow_name")

        # Check if workflow exists
        if [ "$json" = "{}" ]; then
            log_error "Workflow not found: $workflow_name"
            return 1
        fi

        # Parse status
        local status
        status=$(parse_status "$json")

        local progress
        progress=$(parse_progress "$json")

        # Print status
        print_header "$workflow_name" "$status" "$progress"
        print_nodes "$json"
        print_pod_logs "$workflow_name"

        # Check if workflow completed
        if [ "$status" = "Succeeded" ] || [ "$status" = "Failed" ] || [ "$status" = "Error" ]; then
            echo ""
            if [ "$status" = "Succeeded" ]; then
                log_success "Workflow completed successfully!"
            else
                log_error "Workflow failed with status: $status"
            fi

            echo ""
            echo "Full details:"
            argo get "$workflow_name" -n "$NAMESPACE"
            return 0
        fi

        # Wait before next refresh
        sleep "$REFRESH_INTERVAL"
    done
}

# Main execution
main() {
    if [ $# -lt 1 ]; then
        log_error "Usage: $0 <workflow_name>"
        echo ""
        echo "Example:"
        echo "  $0 load-test-matrix-abc123"
        echo ""
        echo "Or use with submission:"
        echo "  ./submit-workflow.sh p0_smoke --watch"
        exit 1
    fi

    local workflow_name="$1"
    shift

    # Handle options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    # Monitor workflow
    monitor_workflow "$workflow_name"
}

main "$@"
