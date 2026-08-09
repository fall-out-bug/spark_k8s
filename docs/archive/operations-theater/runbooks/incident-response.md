# Incident Response Runbook

Structured framework for responding to Spark platform incidents with severity levels, escalation paths, and communication templates.

## 🎯 Overview

This runbook provides a structured approach to incident response for the Apache Spark on Kubernetes platform, following industry best practices (PIRA framework - Preparation, Identification, Response, Aftermath).

---

## 🚨 Severity Levels

### P0 - Critical (Page Immediately)

**Definition:** Complete platform outage affecting all users

**Examples:**
- All Spark jobs failing
- Complete data loss
- Security breach
- Cluster completely unavailable

**Response Time:** Page immediately, 15 min initial response

**Escalation:** If not resolved in 30 min → Engineering Manager

### P1 - High (Page Within 15 min)

**Definition:** Significant degradation affecting multiple users

**Examples:**
- Multiple job failures (>50% failure rate)
- Severe performance degradation (>5x slower)
- Single data source unavailable
- Partial cluster failure

**Response Time:** Page within 15 min, 1 hour initial response

**Escalation:** If not resolved in 2 hours → Engineering Manager

### P2 - Medium (Respond Within 1 Hour)

**Definition:** Limited impact affecting specific users or features

**Examples:**
- Single team jobs failing
- Moderate performance degradation (2-5x slower)
- Non-critical feature broken

**Response Time:** Respond within 1 hour, 4 hour initial response

**Escalation:** If not resolved in 1 day → Team Lead

### P3 - Low (Next Business Day)

**Definition:** Minor issues with workaround available

**Examples:**
- Documentation errors
- UI issues
- Feature requests

**Response Time:** Next business day

**Escalation:** If not resolved in 1 week → Team Lead

---

## 📋 Incident Response Workflow

### Phase 1: Preparation (Pre-Incident)

**On-Call Setup:**

1. **Rotation Schedule**
   - Weekly rotation shared in calendar
   - Primary and secondary on-call
   - Handoff document reviewed weekly

2. **Monitoring**
   - Alerts configured for all P0/P1 scenarios
   - PagerDuty/on-call tool integration
   - Dashboard for quick health check

3. **Access**
   - On-call has cluster admin access
   - Runbook links bookmarked
   - Communication tools configured

4. **Documentation**
   - This runbook reviewed monthly
   - Contact list up-to-date
   - Escalation paths verified

### Phase 2: Identification (Detection)

**Detection Methods:**

1. **Automated Alerts**
   - Prometheus/PagerDuty alerts
   - Health check failures
   - Metrics exceeding thresholds

2. **User Reports**
   - Support tickets
   - Telegram messages
   - Direct reports

**Triage Steps:**

```bash
# 1. Run health check
./scripts/diagnostics/spark-health-check.sh

# 2. Check recent errors
kubectl logs -l app.kubernetes.io/part-of=spark-k8s --tail=100

# 3. Check metrics
kubectl port-forward svc/prometheus 9090:9090
# Query: spark_job_failed_total, driver_pod_oom_killed_total

# 4. Determine severity
# Use severity level definitions above
```

**Create Incident Ticket:**

```markdown
## Incident: [Brief Description]

**Severity:** P0/P1/P2/P3
**Reporter:** [Name]
**Started:** [Timestamp]
**Affected:** [Who/What]

### Impact
[What is broken? Who is affected?]

### Current Status
[What do we know right now?]

### Initial Actions
[What have we tried so far?]
```

### Phase 3: Response (Mitigation)

**Standard Response Procedure:**

1. **Acknowledge (5 min)**
   - Update incident ticket: "Investigating"
   - Post to #incidents channel: "Investigating P0: [description]"
   - Join incident bridge call (if P0/P1)

2. **Diagnose (15-30 min)**
   - Run health check script
   - Check logs and metrics
   - Identify root cause hypothesis
   - Update ticket with findings

3. **Mitigate (Time varies by severity)**
   - Implement temporary fix (restore service)
   - Document workaround
   - Communicate status
   - Monitor for stability

4. **Resolve**
   - Permanent fix implemented
   - Verify service restored
   - Close incident ticket
   - Schedule post-incident review

**Common Incident Patterns:**

| Pattern | Detection | Mitigation | Permanent Fix |
|---------|-----------|------------|---------------|
| Driver OOM | `driver_pod_oom_killed_total > 0` | Increase driver memory, restart job | Tune memory settings |
| Executor Loss | `executor_removed_total > 0` | Increase executor count, retry | Fix root cause, add retries |
| Network Timeout | Connection refused errors | Restart pods, check network | Fix network policy |
| Storage Issue | Can't read/write data | Check PVC, restore from backup | Fix storage configuration |
| High Load | CPU > 90%, slow jobs | Scale up executors | Right-size resources |

### Phase 4: Aftermath (Post-Incident)

**Immediate Actions (Same Day):**

1. **Post-Incident Review (PIR)**
   - Schedule within 24-48 hours
   - All responders attend
   - Document timeline and root cause

2. **Communication**
   - Postmortem published
   - Stakeholders notified
   - Customers updated (if applicable)

**Follow-up Actions (Within 1 Week):**

1. **Action Items**
   - Create tickets for improvements
   - Prioritize by severity
   - Assign owners

2. **Process Updates**
   - Update runbooks based on learnings
   - Improve monitoring/alerts
   - Update documentation

---

## 📢 Communication Templates

### Initial Announcement (P0/P1)

```markdown
🚨 **[P0/P1] Incident: [Brief Description]**

**Status:** 🟡 Investigating
**Started:** [Time]
**Severity:** P0/P1

**Impact:** [Brief description of impact]

**Next Update:** [Time, typically 30 min]

*Follow along in #incident-[number]*
```

### Update Template

```markdown
🚨 **[P0/P1] Incident Update: [Brief Description]**

**Status:** [Investigating / Mitigating / Monitoring / Resolved]
**Started:** [Time]
**Duration:** [X hours]

**Update:** [What's new, what we're doing]

**Next Update:** [Time]

*Details: [ticket link]*
```

### Resolution Template

```markdown
🟢 **[P0/P1] Incident Resolved: [Brief Description]**

**Status:** ✅ Resolved
**Duration:** [X hours]
**Severity:** P0/P1

**Root Cause:** [Summary]

**Resolution:** [Summary of fix]

**Postmortem:** Coming soon

**Questions?** Contact [on-call]
```

---

## 📞 Escalation Paths

### On-Call Structure

```
Primary On-Call
├── Responsible for: All P0/P1 incidents
├── Response time: 15 min (P0), 1 hour (P1)
└── Escalates to: Secondary On-Call

Secondary On-Call
├── Backup for primary
├── Response time: 30 min (P0)
└── Escalates to: Team Lead

Team Lead
├── Responsible for: Escalated incidents
├── Response time: 1 hour (P0/P1)
└── Escalates to: Engineering Manager

Engineering Manager
├── Responsible for: Critical incidents
├── Response time: Immediate for P0
└── Escalates to: CTO (if needed)
```

### Escalation Triggers

| Severity | Escalate If | To Whom |
|----------|-------------|---------|
| P0 | Not resolved in 30 min | Engineering Manager |
| P0 | Not resolved in 1 hour | CTO |
| P1 | Not resolved in 2 hours | Engineering Manager |
| P1 | Not resolved in 4 hours | CTO |
| P2 | Not resolved in 1 day | Team Lead |
| P3 | Not resolved in 1 week | Team Lead |

---

## 🛠️ Quick Commands During Incident

### Diagnostics

```bash
# Quick health check
./scripts/diagnostics/spark-health-check.sh

# Check for failed pods
kubectl get pods -l app.kubernetes.io/part-of=spark-k8s --field-selector=status.phase=Failed

# Check recent errors
kubectl logs -l app.kubernetes.io/part-of=spark-k8s --tail=50 | grep -i error

# Check resource usage
kubectl top pods -l app.kubernetes.io/part-of=spark-k8s
kubectl top nodes

# Port-forward Spark UI
kubectl port-forward svc/spark-history 18080:18080
```

### Emergency Actions

```bash
# Restart Spark Connect
kubectl rollout restart deployment/spark-connect

# Scale up executors
kubectl scale statefulset spark-connect-executor --replicas=20

# Kill specific job
kubectl delete pod <driver-pod>

# Restore from backup (if storage issue)
kubectl apply -f backups/restore-manual.yaml
```

---

## 📊 Incident Metrics

### Track Monthly

| Metric | Target | How to Measure |
|--------|--------|----------------|
| **MTTD** (Mean Time To Detect) | <5 min | Time from start to detection |
| **MTTR** (Mean Time To Resolve) | P0: <30 min, P1: <2 hours | Time from detection to resolution |
| **Incident Count** | <5 P0, <10 P1 per month | Count from incident tickets |
| **Repeat Incidents** | <10% | Same root cause within 30 days |

### Review Cadence

- **Weekly:** On-call handoff, review recent incidents
- **Monthly:** Metrics review, process improvement
- **Quarterly:** Major incident retrospective, process overhaul

---

## 📚 Related Resources

- [Troubleshooting Guide](../troubleshooting.md) — Decision trees for issues
- [Job Failures Runbook](job-failures.md) — Specific job failure procedures
- [Performance Tuning Runbook](performance.md) — Performance procedures
- [Production Checklist](../production-checklist.md) — Prevention measures
- [Alert Configuration](../alert-configuration.md) — Alert setup

---

**Last Updated:** 2026-02-04
**Part of:** [F18: Production Operations Suite](../../drafts/feature-production-operations.md)
**Version:** 1.0
