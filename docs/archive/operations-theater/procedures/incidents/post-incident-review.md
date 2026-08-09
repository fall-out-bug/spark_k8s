# Post-Incident Review Procedure

## Overview

This procedure defines the process for conducting blameless Post-Incident Reviews (PIRs) to learn from incidents and prevent recurrence.

## When to Conduct a PIR

A PIR should be conducted for:
- **P0 incidents**: Always required
- **P1 incidents**: Required if customer impact > 15 minutes
- **P2 incidents**: Required if > 3 occurrences in 30 days
- **P3 incidents**: Optional (at team discretion)

## Timeline

| Milestone | Timeline | Owner |
|-----------|----------|-------|
| Incident declared | T0 | On-call engineer |
| Incident resolved | T0 + MTTR | Incident commander |
| PIR scheduled | Within 24 hours | Engineering manager |
| PIR conducted | Within 5 business days | Facilitator |
| PIR published | Within 7 business days | SRE lead |
| Actions tracked | Within 10 business days | Action owner |

## Roles and Responsibilities

### Incident Facilitator

- Schedule and conduct PIR meeting
- Ensure blameless, productive discussion
- Document findings and action items
- Track action items to completion

### Participants

- **Required**: Incident commander, all responders, service owner
- **Optional**: Engineering manager, SRE lead, customer support
- **Observers**: Anyone who can learn (optional participation)

### Meeting Notes Taker

- Capture discussion points
- Record timeline and decisions
- Document action items with owners

## Pre-PIR Preparation

### Step 1: Gather Data

```bash
# Generate incident data package
scripts/operations/incidents/collect-incident-data.sh --incident-id INC-123

# Includes:
# - Alert history
# - Timeline of events
# - Logs (relevant excerpts)
# - Metrics graphs
# - Chat logs
# - Customer impact report
```

### Step 2: Send Calendar Invite

Send calendar invite with:
- **Title**: PIR: [Incident Title]
- **Duration**: 60 minutes
- **Attendees**: All responders + service owner
- **Attachments**: Incident data package, timeline
- **Preparation**: Review timeline and metrics before meeting

### Step 3: Review Timeline

Facilitator should review the timeline and identify:
- Key decision points
- Unknown factors at decision time
- Communication breakdowns
- Tooling issues
- Process gaps

## PIR Meeting Agenda

### 1. Introduction (5 minutes)

- **Ground rules**: Blameless postmortem, focus on systems not people
- **Objective**: Learn and improve, not assign blame
- **Process**: We will review what happened, why it happened, and how to prevent it

### 2. Incident Timeline (15 minutes)

- Walk through the timeline from start to resolution
- For each event:
  - What happened?
  - What did we know at the time?
  - What decisions were made?
  - What information was missing?

### 3. Root Cause Analysis (20 minutes)

Use one or more methods:

#### 5 Whys Method

```
Problem: Spark job failed
Why 1: Executor pods were OOMKilled
Why 2: Memory requests were too low
Why 3: No baseline testing was done
Why 4: No sizing calculator existed
Why 5: Capacity planning process not established
Root cause: Lack of capacity planning process
```

#### Fishbone Diagram

Categories to explore:
- **People**: Training, onboarding, rotation
- **Process**: Procedures, runbooks, automation
- **Technology**: Tools, monitoring, alerts
- **Environment**: Configuration, dependencies
- **Management**: Priorities, resources, decisions
- **Data**: Metrics, logs, visibility

### 4. Action Items (15 minutes)

For each root cause:
- Generate specific action items
- Assign owner
- Set due date
- Define acceptance criteria

Action item format:
- [ ] **Short description of change** (Owner: @name, Due: YYYY-MM-DD)
  - Specific, measurable, time-bound
  - Example: "Add memory limits to all Spark executors" → "[ ] Create VPA for executor pods (Owner: @sre-team, Due: 2026-02-20)"

### 5. Lessons Learned (5 minutes)

- What went well during the incident?
- What could be improved?
- What surprised us?
- What would we do differently?

## PIR Document Template

Use the template at `/docs/operations/templates/pira-template.md`:

```markdown
# PIR: [Incident Title]

## Summary
[2-3 sentences describing what happened and impact]

## Impact
- **Customer Impact**: [duration, affected users]
- **Business Impact**: [revenue, SLA breaches]
- **Technical Impact**: [services affected]

## Timeline
| Time | Event | Notes |
|------|-------|-------|
| ... | ... | ... |

## Root Cause
[Use 5 Whys or Fishbone to explain]

## Contributing Factors
- Factor 1: [description]
- Factor 2: [description]

## Resolution
[How we fixed the immediate issue]

## Action Items
- [ ] [Action 1] (Owner: @name, Due: YYYY-MM-DD)
- [ ] [Action 2] (Owner: @name, Due: YYYY-MM-DD)

## Follow-up
- How will we verify actions are complete?
- When will we review this PIR again?

## Appendix
- Logs
- Metrics
- Screenshots
```

## Action Item Tracking

### Step 1: Create GitHub Issues

```bash
# Auto-create from PIR
scripts/operations/incidents/create-issues-from-pir.sh --pir-id PIR-123

# Or manually:
gh issue create \
  --title "[PIR-123] Add memory limits to Spark executors" \
  --body "See PIR-123 for context. Owner: @sre-team, Due: 2026-02-20" \
  --label "pir,action-item,priority-high"
```

### Step 2: Track Progress

Action items are tracked in:
- GitHub issues with `pir` label
- Kanban board for PIR actions
- Weekly PIR review meeting

### Step 3: Close Action Items

When complete:
1. Update GitHub issue with verification
2. Reference in PIR document
3. Mark as complete in tracking sheet
4. Celebrate the improvement!

## PIR Review and Publication

### Internal Review

PIR documents go through:
1. **Technical review**: SRE lead (1 business day)
2. **Management review**: Engineering manager (1 business day)
3. **Security review**: If customer data involved (1 business day)

### Publication

- **Internal**: Publish to confluence/wiki
- **External**: If customer-facing, prepare public version
- **Index**: Add to PIR database for searchability

## Follow-up

### 30-Day Check

At 30 days:
- Verify all action items complete
- Measure improvement (metrics improved?)
- Update PIR with results

### Quarterly Review

Review PIR trends:
- Common themes
- Action item completion rate
- Recurring incidents
- Process improvements needed

## Blameless Culture Guidelines

### Do's

- Focus on **systems and processes**, not individuals
- Ask **"how"** and **"why"** questions, not "who"
- Acknowledge **tradeoffs** made during incident
- Recognize that **everyone acted with good intent**
- Treat **near-misses** as learning opportunities

### Don'ts

- Don't ask "Who made this mistake?"
- Don't use "careless", "negligent", "should have known"
- Don't assume hindsight was available during incident
- Don't punish for honest mistakes
- Don't hide incidents or PIRs

### Example Questions

**Good**:
- "What conditions led to this decision?"
- "What information was available at the time?"
- "How can we make the system more resilient?"
- "What tools would have helped?"

**Bad**:
- "Who wrote this code?"
- "Why did you make this mistake?"
- "Who is responsible for this?"
- "Shouldn't you have known better?"

## Metrics and KPIs

Track these metrics for PIR effectiveness:

| Metric | Target | Measurement |
|--------|--------|-------------|
| PIR completion rate | 100% of P0/P1 incidents | PIRs created / incidents |
| Action item completion | 90% within due date | Completed / total actions |
| Recurrence rate | < 5% repeat incidents | Recurring / total incidents |
| PIR timeline | 7 business days | Avg days to publish |
| Participant satisfaction | > 80% positive | Post-PIR survey |

## Related Procedures

- [Incident Response Runbook](../runbooks/incidents/incident-response.md)
- [Root Cause Analysis Methodology](./root-cause-analysis.md)
- [Blameless Culture Guidelines](./blameless-culture.md)

## References

- [Google SRE Book: Postmortem Culture](https://sre.google/sre-book/postmortem-culture/)
- [Blameless Postmortems](https://queue.acm.org/detail.cfm?id=2796433)
