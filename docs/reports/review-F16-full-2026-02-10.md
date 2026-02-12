# F16 Review Report

**Feature:** F16 — Observability Stack (Monitoring & Tracing)  
**Review Date:** 2026-02-10  
**Reviewer:** Cursor Composer  

---

## Executive Summary

**VERDICT: ❌ CHANGES REQUESTED**

Charts exist (prometheus, loki, jaeger, grafana, alertmanager) and scripts/observability/ has setup scripts. Critical issues: (1) grafana values.yaml has YAML syntax error (invalid JSON in jsonData); (2) prometheus/loki templates reference `include "spark.name"` but observability charts are standalone; (3) prometheus chart missing helm dependency build; (4) test_observability.py 218 LOC (>200); (5) tests hardcode spark-4.1 only.

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

### 2.1 grafana/values.yaml — YAML syntax error

**Line 36–40:** jsonData block has invalid JSON (missing comma):

```yaml
"httpMethod": "POST"   # missing comma
"exemplarTraceIdLink": true
```

**Line 33:** Typo `prometheus-operato` → should be `prometheus-operator`.

**Lines 34, 48, 62:** Multiple datasources have `isDefault: true` — only one should be default.

**Result:** `helm template test charts/observability/grafana` fails.

### 2.2 prometheus/loki templates — wrong scope

Templates reference `include "spark.name"` and `include "spark.namespace"` — these are Spark chart helpers. Observability charts are standalone; they don't have access to Spark subchart. Templates will fail when rendered standalone.

### 2.3 prometheus chart — missing dependency

```
Error: found in Chart.yaml, but missing in charts/ directory: prometheus-operator
```

**Fix:** `helm dependency build charts/observability/prometheus`

### 2.4 test_observability.py — 218 LOC (>200)

File exceeds 200 LOC limit. Split required.

### 2.5 tests hardcode spark-4.1

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

| # | Severity | Issue | Fix |
|---|----------|-------|-----|
| 1 | CRITICAL | grafana values.yaml invalid JSON in jsonData | Add comma after "POST"; fix typo prometheus-operato |
| 2 | CRITICAL | grafana helm template fails | Fix YAML syntax |
| 3 | HIGH | prometheus/loki templates use spark.name, spark.namespace | Use observability chart values or make configurable |
| 4 | HIGH | prometheus chart dependency missing | helm dependency build |
| 5 | MEDIUM | test_observability.py 218 LOC | Split to <200 |
| 6 | MEDIUM | tests hardcode spark-4.1 | Parameterize for 3.5 and 4.1 |
| 7 | MEDIUM | test_metrics.sh missing | Create per spec |
| 8 | MEDIUM | Runtime tests missing | test_metrics_scrape, test_logs, test_traces, test_dashboards |
| 9 | LOW | F18 references F16 as completed | Update WS-018 docs |
| 10 | LOW | Dashboards mismatch | Consolidate Spark vs ops dashboards |

---

## 6. Next Steps

1. Fix grafana values.yaml (JSON syntax, typo, isDefault).
2. Fix prometheus/loki template helpers (observability-scoped).
3. Run `helm dependency build` for prometheus.
4. Split test_observability.py.
5. Parameterize tests for Spark 3.5 and 4.1.
6. Create test_metrics.sh and runtime tests.
7. Re-run `/review F16` after fixes.

---

## 7. Monitoring Checklist

- [ ] Metrics collected (N/A)
- [ ] Alerts configured (N/A)
- [ ] Dashboard updated (N/A)

---

**Report ID:** review-F16-full-2026-02-10
