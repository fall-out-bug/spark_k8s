#!/usr/bin/env python3
"""E2E workload: 10K rows, aggregations, joins. EXECUTES workload, no file-existence checks."""

from pyspark.sql import SparkSession
from pyspark.sql import functions as f

spark = SparkSession.builder.getOrCreate()
df = spark.range(10000)

# Aggregation: groupBy bucket, count and sum
agg = df.groupBy((df.id % 10).alias("bucket")).agg(
    f.count("*").alias("cnt"),
    f.sum("id").alias("total"),
)
agg_rows = agg.collect()
assert len(agg_rows) == 10, f"Expected 10 buckets, got {len(agg_rows)}"
total_sum = sum(r.total for r in agg_rows)
expected_sum = sum(range(10000))
assert total_sum == expected_sum, f"Expected sum {expected_sum}, got {total_sum}"

# Join: df with smaller df on id
df_small = spark.range(1000)
joined = df.join(df_small, df.id == df_small.id, "inner")
joined_cnt = joined.count()
assert joined_cnt == 1000, f"Expected join count 1000, got {joined_cnt}"

print("E2E_SUCCESS")
