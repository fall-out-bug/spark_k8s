# Incident Escalation Paths

## Overview

This document defines escalation procedures and contact paths for Spark operations incidents.

## Severity Levels

| Level | Name              | Response Time | Escalation Time | Examples                              |
|--------|-------------------|---------------|-----------------|---------------------------------------|
| P0     | Critical           | Immediate      | 5 minutes       | Complete Spark cluster failure, data loss    |
| P1     | High              | 15 minutes    | 1 hour         | Multiple executor failures, performance degradation |
| P2     | Medium            | 4 hours       | Next business day | Single executor failure, minor performance issues |
| P3     | Low               | 1 day          | Weekly review  | Documentation gaps, minor UI issues      |

## Escalation Chain

```
┌─────────────────────────────────────────────────────────────────┐
│                                                             │
│  Level 0: On-Call Engineer                                   │
│  (P0-P3: < 15 min response; 24/7 monitoring)          │
│                                                             │
│  Level 1: Engineering Manager                                │
│  (P0 only: Immediate escalation for critical incidents)             │
│                                                             │
│  Level 2: Platform Lead                                     │
│  (Critical infrastructure: K8s cluster, storage, network)        │
│                                                             │
│  Level 3: CTO / Architecture Board                     │
│  (Extreme cases: data breach, complete service outage)          │
│                                                             │
└─────────────────────────────────────────────────────────────────────────┘
```

## Escalation Contacts

| Role                | Name              | Email/Phone         | Availability      |
|---------------------|-------------------|----------------------|-----------------|
| On-Call Engineer    | Andrey Zhukov     | andrey@s7.ru         | 24/7           |
| Engineering Manager   | [Manager Name]     | [manager@s7.ru]    | M-F 9-18      |
| Platform Lead        | [Lead Name]       | [lead@s7.ru]       | M-F 9-18      |
| CTO                | Alex V.          | cto@s7.ru           | As needed       |

## Escalation Triggers

**Automatic Escalation** occurs when:
- P0 incident not acknowledged in 5 minutes
- P1 incident not updated in 1 hour
- P2 incident not resolved in 4 hours
- On-call engineer not available

**Manual Escalation** via:
- Slack: `#incidents`
- Email: incidents@s7.ru
- Phone: +7-XXX-XX-XX-XX (on-call engineer)

## Related Procedures

- [On-Call Rotation Schedule](../on-call/rotation-schedule.md)
- [Incident Declaration](../../templates/incident-declaration.md)
- [Post-Incident Review](../post-incident-review/)
