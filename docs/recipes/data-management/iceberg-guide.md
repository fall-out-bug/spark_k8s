# Apache Iceberg Integration Guide

This guide covers Apache Iceberg integration with Spark on Kubernetes for ACID transactions, time travel, and schema evolution.

## Overview

Apache Iceberg is an open table format for huge analytic datasets. Iceberg adds tables to compute engines including Spark, Trino, Flink, and Hive using a high-performance table format.

### Key Features

- **ACID Transactions**: Insert, update, delete operations with full ACID guarantees
- **Time Travel**: Query data as it was at any point in time
- **Schema Evolution**: Add, rename, or modify columns without breaking queries
- **Partition Evolution**: Change partitioning without rewriting data
- **Hidden Partitioning**: Partition values are derived from data, not explicit columns
- **Snapshots**: Each write creates a new snapshot, enabling rollback

## Quick Start

### Deploy Iceberg-Enabled Spark

```bash
helm install spark-iceberg charts/spark-4.1 \
  -f charts/spark-4.1/presets/iceberg-values.yaml
```

### Create Iceberg Table

```python
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .config("spark.sql.extensions", "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions") \
    .config("spark.sql.catalog.iceberg", "org.apache.iceberg.spark.SparkCatalog") \
    .config("spark.sql.catalog.iceberg.type", "hadoop") \
    .config("spark.sql.catalog.iceberg.warehouse", "s3a://warehouse/iceberg") \
    .getOrCreate()

# Create database
spark.sql("CREATE DATABASE IF NOT EXISTS iceberg.analytics")
spark.sql("USE iceberg.analytics")

# Create table
spark.sql("""
    CREATE TABLE orders (
        order_id BIGINT,
        customer_id BIGINT,
        product_id BIGINT,
        quantity INT,
        price DOUBLE,
        order_timestamp TIMESTAMP
    ) USING iceberg
    PARTITIONED BY (days(order_timestamp))
""")
```

### Insert Data

```python
# Insert data
spark.sql("""
    INSERT INTO orders VALUES
        (1, 100, 1000, 2, 99.99, TIMESTAMP '2024-01-01 10:00:00'),
        (2, 101, 1001, 1, 149.99, TIMESTAMP '2024-01-01 11:00:00')
""")

# Query data
spark.sql("SELECT * FROM orders").show()
```

## Catalog Configuration

### Hadoop Catalog (Simple)

```yaml
connect:
  sparkConf:
    "spark.sql.catalog.iceberg": "org.apache.iceberg.spark.SparkCatalog"
    "spark.sql.catalog.iceberg.type": "hadoop"
    "spark.sql.catalog.iceberg.warehouse": "s3a://warehouse/iceberg"
```

### Hive Catalog (Production)

```yaml
connect:
  sparkConf:
    "spark.sql.catalog.iceberg": "org.apache.iceberg.spark.SparkCatalog"
    "spark.sql.catalog.iceberg.type": "hive"
    "spark.sql.catalog.iceberg.uri": "thrift://hive-metastore:9083"
```

### REST Catalog (Cloud-Native)

```yaml
connect:
  sparkConf:
    "spark.sql.catalog.production": "org.apache.iceberg.spark.rest.RESTCatalog"
    "spark.sql.catalog.production.uri": "http://iceberg-rest-catalog:8181"
    "spark.sql.catalog.production.warehouse": "s3a://warehouse/iceberg"
```

## Time Travel

### Query by Snapshot ID

```python
# Get snapshot ID
snapshot_id = spark.sql(
    "SELECT snapshot_id FROM iceberg.analytics.orders.snapshots"
    " ORDER BY committed_at DESC LIMIT 1"
).collect()[0]["snapshot_id"]

# Query historical data
spark.sql(
    f"SELECT * FROM iceberg.analytics.orders VERSION AS OF {snapshot_id}"
).show()
```

### Query by Timestamp

```python
# Query data as of specific timestamp
spark.sql("""
    SELECT * FROM iceberg.analytics.orders
    TIMESTAMP AS OF '2024-01-01 12:00:00'
""").show()
```

### List Snapshots

```python
# List all snapshots
spark.sql("""
    SELECT snapshot_id, committed_at, summary
    FROM iceberg.analytics.orders.snapshots
    ORDER BY committed_at
""").show(truncate=False)
```

## Schema Evolution

### Add Column

```python
# Add new column
spark.sql(
    "ALTER TABLE iceberg.analytics.orders ADD COLUMN discount DOUBLE"
)

# Update new column for existing rows
spark.sql(
    "UPDATE iceberg.analytics.orders SET discount = 0.0 WHERE discount IS NULL"
)
```

### Change Column Type

```python
# Change INT to BIGINT (safe evolution)
spark.sql(
    "ALTER TABLE iceberg.analytics.orders ALTER COLUMN quantity TYPE BIGINT"
)
```

### Rename Column

```python
# Rename column
spark.sql(
    "ALTER TABLE iceberg.analytics.orders RENAME COLUMN price TO unit_price"
)
```

### Drop Column

```python
# Drop column
spark.sql(
    "ALTER TABLE iceberg.analytics.orders DROP COLUMN discount"
)
```

## Partition Evolution

### Add Partition

```python
# Add new partition field
spark.sql(
    "ALTER TABLE iceberg.analytics.orders ADD PARTITION FIELD customer_id"
)
```

### Drop Partition

```python
# Drop partition field
spark.sql(
    "ALTER TABLE iceberg.analytics.orders DROP PARTITION FIELD customer_id"
)
```

### Replace Partition

```python
# Replace partition strategy
spark.sql(
    "ALTER TABLE iceberg.analytics.orders REPLACE PARTITION FIELD days(order_timestamp) WITH bucket(16, customer_id)"
)
```

## Rollback Procedures

### Rollback to Snapshot

```python
# Get target snapshot ID
snapshot_id = spark.sql(
    "SELECT snapshot_id FROM iceberg.analytics.orders.snapshots"
    " ORDER BY committed_at LIMIT 1"
).collect()[0]["snapshot_id"]

# Rollback using stored procedure
spark.sql(
    f"CALL iceberg.system.rollback_to_snapshot('iceberg.analytics.orders', {snapshot_id})"
)
```

### Rollback to Timestamp

```python
# Rollback to specific timestamp
spark.sql(
    "CALL iceberg.system.rollback_to_timestamp('iceberg.analytics.orders', TIMESTAMP '2024-01-01 12:00:00')"
)
```

### Cherry-Pick Snapshot

```python
# Create new snapshot from specific snapshot
spark.sql(
    f"CALL iceberg.system.cherrypick_snapshot('iceberg.analytics.orders', {snapshot_id})"
)
```

## Delete Operations

### Delete Rows

```python
# Delete specific rows
spark.sql(
    "DELETE FROM iceberg.analytics.orders WHERE order_id = 1"
)
```

### Delete with Condition

```python
# Delete with complex condition
spark.sql("""
    DELETE FROM iceberg.analytics.orders
    WHERE order_timestamp < TIMESTAMP '2024-01-01'
    AND price < 50.0
""")
```

## Update Operations

### Update Rows

```python
# Update specific rows
spark.sql(
    "UPDATE iceberg.analytics.orders SET discount = 0.1 WHERE order_id > 100"
)
```

### Update with Expression

```python
# Update with calculation
spark.sql("""
    UPDATE iceberg.analytics.orders
    SET total_price = quantity * unit_price * (1 - discount)
""")
```

## Merge Operations

### Upsert Data

```python
# Merge new data with existing data
spark.sql("""
    MERGE INTO iceberg.analytics.orders AS target
    USING new_orders AS source
    ON target.order_id = source.order_id
    WHEN MATCHED THEN
        UPDATE SET target.quantity = source.quantity, target.price = source.price
    WHEN NOT MATCHED THEN
        INSERT *
""")
```

## Performance Tuning

### File Size Optimization

```yaml
connect:
  sparkConf:
    "spark.sql.iceberg.v2.enabled": "true"
    "spark.sql.iceberg.vectorization.enabled": "true"
    "spark.sql.iceberg.delete-planning.enabled": "true"
```

### Write Configuration

```python
# Configure write properties
spark.sql("""
    ALTER TABLE iceberg.analytics.orders
    SET TBLPROPERTIES (
        'write.target-file-size-bytes' = '536870912',
        'write.parquet.compression-codec' = 'zstd'
    )
""")
```

### Snapshot Retention

```python
# Configure snapshot expiration
spark.sql("""
    ALTER TABLE iceberg.analytics.orders
    SET TBLPROPERTIES (
        'history.expire.min-snapshots-to-keep' = '10',
        'history.expire.max-snapshot-age-ms' = '86400000'
    )
""")
```

## Troubleshooting

### Snapshot Not Found

**Problem:** `Snapshot does not exist` error

**Solutions:**
1. Check snapshot exists: `SELECT * FROM table.snapshots`
2. Use correct snapshot ID
3. Verify catalog configuration

### Schema Mismatch

**Problem:** `Schema mismatch` error when querying

**Solutions:**
1. Refresh table metadata: `spark.sql("REFRESH TABLE iceberg.analytics.orders")`
2. Check current schema: `DESCRIBE iceberg.analytics.orders`
3. Use time travel with correct schema version

### Slow Queries

**Problem:** Time travel queries are slow

**Solutions:**
1. Enable snapshot caching: `spark.sql.iceberg.vectorization.enabled=true`
2. Optimize file size: `write.target-file-size-bytes=536870912`
3. Use partition pruning
4. Consider materialized views

## Best Practices

1. **Use partitioning wisely** - Start with simple partitions (date, country)
2. **Enable V2** - For delete and row-level operations
3. **Configure snapshot retention** - Prevent unbounded metadata growth
4. **Use time travel for debugging** - Query historical data without copying
5. **Test schema evolution** - Verify compatibility with existing queries
6. **Monitor snapshot count** - Expire old snapshots regularly
7. **Use hidden partitioning** - Let Iceberg derive partition values
8. **Optimize file sizes** - Target 256-512MB files
9. **Enable vectorization** - For improved read performance
10. **Plan rollbacks** - Document snapshot IDs for critical points

## Examples

### Complete Workflow

```python
from pyspark.sql import SparkSession

# Initialize Spark with Iceberg
spark = SparkSession.builder \
    .config("spark.sql.extensions", "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions") \
    .config("spark.sql.catalog.iceberg", "org.apache.iceberg.spark.SparkCatalog") \
    .getOrCreate()

# Create table
spark.sql("""
    CREATE TABLE iceberg.analytics.events (
        event_id BIGINT,
        user_id BIGINT,
        event_type STRING,
        event_timestamp TIMESTAMP,
        properties MAP<STRING, STRING>
    ) USING iceberg
    PARTITIONED BY (days(event_timestamp), event_type)
""")

# Insert data
spark.sql("""
    INSERT INTO iceberg.analytics.events
    VALUES (1, 100, 'click', TIMESTAMP '2024-01-01 10:00:00', map('page', '/home'))
""")

# Update data
spark.sql("""
    UPDATE iceberg.analytics.events
    SET properties['page'] = '/homepage'
    WHERE event_id = 1
""")

# Time travel
snapshot_id = spark.sql(
    "SELECT snapshot_id FROM iceberg.analytics.events.snapshots LIMIT 1"
).collect()[0]["snapshot_id"]

old_data = spark.sql(
    f"SELECT * FROM iceberg.analytics.events VERSION AS OF {snapshot_id}"
)

# Schema evolution
spark.sql(
    "ALTER TABLE iceberg.analytics.events ADD COLUMN session_id STRING"
)
```

## Further Reading

- [Apache Iceberg Documentation](https://iceberg.apache.org/)
- [Iceberg Spark Integration](https://iceberg.apache.org/spark/)
- [Iceberg Spec](https://iceberg.apache.org/spec/)
