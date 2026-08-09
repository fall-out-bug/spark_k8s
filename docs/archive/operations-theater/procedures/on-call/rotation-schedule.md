# On-Call Rotation Schedule

## Overview

This document defines the on-call rotation schedule for Spark Kubernetes operations team.

## Rotation Schedule

### Primary On-Call (24/7 coverage)
- **Weekdays**: Monday - Friday
- **Weekend**: Saturday - Sunday
- **Hours**: 00:00 - 23:59 UTC
- **Response Time**: < 15 minutes for P0/P1 incidents

### Secondary On-Call (Escalation)
- **Availability**: Monday - Friday
- **Hours**: 09:00 - 18:00 UTC
- **Purpose**: Backup for primary on-call

### Rotation Handoff

**Daily Handoff Time**: 10:00 UTC

**Handoff Checklist:**
- [ ] Review overnight alerts
- [ ] Discuss ongoing incidents
- [ ] Transfer context for active issues
- [ ] Update handoff document

## On-Call Engineers

| Name        | Primary | Secondary | Timezone    | Contact               |
|-------------|----------|------------|----------|----------------------|
| Andrey Z.   | Yes      | No         | Europe/Moscow | andrey@s7.ru        |
| [TBD]       | No       | Yes        | Europe/Moscow | [TBD]@s7.ru         |

## Escalation Path

1. **Secondary On-Call** (if no response in 15 min)
2. **Engineering Manager** (P0 incidents only)
3. **Platform Lead** (critical infrastructure issues)

## Related Procedures

- [Escalation Paths](./escalation-paths.md)
- [Incident Declaration](../../templates/incident-declaration.md)
