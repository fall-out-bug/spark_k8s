# Incident Declaration Template

## Overview

This template is used for declaring production incidents affecting Spark Kubernetes operations.

## Incident Metadata

| Field           | Description                              | Example                     |
|-----------------|-----------------------------------------|------------------------------|
| Incident ID     | Unique identifier                        | INC-2026-001              |
| Severity        | P0 (Critical), P1 (High), P2, P3    | P1                          |
| Status          | Declared, Investigating, Mitigating, Resolved | Declared                    |
| Start Time      | ISO 8601 timestamp                      | 2026-02-12T10:30:00Z  |
| Detected By     | Who detected/declared                  | On-Call Engineer             |
| Affected Components | Spark components impacted            | driver, executor, shuffle  |
| Customer Impact | Yes/No and duration                   | Yes, 2 hours affected      |

## Declaration Template

```markdown
# [INC-ID] [Severity] - Brief Title

**Status:** DECLARED

**Detected By:** On-Call Engineer

**Start Time:** YYYY-MM-DDTHH:MM:SSZ

**Affected Components:** [List affected Spark components]

## Impact Assessment

- **User Impact:** [Description of user impact]
- **Data Impact:** [None / Data loss / Degradation]
- **Service Impact:** [Description of service degradation]

## Current Status

- **Investigation Status:** [Not Started / In Progress / Awaiting Input]
- **Initial Hypothesis:** [Best guess at time of declaration]

## Actions Taken

- [ ] Action 1: [Description]
- [ ] Action 2: [Description]
- [ ] Action 3: [Description]

## Next Steps

- [ ] [Next action item]
- [ ] [Next action item]

## Related Resources

- Runbooks: [Links to relevant runbooks]
- Metrics: [Prometheus/Loki links]
- Previous Incidents: [Related incident IDs]

---

*Declared by: [Name]*
*Date: [Declaration date]*
*Channel: [#incidents]*
```

## Required Fields

- **Brief Title**: Concise description (< 80 chars)
- **Severity**: Based on [Escalation Policy](../on-call/escalation-paths.md)
- **Affected Components**: At least one component must be specified
- **Impact Assessment**: User, Data, Service impact sections required
- **Current Status**: Must be updated every 30 minutes during investigation

## Declaration Channels

1. **Slack**: Post to `#incidents` channel
2. **Email**: Send to incidents@s7.ru
3. **Phone**: Call on-call engineer for P0 incidents

## Related Procedures

- [On-Call Rotation](../on-call/rotation-schedule.md)
- [Escalation Paths](../on-call/escalation-paths.md)
