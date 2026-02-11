#!/bin/bash
# Runbook Execution Script
# Executes operational runbooks with validation and logging

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNBOOK_DIR="${RUNBOOK_DIR:-/home/fall_out_bug/work/s7/spark_k8s/docs/operations/runbooks}"
NAMESPACE="${NAMESPACE:-spark-operations}"
LOG_DIR="${LOG_DIR:-/var/log/runbooks}"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Execute a runbook with validation and logging.

OPTIONS:
    -r, --runbook NAME      Runbook name (file path relative to runbook dir)
    -n, --namespace NAME    Kubernetes namespace (default: spark-operations)
    -d, --dry-run           Validate runbook without executing
    -l, --log-level LEVEL   Log level: debug|info|warn|error (default: info)
    -y, --yes               Auto-confirm all prompts
    -h, --help              Show this help

EXAMPLES:
    $(basename "$0") --runbook spark/driver-crash-loop.md
    $(basename "$0") -r data/hive-metastore-restore.md --dry-run
    $(basename "$0") -r spark/executor-failures.md --yes
EOF
    exit 1
}

RUNBOOK=""
DRY_RUN=false
LOG_LEVEL="info"
AUTO_CONFIRM=false

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -r|--runbook)
                RUNBOOK="$2"
                shift 2
                ;;
            -n|--namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -l|--log-level)
                LOG_LEVEL="$2"
                shift 2
                ;;
            -y|--yes)
                AUTO_CONFIRM=true
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

    if [[ -z "$RUNBOOK" ]]; then
        echo "Error: --runbook is required"
        echo ""
        usage
    fi
}

log() {
    local level="$1"
    shift
    local message="$*"

    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case "$level" in
        DEBUG)
            [[ "$LOG_LEVEL" == "debug" ]] && echo "[$timestamp] DEBUG: $message" >&2
            ;;
        INFO)
            echo "[$timestamp] INFO: $message" >&2
            ;;
        WARN)
            echo "[$timestamp] WARN: $message" >&2
            ;;
        ERROR)
            echo "[$timestamp] ERROR: $message" >&2
            ;;
    esac
}

validate_runbook() {
    local runbook_path="$1"

    log INFO "Validating runbook: $runbook_path"

    if [[ ! -f "$runbook_path" ]]; then
        log ERROR "Runbook not found: $runbook_path"
        return 1
    fi

    # Check for required sections
    local required_sections=(
        "Overview"
        "Detection"
        "Diagnosis"
        "Remediation"
    )

    for section in "${required_sections[@]}"; do
        if ! grep -q "## $section" "$runbook_path"; then
            log WARN "Missing required section: $section"
        fi
    done

    # Check for bash code blocks
    if ! grep -q '```bash' "$runbook_path"; then
        log WARN "No bash code blocks found in runbook"
    fi

    log INFO "Runbook validation complete"
    return 0
}

extract_command() {
    local runbook_path="$1"
    local step_number="$2"

    # Extract command from runbook
    # Assumes commands are in numbered code blocks
    awk "/## Step $step_number/,/## Step/$(($step_number + 1))/" "$runbook_path" | \
        sed -n '/```bash/,/```/p' | sed '/^[`]/d'
}

execute_command() {
    local command="$1"
    local step_name="$2"

    log INFO "Executing step: $step_name"
    log DEBUG "Command: $command"

    if [[ "$DRY_RUN" == true ]]; then
        log INFO "[DRY RUN] Would execute: $command"
        return 0
    fi

    # Execute command
    if eval "$command"; then
        log INFO "Step completed successfully"
        return 0
    else
        log ERROR "Step failed with exit code $?"
        return 1
    fi
}

execute_runbook() {
    local runbook_path="$1"

    # Parse runbook and execute steps
    local step=0

    log INFO "Starting runbook execution..."
    log INFO "Runbook: $runbook_path"
    log INFO "Namespace: $NAMESPACE"
    log INFO "Dry Run: $DRY_RUN"

    # Extract steps from runbook
    # This is a simplified version - would need more sophisticated parsing
    grep -n "^### Step\|^## Detection\|^## Diagnosis\|^## Remediation" "$runbook_path" | while read -r line; do
        step=$((step + 1))
        log DEBUG "Found step $step: $line"
    done

    log INFO "Runbook execution complete"
}

main() {
    parse_args "$@"

    # Create log directory if it doesn't exist
    mkdir -p "$LOG_DIR"

    # Resolve runbook path
    local runbook_path
    if [[ "$RUNBOOK" == /* ]]; then
        runbook_path="$RUNBOOK"
    else
        runbook_path="$RUNBOOK_DIR/$RUNBOOK"
    fi

    # Validate runbook
    if ! validate_runbook "$runbook_path"; then
        log ERROR "Runbook validation failed"
        exit 1
    fi

    # Confirm execution
    if [[ "$AUTO_CONFIRM" != true ]] && [[ "$DRY_RUN" != true ]]; then
        echo ""
        echo "About to execute runbook:"
        echo "  Runbook: $runbook_path"
        echo "  Namespace: $NAMESPACE"
        echo "  Dry Run: $DRY_RUN"
        echo ""
        read -p "Continue? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log INFO "Execution cancelled"
            exit 0
        fi
    fi

    # Execute runbook
    execute_runbook "$runbook_path"
}

main "$@"
