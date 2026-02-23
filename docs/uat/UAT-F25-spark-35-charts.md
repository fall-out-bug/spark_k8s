# UAT Guide: F25 — Spark 3.5 Charts Production-Ready

**Feature:** F25  
**Date:** 2026-02-10  

---

## Overview

F25 brings Spark 3.5.7/3.5.8 Helm charts to production-ready state: fixed metadata, Spark Standalone template, Prometheus/Grafana monitoring, OpenShift Routes, 8 scenario values files (k8s/standalone), smoke scripts, and minikube integration tests.

---

## Prerequisites

- [ ] Helm 3.x installed
- [ ] Minikube (optional, for integration tests): `minikube start --cpus=4 --memory=8g`
- [ ] Docker images built and loaded (for integration): `minikube image load spark-custom:3.5.7`

---

## Quick Verification (30 seconds)

### Helm template for all scenarios

```bash
cd charts/spark-3.5
for f in airflow-connect-k8s-3.5.7.yaml airflow-connect-k8s-3.5.8.yaml \
  airflow-connect-standalone-3.5.7.yaml airflow-connect-standalone-3.5.8.yaml \
  jupyter-connect-k8s-3.5.7.yaml jupyter-connect-k8s-3.5.8.yaml \
  jupyter-connect-standalone-3.5.7.yaml jupyter-connect-standalone-3.5.8.yaml; do
  helm template test . -f "$f" > /dev/null && echo "OK: $f" || echo "FAIL: $f"
done
# Expected: 8x OK
```

### OpenShift presets

```bash
helm template test charts/spark-3.5 -f charts/spark-3.5/presets/openshift/restricted.yaml > /dev/null && echo "OK: restricted"
helm template test charts/spark-3.5 -f charts/spark-3.5/presets/openshift/anyuid.yaml > /dev/null && echo "OK: anyuid"
```

---

## Detailed Scenarios

### Scenario 1: Backend modes

Verify scenario files use correct backendMode:

```bash
grep -l "backendMode: k8s" charts/spark-3.5/*.yaml | wc -l  # Expected: 4
grep -l "backendMode: standalone" charts/spark-3.5/*.yaml | wc -l  # Expected: 4
```

### Scenario 2: Monitoring templates

```bash
ls charts/spark-3.5/templates/monitoring/servicemonitor.yaml
ls charts/spark-3.5/templates/monitoring/podmonitor.yaml
ls charts/spark-3.5/templates/monitoring/grafana-dashboard-*.yaml | wc -l  # Expected: 5
```

### Scenario 3: Minikube integration (optional)

```bash
./scripts/tests/integration/test-spark-35-minikube.sh
# Requires minikube running, images loaded
```

---

## Red Flags

| # | Red Flag | Severity |
|---|----------|----------|
| 1 | helm template fails for any scenario | 🔴 HIGH |
| 2 | Scenario file uses wrong backendMode (e.g. k8s file with standalone) | 🔴 HIGH |
| 3 | Chart.yaml appVersion ≠ 3.5.7 | 🟡 MEDIUM |
| 4 | values.yaml references postgresql-metastore-41 | 🟡 MEDIUM |

---

## Code Sanity Checks

```bash
# Chart metadata
grep "appVersion:" charts/spark-3.5/Chart.yaml  # Expected: 3.5.7
grep "postgresql-metastore-35" charts/spark-3.5/values.yaml  # Expected: match

# Typo fixed
grep "bypassMergeThreshold" charts/spark-3.5/templates/spark-connect-configmap.yaml
# Expected: spark.shuffle.sort.bypassMergeThreshold (no space)
```

---

## Sign-off

- [ ] All 8 scenario helm templates pass
- [ ] OpenShift presets pass
- [ ] Chart metadata correct (appVersion 3.5.7)
- [ ] Red flags absent

---

## Related Documents

- Feature spec: `docs/drafts/idea-spark-35-production-ready.md`
- Workstreams: `docs/workstreams/completed/WS-025-*.md`
- Review: `docs/reports/review-F25-full-2026-02-10.md`
