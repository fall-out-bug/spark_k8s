#!/bin/bash
# Prepare a monthly runbook drill
#
# Usage:
#   ./drill-prepare.sh --drill-id <YYYY-MM>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Configuration
DRILL_ID=""
DRILL_DIR="$(cd "$SCRIPT_DIR" && cd ../.. && pwd)/.drills"
FACILITATOR=${DRILL_FACILITATOR:-"oncall@example.com"}
PARTICIPANTS=${DRILL_PARTICIPANTS:-""}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --drill-id)
            DRILL_ID="$2"
            shift 2
            ;;
        --facilitator)
            FACILITATOR="$2"
            shift 2
            ;;
        --participants)
            PARTICIPANTS="$2"
            shift 2
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [[ -z "$DRILL_ID" ]]; then
    log_error "Usage: $0 --drill-id <YYYY-MM>"
    exit 1
fi

log_info "=== Preparing Drill: ${DRILL_ID} ==="

# Create drill directory
DRILL_PATH="${DRILL_DIR}/${DRILL_ID}"
mkdir -p "$DRILL_PATH"

log_info "Drill directory: ${DRILL_PATH}"

# Check if drill already exists
if [[ -f "${DRILL_PATH}/config.yaml" ]]; then
    log_warn "Drill already exists. Loading existing config."
else
    log_info "Creating new drill configuration"

    # Create config from template
    cat > "${DRILL_PATH}/config.yaml" <<EOF
name: "Runbook Drill - ${DRILL_ID}"
date: "$(date -u +"%Y-%m-%dT%H:00:00Z")"
facilitator: "${FACILITATOR}"
participants:
  - "${FACILITATOR}"
$(if [[ -n "$PARTICIPANTS" ]]; then
    for p in ${PARTICIPANTS//,/ }; do
        echo "  - \"${p}\""
    done
fi)

scenarios: []

# Scenarios will be added during drill selection
# Use ./drill-add-scenario.sh --drill-id ${DRILL_ID} --runbook <name>
EOF
fi

# Create results template
cat > "${DRILL_PATH}/results.yaml" <<EOF
drill_id: "${DRILL_ID}"
date: ""
duration_minutes: 0
participants: []
scenarios_completed: 0
accuracy_scores: {}
average_accuracy: 0
lessons_learned: []
action_items: []
next_drill_date: ""
EOF

# Create scenario pool
SCENARIO_POOL="${DRILL_PATH}/scenario-pool.txt"

if [[ ! -f "$SCENARIO_POOL" ]]; then
    log_info "Creating scenario pool"
    cat > "$SCENARIO_POOL" <<'EOF'
# High Severity (P0)
driver-oom-recovery.md
shuffle-failure-recovery.md
storage-pressure.md
critical-job-failure.md

# Medium Severity (P1)
high-executor-failures.md
executor-memory-pressure.md
network-partition.md
straggler-tasks.md

# Low Severity (P2)
idle-executor-cleanup.md
cost-spike-investigation.md
metric-collection-gap.md
EOF
fi

# Select random scenarios for the drill
log_info "Selecting scenarios for drill..."

SELECTED_SCENARIOS=$(shuf -n 3 "$SCENARIO_POOL" 2>/dev/null || head -3 "$SCENARIO_POOL")

log_info "Selected scenarios:"
echo "$SELECTED_SCENARIOS"

# Add scenarios to config (if not already present)
if ! grep -q "scenarios:" "${DRILL_PATH}/config.yaml" || ! grep -q "runbook:" "${DRILL_PATH}/config.yaml"; then
    log_info "Adding scenarios to config"

    # This is a simple append - in production, use proper YAML parsing
    for scenario in $SELECTED_SCENARIOS; do
        cat >> "${DRILL_PATH}/config.yaml" <<EOF

  - name: "$(basename "$scenario" .md | sed 's/-/ /g' | title)"
    runbook: "${scenario}"
    severity: P1
    duration_minutes: 15
    success_criteria:
      - Procedure executed without deviation
      - Expected outcome achieved
      - Time within estimate
EOF
    done
fi

# Create participants checklist
cat > "${DRILL_PATH}/checklist.md" <<EOF
# Drill ${DRILL_ID} - Participant Checklist

## Before the Drill

- [ ] Review assigned runbook scenarios
- [ ] Ensure access to monitoring tools (Grafana, Prometheus, Kubernetes)
- [ ] Test kubectl connectivity to test cluster
- [ ] Review on-call escalation procedures
- [ ] Prepare note-taking template

## During the Drill

For each scenario:
- [ ] Record start time
- [ ] Document each step taken
- [ ] Note any deviations from runbook
- [ ] Record time to resolution
- [ ] Identify any missing information

## After the Drill

- [ ] Complete accuracy survey for each runbook
- [ ] Document lessons learned
- [ ] Identify action items
- [ ] Submit results to facilitator

## Accuracy Survey

For each runbook used:

1. **Steps worked as documented?** Yes/No
   - Comments:

2. **Commands executed successfully?** Yes/No
   - Comments:

3. **Estimated time accurate (±20%)?** Yes/No
   - Actual time:

4. **No missing information?** Yes/No
   - What was missing:

5. **Would you trust this runbook during a real incident?** Yes/No
   - Comments:
EOF

# Schedule calendar event (if cal command available)
if command -v cal &>/dev/null; then
    log_info "Scheduling drill for first Tuesday of next month"
    # This would integrate with calendar API in production
fi

log_info "=== Drill Preparation Complete ==="
log_info "Config: ${DRILL_PATH}/config.yaml"
log_info "Results template: ${DRILL_PATH}/results.yaml"
log_info "Checklist: ${DRILL_PATH}/checklist.md"
log_info ""
log_info "Next steps:"
log_info "1. Review and edit config.yaml to add participants"
log_info "2. Share checklist.md with participants"
log_info "3. Run: ./drill-start.sh --drill-id ${DRILL_ID}"

exit 0
