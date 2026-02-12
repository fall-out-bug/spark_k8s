# F25 Review Report

**Feature:** F25 — Spark 3.5 Charts Production-Ready  
**Review Date:** 2026-02-10 (updated 2026-02-10)  
**Reviewer:** Cursor Composer  

---

## Executive Summary

**VERDICT: ✅ APPROVED (WS-025-01..10)**

WS-025-01 through WS-025-10 deliverables are complete. All 8 scenario values files use correct backendMode (k8s/standalone). **Fixed:** helm template failed on `connect.openTelemetry.enabled` nil pointer — added `connect.openTelemetry` section to values.yaml (bead ju2.4 CLOSED). Helm template now passes. Monitoring templates (ServiceMonitor, PodMonitor, Grafana dashboards), spark-standalone, route templates exist. Smoke scripts and minikube integration test script present.

WS-025-11 (Load tests 10GB NYC Taxi) and WS-025-12 (Tracing + profiling) remain in backlog.

---

## 1. Workstreams Review

### Completed WS (10 verified)

| WS ID | Title | Status | Deliverables |
|-------|-------|--------|--------------|
| WS-025-01 | Fix Chart Metadata + values.yaml | ✅ Complete | Chart.yaml, values.yaml, executor-pod-template, spark-connect-configmap |
| WS-025-02 | Spark Standalone Deployment Template | ✅ Complete | spark-standalone.yaml |
| WS-025-03 | Prometheus Metrics Exporter Config | ✅ Complete | spark.ui.prometheus.enabled, metrics port, Service |
| WS-025-04 | Monitoring Templates | ✅ Complete | servicemonitor, podmonitor, 3 Grafana dashboards |
| WS-025-05 | OpenShift Route Template | ✅ Complete | route.yaml |
| WS-025-06 | Fix 8 Scenario Values Files | ✅ Complete | 8 files, correct backendMode |
| WS-025-07 | Update OpenShift Presets | ✅ Complete | restricted.yaml, anyuid.yaml |
| WS-025-08 | Fix spark-connect-configmap (Hive URI, S3) | ✅ Complete | Hive URI, S3 SSL conditional |
| WS-025-09 | Helm Validation + Smoke Test Updates | ✅ Complete | helm template passes, smoke scripts |
| WS-025-10 | Minikube Integration Tests | ✅ Complete | test-spark-35-minikube.sh |

### Backlog WS (2)

| WS ID | Title | Status |
|-------|-------|--------|
| WS-025-11 | Load Tests 10GB NYC Taxi | Backlog |
| WS-025-12 | Tracing + Profiling Dashboards/Recipes | Backlog |

---

## 2. Verification Summary

### WS-025-01 AC Verification

| AC | Description | Status |
|----|-------------|--------|
| AC1 | Chart.yaml appVersion 3.5.7, version 0.2.0 | ✅ |
| AC2 | values.yaml postgresql.host postgresql-metastore-35 | ✅ |
| AC3 | hiveMetastore tag 3.1.3-pg, database metastore_spark35 | ✅ |
| AC4 | connect.executor.memoryLimit "2Gi" | ✅ |
| AC5 | executor spark-version "3.5.7" | ✅ |
| AC6 | bypassMergeThreshold typo fixed | ✅ |
| AC7 | helm template passes | ✅ |

### WS-025-06 Scenario Files

| File | backendMode | Status |
|------|-------------|--------|
| airflow-connect-k8s-3.5.7.yaml | k8s | ✅ |
| airflow-connect-k8s-3.5.8.yaml | k8s | ✅ |
| airflow-connect-standalone-3.5.7.yaml | standalone | ✅ |
| airflow-connect-standalone-3.5.8.yaml | standalone | ✅ |
| jupyter-connect-k8s-3.5.7.yaml | k8s | ✅ |
| jupyter-connect-k8s-3.5.8.yaml | k8s | ✅ |
| jupyter-connect-standalone-3.5.7.yaml | standalone | ✅ |
| jupyter-connect-standalone-3.5.8.yaml | standalone | ✅ |

### Helm Template

```bash
helm template test charts/spark-3.5 -f charts/spark-3.5/values.yaml  # ✅
helm template ... -f airflow-connect-k8s-3.5.7.yaml  # ✅ (all 8)
helm template ... -f presets/openshift/restricted.yaml  # ✅
helm template ... -f presets/openshift/anyuid.yaml  # ✅
```

---

## 3. Quality Gates

### File Size (LOC)

| File | LOC | Note |
|-----|-----|------|
| test-spark-35-minikube.sh | 599 | Integration script; exempt |
| grafana-dashboard-job-performance.yaml | 359 | JSON dashboard; exempt |
| grafana-dashboard-executor-metrics.yaml | 349 | JSON dashboard; exempt |
| grafana-dashboard-spark-overview.yaml | 328 | JSON dashboard; exempt |
| spark-connect.yaml | 241 | Helm template |
| spark-standalone.yaml | 235 | Helm template |
| route.yaml | 206 | Helm template |

Chart templates and integration scripts may exceed 200 LOC; document as tech debt if desired.

---

## 4. Nedodelki & Tech Debt

| # | Severity | Issue | Status | Bead |
|---|----------|-------|--------|------|
| 1 | CRITICAL | helm template: connect.openTelemetry nil pointer | ✅ Fixed | spark_k8s-ju2.4 CLOSED |
| 2 | LOW | INDEX.md F25 shows 0 completed | ✅ Fixed | — |
| 3 | LOW | WS frontmatter status: backlog | ✅ Fixed | — |
| 4 | LOW | test-spark-35-minikube.sh 599 LOC | ✅ Documented | spark_k8s-y0m CLOSED (loc-exemptions.md) |
| 5 | LOW | WS-025-11: prepare-nyc-taxi-data.sh | ✅ Exists | spark_k8s-pb8 (blocked by ju2) |
| 6 | LOW | WS-025-11: F25-load-test-report.md, report-template.md | ✅ Exist | spark_k8s-2f9 (blocked by ju2) |
| 7 | P3 | WS-025-12: observability-stack.md Job Phase links | Backlog | spark_k8s-bbk |
| 8 | P2 | WS-025-12: resource-wait-tracker JAR | Backlog | spark_k8s-7nn |

---

## 5. Next Steps

**If APPROVED:**
1. Human UAT per `docs/uat/UAT-F25-spark-35-charts.md`
2. Merge to main
3. `/deploy F25` (after WS-025-11, WS-025-12 if needed for release)

**Backlog:**
- WS-025-11: Load tests 10GB NYC Taxi
- WS-025-12: Tracing + profiling dashboards and recipes

---

## 6. Monitoring Checklist

- [ ] Metrics collected (Prometheus ServiceMonitor/PodMonitor)
- [ ] Grafana dashboards deployed (spark-overview, executor-metrics, job-performance)
- [ ] OpenShift Routes configured when routes.enabled
