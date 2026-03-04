# Executor Sizing Guide

> **Audience:** Operators, Data Engineers
> **Related:** [Capacity Planning](../procedures/capacity/capacity-planning.md)

## Overview

Executor sizing affects throughput, cost, and stability. Use the calculator for workload-specific recommendations.

## Workload Types

| Type | Cores/Executor | Memory | Max Executors | Notes |
|------|----------------|--------|---------------|-------|
| **Interactive (SQL)** | 2-4 | 8-16GB | 10-50 | Low latency |
| **Batch (ETL)** | 4-8 | 16-32GB | 50-200 | High throughput |
| **ML Training** | 8-16 | 32-64GB | 20-100 | Large models |
| **Streaming** | 4-8 | 16-32GB | Fixed | Steady load |

## Calculator

Use the sizing script:

```bash
./scripts/tuning/calculate-executor-sizing.sh \
  --concurrent-jobs 20 \
  --parallelism 2000 \
  --data-size 5TB
```

Output includes:

- Recommended executor count
- Memory per executor
- Cores per executor
- Overhead allocation

## Memory Overhead

Spark reserves ~10-15% overhead for off-heap:

- Shuffle
- Native memory
- Other JVM overhead

Configure `spark.executor.memoryOverhead` when needed.

## See Also

- [Memory Configuration](./memory-configuration.md)
- [Rightsizing](../procedures/capacity/rightsizing.md)
