# Data Skew Diagnosis

## Problem
Data is unevenly distributed across partitions/tasks, causing some executors to process significantly more data than others.

## Diagnosis Steps

### 1. Check Task Size Distribution

```bash
# Use Spark UI or event logs
grep "task rows" /var/log/spark-events/* | \
  sed 's/.*rows=\([0-9,]*\).*/\1/p' | \
  sort -t: -n -r | head -20
```

**Interpretation:**
- If max >> 4× median → severe skew
- If max >> 2× median → moderate skew
- If max ≈ median → balanced

### 2. Identify Skewed Keys

```bash
# From Spark SQL
df.groupBy("PULocationID").agg(
    count("*").alias("total_rows"),
    count("*").alias("partition_rows")
).orderBy(desc("total_rows")).show()
```

### 3. Check Shuffle Metrics

**Dashboard**: Spark Profiling → "Shuffle Skew" panel

| Metric | Meaning | Action |
|--------|---------|--------|
| max/avg read ratio > 3 | High read imbalance | Repartition data |
| max/avg write ratio > 3 | High write imbalance | Increase shuffle partitions |

### 4. Solutions

| Solution | When to Use |
|---------|--------------|
| Add `coalesce` before heavy operations | Small data sets |
| Use `repartition` with custom partitioner | Known key distribution |
| Use salting for large aggregations | String keys with known cardinality |
