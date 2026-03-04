# Memory Configuration Guide

> **Audience:** Operators
> **Related:** [Executor Sizing](./executor-sizing.md), [Shuffle Optimization](./shuffle-optimization.md)

## Overview

Spark memory is split into heap, off-heap, and overhead. Misconfiguration causes OOM or underutilization.

## Components

| Component | Purpose | Config |
|-----------|---------|--------|
| **Executor memory** | Heap for tasks, caching | `spark.executor.memory` |
| **Overhead** | Off-heap, native, shuffle | `spark.executor.memoryOverhead` |
| **Driver memory** | DAG, collect, broadcast | `spark.driver.memory` |

## Overhead Calculation

Default: `max(384MB, 0.1 * executor_memory)`

Increase when:

- Shuffle-heavy workloads
- Native libraries (Arrow, etc.)
- OOM in `Executor` (not `Task`)

```properties
spark.executor.memoryOverhead=2g
```

## Shuffle Memory

Shuffle uses:

- **Execution memory** — Sort buffer, aggregation
- **Storage memory** — Cached blocks (shared)

Fraction: `spark.memory.fraction` (default 0.6)

## Common Issues

| Symptom | Cause | Fix |
|---------|-------|-----|
| Executor OOM | Heap too small | Increase `spark.executor.memory` |
| Task OOM | Large partition | Repartition, increase parallelism |
| GC pressure | Heap too large | Reduce heap, increase overhead |
| Shuffle spill | Insufficient memory | Increase memory or enable Celeborn |

## Recommendations

- Start with 4-8GB per executor for batch
- Reserve 15-20% overhead for shuffle-heavy jobs
- Monitor `spark_executor_metrics_memoryUsed` in Prometheus
