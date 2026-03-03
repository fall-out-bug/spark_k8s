#!/usr/bin/env python3
"""
NYC Taxi pipeline for smoke/e2e/load validation.
No SparkPi - uses NYC Taxi schema at all levels.
Env: TEST_LEVEL=smoke|e2e|load, MASTER_URL=spark://host:7077
"""

import os
import sys
import time
from functools import reduce

from pyspark.sql import SparkSession
from pyspark.sql.functions import col
from pyspark.sql.types import (
    StructType,
    StructField,
    IntegerType,
    DoubleType,
    StringType,
    TimestampType,
)

NYC_SCHEMA = StructType(
    [
        StructField("VendorID", IntegerType()),
        StructField("tpep_pickup_datetime", TimestampType()),
        StructField("tpep_dropoff_datetime", TimestampType()),
        StructField("passenger_count", IntegerType()),
        StructField("trip_distance", DoubleType()),
        StructField("PULocationID", IntegerType()),
        StructField("DOLocationID", IntegerType()),
        StructField("fare_amount", DoubleType()),
        StructField("total_amount", DoubleType()),
    ]
)


def make_nyc_data(spark: SparkSession, rows: int):
    """Generate in-memory NYC Taxi-like data."""
    from datetime import datetime, timedelta
    import random

    random.seed(42)
    base = datetime(2023, 1, 1, 12, 0, 0)
    data = []
    for i in range(rows):
        pickup = base + timedelta(minutes=random.randint(0, 1440))
        dropoff = pickup + timedelta(minutes=random.randint(5, 60))
        dist = random.uniform(0.5, 15.0)
        fare = dist * 2.5 + random.uniform(0, 5)
        data.append(
            (
                1 if i % 2 == 0 else 2,
                pickup,
                dropoff,
                random.randint(1, 6),
                dist,
                random.randint(1, 263),
                random.randint(1, 263),
                fare,
                fare + random.uniform(0, 3),
            )
        )
    return spark.createDataFrame(data, NYC_SCHEMA)


def run_smoke(spark: SparkSession) -> bool:
    """Smoke: 1K rows, count + simple aggregation."""
    df = make_nyc_data(spark, 1000)
    df.createOrReplaceTempView("nyc_taxi")
    cnt = spark.sql("SELECT COUNT(*) AS c FROM nyc_taxi").collect()[0]["c"]
    if cnt != 1000:
        print(f"FAIL: expected 1000, got {cnt}")
        return False
    agg = spark.sql("SELECT COUNT(*) AS c FROM nyc_taxi WHERE total_amount > 0 AND trip_distance > 0").collect()[0]["c"]
    if agg < 900:
        print(f"FAIL: filter expected ~1000, got {agg}")
        return False
    print("SMOKE_SUCCESS")
    return True


def run_e2e(spark: SparkSession) -> bool:
    """E2E: 10K rows, aggregations, joins, groupBy."""
    df = make_nyc_data(spark, 10000)
    df.createOrReplaceTempView("nyc_taxi")
    # Q1: count
    r1 = spark.sql("SELECT COUNT(*) AS c FROM nyc_taxi WHERE total_amount > 0").collect()[0]["c"]
    if r1 < 9000:
        print(f"FAIL E2E Q1: got {r1}")
        return False
    # Q2: groupBy
    r2 = spark.sql(
        "SELECT PULocationID, COUNT(*) AS cnt FROM nyc_taxi " "GROUP BY PULocationID ORDER BY cnt DESC LIMIT 5"
    ).count()
    if r2 < 5:
        print(f"FAIL E2E Q2: got {r2}")
        return False
    # Q3: join-like (self join on location)
    r3 = spark.sql(
        "SELECT a.PULocationID, COUNT(*) FROM nyc_taxi a "
        "JOIN nyc_taxi b ON a.PULocationID = b.DOLocationID "
        "GROUP BY a.PULocationID LIMIT 3"
    ).count()
    if r3 < 1:
        print(f"FAIL E2E Q3: got {r3}")
        return False
    print("E2E_SUCCESS")
    return True


def _list_parquet_paths(spark: SparkSession, base_path: str) -> list[str]:
    """List parquet file paths under base_path via binaryFile (no schema inference)."""
    paths_df = (
        spark.read.format("binaryFile")
        .option("pathGlobFilter", "*.parquet")
        .option("recursiveFileLookup", "true")
        .load(base_path)
        .select("path")
        .distinct()
    )
    return [r.path for r in paths_df.collect()]


def run_load(spark: SparkSession, s3_endpoint: str) -> bool:
    """Load: S3 parquet only. Reads each file separately to handle INT32/INT64 mix."""
    path = "s3a://nyc-taxi/raw/"
    spark.conf.set("fs.s3a.endpoint", s3_endpoint)
    spark.conf.set("fs.s3a.access.key", "minioadmin")
    spark.conf.set("fs.s3a.secret.key", "minioadmin")
    spark.conf.set("fs.s3a.path.style.access", "true")

    paths = _list_parquet_paths(spark, path)
    if not paths:
        raise ValueError(f"No parquet files found in {path}")

    dfs = []
    for p in paths:
        part = spark.read.parquet(p).select(
            col("PULocationID").cast("int").alias("PULocationID"),
            col("total_amount"),
        )
        dfs.append(part)

    df = reduce(lambda a, b: a.union(b), dfs)
    count = df.count()
    if count < 100:
        raise ValueError(f"Too few rows from S3: {count}")

    df.createOrReplaceTempView("nyc_taxi")
    start = time.time()
    for _ in range(3):
        spark.sql("SELECT PULocationID, AVG(total_amount) FROM nyc_taxi GROUP BY PULocationID").collect()
    duration = time.time() - start
    print(f"LOAD_SUCCESS: {count} rows, 3 agg iterations in {duration:.2f}s")
    return True


def main() -> int:
    level = os.environ.get("TEST_LEVEL", "smoke")
    master_url = os.environ.get("MASTER_URL", "spark://localhost:7077")
    s3_endpoint = os.environ.get("S3_ENDPOINT", "http://minio.spark-infra.svc.cluster.local:9000")
    driver_host = os.environ.get("DRIVER_HOST")
    if not driver_host:
        import subprocess

        driver_host = (
            subprocess.run(
                ["hostname", "-i"],
                capture_output=True,
                text=True,
                check=False,
            ).stdout.strip()
            or "127.0.0.1"
        )
    builder = (
        SparkSession.builder.appName(f"nyc-taxi-{level}")
        .master(master_url)
        .config("spark.driver.host", driver_host)
        .config("spark.driver.bindAddress", "0.0.0.0")
    )
    # S3 config for event logging (images may default to s3a://spark-logs/...)
    if s3_endpoint:
        builder = (
            builder.config("spark.hadoop.fs.s3a.endpoint", s3_endpoint)
            .config("spark.hadoop.fs.s3a.access.key", "minioadmin")
            .config("spark.hadoop.fs.s3a.secret.key", "minioadmin")
            .config("spark.hadoop.fs.s3a.path.style.access", "true")
        )
    # Event logs to S3 for load (History Server path: s3a://spark-logs/events for 3.5.x)
    if level == "load" and s3_endpoint:
        builder = builder.config("spark.eventLog.enabled", "true").config(
            "spark.eventLog.dir", "s3a://spark-logs/events"
        )
    spark = builder.getOrCreate()
    ok = False
    if level == "smoke":
        ok = run_smoke(spark)
    elif level == "e2e":
        ok = run_e2e(spark)
    elif level == "load":
        ok = run_load(spark, s3_endpoint)
    else:
        print(f"Unknown TEST_LEVEL: {level}")
    spark.stop()
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
