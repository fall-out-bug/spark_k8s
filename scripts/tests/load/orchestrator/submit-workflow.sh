#!/bin/bash
# Workflow Submission Script
# Part of WS-013-09: Argo Workflows Integration
#
# Submits load test workflow to Argo for execution.

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
WORKFLOW_FILE="$PROJECT_ROOT/scripts/tests/load/workflows/load-test-workflow.yaml"
NAMESPACE="${ARGO_NAMESPACE:-argo}"

# Tier configurations
TIER_CONFIGS=(
    "p0_smoke:4:3.5.0,4.1.0:connect:kubernetes:none:read:1gb"
    "p1_core:8:3.5.0,4.1.0:connect,operator:kubernetes,standalone:none,iceberg,rapids:read,aggregate,join:1gb,11gb"
    "p2_full:4:3.5.0,4.1.0:connect,operator:kubernetes,standalone:none,iceberg,rapids,iceberg+rapids:read,aggregate,join,window,write:1gb,11gb"
)

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

usage() {
    cat <<EOF
Usage: $0 <tier> [OPTIONS]

Tiers:
  p0_smoke   Smoke tests (64 combinations, ~30 min)
  p1_core    Core tests (384 combinations, ~4 hours)
  p2_full    Full matrix (1280 combinations, ~48 hours)

Options:
  --dry-run      Print workflow without submitting
  --watch        Watch workflow after submission
  --namespace N  Argo namespace (default: argo)
  -h, --help     Show this help

Example:
  $0 p0_smoke --watch
EOF
}

get_tier_config() {
    local tier="$1"
    for config in "${TIER_CONFIGS[@]}"; do
        if [[ "$config" == "$tier:"* ]]; then
            echo "$config"
            return 0
        fi
    done
    return 1
}

parse_tier_config() {
    local config="$1"
    IFS=':' read -ra PARTS <<< "$config"
    echo "${PARTS[@]}"
}

submit_workflow() {
    local tier="$1"
    local dry_run="${2:-false}"

    # Get tier configuration
    local tier_config
    tier_config=$(get_tier_config "$tier")

    if [ -z "$tier_config" ]; then
        log_error "Unknown tier: $tier"
        return 1
    fi

    # Parse configuration
    local parts
    parts=$(parse_tier_config "$tier_config")
    read -r _ parallelism spark_versions orchestrators modes extensions operations data_sizes <<< "$parts"

    log_info "Submitting $tier tier workflow"
    log_info "  Parallelism: $parallelism"
    log_info "  Spark versions: $spark_versions"
    log_info "  Orchestrators: $orchestrators"
    log_info "  Modes: $modes"
    log_info "  Extensions: $extensions"
    log_info "  Operations: $operations"
    log_info "  Data sizes: $data_sizes"

    # Check if workflow file exists
    if [ ! -f "$WORKFLOW_FILE" ]; then
        log_error "Workflow file not found: $WORKFLOW_FILE"
        return 1
    fi

    # Build argo command
    local cmd="argo submit $WORKFLOW_FILE"
    cmd="$cmd --namespace $NAMESPACE"
    cmd="$cmd --parameter tier=$tier"
    cmd="$cmd --parameter parallelism=$parallelism"
    cmd="$cmd --parameter spark_versions=$spark_versions"
    cmd="$cmd --parameter orchestrators=$orchestrators"
    cmd="$cmd --parameter modes=$modes"
    cmd="$cmd --parameter extensions=$extensions"
    cmd="$cmd --parameter operations=$operations"
    cmd="$cmd --parameter data_sizes=$data_sizes"
    cmd="$cmd --generate-name"

    if [ "$dry_run" = "true" ]; then
        log_info "Dry run - would execute:"
        echo "  $cmd"
        return 0
    fi

    # Submit workflow
    log_info "Submitting workflow..."
    local output
    output=$($cmd 2>&1)

    if [ $? -ne 0 ]; then
        log_error "Failed to submit workflow"
        echo "$output"
        return 1
    fi

    # Extract workflow name
    local workflow_name
    workflow_name=$(echo "$output" | grep -oP 'Name:\s*\K\S+' || echo "$output" | head -1)

    log_success "Workflow submitted: $workflow_name"
    log_info "Track with: argo get $workflow_name -n $NAMESPACE"
    log_info "UI: https://localhost:2746/workflows/$NAMESPACE/$workflow_name"

    echo "$workflow_name"
}

watch_workflow() {
    local workflow_name="$1"

    log_info "Watching workflow: $workflow_name"
    argo watch "$workflow_name" -n "$NAMESPACE"
}

main() {
    if [ $# -lt 1 ]; then
        usage
        exit 1
    fi

    local tier="$1"
    shift

    local dry_run=false
    local watch=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                dry_run=true
                shift
                ;;
            --watch)
                watch=true
                shift
                ;;
            --namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    # Validate tier
    case "$tier" in
        p0_smoke|p1_core|p2_full)
            ;;
        *)
            log_error "Invalid tier: $tier"
            usage
            exit 1
            ;;
    esac

    # Submit workflow
    local workflow_name
    workflow_name=$(submit_workflow "$tier" "$dry_run")

    if [ $? -ne 0 ]; then
        exit 1
    fi

    if [ "$dry_run" = "true" ]; then
        exit 0
    fi

    # Watch if requested
    if [ "$watch" = "true" ]; then
        watch_workflow "$workflow_name"
    fi
}

main "$@"
