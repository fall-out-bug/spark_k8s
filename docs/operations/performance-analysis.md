# Performance Analysis Methodology

> **Audience:** Operators, SRE
> **Related:** [Performance Tuning](./performance-tuning.md), [Dashboard Reference](./dashboard-reference.md)

## Overview

Structured approach to analyzing Spark job performance.

## Step 1: Collect Data

- Spark event logs (S3/GCS)
- Prometheus metrics (last 24h)
- Grafana dashboards
- Application logs (Loki)

## Step 2: Identify Bottlenecks

| Metric | Indicates |
|--------|-----------|
| High `spark_task_duration_max` / min ratio | Data skew |
| High `spark_executor_metrics_maxMemUsed` | Memory pressure |
| High `spark_shuffle_read` / write | Shuffle bottleneck |
| High GC time | Heap pressure |

## Step 3: Root Cause

- **Skew** — Check key distribution; use AQE or salting
- **Memory** — Increase executor memory or enable Celeborn
- **I/O** — Check storage throughput; consider caching
- **Scheduling** — Check executor locality

## Step 4: Apply Changes

- One change at a time
- Compare before/after metrics
- Document in runbook

## Step 5: Validate

- Re-run same workload
- Compare: duration, resource utilization, cost

## Tools

- `scripts/tuning/analyze-spark-plan.sh` — Query plan analysis
- `scripts/tuning/generate-tuning-recommendations.sh` — Automated suggestions
