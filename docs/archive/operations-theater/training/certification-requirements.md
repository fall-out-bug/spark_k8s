# On-Call Certification Requirements

## Overview

This document defines the requirements for on-call certification in Spark on Kubernetes environments.

## Certification Prerequisites

Before starting on-call training, you must:

1. **Complete Kubernetes Fundamentals**
   - Basic kubectl commands
   - Pod and deployment concepts
   - Service and ingress understanding
   - ConfigMap and secret usage

2. **Complete Apache Spark Fundamentals**
   - Spark architecture (driver, executor, shuffle)
   - Spark job lifecycle
   - Common Spark configurations
   - Understanding of Spark UI

3. **Complete Monitoring Tools Training**
   - Prometheus basics
   - Grafana dashboard navigation
   - Loki log queries
   - AlertManager configuration

## Training Requirements

### Module Completion

Complete all 6 training modules:

| Module | Duration | Status |
|--------|----------|--------|
| 1. On-Call Fundamentals | 30 min | [ ] |
| 2. Monitoring and Alerting | 45 min | [ ] |
| 3. Common Spark Failures | 60 min | [ ] |
| 4. Incident Response | 45 min | [ ] |
| 5. Runbook Usage | 30 min | [ ] |
| 6. Post-Incident Review | 30 min | [ ] |

### Quiz Completion

Pass the training quiz with 80%+ score (8/10 questions correct).

## Shadow Rotation Requirements

### Duration: 1 Week

Shadow the current on-call engineer for one full week including:

- [ ] Attend daily standup
- [ ] Participate in incident responses (if any)
- [ ] Review alert handling
- [ ] Practice using monitoring tools
- [ ] Execute runbooks in staging
- [ ] Document shadow observations

### Shadow Rotation Checklist

**Day 1: Orientation**
- Review on-call schedule
- Set up communication tools
- Review escalation paths
- Practice incident declaration

**Days 2-3: Observation**
- Monitor alerts with on-call
- Review incident response
- Practice diagnostics
- Ask questions

**Days 4-5: Practice**
- Handle simulated incidents
- Execute runbooks in staging
- Practice communication
- Get feedback from on-call

## Practical Assessment

### Incident Resolution

Diagnose and resolve a sample incident in the staging environment:

**Scenario**: Driver pod crash loop

**Tasks**:
1. Identify the incident severity (P0-P3)
2. Find the appropriate runbook
3. Execute diagnosis steps
4. Implement remediation
5. Verify the fix
6. Document the resolution

**Passing Criteria**:
- Correct severity identified
- Appropriate runbook selected
- All steps executed successfully
- Incident resolved within SLA
- Documentation complete

## Sign-Off Requirements

### Self-Assessment

Complete the self-assessment checklist:

- [ ] I understand the on-call rotation and escalation paths
- [ ] I can identify incident severity levels correctly
- [ ] I can navigate Prometheus and Grafana effectively
- [ ] I can diagnose common Spark failures
- [ ] I can execute runbooks correctly
- [ ] I can communicate effectively during incidents
- [ ] I understand blameless culture and PIR process
- [ ] I feel confident handling incidents independently

### Manager Sign-Off

Get sign-off from your manager:

- [ ] Training modules completed
- [ ] Quiz passed (80%+ score)
- [ ] Shadow rotation completed
- [ ] Practical assessment passed
- [ ] Self-assessment complete
- [ ] Manager approval: _________________ Date: _______

### SRE Lead Sign-Off

Get sign-off from the SRE lead:

- [ ] Reviewed shadow rotation performance
- [ ] Reviewed practical assessment
- [ ] Verified runbook proficiency
- [ ] Confirmed readiness for on-call duty
- [ ] SRE lead approval: _________________ Date: _______

## Certification Validity

- **Duration**: 1 year from certification date
- **Recertification**: Required annually
- **Revocation**: Possible for failure to follow procedures

## Recertification Requirements

Annual recertification requires:

1. Complete updated training modules (1-2 hours)
2. Pass updated quiz (80%+ score)
3. Shadow on-call for 2 days
4. Review new runbooks added in past year
5. Complete practical assessment with new scenarios

## Decertification

Certification may be revoked for:

- Failure to respond to P0 incidents
- Repeated failure to follow procedures
- Blaming individuals during incidents
- Incomplete PIR documentation
- Failure to complete recertification

## Appeals Process

If certification is denied:

1. Review reason for denial
2. Complete additional training if needed
3. Retake practical assessment
4. Re-apply for certification

## Resources

### Training Materials
- [On-Call Training Guide](./on-call-training.md)
- [Incident Scenarios](./incident-scenarios.md)
- [Training Quiz](./training-quiz.md)

### References
- [On-Call Procedures](../procedures/on-call/rotation-schedule.md)
- [Incident Response](../runbooks/incidents/incident-response.md)

---

**Document Version**: 1.0
**Last Updated**: 2026-02-11
**Maintained By**: SRE Team
