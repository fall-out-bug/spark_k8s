#!/usr/bin/env python3
"""E2E workload: 10K rows, aggregations, joins. EXECUTES workload, no file-existence checks.

With spark.e2e.s3.roundtrip=true (set by run-e2e-against-release.sh when
E2E_S3_ROUNDTRIP=1), the aggregation result is additionally written to
s3a:// as parquet and read back, so the scenario verifies an actual
object-storage round trip instead of only co-existing with MinIO.
"""

from pyspark.sql import SparkSession
from pyspark.sql import functions as f

spark = SparkSession.builder.getOrCreate()

s3_roundtrip = spark.conf.get("spark.e2e.s3.roundtrip", "false").lower() == "true"

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

# S3 round-trip: write aggregate to object storage, read back, compare exactly.
if s3_roundtrip:
    s3_path = spark.conf.get("spark.e2e.s3.path", "")
    if not s3_path:
        raise SystemExit(
            "spark.e2e.s3.roundtrip=true requires spark.e2e.s3.path " "(e.g. s3a://spark-jobs/e2e-roundtrip/<release>)"
        )
    agg.write.mode("overwrite").parquet(s3_path)
    read_back = spark.read.parquet(s3_path)
    rt_rows = read_back.collect()
    assert len(rt_rows) == 10, f"S3 read-back: expected 10 buckets, got {len(rt_rows)}"
    expected = {r.bucket: (r.cnt, r.total) for r in agg_rows}
    actual = {r.bucket: (r.cnt, r.total) for r in rt_rows}
    assert actual == expected, f"S3 read-back mismatch:\nexpected={expected}\nactual={actual}"
    rt_sum = sum(r.total for r in rt_rows)
    assert rt_sum == expected_sum, f"S3 read-back sum {rt_sum} != {expected_sum}"
    print(f"S3_ROUNDTRIP_OK path={s3_path}")

print("E2E_SUCCESS")
