#!/usr/bin/env python3
"""Load workload: S3 parquet read + 3 agg iterations. EXECUTES, no in-memory fallback."""

import os
import sys
import time

from pyspark.sql import SparkSession
from pyspark.sql import functions as f

# S3 config from env - no fallback, fail explicitly if missing
endpoint = os.environ.get("S3_ENDPOINT")
if not endpoint:
    print("ERROR: S3_ENDPOINT required", file=sys.stderr)
    sys.exit(1)

spark = (
    SparkSession.builder.config("spark.hadoop.fs.s3a.endpoint", endpoint)
    .config("spark.hadoop.fs.s3a.access.key", os.environ.get("S3_ACCESS_KEY", ""))
    .config("spark.hadoop.fs.s3a.secret.key", os.environ.get("S3_SECRET_KEY", ""))
    .config("spark.hadoop.fs.s3a.path.style.access", "true")
    .getOrCreate()
)

# Write parquet to S3 (creates data for read)
s3_path = "s3a://raw-data/load-test/"
spark.range(10000).write.mode("overwrite").parquet(s3_path)

# Read from S3 - no fallback, will fail if S3 unreachable
df = spark.read.parquet(s3_path)
rows_total = df.count()

# 3 aggregation iterations
t0 = time.perf_counter()
for _ in range(3):
    agg = df.groupBy((df.id % 10).alias("b")).agg(
        f.count("*").alias("cnt"),
        f.sum("id").alias("s"),
    )
    agg.count()  # force execution
elapsed = time.perf_counter() - t0

throughput = rows_total / elapsed if elapsed > 0 else 0
print(f"LOAD_ROWS={rows_total}")
print(f"LOAD_THROUGHPUT_ROWS_SEC={throughput:.0f}")
print("LOAD_SUCCESS")
