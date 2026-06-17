#!/usr/bin/env python3
"""Smoke workload: 1K rows, count, filter. EXECUTES workload, no file-existence checks."""

from pyspark.sql import SparkSession

spark = SparkSession.builder.getOrCreate()
df = spark.range(1000)
cnt = df.count()
assert cnt == 1000, f"Expected count 1000, got {cnt}"
filtered = df.filter("id > 500")
fcnt = filtered.count()
assert fcnt == 499, f"Expected filtered count 499, got {fcnt}"
print("SMOKE_SUCCESS")
