# On-Call Training Guide

## Overview

This training guide prepares team members for on-call responsibilities in Spark on Kubernetes environments.

## Training Objectives

By the end of this training, you will be able to:

1. Understand the on-call rotation and escalation paths
2. Effectively respond to incidents using runbooks
3. Diagnose and resolve common Spark issues
4. Communicate effectively during incidents
5. Conduct post-incident reviews

## Prerequisites

- Access to Kubernetes cluster
- Access to monitoring tools (Prometheus, Grafana, Loki)
- Familiarity with Spark architecture
- Completion of this training quiz (80%+ score required)

## Training Modules

### Module 1: On-Call Fundamentals

**Duration**: 30 minutes

**Topics**:
- On-call rotation schedule
- Escalation paths and contacts
- Communication channels (Slack, PagerDuty, email)
- Incident severity classification (P0-P3)
- On-call handoff process

**Resources**:
- [On-Call Rotation Schedule](../procedures/on-call/rotation-schedule.md)
- [Escalation Paths](../procedures/on-call/escalation-paths.md)
- [Incident Response](../runbooks/incidents/incident-response.md)

**Assessment**:
- Identify correct severity levels for given scenarios
- Demonstrate escalation path for P0 incident

---

### Module 2: Monitoring and Alerting

**Duration**: 45 minutes

**Topics**:
- Prometheus queries and dashboards
- Grafana dashboard navigation
- AlertManager configuration
- Log aggregation with Loki
- Distributed tracing with Jaeger

**Resources**:
- [Observability Stack](../../docs/drafts/feature-observability.md)
- [Monitoring Runbooks](../runbooks/scaling/)

**Assessment**:
- Query Prometheus for specific metrics
- Interpret Grafana dashboard
- Find relevant logs in Loki

---

### Module 3: Common Spark Failures

**Duration**: 60 minutes

**Topics**:
- Driver pod crash loop
- Executor pod failures
- OOM kill mitigation
- Task failure recovery
- Shuffle failure handling
- Spark Connect connection issues

**Resources**:
- [Spark Failure Runbooks](../runbooks/spark/)
- [Data Recovery Runbooks](../runbooks/data/)

**Assessment**:
- Diagnose driver crash loop using logs
- Mitigate OOM kill by adjusting memory settings
- Recover from shuffle failure

---

### Module 4: Incident Response

**Duration**: 45 minutes

**Topics**:
- Incident declaration
- Incident command roles
- Communication during incidents
- Incident resolution workflow
- Customer communication

**Resources**:
- [Incident Response Runbook](../runbooks/incidents/incident-response.md)
- [PIR Template](../templates/pira-template.md)

**Assessment**:
- Declare incident with proper severity
- Execute incident response workflow
- Draft customer communication

---

### Module 5: Runbook Usage

**Duration**: 30 minutes

**Topics**:
- Runbook structure and sections
- Finding the right runbook
- Executing runbook steps
- Runbook validation
- Runbook feedback process

**Resources**:
- [Runbook Testing](../procedures/runbook-testing.md)

**Assessment**:
- Find appropriate runbook for given scenario
- Execute runbook in staging environment

---

### Module 6: Post-Incident Review

**Duration**: 30 minutes

**Topics**:
- PIR purpose and scope
- PIR template usage
- Root cause analysis methods (5 Whys, Fishbone)
- Blameless culture
- Action item tracking

**Resources**:
- [Post-Incident Review Procedure](../procedures/incidents/post-incident-review.md)
- [Root Cause Analysis](../procedures/incidents/root-cause-analysis.md)
- [Blameless Culture](../procedures/incidents/blameless-culture.md)

**Assessment**:
- Complete PIR template for sample incident
- Apply 5 Whys technique

---

## Training Quiz

### Section 1: Incident Severity

**Q1**: A Spark job failure affects all users for 2 hours. What is the severity?
- a) P0
- b) P1
- c) P2
- d) P3

**Answer**: a) P0 - Complete service outage affecting all users.

**Q2**: Single user experiencing slow query response. What is the severity?
- a) P0
- b) P1
- c) P2
- d) P3

**Answer**: d) P3 - Minor issue affecting single user.

---

### Section 2: Escalation

**Q3**: Who do you contact first when a P0 incident is declared?
- a) Engineering manager
- b) CTO
- c) Start incident response process
- d) Post on social media

**Answer**: c) Start incident response process (declare incident, set up comms channel).

**Q4**: When do you escalate to the next level?
- a) After 1 hour
- b) After 2 hours
- c) When SLA is at risk
- d) Never handle alone

**Answer**: d) Never handle alone - always engage team immediately for P0/P1.

---

### Section 3: Diagnosis

**Q5**: A Spark job shows "OutOfMemoryError: Java heap space". What do you check first?
- a) Network connectivity
- b) Disk space
- c) Executor memory settings
- d) DNS resolution

**Answer**: c) Executor memory settings - check memory requests and actual usage.

**Q6**: Executor pods are being OOMKilled. What is the first remediation step?
- a) Increase executor memory
- b) Increase executor count
- c) Check for data skew
- d) All of the above

**Answer**: d) All of the above - need to investigate all potential causes.

---

### Section 4: Communication

**Q7**: What information should be included in a customer notification for a P1 incident?
- a) We're working on it
- b) Impact, timeline, next update
- c) Technical details of the issue
- d) All internal team discussion

**Answer**: b) Impact, timeline, next update - what customers need to know.

**Q8**: When should you notify customers about an incident?
- a) Only after it's resolved
- b) Within 15 minutes of detection
- c) Never, they won't notice
- d) Only if they complain

**Answer**: b) Within 15 minutes of detection (or per your SLA).

---

### Section 5: Post-Incident

**Q9**: What is the purpose of a blameless PIR?
- a) To identify who made the mistake
- b) To learn and improve systems
- c) To assign blame
- d) To punish the responsible party

**Answer**: b) To learn and improve systems.

**Q10**: Which of the following is NOT part of a PIR?
- a) What happened
- b) Who is to blame
- c) Root cause analysis
- d) Action items

**Answer**: b) Who is to blame - blameless PIRs focus on systems, not individuals.

---

## Certification Requirements

To become certified for on-call duty:

1. **Complete all training modules**: ~4 hours total
2. **Pass training quiz**: Score 80%+ (8/10 questions)
3. **Complete shadow rotation**: Shadow current on-call for 1 week
4. **Pass practical assessment**: Diagnose and resolve sample incident in staging
5. **Sign-off**: Get sign-off from SRE lead

## Recertification

Annual recertification required:
- Complete updated training modules
- Pass updated quiz
- Review new runbooks added in past year
- Shadow on-call for 2 days

## Resources

### Quick Reference
- [Incident Severity Guide](../runbooks/incidents/severity-guide.md)
- [Escalation Contacts](../procedures/on-call/escalation-paths.md)
- [Runbook Index](../runbooks/README.md)

### Deep Dive
- [Blameless Culture](../procedures/incidents/blameless-culture.md)
- [Root Cause Analysis](../procedures/incidents/root-cause-analysis.md)
- [PIR Template](../templates/pira-template.md)

### Practice
- [Incident Scenarios](./incident-scenarios.md)
- [Training Environment Setup](./training-setup.md)

---

**Training Version**: 1.0
**Last Updated**: 2026-02-11
**Maintained By**: SRE Team
