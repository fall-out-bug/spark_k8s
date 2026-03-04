# Shuffle Optimization

> **Audience:** Operators, Data Engineers
> **Related:** [Memory Configuration](./memory-configuration.md)

## Overview

Shuffle is often the bottleneck. This guide covers hash shuffle, sort shuffle, and Celeborn.

## Shuffle Types

| Type | When Used | Pros | Cons |
|------|-----------|-----|-----|
| **Hash shuffle** | < 200 partitions (legacy) | Fast | Memory pressure |
| **Sort shuffle** | Default (Spark 2.0+) | Scalable | Disk I/O |
| **Celeborn** | External shuffle service | Offloads driver | Extra components |

## Sort Shuffle (Default)

```properties
spark.shuffle.manager=sort
spark.shuffle.sort.bypassMergeThreshold=200
```

- Writes to disk, merges on read
- Bypass merge for small partition counts

## Celeborn (Recommended for Large Jobs)

External shuffle service reduces driver memory and improves stability:

```yaml
# Helm values
sparkConf:
  spark.shuffle.manager: org.apache.spark.shuffle.celeborn.RssShuffleManager
  spark.celeborn.master.endpoints: celeborn-master:9097
```

Benefits:

- Offloads shuffle from executors
- Better fault tolerance
- Reduced executor memory pressure

## Tuning

| Config | Purpose |
|--------|---------|
| `spark.shuffle.file.buffer` | Write buffer (default 32KB) |
| `spark.reducer.maxSizeInFlight` | Read buffer (default 48MB) |
| `spark.shuffle.service.enabled` | External shuffle service |

## Common Issues

- **Shuffle fetch failures** — Network, disk; check Celeborn logs
- **Spill to disk** — Increase executor memory or enable Celeborn
- **Skew** — Enable AQE: `spark.sql.adaptive.skewJoin.enabled=true`
