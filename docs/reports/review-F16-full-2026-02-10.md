# F16 Review Report

**Feature:** F16 — Observability Stack (Monitoring & Tracing)  
**Review Date:** 2026-02-10 (updated 2026-02-10)  
**Reviewer:** Cursor Composer  

---

## Executive Summary

**VERDICT: ⚠️ CHANGES REQUESTED (reduced blockers)**

Charts exist (prometheus, loki, jaeger, grafana, alertmanager) and scripts/observability/ has setup scripts. **Fixed:** prometheus values.yaml YAML error (serviceMonitors structure); prometheus helm dependency built. **Remaining:** (1) grafana needs `helm dependency build`; (2) test_observability.py 218 LOC (>200); (3) tests hardcode spark-4.1 paths; (4) runtime tests missing; (5) test_metrics.sh missing.

---

## 1. Workstreams Review

### Deliverables Status

| WS ID | Title | Expected | Exists | Gap |
|-------|-------|----------|--------|-----|
| 00-016-01 | Prometheus | Chart + JMX exporter, 15s scrape | Chart exists; dep missing; scrape 30s | Partial |
| 00-016-02 | Loki | Chart + Promtail | Chart exists; template refs spark.* | Partial |
| 00-016-03 | Jaeger | Chart + OTel | Chart exists | ✅ |
| 00-016-04 | Grafana | Chart + 5 Spark dashboards | Chart exists; 7 ops dashboards; values YAML error | Partial |
| 00-016-05 | Alerting | AlertManager | Chart exists | ✅ |
| 00-016-06 | Spark UI integration | History Server + metrics/traces | In spark values; no dedicated templates | Partial |

---

## 2. Critical Issues

### 2.1 grafana chart — dependency build

**Status:** Grafana chart requires `helm dependency build charts/observability/grafana`. Chart depends on grafana subchart.

### 2.2 prometheus values.yaml — YAML structure

**Status:** ✅ FIXED. serviceMonitors had invalid mix of map+list; restructured to use `items:` list.

### 2.3 prometheus chart — dependency

**Status:** ✅ FIXED. prometheus-operator dependency built (Chart.lock, charts/*.tgz).

### 2.4 prometheus/loki templates — spark scope

**Status:** ✅ FIXED (per bead kcj). Templates use Release.Name/Namespace.

### 2.5 test_observability.py — 218 LOC (>200)

**Status:** Open. File exceeds 200 LOC. scripts/observability/ has test_observability_monitoring.py, test_observability_logging.py but tests/observability/test_observability.py is main pytest target.

### 2.6 tests hardcode spark-4.1

All paths point to `charts/spark-4.1`. Spark 3.5 has same monitoring; tests should be parameterized.

---

## 3. Scripts & Tests

### scripts/observability/

| Script | Exists |
|--------|--------|
| setup_prometheus.sh | ✅ |
| setup_loki.sh | ✅ |
| setup_jaeger.sh | ✅ |
| setup_alertmanager.sh | ✅ |
| setup_grafana.sh | ✅ |
| test_metrics.sh | ❌ |

### tests/observability/

| Test | Exists | Notes |
|------|--------|-------|
| test_observability.py | ✅ | 19 pass; template validation only |
| test_metrics_scrape.py | ❌ | Runtime validation |
| test_logs_aggregation.py | ❌ | Runtime validation |
| test_traces.py | ❌ | Runtime validation |
| test_dashboards.py | ❌ | Runtime validation |

---

## 4. Dashboards Mismatch

**F16 spec (WS-016-04):** cluster-overview, spark-applications, executor-metrics, sql-performance, resource-usage (5 Spark dashboards).

**observability/grafana/dashboards/:** backup-status, budget-status, chaos-metrics, cost-by-job, cost-by-team, incident-metrics, slo-forecast (7 ops dashboards).

**Spark charts:** grafana-dashboard-spark-overview, executor-metrics, job-performance, etc. (in templates).

No consolidation — Spark dashboards in spark-* templates; ops dashboards in observability/grafana.

---

## 5. Blockers & Nedodelki

| # | Severity | Issue | Fix | Status |
|---|----------|-------|-----|--------|
| 1 | ~~CRITICAL~~ | ~~grafana values.yaml~~ | Fixed (8h5) | ✅ CLOSED |
| 2 | ~~HIGH~~ | ~~prometheus/loki templates~~ | Fixed (kcj) | ✅ CLOSED |
| 3 | ~~HIGH~~ | ~~prometheus dependency~~ | helm dep build (emp) | ✅ CLOSED |
| 4 | HIGH | grafana helm dependency build | helm dependency build charts/observability/grafana | Open |
| 5 | MEDIUM | test_observability.py 218 LOC | Split to <200 | Open |
| 6 | MEDIUM | tests hardcode spark-4.1 | Parameterize for 3.5 and 4.1 | Open |
| 7 | MEDIUM | test_metrics.sh missing | Create per spec | Open |
| 8 | MEDIUM | Runtime tests missing | test_metrics_scrape, test_logs, test_traces, test_dashboards | Open |
| 9 | LOW | F18 references F16 as completed | Update WS-018 docs | Open |
| 10 | LOW | Dashboards mismatch | Consolidate Spark vs ops dashboards | Open |

---

## 6. Next Steps

1. ~~Fix prometheus values.yaml~~ — Done (serviceMonitors structure)
2. Run `helm dependency build` for grafana.
3. Split test_observability.py.
4. Parameterize tests for Spark 3.5 and 4.1.
5. Create test_metrics.sh and runtime tests.
6. Re-run `/review F16` after fixes.

---

## 7. Monitoring Checklist

- [ ] Metrics collected (N/A)
- [ ] Alerts configured (N/A)
- [ ] Dashboard updated (N/A)

---

**Report ID:** review-F16-full-2026-02-10
