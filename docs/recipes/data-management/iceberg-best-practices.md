# Apache Iceberg Best Practices

This guide covers best practices for using Apache Iceberg with Spark K8s.

## Partitioning Strategies

### Strategy Overview

| Strategy | Use Case | Example |
|----------|----------|---------|
| **Identity** | Low cardinality, exact match queries | `region`, `status` |
| **Bucket** | High cardinality, even distribution | `user_id`, `order_id` |
| **Truncate** | String prefixes, hierarchical data | `date` from timestamp |
| **Day/Hour** | Time-series data | Event logs, metrics |

### When to Use Each

#### Identity Partitioning
```sql
-- Good for: Low cardinality columns with exact match filters
CREATE TABLE events (
    event_id bigint,
    event_type string,
    event_time timestamp,
    data string
) USING iceberg
PARTITIONED BY (identity(event_type));
```
**Best for:** Filter by `event_type = 'click'`

#### Bucket Partitioning
```sql
-- Good for: High cardinality, even data distribution
CREATE TABLE user_events (
    user_id bigint,
    event_time timestamp,
    event_data string
) USING iceberg
PARTITIONED BY (bucket(16, user_id));
```
**Best for:** Filter by `user_id = 12345` with even distribution

#### Day/Hour Partitioning
```sql
-- Good for: Time-series queries
CREATE TABLE logs (
    log_id bigint,
    log_time timestamp,
    message string
) USING iceberg
PARTITIONED BY (days(log_time));
```
**Best for:** Filter by date range

### Partitioning Recommendations

| Data Size | Partition Grain | Partitions |
|-----------|-----------------|------------|
| < 1 GB/day | No partitioning | N/A |
| 1-10 GB/day | Day | ~365/year |
| 10-100 GB/day | Day + Bucket | ~365 * N |
| > 100 GB/day | Hour | ~8760/year |

## Compaction

### When to Compact

| Scenario | Action |
|----------|--------|
| Many small files (< 128 MB) | Merge into larger files |
| Skewed partitions | Redistribute data |
| Delete-heavy workload | Rewrite to remove deleted rows |

### Compaction Parameters

```python
# Optimal file size: 256-512 MB
spark.sql("""
    CALL catalog.system.rewrite_data_files(
        table => 'db.table',
        options => map(
            'target-file-size-bytes', '268435456',  -- 256 MB
            'max-concurrent-file-group-rewrites', '10'
        )
    )
""")
```

### Automation via Airflow

```python
from airflow import DAG
from airflow.providers.apache.spark.operators.spark_submit import SparkSubmitOperator

with DAG("iceberg_compaction", schedule_interval="0 3 * * *"):
    compact = SparkSubmitOperator(
        task_id="compact_tables",
        application="s3a://scripts/iceberg/compaction.py",
        application_args=[
            "--tables", "db.events,db.logs",
            "--target-size", "268435456",
        ],
    )
```

## Snapshot Management

### Expiry

```sql
-- Keep last 7 days of snapshots
CALL catalog.system.expire_snapshots(
    table => 'db.table',
    older_than => TIMESTAMP '2024-01-01 00:00:00',
    max_concurrent_deletes => 100
);
```

### Time Travel

```sql
-- Query as of specific snapshot
SELECT * FROM db.table VERSION AS OF 1234567890;

-- Query as of timestamp
SELECT * FROM db.table TIMESTAMP AS OF '2024-01-01 12:00:00';

-- Get snapshot history
SELECT * FROM db.table.snapshots ORDER BY committed_at DESC;
```

### Rollback

```sql
-- Rollback to previous snapshot
CALL catalog.system.rollback_to_snapshot(
    'db.table',
    1234567890
);
```

## Schema Evolution

### Add Column
```sql
ALTER TABLE db.table ADD COLUMNS (
    new_column string COMMENT 'New column'
);
```

### Rename Column
```sql
ALTER TABLE db.table RENAME COLUMN old_name TO new_name;
```

### Drop Column
```sql
ALTER TABLE db.table DROP COLUMN deprecated_column;
```

### Type Promotion

| From | To | Notes |
|------|-----|-------|
| `int` | `bigint` | Safe |
| `float` | `double` | Safe |
| `string` | `date` | Requires valid format |
| `string` | `timestamp` | Requires valid format |

## Performance Tips

### 1. Use Partition Pruning
```sql
-- Good: Partition filter first
SELECT * FROM db.table
WHERE date = '2024-01-01'  -- Partition filter
  AND user_id = 123;       -- Data filter
```

### 2. Optimize File Size
```python
# Write with optimal file size
df.writeTo("db.table").using("iceberg") \
    .option("write-format", "parquet") \
    .option("target-file-size-bytes", "268435456") \
    .append()
```

### 3. Use Metadata Tables
```sql
-- Check file sizes
SELECT path, file_size_in_bytes
FROM db.table.files
ORDER BY file_size_in_bytes DESC;

-- Check partition sizes
SELECT partition, count(*) as file_count, sum(file_size_in_bytes) as total_size
FROM db.table.files
GROUP BY partition;
```

### 4. Enable Caching
```sql
-- Enable table caching
ALTER TABLE db.table SET TBLPROPERTIES (
    'cache.enabled' = 'true',
    'cache.expiration-interval-ms' = '3600000'
);
```

## Monitoring

### Key Metrics

| Metric | Query |
|--------|-------|
| Snapshot count | `SELECT count(*) FROM db.table.snapshots` |
| File count | `SELECT count(*) FROM db.table.files` |
| Total size | `SELECT sum(file_size_in_bytes) FROM db.table.files` |
| Last updated | `SELECT max(committed_at) FROM db.table.snapshots` |

### Alert Thresholds

| Metric | Warning | Critical |
|--------|---------|----------|
| File count | > 10,000 | > 50,000 |
| Avg file size | < 64 MB | < 16 MB |
| Snapshot age | > 7 days | > 30 days |

## Resources

- [Iceberg Documentation](https://iceberg.apache.org/docs/latest/)
- [Spark Procedures](https://iceberg.apache.org/docs/latest/spark-procedures/)
- [Performance Tuning](https://iceberg.apache.org/docs/latest/performance/)
