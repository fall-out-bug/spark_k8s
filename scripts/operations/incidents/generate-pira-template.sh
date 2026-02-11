#!/bin/bash
# PIRA Template Generator
# Generates a Post-Incident Review Analysis template for a given incident

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="/home/fall_out_bug/work/s7/spark_k8s/docs/operations/templates"
OUTPUT_DIR="/home/fall_out_bug/work/s7/spark_k8s/docs/operations/reports/pira"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Generate a PIRA template for an incident.

OPTIONS:
    -i, --incident-id ID      Incident ID (e.g., INC-123)
    -t, --title TITLE         Incident title
    -d, --date DATE           Incident date (default: today)
    -f, --facilitator NAME    PIRA facilitator name
    -o, --output FILE         Output file (default: auto-generated)
    -h, --help                Show this help

EXAMPLES:
    $(basename "$0") --incident-id INC-123 --title "Spark job failure"
    $(basename "$0") -i INC-456 -t "Data pipeline outage" -f @john.doe
EOF
    exit 1
}

INCIDENT_ID=""
INCIDENT_TITLE=""
INCIDENT_DATE=$(date +%Y-%m-%d)
FACILITATOR=""
OUTPUT_FILE=""

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -i|--incident-id)
                INCIDENT_ID="$2"
                shift 2
                ;;
            -t|--title)
                INCIDENT_TITLE="$2"
                shift 2
                ;;
            -d|--date)
                INCIDENT_DATE="$2"
                shift 2
                ;;
            -f|--facilitator)
                FACILITATOR="$2"
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

    if [[ -z "$INCIDENT_ID" ]]; then
        echo "Error: --incident-id is required"
        echo ""
        usage
    fi
}

main() {
    parse_args "$@"

    # Set default output file if not specified
    if [[ -z "$OUTPUT_FILE" ]]; then
        OUTPUT_FILE="${OUTPUT_DIR}/PIRA-${INCIDENT_ID}.md"
    fi

    # Create output directory if it doesn't exist
    mkdir -p "$(dirname "$OUTPUT_FILE")"

    # Generate the PIRA
    cat > "$OUTPUT_FILE" <<EOF
# PIR: ${INCIDENT_TITLE:-Incident ${INCIDENT_ID}}

**Incident ID**: ${INCIDENT_ID}
**Incident Date**: ${INCIDENT_DATE}
**PIR Date**: $(date +%Y-%m-%d)
**PIR Facilitator**: ${FACILITATOR:-TBD}
**Document Status**: Draft

---

## Executive Summary

*2-3 sentences describing what happened, the impact, and the key learning.*

[Write executive summary here]

---

## Impact Assessment

### Customer Impact

- **Duration**: [X hours/Y minutes]
- **Affected Users**: [Number or percentage]
- **Affected Services**: [List of services]
- **User-Facing Symptoms**: [What users experienced]

### Business Impact

- **Revenue Impact**: [Dollars lost/opportunity cost]
- **SLA Breaches**: [Yes/No, details]
- **Customer Complaints**: [Number]
- **Compensation Required**: [Yes/No, details]

### Technical Impact

- **Services Degraded**: [List with duration]
- **Data Loss**: [Yes/No, details]
- **Recovery Time**: [Time to restore service]
- **MTTR**: [Mean time to resolution]

---

## Incident Timeline

| Time (UTC) | Event | State | Information Available | Action Taken |
|------------|-------|-------|----------------------|--------------|
| HH:MM | [What happened] | Normal/Degraded/Failure | [What was known] | [What was done] |
| ... | ... | ... | ... | ... |

**Timeline Notes**:
- [Any important context about the timeline]
- [Decision points and rationale]
- [Communication breakdowns]

---

## Root Cause Analysis

### Investigation Method

Select methods used:
- [ ] 5 Whys
- [ ] Fishbone Diagram
- [ ] Timeline Analysis
- [ ] Change Analysis
- [ ] Other: [specify]

### 5 Whys

1. **Why did [symptom] happen?**
   - [Answer]

2. **Why did [that] happen?**
   - [Answer]

3. **Why did [that] happen?**
   - [Answer]

4. **Why did [that] happen?**
   - [Answer]

5. **Why did [that] happen?**
   - **Root Cause**: [The fundamental issue]

### Root Cause Summary

**Primary Root Cause**:
[Description of the fundamental system issue that caused the incident]

**Secondary Contributing Factors**:
1. [Factor 1]
2. [Factor 2]

---

## Resolution

### Immediate Fix

**What we did to fix the incident**:
- [Action 1]
- [Action 2]
- [Action 3]

**Time to Resolution**: [X hours/Y minutes]

### Verification

**How we verified the fix worked**:
- [Verification method 1]
- [Verification method 2]

---

## Action Items

### High Priority (P0)

- [ ] **[Action Item Title]** (Owner: @name, Due: YYYY-MM-DD)
  - **Description**: [What needs to be done]
  - **Acceptance Criteria**: [How to verify completion]
  - **Link**: [GitHub issue / Jira ticket]

### Medium Priority (P1)

- [ ] **[Action Item Title]** (Owner: @name, Due: YYYY-MM-DD)
  - **Description**: [What needs to be done]
  - **Acceptance Criteria**: [How to verify completion]
  - **Link**: [GitHub issue / Jira ticket]

---

## Lessons Learned

### What Went Well

- [Positive aspect 1]
- [Positive aspect 2]

### What Could Be Improved

- [Improvement area 1]
- [Improvement area 2]

### What Surprised Us

- [Surprise 1]
- [Surprise 2]

---

## Follow-up

### 30-Day Check

**Date**: $(date -d "+30 days" +%Y-%m-%d)
**Items to Verify**:
- [ ] All action items completed
- [ ] Metrics improved
- [ ] No recurrence of incident

---

## Appendix

### Logs

**Relevant Log Excerpts**:

\`\`\`
[Paste relevant log entries here]
\`\`\`

### Metrics

**Screenshots/Graphs**:

[Attach metrics graphs showing incident]

---

## Review History

| Date | Reviewer | Status | Comments |
|------|----------|--------|----------|
| $(date +%Y-%m-%d) | ${FACILITATOR:-TBD} | Draft | Initial creation |

---

**Document Status**: Draft
**Next Review**: [Date for 30-day check]

---

## Resources

- **Incident Ticket**: [Link]
- **Runbook Used**: [Link]
- **Related PIRs**: [Links]

---

*Generated by $(basename "$0") on $(date)*
EOF

    echo "PIRA template created: $OUTPUT_FILE"
    echo ""
    echo "Next steps:"
    echo "1. Fill in the template with incident details"
    echo "2. Schedule PIR meeting within 5 business days"
    echo "3. Publish PIR within 7 business days"
    echo ""
}

main "$@"
