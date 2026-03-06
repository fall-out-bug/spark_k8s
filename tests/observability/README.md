# Observability Tests

## Smoke Tests (PR Gate)

**File:** `test_observability_smoke.py`

Runs `helm template` on `observability-demo` and asserts key resources render. No live cluster required.

### What is checked (AC2)

| Check | Assertion |
|-------|-----------|
| Loki up | Loki ConfigMap/ServiceAccount present, Promtail spark-pods job |
| Prometheus scrape OK | ServiceMonitor, demo-metrics-exporter |
| Grafana dashboards load | Dashboards ConfigMaps, Prometheus/Loki datasources |

### How to run

```bash
# All observability smoke tests
pytest tests/observability/test_observability_smoke.py -v

# By marker
pytest -m observability -v
```

### CI Integration (AC3)

- Runs in `ci-charts` workflow (template-tests job)
- Marker: `observability`
- Paths: `tests/observability/**` triggers CI

### See also

- [INVENTORY](../../docs/observability/INVENTORY.md) — components
- [DevOps recipe](../../docs/observability/recipes/devops-5min.md) — live health check
