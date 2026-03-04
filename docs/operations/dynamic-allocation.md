# Dynamic Allocation Tuning

> **Audience:** Operators
> **Related:** [Executor Sizing](./executor-sizing.md)

## Overview

Dynamic allocation scales executors based on demand. Recommended for batch workloads.

## Enable

```properties
spark.dynamicAllocation.enabled=true
spark.dynamicAllocation.minExecutors=2
spark.dynamicAllocation.maxExecutors=100
spark.dynamicAllocation.initialExecutors=2
spark.dynamicAllocation.executorIdleTimeout=60s
spark.dynamicAllocation.schedulerBacklogTimeout=1s
```

## Key Parameters

| Parameter | Purpose | Recommendation |
|-----------|---------|----------------|
| `minExecutors` | Floor | 2 for dev, 5-10 for prod |
| `maxExecutors` | Ceiling | Based on cluster capacity |
| `executorIdleTimeout` | Scale down | 60s batch, 300s interactive |
| `schedulerBacklogTimeout` | Scale up trigger | 1s for responsive scaling |

## Shuffle Service Required

Dynamic allocation requires external shuffle service:

```properties
spark.shuffle.service.enabled=true
spark.dynamicAllocation.shuffleTracking.enabled=true
```

Or use Celeborn for shuffle offload.

## Recommendations

- **Batch ETL:** min=5, max=200, idle=60s
- **Interactive:** min=10, max=50, idle=300s
- **Streaming:** Usually fixed executors; dynamic optional

## Caveats

- Cold start latency on scale-up
- Shuffle data must be preserved when scaling down (shuffle service)
- Not suitable for very short jobs (< 1 min)
