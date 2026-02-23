#!/bin/bash
# Declare Spark Operations Incident
#
# Usage:
#   ./declare-incident.sh <INCIDENT_ID> <SEVERITY> <TITLE> [DESCRIPTION]
#
# Example:
#   ./declare-incident.sh INC-001 P1 "Multiple executor failures" "Spark executors failing with OOM"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INCIDENTS_DIR="$SCRIPT_DIR/../../docs/operations/incidents"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Declare a Spark operations incident.

OPTIONS:
    -i, --id ID              Incident ID (required)
    -s, --severity SEV    Severity: P0, P1, P2, P3 (required)
    -t, --title TITLE     Brief incident title (required)
    -d, --description DESC  Full description (optional)
    -c, --components CSV  Affected components (default: all)
    --dry-run              Show what would be done without executing

EXAMPLES:
    $(basename "$0") -i INC-001 -s P1 -t "Driver pod crash loop"
    $(basename "$0") --id INC-002 --severity P2 --title "Executor failures"

EOF
    exit 1
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Parse arguments
INCIDENT_ID=""
SEVERITY=""
TITLE=""
DESCRIPTION=""
COMPONENTS="all"
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -i|--id)
            INCIDENT_ID="$2"
            shift 2
            ;;
        -s|--severity)
            SEVERITY="$2"
            shift 2
            ;;
        -t|--title)
            TITLE="$2"
            shift 2
            ;;
        -d|--description)
            DESCRIPTION="$2"
            shift 2
            ;;
        -c|--components)
            COMPONENTS="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate required arguments
if [[ -z "$INCIDENT_ID" || -z "$SEVERITY" || -z "$TITLE" ]]; then
    log_error "Missing required arguments: -i, -s, -t are required"
    usage
fi

# Validate severity
if [[ ! "$SEVERITY" =~ ^P[0-3]$ ]]; then
    log_error "Invalid severity: $SEVERITY (must be P0, P1, P2, P3)"
    usage
fi

# Generate incident filename
YEAR=$(date +%Y)
INCIDENT_FILE="$INCIDENTS_DIR/incidents/$YEAR/$INCIDENT_ID.md"

if [[ "$DRY_RUN" == true ]]; then
    log_info "[DRY RUN] Would create incident file: $INCIDENT_FILE"
    exit 0
fi

# Create directory if needed
mkdir -p "$(dirname "$INCIDENT_FILE")"

# Get current timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
DATE_HUMAN=$(date -u +"%Y-%m-%d %H:%M:%S UTC")

# Determine severity color
case "$SEVERITY" in
    P0)
        SEVERITY_COLOR="$RED"
        SEVERITY_NAME="Critical"
        ;;
    P1)
        SEVERITY_COLOR="$RED"
        SEVERITY_NAME="High"
        ;;
    P2)
        SEVERITY_COLOR="$YELLOW"
        SEVERITY_NAME="Medium"
        ;;
    P3)
        SEVERITY_COLOR="$YELLOW"
        SEVERITY_NAME="Low"
        ;;
esac

# Create incident file
cat > "$INCIDENT_FILE" <<EOF
# [INC-$INCIDENT_ID] [$SEVERITY] - $TITLE]

**Status:** DECLARED

**Detected By:** $(git config user.name || echo "On-Call Engineer")
**Start Time:** $TIMESTAMP

$(if [[ -n "$COMPONENTS" && "$COMPONENTS" != "all" ]]; then
    echo "**Affected Components:** $COMPONENTS"
else
    echo "**Affected Components:** All Spark components"
fi)

## Impact Assessment

- **User Impact:** $(if [[ -n "$DESCRIPTION" ]]; then echo "$DESCRIPTION"; else echo "To be determined"; fi)
- **Data Impact:** To be determined
- **Service Impact:** Spark operations affected

## Current Status

- **Investigation Status:** Not Started
- **Initial Hypothesis:** Under investigation

## Actions Taken

- [ ] Investigate logs and metrics
- [ ] Identify root cause
- [ ] Implement mitigation

## Next Steps

- [ ] Update status as investigation progresses

## Related Resources

- Slack: #incidents
- Email: incidents@s7.ru
- Phone: On-call engineer

---

*Declared by: $(git config user.name || echo "Operations")*
*Date: $DATE_HUMAN*
*Severity: $SEVERITY_NAME*
EOF

log_info "Incident declared: $INCIDENT_FILE"
log_info "Severity: $SEVERITY_NAME ($SEVERITY)"
log_info "Post summary to Slack #incidents"

# Output summary
echo "{'=\"*60}"
echo "Incident Declaration Summary"
echo "{'=\"*60}"
echo "ID: $INCIDENT_ID"
echo "Severity: $SEVERITY ($SEVERITY_NAME)"
echo "Title: $TITLE"
echo "File: $INCIDENT_FILE"
echo "{'=\"*60}"

# Create Slack notification message (for manual posting)
SLACK_MSG="*$SEVERITY_COLOR*$SEVERITY_NAME Incident [$INCIDENT_ID] declared: $TITLE*"
echo "$SLACK_MSG"
echo "Affected Components: $COMPONENTS"
echo "Channel: #incidents"
echo ""

log_info "Complete incident declaration with details in file"
