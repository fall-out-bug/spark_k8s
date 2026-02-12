# F16 Review Report

**Feature:** F16 — Observability Stack (Monitoring & Tracing)  
**Review Date:** 2026-02-10 (updated 2026-02-10)  
**Reviewer:** Cursor Composer  

---

## Executive Summary

**VERDICT: ⚠️ CHANGES REQUESTED (reduced blockers)**

Charts exist (prometheus, loki, jaeger, grafana, alertmanager) and scripts/observability/ has setup scripts. **Fixed:** prometheus values.yaml, helm deps; test_metrics.sh; runtime tests; ozu (grafana dep build done). **Remaining:** (1) grafana helm template fails — datasources jsonData wrong type (74z.8); (2) tests >200 LOC: test_dashboards 365, test_traces 277, test_logs_aggregation 237, test_metrics_scrape 213 (k5r); (3) parameterize for Spark 3.5 + 4.1 (2qk); (4) dashboards consolidation (31l, b23); (5) test_monitoring_enabled_in_prod[3.5] fails (Spark 3.5 lacks environments/prod).

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

**Status:** ✅ DONE (ozu closed). charts/observability/grafana/charts/grafana-10.5.15.tgz exists. BUT `helm template` fails: wrong type for datasources jsonData (expected map, got list) — bead 74z.8.

### 2.2 prometheus values.yaml — YAML structure

**Status:** ✅ FIXED. serviceMonitors had invalid mix of map+list; restructured to use `items:` list.

### 2.3 prometheus chart — dependency

**Status:** ✅ FIXED. prometheus-operator dependency built (Chart.lock, charts/*.tgz).

### 2.4 prometheus/loki templates — spark scope

**Status:** ✅ FIXED (per bead kcj). Templates use Release.Name/Namespace.

### 2.5 tests/observability — files >200 LOC

**Status:** Open (bead k5r). Files exceeding 200 LOC: test_dashboards.py 365, test_traces.py 277, test_logs_aggregation.py 237, test_metrics_scrape.py 213. Target: each <200.

### 2.6 tests parameterization (2qk)

test_monitoring_common.py has SPARK_VERSIONS ["3.5","4.1"] and get_spark_chart_path(). test_monitoring_enabled_in_prod[3.5] fails: Spark 3.5 has no environments/prod/. Parameterize or skip 3.5 in prod tests.

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
| test_metrics.sh | ✅ |

### tests/observability/

| Test | Exists | Notes |
|------|--------|-------|
| test_monitoring_config.py, test_dashboards_config.py | ✅ | Template validation (parameterized 3.5/4.1) |
| test_metrics_scrape.py | ✅ | Runtime validation |
| test_logs_aggregation.py | ✅ | Runtime validation |
| test_traces.py | ✅ | Runtime validation |
| test_dashboards.py | ✅ | Runtime validation |

---

## 4. Dashboards Mismatch

**F16 spec (WS-016-04):** cluster-overview, spark-applications, executor-metrics, sql-performance, resource-usage (5 Spark dashboards).

**observability/grafana/dashboards/:** backup-status, budget-status, chaos-metrics, cost-by-job, cost-by-team, incident-metrics, slo-forecast (7 ops dashboards).

**Spark charts:** grafana-dashboard-spark-overview, executor-metrics, job-performance, etc. (in templates).

No consolidation — Spark dashboards in spark-* templates; ops dashboards in observability/grafana.

---

## 5. Blockers & Nedodelki

| # | Severity | Issue | Fix | Status | Bead |
|---|----------|-------|-----|--------|------|
| 1 | ~~CRITICAL~~ | ~~grafana values.yaml~~ | Fixed (8h5) | ✅ CLOSED | spark_k8s-8h5 |
| 2 | ~~HIGH~~ | ~~prometheus/loki templates~~ | Fixed (kcj) | ✅ CLOSED | spark_k8s-kcj |
| 3 | ~~HIGH~~ | ~~prometheus dependency~~ | helm dep build (emp) | ✅ CLOSED | spark_k8s-emp |
| 4 | ~~HIGH~~ | ~~grafana helm dependency build~~ | Done (charts/*.tgz) | ✅ CLOSED | spark_k8s-ozu |
| 4b | HIGH | grafana helm template fails | Fix datasources jsonData type (map not list) | Open | spark_k8s-74z.8 |
| 5 | MEDIUM | tests >200 LOC (4 files) | Split test_dashboards, test_traces, test_logs_aggregation, test_metrics_scrape | Open | spark_k8s-k5r |
| 6 | MEDIUM | test_monitoring_enabled_in_prod[3.5] fails | Spark 3.5 lacks environments/prod; parameterize or skip | Open | spark_k8s-2qk |
| 7 | ~~MEDIUM~~ | ~~test_metrics.sh missing~~ | Created | ✅ CLOSED | spark_k8s-ci6 |
| 8 | ~~MEDIUM~~ | ~~Runtime tests missing~~ | test_metrics_scrape, test_logs, test_traces, test_dashboards exist | ✅ CLOSED | spark_k8s-mgv |
| 9 | ~~LOW~~ | ~~F18 references F16 as completed~~ | Update WS-018 docs | ✅ CLOSED (via 7xp) | spark_k8s-8e9 |
| 10 | LOW | Dashboards mismatch | Consolidate Spark vs ops dashboards | Open | spark_k8s-31l, spark_k8s-b23 |

---

## 6. Next Steps

1. ~~Fix prometheus values.yaml~~ — Done
2. ~~Run helm dependency build for grafana~~ — Done (ozu)
3. Fix grafana helm template — datasources jsonData type (74z.8)
4. Split tests >200 LOC (k5r)
5. Fix test_monitoring_enabled_in_prod[3.5] — Spark 3.5 environments/prod (2qk)
6. ~~Create test_metrics.sh and runtime tests~~ — Done (ci6, mgv)
7. Re-run `/review F16` after fixes

---

## 7. Monitoring Checklist

- [ ] Metrics collected (N/A)
- [ ] Alerts configured (N/A)
- [ ] Dashboard updated (N/A)

---

---

## 8. Per-WS Review Summary (Goal Check)

| WS | Goal | Deliverables | Status |
|----|------|--------------|--------|
| WS-016-01 | Prometheus + JMX, 15s scrape | Chart ✅; scrape 30s | Partial |
| WS-016-02 | Loki + Promtail | Chart ✅; templates fixed | ✅ |
| WS-016-03 | Jaeger + OTel | Chart ✅ | ✅ |
| WS-016-04 | Grafana + 5 Spark dashboards | Chart ✅; 7 ops dashboards; template error | Partial |
| WS-016-05 | AlertManager | Chart ✅ | ✅ |
| WS-016-06 | Spark UI integration | In spark values | Partial |

---

## 9. Beads Referenced

| Bead | Issue | Status |
|------|-------|--------|
| spark_k8s-74z | F16 parent | open |
| spark_k8s-74z.8 | Grafana template jsonData | open |
| spark_k8s-ozu | Grafana dep build | ✅ CLOSED |
| spark_k8s-k5r | Tests >200 LOC | open |
| spark_k8s-2qk | Spark 3.5 prod env parameterization | open |
| spark_k8s-31l | Consolidate dashboards | open |
| spark_k8s-8e9 | F18 F16 refs | ✅ CLOSED (7xp) |

---

**Report ID:** review-F16-full-2026-02-10  
**Updated:** 2026-02-10 (protocol review, beads sync)
