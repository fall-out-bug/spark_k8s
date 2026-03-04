# Performance Tuning Overview

> **Audience:** Operators, SRE
> **Related:** [Executor Sizing](./executor-sizing.md), [Memory Configuration](./memory-configuration.md), [Shuffle Optimization](./shuffle-optimization.md)

## Overview

This guide provides a methodology for tuning Spark applications on Kubernetes. Use the linked guides for specific topics.

## Tuning Workflow

1. **Profile** — Collect metrics (Spark UI, Prometheus, event logs)
2. **Identify** — Find bottlenecks (CPU, memory, shuffle, I/O)
3. **Tune** — Apply changes per workload type
4. **Validate** — Re-run and compare metrics

## Key Configuration Areas

| Area | Primary Knobs | See |
|------|---------------|-----|
| Executor sizing | cores, memory, instances | [executor-sizing.md](./executor-sizing.md) |
| Memory | executor memory, overhead, off-heap | [memory-configuration.md](./memory-configuration.md) |
| Shuffle | sort/hash shuffle, Celeborn | [shuffle-optimization.md](./shuffle-optimization.md) |
| Dynamic allocation | min/max executors, idle timeout | [dynamic-allocation.md](./dynamic-allocation.md) |

## Common Bottlenecks

- **Data skew** — Salting, repartition, AQE skew join
- **Small partitions** — Coalesce, increase parallelism
- **OOM** — Increase executor memory, reduce partition size
- **GC pressure** — Tune heap, use off-heap
- **Shuffle spill** — Increase memory, enable Celeborn

## Next Steps

- [Performance Analysis](./performance-analysis.md) — Methodology
- [Monitoring Setup](./monitoring.md) — Observability
- [Dashboard Reference](./dashboard-reference.md) — Grafana panels
