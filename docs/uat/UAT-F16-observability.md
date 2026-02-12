# UAT Guide: F16 — Observability Stack (Monitoring & Tracing)

**Feature:** F16  
**Date:** 2026-02-10  

---

## Overview

F16 provides Prometheus, Loki, Jaeger, Grafana, and Alertmanager Helm charts for Spark monitoring. Scripts in scripts/observability/ deploy the stack.

---

## Prerequisites

- [ ] Kubernetes cluster (kind/minikube)
- [ ] `helm` installed
- [ ] `kubectl` configured

---

## Quick Verification (30 seconds)

### Helm template (must pass)

```bash
# Fix grafana values first, then:
helm dependency build charts/observability/prometheus
helm template test charts/observability/prometheus
helm template test charts/observability/grafana
helm template test charts/observability/loki
helm template test charts/observability/jaeger
helm template test charts/observability/alertmanager
```

### Observability tests

```bash
pytest tests/observability/ -v
# Expected: 19 passed
```

---

## Detailed Scenarios

### Scenario 1: Deploy observability stack

```bash
./scripts/observability/setup_prometheus.sh --namespace spark-operations
./scripts/observability/setup_loki.sh
./scripts/observability/setup_jaeger.sh
./scripts/observability/setup_grafana.sh
```

### Scenario 2: Verify Grafana datasources

Access Grafana UI, check Prometheus, Loki, Jaeger datasources configured.

---

## Red Flags

| # | Red Flag | Severity |
|---|----------|----------|
| 1 | helm template grafana fails | 🔴 HIGH |
| 2 | helm template prometheus fails (dependency) | 🔴 HIGH |
| 3 | test_observability.py > 200 LOC | 🟡 MEDIUM |
| 4 | Tests only cover spark-4.1 | 🟡 MEDIUM |

---

## Code Sanity

```bash
wc -l tests/observability/*.py | awk '$1 > 200 {print "OVER 200:", $0}'
```

---

## Sign-off

- [ ] All helm template commands pass
- [ ] pytest tests/observability/ passes
- [ ] All files < 200 LOC
- [ ] Tests cover Spark 3.5 and 4.1

---

**Human tester:** Complete UAT before F16 deployment.
