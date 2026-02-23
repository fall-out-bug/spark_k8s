# Idea: Spark Performance Defaults (F26)

**Date:** 2026-02-13
**Source:** repo-audit-2026-02-13.md (Apache Spark Practices, items SP-1..SP-8)
**Priority:** High

## Problem

Production Spark configs miss critical performance settings that are industry standard:
- AQE (Adaptive Query Execution) not enabled by default — this alone gives +20-40% for most workloads
- `spark.blacklist.*` deprecated in Spark 4.x (renamed to `spark.excludeOnFailure.*`)
- Hardcoded `spark.sql.shuffle.partitions=200` instead of AQE coalesce
- No KryoSerializer recommendation
- No zstd compression for Parquet
- No `podNamePrefix` for executor observability
- No Structured Streaming example

## Solution

Add performance-optimized Spark defaults to all presets and create Structured Streaming example.

## Users Affected

- DevOps Engineer (better defaults out of the box)
- Data Engineer (performance gains without manual tuning)
- Data Scientist (faster Jupyter queries)

## Success Metrics

- All presets include AQE enabled
- Spark 4.x configs use modern property names
- Streaming example functional with Kafka → Iceberg
