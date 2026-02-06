# F13-improvements: Execution Plan Summary

## Feature Overview

**Goal:** Implement full load test matrix (1,280 combinations) for Spark K8s with automated infrastructure setup, template-based scenario generation, and Argo Workflows orchestration.

**Selected Approach:**
- **Tier:** P2 Full (all 1,280 combinations)
- **Orchestrator:** Argo Workflows (Kubernetes-native)
- **Setup:** Full automation (Minikube + Minio + Postgres + Hive + History Server + data)
- **Templates:** All combinations generated via Jinja2

## Workstreams (6)

```
┌─────────────────────────────────────────────────────────────────────┐
│                     F13-improvements Dependency Graph                │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  WS-013-06: Minikube Auto-Setup                                     │
│  ├── Minio + Postgres + Hive Metastore + History Server             │
│  └── 1GB + 11GB NYC taxi data generation                            │
│                                                                      │
│  WS-013-07: Matrix Definition & Templates                          │
│  ├── priority-matrix.yaml (6 dimensions)                            │
│  ├── Jinja2 templates (Helm values, scenarios, workflows)           │
│  └── Generator scripts (generate-matrix.py, validate-matrix.py)     │
│                                                                      │
│  WS-013-08: Load Test Scenarios ────────────────┐                  │
│  ├── 5 workload scripts (read, aggregate, join, window, write)      │
│  ├── Postgres integration helpers                                      │
│  └── Metrics collection enhancement                                   │
│                                                                      │
│  WS-013-09: Argo Workflows ────────────────────┤                  │
│  ├── Argo Workflows installation                                      │
│  ├── Workflow templates (matrix execution)                              │
│  └── Monitoring scripts                                                   │
│                                                                      │
│  WS-013-10: Metrics & Regression ────────────────────────┐          │
│  ├── Three-tier metrics collection (Stability, Efficiency, Perf)    │
│  ├── Baseline management (YAML-based)                                  │
│  ├── Statistical analysis (CI, t-tests, trend detection)              │
│  └── Regression detection (>20% degradation, p<0.05)                   │
│                                                                      │
│  WS-013-11: CI/CD & Docs ───────────────────────────────────┐       │
│  ├── GitHub Actions workflows (smoke, nightly, weekly)             │
│  ├── Comprehensive documentation (setup, architecture, troubleshooting)│
│  └── Slack integration                                                 │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

## Execution Order

| Phase | Workstreams | Duration | Dependencies |
|-------|-------------|----------|--------------|
| **1: Foundation** | WS-013-06, WS-013-07 | 10-14 days | None (can run in parallel) |
| **2: Core Implementation** | WS-013-08 | 7-10 days | WS-013-06 |
| **3: Orchestration** | WS-013-09 | 5-7 days | WS-013-07, WS-013-08 |
| **4: Analytics** | WS-013-10 | 5-7 days | WS-013-08, WS-013-09 |
| **5: Integration** | WS-013-11 | 3-5 days | All previous |

**Total Duration:** 30-43 days (6-8 weeks with parallel execution)

## Files Created/Modified

### New Files (47)

**WS-013-06 (9 files):**
- `scripts/local-dev/setup-minikube-load-tests.sh`
- `scripts/load-tests/infrastructure/minio-config.yaml`
- `scripts/load-tests/infrastructure/postgres-init.sql`
- `scripts/load-tests/infrastructure/setup-hive.sh`
- `scripts/load-tests/infrastructure/setup-history-server.sh`
- `scripts/load-tests/data/generate-nyc-taxi.py`
- `scripts/local-dev/verify-load-test-env.sh`
- `scripts/local-dev/teardown-load-tests.sh`
- `scripts/tests/load/matrix/README.md`

**WS-013-02 (7 files):**
- `scripts/tests/load/matrix/priority-matrix.yaml`
- `scripts/tests/load/matrix/templates/test-values.jinja2.yaml`
- `scripts/tests/load/matrix/templates/load-scenario.jinja2.sh`
- `scripts/tests/load/matrix/templates/workflow-template.jinja2.yaml`
- `scripts/tests/load/matrix/generators/generate-matrix.py`
- `scripts/tests/load/matrix/generators/validate-matrix.py`
- `scripts/tests/load/matrix/README.md`

**WS-013-03 (11 files):**
- `scripts/tests/load/workloads/read.py`
- `scripts/tests/load/workloads/aggregate.py`
- `scripts/tests/load/workloads/join.py`
- `scripts/tests/load/workloads/window.py`
- `scripts/tests/load/workloads/write.py`
- `scripts/tests/load/workloads/postgres.py`
- `scripts/tests/load/queries/load/` (5 SQL files)
- `scripts/tests/load/lib/workload-runner.sh`
- `scripts/tests/load/lib/metrics-collector.sh`
- `scripts/tests/load/helpers_postgres.py`

**WS-013-04 (7 files):**
- `scripts/argocd/argo-workflows/install.sh`
- `scripts/tests/load/workflows/load-test-workflow.yaml`
- `scripts/tests/load/orchestrator/submit-workflow.sh`
- `scripts/tests/load/orchestrator/watch-workflow.sh`
- `scripts/tests/load/orchestrator/workflow-monitor.py`
- `charts/argo-workflows/` (Helm chart)
- `scripts/tests/load/README-argo.md`

**WS-013-05 (8 files):**
- `scripts/tests/load/metrics/collector.py`
- `scripts/tests/load/metrics/baseline_manager.py`
- `scripts/tests/load/metrics/regression_detector.py`
- `scripts/tests/load/metrics/statistical_analyzer.py`
- `scripts/tests/load/metrics/report_generator.py`
- `scripts/tests/load/metrics/storage.py`
- `config/baselines/load-test-baselines.yaml`
- `config/monitoring/prometheus-load-test-rules.yaml`

**WS-013-06 (8 files):**
- `.github/workflows/load-test-smoke.yml`
- `.github/workflows/load-test-nightly.yml`
- `.github/workflows/load-test-weekly.yml`
- `scripts/tests/load/SETUP.md`
- `scripts/tests/load/ARCHITECTURE.md`
- `scripts/tests/load/TROUBLESHOOTING.md`
- `docs/guides/load-testing-guide.md`
- `docs/reports/load-test-matrix-reference.md`

**Modified Files (2):**
- `scripts/tests/load/README.md` (updated with matrix info)
- `scripts/local-dev/verify-load-test-env.sh` (updated)

## Success Criteria

| Criterion | Measure | Target |
|-----------|---------|--------|
| Infrastructure setup time | Manual → Automated | < 10 min |
| Test combinations | Manual → Generated | 1,280 |
| Execution time (P0) | Manual → Orchestrated | < 30 min |
| Execution time (P2) | Not possible → 48 hours | Full matrix |
| Regression detection | None → Automated | < 20%, p<0.05 |
| Documentation | Fragmented → Comprehensive | 8 docs |

## Risk Mitigation

| Risk | Impact | Mitigation |
|------|--------|------------|
| Minikube resource limits | Can't run parallel tests | Resource-aware queueing, mutex |
| Data generation time | Long setup | Generate once, store in Minio |
| Argo learning curve | Team unfamiliar | Comprehensive docs, examples |
| 1,280 test execution | Very long | Priority tiers, selective execution |
| Baseline establishment | Cold start problem | Start with loose thresholds, tighten |

## Next Steps

1. Review this plan with team
2. Create feature in beads: `bd create --title="F13-improvements" --type=feature`
3. Register workstreams via `sdp beads migrate`
4. Start with WS-013-01 (foundation)
