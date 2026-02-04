#!/bin/bash
# Create incident ticket template
# Part of WS-018-01: Incident Response Framework

set -e

SEVERITY="${1:-P2}"
DESCRIPTION="${2:-General Incident}"

if [[ ! "$SEVERITY" =~ ^[Pp][0-3]$ ]]; then
    echo "Usage: $0 [P0|P1|P2|P3] [description]"
    echo "Example: $0 P1 'Multiple job failures'"
    exit 1
fi

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
INCIDENT_ID="inc-$(date +%Y%m%d-%H%M%S)"

cat > "incident-${INCIDENT_ID}.md" << EOF
# Incident: ${DESCRIPTION}

**Severity:** ${SEVERITY}
**Reporter:** $(git config user.name || echo "Unknown")
**Started:** ${TIMESTAMP}
**Incident ID:** ${INCIDENT_ID}

## Impact
[Who is affected? What is broken?]

## Current Status
- [ ] Investigating
- [ ] Diagnosing
- [ ] Mitigating
- [ ] Monitoring
- [ ] Resolved

## Timeline

### ${TIMESTAMP} - Incident Detected
**Reporter:** $(git config user.name || echo "Unknown")
**Actions:**
- [ ] Run health check
- [ ] Check logs and metrics
- [ ] Determine severity

### [Update Time] - [Status Update]
**Actions:**
-

## Communication
**Channels:**
- [ ] #incidents (Slack/Telegram)
- [ ] Support tickets
- [ ] Customer notification (if applicable)

## Root Cause
[To be filled during investigation]

## Resolution
[To be filled during mitigation]

## Action Items
- [ ] [Create improvement ticket]()
- [ ] [Update runbook]()
- [ ] [Improve monitoring]()

## Post-Incident Review
**Scheduled:** [Date/Time]
**Attendees:**
EOF

echo "✅ Incident ticket created: incident-${INCIDENT_ID}.md"
echo ""
echo "Next steps:"
echo "  1. Edit the ticket: nano incident-${INCIDENT_ID}.md"
echo "  2. Share with team"
echo "  3. Follow incident-response.md procedures"
