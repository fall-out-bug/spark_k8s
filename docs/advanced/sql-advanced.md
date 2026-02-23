# Advanced SQL Guide

Advanced SQL patterns and optimizations for Spark SQL.

## Overview

This guide covers:
- Window functions
- Complex joins
- Optimizations
- UDFs andUDAFs
- SQL hints
- Performance tuning

## Window Functions

### Ranking Functions

```sql
-- Row number within partition
SELECT
    user_id,
    transaction_date,
    amount,
    ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY amount DESC) as rn
FROM transactions

-- Top N per user
WITH ranked AS (
    SELECT
        user_id,
        transaction_date,
        amount,
        ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY amount DESC) as rn
    FROM transactions
)
SELECT * FROM ranked WHERE rn <= 10
```

### Analytic Functions

```sql
-- Moving averages
SELECT
    date,
    product,
    sales,
    AVG(sales) OVER (
        PARTITION BY product
        ORDER BY date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) as moving_avg_7day
FROM sales_data

-- Year-over-year comparison
SELECT
    date,
    revenue,
    LAG(revenue, 365) OVER (ORDER BY date) as revenue_last_year,
    revenue - LAG(revenue, 365) OVER (ORDER BY date) as yoy_growth
FROM daily_revenue
```

### Sessionization

```sql
-- Identify user sessions
WITH session_starts AS (
    SELECT
        user_id,
        event_time,
        CASE
            WHEN event_time > LAG(event_time) OVER (PARTITION BY user_id ORDER BY event_time) + INTERVAL 30 MINUTES
            THEN 1
            ELSE 0
        END as is_new_session
    FROM events
),
session_ids AS (
    SELECT
        user_id,
        event_time,
        SUM(is_new_session) OVER (PARTITION BY user_id ORDER BY event_time) as session_id
    FROM session_starts
)
SELECT
    user_id,
    session_id,
    MIN(event_time) as session_start,
    MAX(event_time) as session_end,
    COUNT(*) as event_count
FROM session_ids
GROUP BY user_id, session_id
```

## Complex Joins

### Broadcast Hash Join Hint

```sql
-- Force small table broadcast
SELECT /*+ BROADCAST(users) */ *
FROM transactions
JOIN users ON transactions.user_id = users.id

-- Or specify broadcast threshold
SET spark.sql.autoBroadcastJoinThreshold = 104857600; -- 100MB
```

### Shuffle Hash Join Hint

```sql
-- Force shuffle hash join (when one table fits in memory)
SELECT /*+ SHUFFLE_HASH(users) */ *
FROM transactions
JOIN users ON transactions.user_id = users.id
```

### Skew Join Hint

```sql
-- Handle data skew in joins
SELECT /*+ SKEW('transactions') */ *
FROM transactions
JOIN users ON transactions.user_id = users.id
```

## SQL Optimizations

### Partition Pruning

```sql
-- Partition by date for automatic pruning
CREATE TABLE events (
    event_id STRING,
    event_data STRING,
    event_date DATE
) PARTITIONED BY (event_date)
USING DELTA;

-- Query automatically prunes partitions
SELECT * FROM events WHERE event_date = '2024-01-15'
```

### Column Pruning

```sql
-- Select only needed columns
SELECT user_id, amount  -- Instead of SELECT *
FROM transactions
WHERE status = 'completed'
```

### Predicate Pushdown

```sql
-- Filter before join
SELECT /*+ SHUFFLE_HASH(transactions) */ *
FROM (
    SELECT * FROM transactions WHERE status = 'completed'
) transactions
JOIN users ON transactions.user_id = users.id
```

### Caching

```sql
-- Cache frequently accessed tables
CACHE TABLE active_users AS
SELECT * FROM users WHERE last_login > CURRENT_DATE - INTERVAL 30 DAYS;

-- Or with specific storage level
CACHE LAZY TABLE active_users OPTIONS(
    'storageLevel' 'MEMORY_AND_DISK_SER'
) AS
SELECT * FROM users WHERE last_login > CURRENT_DATE - INTERVAL 30 DAYS;

-- Uncache when done
UNCACHE TABLE active_users;
```

## UDFs (User-Defined Functions)

### Python UDFs

```python
from pyspark.sql.functions import udf
from pyspark.sql.types import IntegerType

# Define UDF
@udf(IntegerType())
def calculate_score(amount: int, tier: str) -> int:
    base_score = amount // 100
    multiplier = {"BRONZE": 1, "SILVER": 2, "GOLD": 3}.get(tier, 1)
    return base_score * multiplier

# Register UDF
spark.udf.register("calculate_score", calculate_score)

# Use in SQL
spark.sql("""
    SELECT
        user_id,
        amount,
        tier,
        calculate_score(amount, tier) as score
    FROM transactions
""")
```

### Pandas UDFs (Vectorized)

```python
from pyspark.sql.functions import pandas_udf
from pyspark.sql.types import IntegerType
import pandas as pd

# Much faster than regular UDFs
@pandas_udf(IntegerType())
def calculate_score_vectorized(amounts: pd.Series, tiers: pd.Series) -> pd.Series:
    multiplier = {"BRONZE": 1, "SILVER": 2, "GOLD": 3}
    return (amounts // 100) * tiers.map(multiplier)

# Use
df.select(
    calculate_score_vectorized(col("amount"), col("tier"))
).show()
```

### UDAFs (User-Defined Aggregate Functions)

```python
from pyspark.sql.functions import pandas_udf, PandasUDFType
from pyspark.sql.types import IntegerType, DoubleType

# Define UDAF
@pandas_udf(DoubleType())
def custom_mean(series: pd.Series) -> float:
    """Custom mean with outlier removal."""
    q1 = series.quantile(0.25)
    q3 = series.quantile(0.75)
    iqr = q3 - q1
    filtered = series[(series >= q1 - 1.5*iqr) & (series <= q3 + 1.5*iqr)]
    return filtered.mean()

# Register
spark.udf.register("custom_mean", custom_mean)

# Use in SQL
spark.sql("""
    SELECT
        category,
        custom_mean(amount) as filtered_mean_amount
    FROM transactions
    GROUP BY category
""")
```

## SQL Hints

### Join Hints

```sql
-- Broadcast hint
SELECT /*+ BROADCAST(table1) */ *
FROM table1 JOIN table2 ON table1.id = table2.id

-- Shuffle hash hint
SELECT /*+ SHUFFLE_HASH(table1) */ *
FROM table1 JOIN table2 ON table1.id = table2.id

-- Shuffle merge hint (default)
SELECT /*+ SHUFFLE_MERGE(table1) */ *
FROM table1 JOIN table2 ON table1.id = table2.id
```

### Repartition Hints

```sql
-- Coalesce before writing
SELECT /*+ COALESCE(10) */ *
FROM large_table

-- Repartition by key
SELECT /*+ REPARTITION(10) */ *
FROM large_table

-- Repartition by specific columns
SELECT /*+ REPARTITION_BY_RANGE(10, date) */ *
FROM time_series_data
```

### Cache Hints

```sql
-- Cache table during query
SELECT /*+ CACHE(table1) */ *
FROM table1 JOIN table2 ON table1.id = table2.id
```

## Performance Tuning

### AQE (Adaptive Query Execution)

```sql
-- Enable AQE
SET spark.sql.adaptive.enabled = true;
SET spark.sql.adaptive.coalescePartitions.enabled = true;
SET spark.sql.adaptive.skewJoin.enabled = true;

-- Configure AQE
SET spark.sql.adaptive.skewJoin.skewedPartitionThresholdInBytes = 256MB;
SET spark.sql.adaptive.skewJoin.skewedPartitionFactor = 5;
```

### Shuffle Optimization

```sql
-- Optimize shuffle partitions
SET spark.sql.shuffle.partitions = 200;

-- Enable shuffle compression
SET spark.shuffle.compress = true;
SET spark.shuffle.spill.compress = true;
```

### Join Optimization

```sql
-- Disable broadcast for specific join
SET spark.sql.autoBroadcastJoinThreshold = -1;

-- Configure for large joins
SET spark.sql.broadcastTimeout = 1200;
SET spark.sql.autoBroadcastJoinThreshold = 104857600;
```

## Advanced Patterns

### Recursive CTEs

```sql
-- Organization hierarchy
WITH RECURSIVE org_hierarchy AS (
    -- Base case: top-level managers
    SELECT id, name, manager_id, 1 as level
    FROM employees
    WHERE manager_id IS NULL

    UNION ALL

    -- Recursive case: direct reports
    SELECT e.id, e.name, e.manager_id, h.level + 1
    FROM employees e
    JOIN org_hierarchy h ON e.manager_id = h.id
)
SELECT * FROM org_hierarchy;
```

### Pivot Tables

```sql
-- Pivot categories to columns
SELECT *
FROM sales_data
PIVOT (
    SUM(amount)
    FOR category IN ('ELECTRONICS', 'CLOTHING', 'FOOD')
)
```

### Hierarchical Queries

```sql
-- Find all descendants
WITH RECURSIVE descendants AS (
    SELECT id, parent_id, name
    FROM categories
    WHERE id = 'root'  -- Start from root

    UNION ALL

    SELECT c.id, c.parent_id, c.name
    FROM categories c
    JOIN descendants d ON c.parent_id = d.id
)
SELECT * FROM descendants;
```

## Best Practices

1. **Use window functions** instead of self-joins
2. **Leverage AQE** for automatic optimization
3. **Broadcast small tables** in joins
4. **Filter early** to reduce data volume
5. **Use appropriate join types** for your data
6. **Profile queries** with EXPLAIN EXTENDED
7. **Cache smartly** for repeated access

## Related

- [Performance Tuning](../guides/performance/)
- [SQL Reference](https://spark.apache.org/sql/)
