# Dashboard Reference

> [!NOTE]
> **Coverage note (2026-08):** this page lists only 5 of the ~20 provisioned
> dashboards. Full inventory lives in `docs/observability/INVENTORY.md`.

> **Audience:** Operators
> **Location:** `charts/observability/grafana/dashboards/`

## Available Dashboards

| Dashboard | Purpose | Key Panels |
|-----------|---------|------------|
| **performance-analysis.json** | Job performance | Task duration, CPU, memory, shuffle |
| **cost-by-job.json** | Cost attribution | Per-job cost, resource usage |
| **backup-status.json** | Backup health | Last backup, size, status |
| **rto-rpo.json** | DR metrics | RTO, RPO, recovery time |
| **incident-metrics.json** | Incident tracking | MTTR, frequency |

## Performance Analysis Panel

| Panel | Query | Description |
|-------|-------|-------------|
| Task Duration | `spark_task_duration_max` | Max task duration by stage |
| Memory Used | `spark_executor_metrics_memoryUsed` | Executor memory |
| Shuffle Read | `spark_shuffle_read` | Shuffle read bytes |
| CPU Utilization | `container_cpu_usage_seconds_total` | Per-pod CPU |

## Customization

Dashboards use Prometheus datasource. Variables:

- `namespace` — Kubernetes namespace
- `app_id` — Spark application ID

## Import

```bash
# From chart
helm template observability charts/observability | grep -A 9999 "performance-analysis"
```

Or import JSON directly in Grafana UI.
