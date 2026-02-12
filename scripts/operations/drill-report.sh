#!/bin/bash
# Generate report from completed drill
#
# Usage:
#   ./drill-report.sh --drill-id <YYYY-MM> [--output-format markdown|json]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Configuration
DRILL_ID=""
OUTPUT_FORMAT="markdown"
DRILL_DIR="$(cd "$SCRIPT_DIR" && cd ../.. && pwd)/.drills"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --drill-id)
            DRILL_ID="$2"
            shift 2
            ;;
        --output-format)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [[ -z "$DRILL_ID" ]]; then
    log_error "Usage: $0 --drill-id <YYYY-MM> [--output-format markdown|json]"
    exit 1
fi

DRILL_PATH="${DRILL_DIR}/${DRILL_ID}"

if [[ ! -d "$DRILL_PATH" ]]; then
    log_error "Drill not found: ${DRILL_ID}"
    exit 1
fi

log_info "=== Generating Drill Report: ${DRILL_ID} ==="

# Load config
if [[ -f "${DRILL_PATH}/config.yaml" ]]; then
    FACILITATOR=$(grep "^facilitator:" "${DRILL_PATH}/config.yaml" | cut -d'"' -f2 || echo "Unknown")
    DATE=$(grep "^date:" "${DRILL_PATH}/config.yaml" | cut -d'"' -f2 || echo "Unknown")
else
    FACILITATOR="Unknown"
    DATE="Unknown"
fi

# Load results
if [[ -f "${DRILL_PATH}/results.yaml" ]]; then
    SCENARIOS_COMPLETED=$(grep "^scenarios_completed:" "${DRILL_PATH}/results.yaml" | cut -d':' -f2 | xargs || echo "0")
    AVERAGE_ACCURACY=$(grep "^average_accuracy:" "${DRILL_PATH}/results.yaml" | cut -d':' -f2 | xargs || echo "0")
else
    SCENARIOS_COMPLETED=0
    AVERAGE_ACCURACY=0
fi

# Generate report
if [[ "$OUTPUT_FORMAT" == "markdown" ]]; then
    cat <<EOF
# Runbook Drill Report: ${DRILL_ID}

## Summary

| Field | Value |
|-------|-------|
| Drill ID | ${DRILL_ID} |
| Date | ${DATE} |
| Facilitator | ${FACILITATOR} |
| Scenarios Completed | ${SCENARIOS_COMPLETED} |
| Average Accuracy | ${AVERAGE_ACCURACY}% |

## Executive Summary

EOF

    if [[ -f "${DRILL_PATH}/results.yaml" ]]; then
        echo "### Lessons Learned"
        grep -A 10 "^lessons_learned:" "${DRILL_PATH}/results.yaml" | grep "^  -" | sed 's/^  - /- /' || echo "None recorded"

        echo ""
        echo "### Action Items"
        grep -A 10 "^action_items:" "${DRILL_PATH}/results.yaml" | grep "^  -" | sed 's/^  - /- /' || echo "None recorded"
    fi

    echo ""
    echo "## Accuracy Scores by Runbook"
    echo ""

    # List accuracy scores
    if [[ -f "${DRILL_PATH}/results.yaml" ]]; then
        grep -A 20 "^accuracy_scores:" "${DRILL_PATH}/results.yaml" | grep '^    "[^"]*":' | while read -r line; do
            runbook=$(echo "$line" | cut -d'"' -f2)
            score=$(echo "$line" | cut -d':' -f2 | xargs)
            echo "- **${runbook}**: ${score}%"
        done
    fi

    echo ""
    echo "## Next Steps"
    echo ""
    echo "- [ ] Address action items above"
    echo "- [ ] Update runbooks with accuracy < 90%"
    echo "- [ ] Schedule next drill: $(date -d "${DRILL_ID}-01 +1 month" +"%Y-%m" 2>/dev/null || echo "TBD")"
    echo ""
    echo "---"
    echo ""
    echo "*Report generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")*"

elif [[ "$OUTPUT_FORMAT" == "json" ]]; then
    echo "{"
    echo "  \"drill_id\": \"${DRILL_ID}\","
    echo "  \"date\": \"${DATE}\","
    echo "  \"facilitator\": \"${FACILITATOR}\","
    echo "  \"scenarios_completed\": ${SCENARIOS_COMPLETED},"
    echo "  \"average_accuracy\": ${AVERAGE_ACCURACY},"

    if [[ -f "${DRILL_PATH}/results.yaml" ]]; then
        echo "  \"accuracy_scores\": {"
        grep -A 20 "^accuracy_scores:" "${DRILL_PATH}/results.yaml" | grep '^    "[^"]*":' | while read -r line; do
            runbook=$(echo "$line" | cut -d'"' -f2)
            score=$(echo "$line" | cut -d':' -f2 | xargs)
            echo "    \"${runbook}\": ${score},"
        done | sed '$ s/,$//'
        echo "  },"
    fi

    echo "  \"generated_at\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\""
    echo "}"
fi

# Save report
REPORT_FILE="${DRILL_PATH}/report.${OUTPUT_FORMAT}"

if [[ "$OUTPUT_FORMAT" == "markdown" ]]; then
    cat <<EOF > "$REPORT_FILE"
# Runbook Drill Report: ${DRILL_ID}

## Summary

| Field | Value |
|-------|-------|
| Drill ID | ${DRILL_ID} |
| Date | ${DATE} |
| Facilitator | ${FACILITATOR} |
| Scenarios Completed | ${SCENARIOS_COMPLETED} |
| Average Accuracy | ${AVERAGE_ACCURACY}% |

## Status

EOF

    if [[ $(echo "$AVERAGE_ACCURACY >= 90" | bc 2>/dev/null || echo "0") -eq 1 ]]; then
        echo "✅ **PASS**: Average accuracy meets or exceeds 90% threshold" >> "$REPORT_FILE"
    else
        echo "⚠️ **REVIEW**: Average accuracy below 90% threshold - improvement needed" >> "$REPORT_FILE"
    fi

    echo "" >> "$REPORT_FILE"
    echo "## Detailed Report" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "See full report above or run with \`--output-format json\` for machine-readable output." >> "$REPORT_FILE"
fi

log_info "Report saved to: ${REPORT_FILE}"

# Check accuracy threshold
if [[ $(echo "$AVERAGE_ACCURACY < 90" | bc 2>/dev/null || echo "0") -eq 1 ]]; then
    log_warn "⚠️ Average accuracy ${AVERAGE_ACCURACY}% is below 90% threshold"
    log_info "Action items:"
    log_info "1. Review underperforming runbooks"
    log_info "2. Update documentation with corrections"
    log_info "3. Schedule follow-up drill"
    exit 1
else
    log_info "✅ Average accuracy ${AVERAGE_ACCURACY}% meets threshold"
    exit 0
fi
