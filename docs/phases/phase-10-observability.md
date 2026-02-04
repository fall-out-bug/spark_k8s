# Phase 10: Observability (Monitoring & Tracing)

> **Status:** Backlog
> **Priority:** P1 - Production readiness
> **Feature:** F16
> **Estimated Workstreams:** 6
> **Estimated LOC:** ~3600

## Goal

Создать полноценную систему observability для Spark K8s: мониторинг (metrics), логирование (logs), трейсинг (traces) и дашборды. Валидировать production-ready observability stack.

## Current State

**Не реализовано** — Phase 10 только начинается. Design Decisions требуют approval.

## Proposed Workstreams

| WS | Task | Scope | Dependencies | Status |
|----|------|-------|-------------|--------|
| WS-016-01 | Metrics collection (Prometheus) | MEDIUM (~700 LOC) | Phase 0 | backlog |
| WS-016-02 | Logging aggregation (Loki/ELK) | MEDIUM (~600 LOC) | Phase 0 | backlog |
| WS-016-03 | Distributed tracing (Jaeger/OTel) | MEDIUM (~600 LOC) | Phase 0 | backlog |
| WS-016-04 | Dashboards (Grafana) | MEDIUM (~500 LOC) | WS-016-01, WS-016-02 | backlog |
| WS-016-05 | Alerting rules | MEDIUM (~400 LOC) | WS-016-01 | backlog |
| WS-016-06 | Spark UI integration | MEDIUM (~800 LOC) | WS-016-01, WS-016-03 | backlog |

**Total Workstreams:** 6

## Design Decisions (Pending Approval)

### 1. Metrics Collection

**Prometheus + JMX Exporter:**
- Spark metrics via JMX exporter
- K8s metrics via kube-state-metrics
- Node metrics via node_exporter
- Scrape interval: 15s

**Key metrics:**
- Executor: memory, CPU, GC time, shuffle metrics
- Driver: application status, stage metrics, task metrics
- K8s: pod status, resource usage, PVC I/O

### 2. Logging Aggregation

**Loki (preferred) vs ELK:**
- Loki: lightweight, Prometheus-like (Grafana Stack)
- ELK: more feature-rich, heavier

**Log levels:**
- ERROR, WARN aggregated
- INFO sampled (10%)
- DEBUG disabled in production

**Log format:**
- Structured JSON logs
- Trace ID correlation
- Pod labels for filtering

### 3. Distributed Tracing

**OpenTelemetry + Jaeger:**
- Spark 3.5+ supports OpenTelemetry natively
- Jaeger as backend
- Trace context propagation

**Traced operations:**
- SQL query execution
- Job/Stage/Task execution
- Shuffle operations
- External calls (S3, JDBC)

### 4. Dashboards

**Grafana dashboards:**
- Cluster overview
- Spark application metrics
- Executor metrics
- SQL performance
- Resource usage

### 5. Alerting

**AlertManager rules:**
- Critical: pod crash loop, OOM killed
- Warning: high GC time, slow queries
- Info: application completed

**Notification channels:**
- Slack (default)
- Email (optional)
- PagerDuty (future)

### 6. Spark UI Integration

**Spark History Server:**
- Metrics integration with Prometheus
- Traces integration with Jaeger
- Unified observability view

## Dependencies

- **Phase 0 (F06):** Helm charts deployed
- **Phase 9 (F15):** Parallel execution (for testing)

## Success Criteria

1. ⏳ Prometheus scrape работает (Spark + K8s metrics)
2. ⏳ Loki агрегирует логи (JSON format + trace ID)
3. ⏳ Jaeger получает трейсы (OpenTelemetry)
4. ⏳ Grafana дашборды созданы (5+ dashboards)
5. ⏳ Alerting rules работают (critical/warning/info)
6. ⏳ Spark UI интегрирован с observability
7. ⏳ Testing scenarios созданы

## File Structure

```
charts/
├── observability/
│   ├── prometheus/
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── templates/
│   ├── loki/
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── templates/
│   ├── jaeger/
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── templates/
│   └── grafana/
│       ├── Chart.yaml
│       ├── values.yaml
│       ├── templates/
│       └── dashboards/
│           ├── cluster-overview.json
│           ├── spark-applications.json
│           ├── executor-metrics.json
│           ├── sql-performance.json
│           └── resource-usage.json

scripts/
├── observability/
│   ├── setup_prometheus.sh
│   ├── setup_loki.sh
│   ├── setup_jaeger.sh
│   └── test_metrics.sh

tests/
└── observability/
    ├── test_metrics_scrape.py
    ├── test_logs_aggregation.py
    ├── test_traces.py
    └── test_dashboards.py
```

## Integration with Other Phases

- **Phase 0 (F06):** Charts provide deployment base
- **Phase 5 (F11):** Final images include exporters
- **Phase 9 (F15):** Parallel execution for load testing
- **Phase 8 (F14):** Security for observability endpoints

## Beads Integration

```bash
# Feature
spark_k8s-xxx - F16: Phase 10 - Observability (P1)

# Workstreams
spark_k8s-xxx - WS-016-01: Metrics collection (P1)
spark_k8s-xxx - WS-016-02: Logging aggregation (P1)
spark_k8s-xxx - WS-016-03: Distributed tracing (P1)
spark_k8s-xxx - WS-016-04: Dashboards (P1)
spark_k8s-xxx - WS-016-05: Alerting rules (P1)
spark_k8s-xxx - WS-016-06: Spark UI integration (P1)

# Dependencies
WS-016-04 depends on WS-016-01, WS-016-02
WS-016-05 depends on WS-016-01
WS-016-06 depends on WS-016-01, WS-016-03
All WS depend on F06
```

## References

- [PRODUCT_VISION.md](../../PRODUCT_VISION.md)
- [workstreams/INDEX.md](../workstreams/INDEX.md)
- [phase-05-docker-final.md](./phase-05-docker-final.md)
- [Prometheus JMX Exporter](https://github.com/prometheus/jmx_exporter)
- [OpenTelemetry Spark](https://spark.apache.org/docs/latest/telemetry.html)
