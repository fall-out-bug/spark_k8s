# F18: Production Operations Suite

> **Type:** Feature
> **Priority:** P0 (Production Readiness Blocker)
> **Phase:** Phase 12 - Production Operations
> **Owner:** Andrey Zhukov
> **Status:** Draft
> **Created:** 2026-02-04

---

## Overview

Complete operational excellence capabilities for production deployment of Apache Spark on Kubernetes. This feature provides the runbooks, automation, and procedures necessary for day-2 operations in production environments.

### Business Value

- **Risk Reduction**: Automated backups and DR testing reduce RTO from 1-4 hours to <30 minutes
- **Faster MTTR**: Comprehensive runbooks reduce incident resolution time by 50%+
- **Developer Velocity**: Job CI/CD patterns enable safe, rapid deployments
- **Cost Control**: Cost visibility enables optimization and accountability
- **On-call Enablement**: Structured incident response and runbooks enable on-call rotations

### Target Personas

- **Primary:** DevOps/SRE (daily operations, incident response)
- **Secondary:** DataOps (deployment automation, monitoring)
- **Tertiary:** Platform Engineers (capacity planning, cost optimization)
- **Quad:** Data Engineers (job failure troubleshooting, performance tuning)

---

## Workstreams

### WS-018-01: Incident Response Framework (P0)

**Goal:** Create structured incident response procedures with on-call rotation and escalation.

**Scope:**
- Incident severity classification (P0-P3)
- On-call rotation schedule template
- Escalation paths and contacts
- Incident communication templates
- Automated incident declaration script
- Post-incident review framework

**Estimated LOC:** ~600
**Estimated Duration:** 3 days
**Dependencies:** F16 (Observability)

**Deliverables:**
- `docs/operations/runbooks/incidents/incident-response.md`
- `docs/operations/procedures/on-call/rotation-schedule.md`
- `docs/operations/procedures/on-call/escalation-paths.md`
- `docs/operations/templates/pira-template.md`
- `scripts/operations/incidents/declare-incident.sh`
- `scripts/operations/incidents/diagnose-spark-failure.sh`
- `scripts/operations/incidents/resolve-incident.sh`

**Acceptance Criteria:**
- AC1: Severity levels (P0-P3) defined with clear criteria
- AC2: On-call rotation template created (Slack/PagerDuty)
- AC3: Escalation paths documented with contacts
- AC4: Incident communication templates provided (email, Slack)
- AC5: Incident declaration script creates channel/ticket
- AC6: Post-incident review template includes root cause analysis
- AC7: Integration with F16 alerting (links from alerts to runbooks)

---

### WS-018-02: Spark Application Failure Runbooks (P0)

**Goal:** Create comprehensive runbooks for common Spark application failures with automated diagnosis and recovery.

**Scope:**
- Driver pod crash loop diagnosis
- Executor pod failures handling
- OOM kill mitigation strategies
- Task failure recovery procedures
- Shuffle failure handling (including Celeborn)
- Spark Connect connection issues
- Application master failures
- Job stuck scenarios

**Estimated LOC:** ~800
**Estimated Duration:** 4 days
**Dependencies:** F16, WS-018-01

**Deliverables:**
- `docs/operations/runbooks/spark/driver-crash-loop.md`
- `docs/operations/runbooks/spark/executor-failures.md`
- `docs/operations/runbooks/spark/oom-kill-mitigation.md`
- `docs/operations/runbooks/spark/task-failure-recovery.md`
- `docs/operations/runbooks/spark/shuffle-failure.md`
- `docs/operations/runbooks/spark/connect-issues.md`
- `docs/operations/runbooks/spark/job-stuck.md`
- `scripts/operations/spark/diagnose-driver-crash.sh`
- `scripts/operations/spark/diagnose-executor-failure.sh`
- `scripts/operations/spark/fix-shuffle-failure.sh`
- `scripts/operations/spark/collect-logs.sh`

**Acceptance Criteria:**
- AC1: 8+ common failure scenarios covered with runbooks
- AC2: Each runbook has: detection, diagnosis, remediation, prevention sections
- AC3: Automated diagnosis scripts for each scenario
- AC4: Integration with observability stack (Prometheus queries, Loki log patterns, Jaeger traces)
- AC5: Runbooks tested in staging environment
- AC6: Links from alerts to runbooks (via AlertManager annotations)
- AC7: Recovery scripts are idempotent and safe to re-run

---

### WS-018-03: Data Layer Recovery Runbooks (P0)

**Goal:** Automated recovery procedures for Hive Metastore and S3/MinIO data with validation.

**Scope:**
- Hive Metastore backup and restore automation
- S3 versioned object restore procedures
- MinIO volume recovery
- Data integrity verification (checksums)
- Metadata consistency checks
- Cross-region replication recovery
- Point-in-time recovery strategies

**Estimated LOC:** ~900
**Estimated Duration:** 4 days
**Dependencies:** F16, existing DR procedures

**Deliverables:**
- `docs/operations/runbooks/data/hive-metastore-restore.md`
- `docs/operations/runbooks/data/s3-object-restore.md`
- `docs/operations/runbooks/data/minio-volume-restore.md`
- `docs/operations/runbooks/data/data-integrity-check.md`
- `docs/operations/procedures/backup-dr/daily-backup.md`
- `docs/operations/procedures/backup-dr/restore-procedure.md`
- `scripts/operations/recovery/restore-hive-metastore.sh`
- `scripts/operations/recovery/restore-s3-bucket.sh`
- `scripts/operations/recovery/restore-minio-volume.sh`
- `scripts/operations/recovery/verify-hive-metadata.sh`
- `scripts/operations/recovery/verify-data-integrity.sh`
- `scripts/operations/recovery/check-metadata-consistency.sh`

**Acceptance Criteria:**
- AC1: Automated Hive restore works (RTO < 2h, RPO < 1h)
- AC2: S3 restore from versioning works (RTO < 4h)
- AC3: MinIO volume recovery tested and documented
- AC4: Data integrity verification passes (checksum validation)
- AC5: Metadata consistency checks identify corruption
- AC6: All recovery procedures tested in staging environment
- AC7: Recovery time metrics tracked and reported
- AC8: Integration with backup verification (WS-018-07)

---

### WS-018-04: SLI/SLO Definitions & Monitoring (P0)

**Goal:** Define Service Level Indicators and Objectives with alerting and dashboards.

**Scope:**
- SLI definitions: availability, latency, durability, throughput
- SLO targets: 99.9% availability, p95 latency < 5s, etc.
- Error budget calculations
- Prometheus rules for SLO monitoring
- Burn rate alerts (fast-burn, slow-burn)
- SLO dashboards in Grafana
- SLO reporting automation
- Multi-dimensional SLOs (by cluster, namespace, team)

**Estimated LOC:** ~600
**Estimated Duration:** 3 days
**Dependencies:** F16 (WS-016-01 Metrics, WS-016-05 Alerting, WS-016-04 Dashboards)

**Deliverables:**
- `docs/operations/procedures/monitoring/sli-slo-definitions.md`
- `docs/operations/procedures/monitoring/slo-targets.md`
- `docs/operations/procedures/monitoring/error-budgets.md`
- `charts/spark-4.1/templates/monitoring/prometheus-slo-rules.yaml`
- `charts/observability/grafana/dashboards/slo-compliance.json`
- `charts/observability/grafana/dashboards/error-budget.json`
- `charts/observability/grafana/dashboards/burn-rate.json`
- `scripts/operations/monitoring/generate-slo-report.sh`
- `scripts/operations/monitoring/burn-rate-alert.sh`

**Acceptance Criteria:**
- AC1: 5+ SLIs defined with clear formulas and data sources
- AC2: SLO targets documented with business justification
- AC3: Error budget calculation implemented
- AC4: Prometheus rules for burn rate alerts (fast/slow)
- AC5: SLO compliance dashboard shows current status
- AC6: Error budget dashboard visualizes consumption
- AC7: Burn rate dashboard alerts on accelerated consumption
- AC8: SLO reports generated daily/weekly/monthly
- AC9: SLOs tracked by dimensions (cluster, namespace, team, job type)

---

### WS-018-05: Scaling & Capacity Planning (P1)

**Goal:** Automated scaling procedures and capacity planning guidelines with cost optimization.

**Scope:**
- Horizontal Pod Autoscaler (HPA) configuration
- Vertical Pod Autoscaler (VPA) guidelines
- KEDA ScaledObject for Spark executors
- Cluster autoscaler integration
- Manual scaling procedures
- Capacity planning calculator
- Rightsizing recommendations
- Cost optimization strategies
- Spot instance usage
- Resource quota management

**Estimated LOC:** ~800
**Estimated Duration:** 3 days
**Dependencies:** F06 (Helm Charts), F16 (Observability)

**Deliverables:**
- `docs/operations/runbooks/scaling/horizontal-pod-autoscaler.md`
- `docs/operations/runbooks/scaling/vertical-pod-autoscaler.md`
- `docs/operations/runbooks/scaling/cluster-scaling.md`
- `docs/operations/runbooks/scaling/spark-executor-scaling.md`
- `docs/operations/procedures/capacity/capacity-planning.md`
- `docs/operations/procedures/capacity/rightsizing.md`
- `docs/operations/procedures/capacity/cost-optimization.md`
- `charts/spark-4.1/templates/hpa.yaml`
- `charts/spark-4.1/templates/vpa.yaml`
- `charts/spark-4.1/templates/keda-scaledobject.yaml`
- `scripts/operations/scaling/scale-cluster.sh`
- `scripts/operations/scaling/capacity-report.sh`
- `scripts/operations/scaling/rightsizing-recommendations.sh`
- `scripts/operations/scaling/calculate-executor-sizing.sh`

**Acceptance Criteria:**
- AC1: HPA configured for all stateless components (Jupyter, History Server)
- AC2: VPA recommendations documented for stateful components
- AC3: KEDA scaling for Spark executors (S3 trigger, schedule trigger)
- AC4: Cluster autoscaler integration documented
- AC5: Manual scaling script works for vertical/horizontal scaling
- AC6: Capacity report generates actionable insights (utilization, trends)
- AC7: Rightsizing calculator provides recommendations by workload type
- AC8: Cost optimization guide covers: dynamic allocation, spot instances, rightsizing
- AC9: Resource quota templates for different team sizes
- AC10: Scaling procedures tested in staging

---

### WS-018-06: Post-Incident Review Process (P1)

**Goal:** Structured blameless post-incident review framework with action tracking.

**Scope:**
- PIRA (Post-Incident Review Analysis) template
- Root cause analysis methodology
- Action item tracking system
- Learning dissemination process
- Incident metrics dashboard
- PIRA facilitation guide
- Blameless culture guidelines

**Estimated LOC:** ~400
**Estimated Duration:** 2 days
**Dependencies:** WS-018-01

**Deliverables:**
- `docs/operations/templates/pira-template.md`
- `docs/operations/procedures/incidents/post-incident-review.md`
- `docs/operations/procedures/incidents/root-cause-analysis.md`
- `docs/operations/procedures/incidents/blameless-culture.md`
- `scripts/operations/incidents/generate-pira-template.sh`
- `scripts/operations/incidents/track-actions.sh`
- `charts/observability/grafana/dashboards/incident-metrics.json`

**Acceptance Criteria:**
- AC1: PIRA template includes: what happened, impact, timeline, root cause, fixes, prevention
- AC2: GitHub issue integration for action item tracking
- AC3: Action items tracked to completion with due dates
- AC4: Root cause analysis methodology documented (5 Whys, Fishbone)
- AC5: Blameless culture guidelines for PIRA facilitation
- AC6: Incident metrics dashboard tracks: MTTR, frequency, severity distribution
- AC7: Learning dissemination process (tech talk, doc update, runbook creation)
- AC8: PIRA database/search for historical incidents

---

### WS-018-07: Backup/DR Automation (P1)

**Goal:** Automated backup scheduling, validation, and disaster recovery testing.

**Scope:**
- Kubernetes CronJob for automated backups
- Hive Metastore backup automation
- MinIO/S3 data backup
- Airflow metadata backup
- MLflow experiment backup
- Backup verification automation
- Restore testing to staging
- Backup retention policies
- Cross-region replication
- Backup failure alerting
- RTO/RPO monitoring dashboard

**Estimated LOC:** ~900
**Estimated Duration:** 4 days
**Dependencies:** F16, existing DR procedures

**Deliverables:**
- `docs/operations/procedures/backup-dr/daily-backup.md`
- `docs/operations/procedures/backup-dr/backup-verification.md`
- `docs/operations/procedures/backup-dr/restore-procedure.md`
- `docs/operations/procedures/backup-dr/dr-test-schedule.md`
- `charts/spark-base/templates/backup-cronjob.yaml`
- `scripts/operations/backup/create-hive-backup.sh`
- `scripts/operations/backup/create-minio-backup.sh`
- `scripts/operations/backup/create-airflow-backup.sh`
- `scripts/operations/backup/create-mlflow-backup.sh`
- `scripts/operations/backup/verify-backups.sh`
- `scripts/operations/backup/test-restore-to-staging.sh`
- `scripts/operations/backup/retention-policy.sh`
- `scripts/operations/backup/replicate-to-dr-region.sh`
- `charts/observability/grafana/dashboards/backup-status.json`
- `charts/observability/grafana/dashboards/rto-rpo.json`

**Acceptance Criteria:**
- AC1: Automated daily backups scheduled via CronJob
- AC2: Backup verification runs automatically (checksum + restore test)
- AC3: Monthly restore test to staging environment
- AC4: Backup retention policy automated (daily: 7d, weekly: 4w, monthly: 12m)
- AC5: Cross-region replication for critical backups
- AC6: Backup failures alert within 15 minutes (Prometheus + AlertManager)
- AC7: Backup status dashboard shows: last backup time, size, status
- AC8: RTO/RPO dashboard tracks recovery metrics
- AC9: RTO < 30 minutes for critical components
- AC10: RPO < 1 hour for all components

---

### WS-018-08: Job CI/CD Framework (P1)

**Goal:** Job-level CI/CD pipelines for Spark jobs with validation and promotion.

**Scope:**
- GitHub Actions workflows for Spark jobs
- Dry-run validation (helm template)
- Spark SQL validation (syntax, schema checks)
- Python/Scala code linting
- Data quality gates (Great Expectations)
- Environment promotion (dev → staging → prod)
- Smoke test automation
- Job deployment rollback
- Blue-green deployment patterns
- A/B testing framework
- Canary releases
- Job versioning and tagging

**Estimated LOC:** ~1000
**Estimated Duration:** 5 days
**Dependencies:** F08 (Smoke Tests), F15 (Parallel Execution), F12 (E2E Tests)

**Deliverables:**
- `docs/operations/procedures/cicd/job-cicd-pipeline.md`
- `docs/operations/procedures/cicd/dry-run-validation.md`
- `docs/operations/procedures/cicd/sql-validation.md`
- `docs/operations/procedures/cicd/data-quality-gates.md`
- `docs/operations/procedures/cicd/blue-green-deployment.md`
- `docs/operations/procedures/cicd/ab-testing.md`
- `.github/workflows/spark-job-ci.yml`
- `.github/workflows/spark-job-deploy.yml`
- `scripts/cicd/validate-spark-job.sh`
- `scripts/cicd/dry-run-spark-job.sh`
- `scripts/cicd/validate-sql.sh`
- `scripts/cicd/run-data-quality-checks.sh`
- `scripts/cicd/promote-job.sh`
- `scripts/cicd/rollback-job.sh`
- `scripts/cicd/ab-test-spark-job.sh`
- `scripts/cicd/smoke-test-job.sh`

**Acceptance Criteria:**
- AC1: GitHub Actions workflow for job CI (lint, validate, test)
- AC2: Dry-run validation prevents invalid deployments
- AC3: SQL validation catches syntax and schema errors
- AC4: Data quality gates run before promotion
- AC5: Environment promotion workflow with manual approval
- AC6: Smoke tests run after deployment
- AC7: Rollback procedure documented and tested
- AC8: Blue-green deployment patterns documented
- AC9: A/B testing framework supports canary releases
- AC10: Job versioning tracks deployments and changes

---

### WS-018-09: SQL & Code Validation (P1)

**Goal:** Automated validation for Spark SQL, Python, and Scala code in CI/CD.

**Scope:**
- Spark SQL syntax validation
- Spark SQL schema validation (against catalog)
- Python code linting (pylint, flake8, black)
- Scala code linting (scalafmt, scalastyle)
- Security scanning (bandit, scalastyle security rules)
- Dependency vulnerability scanning
- Code coverage reporting
- Performance regression detection
- SQL query plan analysis
- Best practices enforcement

**Estimated LOC:** ~700
**Estimated Duration:** 3 days
**Dependencies:** WS-018-08

**Deliverables:**
- `docs/operations/procedures/cicd/sql-validation.md`
- `docs/operations/procedures/cicd/python-validation.md`
- `docs/operations/procedures/cicd/scala-validation.md`
- `.github/workflows/code-validation.yml`
- `scripts/cicd/validate-spark-sql.sh`
- `scripts/cicd/analyze-sql-plan.sh`
- `scripts/cicd/lint-python.sh`
- `scripts/cicd/lint-scala.sh`
- `scripts/cicd/scan-dependencies.sh`
- `scripts/cicd/detect-performance-regression.sh`
- `configs/codestyle/.flake8`
- `configs/codestyle/pyproject.toml`
- `configs/codestyle/scalafmt.conf`

**Acceptance Criteria:**
- AC1: Spark SQL validator catches syntax errors
- AC2: Schema validator checks against Hive Metastore
- AC3: Python linting enforces PEP8 and project standards
- AC4: Scala linting enforces style and best practices
- AC5: Security scanning identifies vulnerabilities
- AC6: Dependency scanning runs in CI
- AC7: Code coverage reported for test suites
- AC8: Performance regression detected (baseline comparison)
- AC9: SQL query plan analyzer identifies anti-patterns
- AC10: All validations run in CI before merge

---

### WS-018-10: Cost Attribution Dashboard (P2)

**Goal:** Per-job, per-team cost attribution with breakdown by resource type.

**Scope:**
- Cost calculation by executor usage
- Per-job cost tracking
- Per-team cost aggregation
- Cost breakdown by component (driver, executor, storage)
- Spot vs on-demand cost comparison
- Time-based cost trends
- Cost forecasting
- Grafana dashboards for cost visualization
- Cost export for billing systems

**Estimated LOC:** ~600
**Estimated Duration:** 3 days
**Dependencies:** F16 (WS-016-01 Metrics, WS-016-04 Dashboards)

**Deliverables:**
- `docs/operations/procedures/cost/cost-attribution.md`
- `scripts/operations/cost/calculate-job-cost.sh`
- `scripts/operations/cost/calculate-team-cost.sh`
- `scripts/operations/cost/cost-breakdown.sh`
- `scripts/operations/cost/forecast-cost.sh`
- `charts/observability/grafana/dashboards/cost-by-job.json`
- `charts/observability/grafana/dashboards/cost-by-team.json`
- `charts/observability/grafana/dashboards/cost-breakdown.json`
- `charts/observability/grafana/dashboards/cost-trends.json`
- `charts/spark-4.1/templates/cost-exporter-cronjob.yaml`

**Acceptance Criteria:**
- AC1: Cost calculated per job (executor-seconds × rate)
- AC2: Cost aggregated by team (label-based)
- AC3: Cost breakdown by component (driver, executor, storage, network)
- AC4: Spot vs on-demand cost comparison available
- AC5: Time-based cost trends (daily, weekly, monthly)
- AC6: Cost forecasting based on historical trends
- AC7: Grafana dashboards show: current costs, trends, forecasts
- AC8: Cost export to CSV/JSON for billing integration
- AC9: Cost metrics stored in Prometheus for long-term tracking
- AC10: Cost attribution linked to job metadata (team, project, cost center)

---

### WS-018-11: Budget Alerts & Optimization (P2)

**Goal:** Budget alerts, anomaly detection, and right-sizing recommendations.

**Scope:**
- Budget definition per team/project
- Budget alerting (daily, weekly, monthly)
- Cost anomaly detection (sudden spikes)
- Right-sizing recommendations based on usage
- Idle resource identification
- Cost optimization suggestions
- Budget forecast alerts
- Overspend prevention
- Cost notification channels (Slack, email)

**Estimated LOC:** ~500
**Estimated Duration:** 2 days
**Dependencies:** WS-018-10

**Deliverables:**
- `docs/operations/procedures/cost/budget-management.md`
- `docs/operations/procedures/cost/cost-optimization.md`
- `charts/spark-4.1/templates/budget-configmap.yaml`
- `charts/observability/templates/prometheus-budget-rules.yaml`
- `scripts/operations/cost/check-budget.sh`
- `scripts/operations/cost/detect-anomalies.sh`
- `scripts/operations/cost/rightsizing-recommendations.sh`
- `scripts/operations/cost/identify-idle-resources.sh`
- `scripts/operations/cost/send-budget-alert.sh`
- `charts/observability/grafana/dashboards/budget-status.json`

**Acceptance Criteria:**
- AC1: Budgets defined per team/project via ConfigMap
- AC2: Budget alerts triggered at 50%, 80%, 100% of budget
- AC3: Cost anomaly detection alerts on unusual spending
- AC4: Right-sizing recommendations generated weekly
- AC5: Idle resources identified (unused executors, volumes)
- AC6: Cost optimization suggestions documented (spot, dynamic allocation)
- AC7: Budget forecast alerts based on trends
- AC8: Overspend prevention (auto-disable on budget exceeded)
- AC9: Alerts sent to Slack/email with cost breakdown
- AC10: Budget status dashboard shows: current spend, budget, forecast

---

### WS-018-12: Runbook Testing & Validation (P2)

**Goal:** Automated testing of operational procedures and runbook accuracy metrics.

**Scope:**
- Runbook validation framework
- Automated runbook testing in staging
- Runbook accuracy metrics
- Runbook maintenance checklist
- Runbook drill schedule
- Runbook update workflow
- Runbook versioning
- Runbook review process

**Estimated LOC:** ~500
**Estimated Duration:** 2 days
**Dependencies:** All WS-018 workstreams

**Deliverables:**
- `docs/operations/procedures/runbook-testing.md`
- `docs/operations/procedures/runbook-maintenance.md`
- `docs/operations/checklists/runbook-review.md`
- `tests/operations/test_runbooks.py`
- `tests/operations/test_recovery_scripts.py`
- `tests/operations/test_backup_procedures.py`
- `tests/operations/test_diagnosis_scripts.sh`
- `scripts/operations/runbook-drill-scheduler.sh`
- `scripts/operations/runbook-accuracy-report.sh`

**Acceptance Criteria:**
- AC1: All runbooks have automated tests
- AC2: Monthly runbook drills conducted in staging
- AC3: Runbook accuracy measured (>90% target)
- AC4: Runbook maintenance checklist followed
- AC5: Runbook updates require review and approval
- AC6: Runbook versioning tracks changes
- AC7: Runbook accuracy report generated monthly
- AC8: Failed runbook tests create issues for updates
- AC9: Runbook drill results documented and reviewed
- AC10: Continuous improvement process based on drill results

---

## Dependencies

```
F18: Production Operations Suite
├── Depends on F06: Core Components (Helm Charts)
├── Depends on F12: E2E Tests (for CI/CD integration)
├── Depends on F15: Parallel Execution (for CI/CD infrastructure)
├── Depends on F16: Observability (for metrics, logs, traces, dashboards)
└── Enables F19: Documentation Enhancement (runbook patterns)
```

**Cross-workstream Dependencies:**
- WS-018-02, 018-03 depend on WS-018-01 (Incident Response Framework)
- WS-018-04 depends on F16 WS-016-01 (Metrics) and WS-016-05 (Alerting)
- WS-018-05 depends on F16 WS-016-04 (Dashboards)
- WS-018-06 depends on WS-018-01 (Incident Response)
- WS-018-07 depends on WS-018-03 (Data Recovery)
- WS-018-08, 018-09 depend on F08, F12, F15
- WS-018-10, 018-11 depend on F16 WS-016-01 (Metrics)
- WS-018-12 depends on all other WS-018 workstreams

---

## Success Criteria

### Feature-Level Acceptance

- ✅ **Incident Response:** Structured framework with on-call rotation, escalation paths
- ✅ **Runbooks:** 12+ published runbooks covering common failures
- ✅ **Data Recovery:** Automated procedures for Hive/S3 with RTO < 30 min
- ✅ **SLI/SLO:** Defined and monitored with burn rate alerts
- ✅ **Backup/DR:** Automated daily backups with 99.9%+ success rate
- ✅ **Job CI/CD:** Framework with validation, promotion, rollback
- ✅ **Cost Monitoring:** Per-job and per-team attribution with dashboards
- ✅ **Runbook Testing:** Automated tests with monthly drills

### Business Metrics

| Metric | Baseline | Target | Measurement |
|--------|----------|--------|-------------|
| **MTTR** | Unknown/hours | <30 min | Incident resolution time |
| **Backup Success** | Manual | 99.9%+ | Automated backup success rate |
| **Deployment Frequency** | Unknown | Weekly | Job deployments via CI/CD |
| **Cost Visibility** | None | 100% | Jobs tracked for cost |
| **Runbook Accuracy** | Unknown | >90% | Runbook test pass rate |
| **SLO Compliance** | Unknown | 99.9% | Spark Connect uptime |

---

## Implementation Phases

### Phase 1: Critical Operations (Weeks 1-3)

**Quick Wins First:**
- WS-018-01: Incident Response Framework (3 days)
- WS-018-04: SLI/SLO Definitions (2 days)
- WS-018-07: Backup Automation (4 days)
- WS-018-02: Spark Failure Runbooks (4 days)

**Deliverables:**
- Incident response procedures
- SLI/SLO definitions and dashboards
- Automated daily backups
- 5+ critical runbooks

---

### Phase 2: CI/CD & Scaling (Weeks 4-6)

**Builds on Phase 1:**
- WS-018-08: Job CI/CD Framework (5 days)
- WS-018-05: Scaling Procedures (3 days)
- WS-018-09: SQL Validation (3 days)
- WS-018-03: Data Recovery Runbooks (4 days)

**Deliverables:**
- Job CI/CD workflows
- Scaling procedures and calculators
- SQL and code validation
- Data recovery procedures

---

### Phase 3: Cost & Advanced (Weeks 7-8)

**Nice-to-Have:**
- WS-018-10: Cost Attribution (3 days)
- WS-018-11: Budget Alerts (2 days)
- WS-018-06: Post-Incident Review (2 days)
- WS-018-12: Runbook Testing (2 days)

**Deliverables:**
- Cost dashboards and alerts
- PIRA framework
- Runbook testing automation

---

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| **Scope creep** | Too many runbooks, can't complete | Focus on P0 runbooks first, iterate |
| **Runbook accuracy** | Outdated procedures cause incidents | Monthly drills, automated tests |
| **CI/CD complexity** | Job CI/CD too complex for teams | Provide templates and examples |
| **Cost calculation** | Inaccurate cost attribution | Validate against cloud billing |
| **Testing burden** | Can't test all runbooks monthly | Prioritize critical runbooks |

---

## Open Questions

1. **Cost attribution rate:** What rate per executor-second to use? (Region/instance-type dependent)
2. **Budget enforcement:** Should we auto-disable on budget exceeded or just alert?
3. **PIRAs public vs private:** Should post-incident reviews be public or internal?
4. **Runbook drill frequency:** Is monthly sufficient for critical runbooks?
5. **SLO targets:** What are the business-defined SLO targets for Spark Connect?

---

## References

- `docs/plans/2026-02-04-spark-k8s-production-gaps-analysis.md`
- `docs/plans/2026-02-04-production-features-proposal.md`
- `docs/drafts/feature-observability.md` (F16)
- `docs/operations/disaster-recovery.md` (existing)
- `docs/operations/compatibility-matrix.md` (existing)

---

**Feature Status:** Draft
**Next Steps:** Review with stakeholders, create workstreams in beads, assign owners
