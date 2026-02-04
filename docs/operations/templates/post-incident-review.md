# Post-Incident Review Template

Use this template to conduct post-incident reviews (PIRs) for all P0 and P1 incidents.

## Incident Information

| Field | Value |
|-------|-------|
| **Incident ID** | inc-YYYYMMDD-HHMMSS |
| **Title** | [Brief description] |
| **Severity** | P0/P1 |
| **Duration** | [Start time] to [End time] ([X hours]) |
| **Reviewer** | [Name] |
| **Review Date** | [Date] |
| **Attendees** | [List] |

---

## Executive Summary

[2-3 sentence summary for executives]

---

## Timeline

| Time | Event | Owner |
|------|-------|-------|
| [Timestamp] | Incident detected | [Name] |
| [Timestamp] | Severity assigned: P0/P1 | [Name] |
| [Timestamp] | Initial diagnosis: [hypothesis] | [Name] |
| [Timestamp] | Mitigation implemented: [action] | [Name] |
| [Timestamp] | Service restored | [Name] |
| [Timestamp] | Incident resolved | [Name] |

---

## Root Cause Analysis

### What Happened?

[Describe the sequence of events that led to the incident]

### Why Did It Happen?

[Identify the root cause(s). Use "5 Whys" technique if helpful]

### Why Wasn't It Detected Earlier?

[Was there a monitoring gap? Could alerting have been better?]

---

## Impact Assessment

### Customer Impact

- [ ] Customers affected: [Number]
- [ ] Services affected: [List]
- [ ] Duration of impact: [Time]
- [ ] Data loss: [Yes/No - describe if Yes]

### Business Impact

- [ ] Revenue impact: [Description]
- [ ] SLA breach: [Yes/No - describe if Yes]
- [ ] Customer complaints: [Number]
- [ ] Press coverage: [Yes/No - describe if Yes]

---

## Response Assessment

### What Went Well

- [ ] [Example: Quick detection due to monitoring]
- [ ] [Example: Effective communication]
- [ ] [Example: Smooth escalation]

### What Could Have Gone Better

- [ ] [Example: Longer time to diagnose]
- [ ] [Example: Communication gaps]
- [ ] [Example: Lack of runbook]

### Response Metrics

| Metric | Target | Actual | Met? |
|--------|--------|--------|------|
| **Time to Detect (MTTD)** | <5 min | [X min] | [Yes/No] |
| **Time to Initial Response** | 15 min (P0) / 1 hour (P1) | [X min] | [Yes/No] |
| **Time to Resolve (MTTR)** | 30 min (P0) / 2 hours (P1) | [X min] | [Yes/No] |

---

## Action Items

### Prevent Recurrence (High Priority)

| Item | Owner | Due Date | Status |
|------|-------|----------|--------|
| [Action item] | [Name] | [Date] | [Open/In Progress/Done] |
| [Action item] | [Name] | [Date] | [Open/In Progress/Done] |

### Improve Detection (Medium Priority)

| Item | Owner | Due Date | Status |
|------|-------|----------|--------|
| [Action item] | [Name] | [Date] | [Open/In Progress/Done] |
| [Action item] | [Name] | [Date] | [Open/In Progress/Done] |

### Process Improvements (Low Priority)

| Item | Owner | Due Date | Status |
|------|-------|----------|--------|
| [Action item] | [Name] | [Date] | [Open/In Progress/Done] |
| [Action item] | [Name] | [Date] | [Open/In Progress/Done] |

---

## Lessons Learned

### Technical Learnings

[What did we learn about the platform, architecture, or technology?]

### Process Learnings

[What did we learn about our incident response process?]

### Organizational Learnings

[What did we learn about team structure, communication, or tools?]

---

## Follow-Up

| Item | Owner | Due Date |
|------|-------|----------|
| Postmortem published | [Name] | [Date] |
| Stakeholders notified | [Name] | [Date] |
| Customers updated (if applicable) | [Name] | [Date] |
| Runbooks updated | [Name] | [Date] |
| Monitoring improved | [Name] | [Date] |

---

## Appendix

### Logs and Screenshots

[Attach relevant logs, screenshots, or metrics]

### Related Documents

- [Incident Ticket](link)
- [Monitoring Dashboard](link)
- [Runbooks Used](link)

---

**Reviewer Signature:** _________________ **Date:** __________

**Approved by:** _________________ **Date:** __________

---

**Last Updated:** 2026-02-04
**Part of:** [F18: Production Operations Suite](../../drafts/feature-production-operations.md)
