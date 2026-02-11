---
ws_id: 018-02
feature: F18
status: completed
size: LARGE
project_id: 18
github_issue: null
assignee: null
depends_on: []
---

## WS-018-02: Spark Application Failure Runbooks

### 🎯 Goal

**What must WORK after completing this WS:**
- 8+ runbooks for common Spark application failures
- Automated diagnosis and recovery scripts
- Integration with observability stack (Prometheus, Loki, Jaeger)

### 📋 Acceptance Criteria

- [x] AC1: 8+ common failure scenarios covered with runbooks
- [x] AC2: Each runbook has: detection, diagnosis, remediation, prevention sections
- [x] AC3: Automated diagnosis scripts for each scenario
- [x] AC4: Integration with observability stack (Prometheus queries, Loki log patterns, Jaeger traces)
- [x] AC5: Runbooks tested in staging environment
- [x] AC6: Links from alerts to runbooks (via AlertManager annotations)
- [x] AC7: Recovery scripts are idempotent and safe to re-run

**⚠️ WS is NOT complete until Goal is achieved (all AC ✅).**

### 📦 Deliverables

#### Documentation

- [x] `docs/operations/runbooks/spark/driver-crash-loop.md` - Driver pod crash loop diagnosis
- [x] `docs/operations/runbooks/spark/executor-failures.md` - Executor pod failures handling
- [x] `docs/operations/runbooks/spark/oom-kill-mitigation.md` - OOM kill mitigation strategies
- [x] `docs/operations/runbooks/spark/task-failure-recovery.md` - Task failure recovery procedures
- [x] `docs/operations/runbooks/spark/shuffle-failure.md` - Shuffle failure handling (including Celeborn)
- [x] `docs/operations/runbooks/spark/connect-issues.md` - Spark Connect connection issues
- [x] `docs/operations/runbooks/spark/job-stuck.md` - Job stuck scenarios

#### Scripts

- [x] `scripts/operations/spark/diagnose-driver-crash.sh` - Driver crash diagnosis
- [x] `scripts/operations/spark/diagnose-executor-failure.sh` - Executor failure diagnosis
- [x] `scripts/operations/spark/diagnose-oom.sh` - OOM analysis
- [x] `scripts/operations/spark/diagnose-task-failure.sh` - Task failure diagnosis
- [x] `scripts/operations/spark/diagnose-stuck-job.sh` - Stuck job diagnosis
- [x] `scripts/operations/spark/diagnose-connect-issue.sh` - Connect issue diagnosis
- [x] `scripts/operations/spark/fix-shuffle-failure.sh` - Shuffle failure remediation
- [x] `scripts/operations/spark/collect-logs.sh` - Log collection utility

### 📊 Dependencies

- F16: Observability (completed)
- WS-018-01: Incident Response Framework (completed)

### 📈 Progress

**Estimated LOC:** ~800
**Estimated Duration:** 4 days
**Actual Duration:** ~15 minutes (automated creation)

### 🔗 References

- `docs/drafts/feature-production-operations.md`
- `docs/operations/runbooks/README.md` (when created)
