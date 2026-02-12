#!/bin/bash
# Resolve Spark Operations Incident
#
# Usage:
#   ./resolve-incident.sh <INCIDENT_ID> [RESOLUTION]
#
# Example:
#   ./resolve-incident.sh INC-001 "Fixed memory configuration issue"

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

Resolve a Spark operations incident.

OPTIONS:
    -i, --id ID              Incident ID (required)
    -r, --resolution TEXT  Resolution description (required)
    -c, --components CSV  Root cause components (optional)
    --dry-run              Show what would be done without executing

EXAMPLES:
    $(basename "$0") -i INC-001 -r "Increased executor memory to 4GB"
    $(basename "$0") --id INC-002 --resolution "Configuration fix deployed"

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
RESOLUTION=""
COMPONENTS=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -i|--id)
            INCIDENT_ID="$2"
            shift 2
            ;;
        -r|--resolution)
            RESOLUTION="$2"
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
if [[ -z "$INCIDENT_ID" || -z "$RESOLUTION" ]]; then
    log_error "Missing required arguments: -i and -r are required"
    usage
fi

# Find incident file
YEAR=$(date +%Y)
INCIDENT_FILE="$INCIDENTS_DIR/incidents/$YEAR/$INCIDENT_ID.md"

if [[ ! -f "$INCIDENT_FILE" ]]; then
    log_error "Incident file not found: $INCIDENT_FILE"
    exit 1
fi

if [[ "$DRY_RUN" == true ]]; then
    log_info "[DRY RUN] Would update incident file: $INCIDENT_FILE"
    exit 0
fi

# Get current timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
DATE_HUMAN=$(date -u +"%Y-%m-%d %H:%M:%S UTC")

# Update incident file
awk -i -v status="RESOLVED" \
    -v timestamp="$TIMESTAMP" \
    -v resolution="$RESOLUTION" \
    -v components="$COMPONENTS" \
'
    /^## Current Status/ {
        print "## Current Status\n\n**Status:** RESOLVED"
    }
    /^## Actions Taken/ {
        print "## Actions Taken\n- [X] Resolution: " resolution
    }
    /^## Next Steps/ {
        # Add resolution to Next Steps
        print $0 "\n- [ ] Resolution implemented"
        print $0 "\n- [ ] Monitor for recurrence"
    }
    1 {print}
' "$INCIDENT_FILE"

log_info "Incident resolved: $INCIDENT_FILE"

# Calculate duration
START_TIME=$(grep "Start Time:" "$INCIDENT_FILE" | sed "s/Start Time: //")
if [[ -n "$START_TIME" ]]; then
    START_SECONDS=$(date -d "$START_TIME" +%s)
    END_SECONDS=$(date -d "$TIMESTAMP" +%s)
    DURATION=$((END_SECONDS - START_SECONDS))
    DURATION_HOURS=$((DURATION / 3600))
    log_info "Incident duration: ${DURATION_HOURS}h"
fi

# Create post-incident review entry
REVIEW_FILE="$INCIDENTS_DIR/../post-incident-review/$YEAR/$INCIDENT_ID-review.md"
mkdir -p "$(dirname "$REVIEW_FILE")"

cat > "$REVIEW_FILE" <<EOF
# Post-Incident Review: $INCIDENT_ID

## Incident Summary

| Field        | Value                           |
|--------------|---------------------------------|
| Incident ID   | $INCIDENT_ID                   |
| Severity      | $(grep "^\\*\\*Severity" "$INCIDENT_FILE" | sed "s/.*Severity: //" | head -1)            |
| Duration      | ${DURATION_HOURS:-N/A} hours       |
| Root Cause   | $(if [[ -n "$COMPONENTS" && "$COMPONENTS" != "all" ]]; then echo "$COMPONENTS"; else echo "To be determined"; fi)      |

## Resolution

**Resolution:** $RESOLUTION

## Timeline

| Time                  | Event                    |
|-----------------------|------------------------------------------|
| $(grep "Start Time:" "$INCIDENT_FILE" | head -1) | Incident declared         |
| $TIMESTAMP         | Incident resolved           |

## Lessons Learned

- [ ] What went well?
- [ ] What could be improved?
- [ ] Action items to prevent recurrence

## Follow-up Actions

- [ ] Update runbooks if needed
- [ ] Share findings with team
- [ ] Update monitoring/alerting

---

*Review completed by: $(git config user.name || echo "Operations")*
*Date: $DATE_HUMAN*
EOF

log_info "Post-incident review created: $REVIEW_FILE"
log_info "Incident $INCIDENT_ID resolved and documented"
