# @oneshot F026 Execution Report

**Feature:** F26 — Spark Performance Defaults  
**Date:** 2026-02-13  
**Status:** Completed

## Summary

All 3 workstreams for F26 (Spark Performance Defaults) were executed.

| WS | Name | Status |
|----|------|--------|
| WS-026-01 | Enable AQE and Modern Spark Defaults | completed |
| WS-026-02 | Fix Deprecated Spark 4.x Properties | completed |
| WS-026-03 | Structured Streaming Example (Kafka → Iceberg) | completed |

## Deliverables

### WS-026-01: AQE and Modern Defaults
- **ConfigMaps:** AQE (adaptive.enabled, coalescePartitions, skewJoin) + podNamePrefix in spark-4.1 and spark-3.5 templates
- **Docker:** spark-4.1/conf/spark-defaults.conf — Kryo, AQE, zstd
- **Prod values:** Kryo, zstd, removed shuffle.partitions (AQE handles it)

### WS-026-02: Deprecated Properties
- **Prod values:** spark.blacklist.* → spark.excludeOnFailure.*
- **Migration guide:** docs/recipes/deployment/migrate-35-to-41.md

### WS-026-03: Streaming Example
- **examples/streaming/kafka_to_iceberg.py** — Kafka → Iceberg with checkpoint
- **examples/streaming/docker-compose.yaml** — Kafka + Schema Registry
- **examples/streaming/README.md** — Setup and execution
- **notebooks/recipes/streaming-quickstart.ipynb** — Jupyter demo

## Next Steps

1. Run `helm template` with prod values to verify
2. UAT: Deploy with new defaults, run workload, verify AQE metrics
3. Streaming: Start Kafka, produce data, run kafka_to_iceberg.py
