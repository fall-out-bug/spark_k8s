#!/usr/bin/env python3
"""Iceberg compaction automation for maintaining optimal file sizes."""

from pyspark.sql import SparkSession
from pyspark.sql.functions import col, sum as spark_sum, count, avg


def create_spark_session():
    """Create Spark session with Iceberg config."""
    return SparkSession.builder \
        .appName("Iceberg Compaction") \
        .config("spark.sql.extensions",
                "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions") \
        .config("spark.sql.catalog.iceberg",
                "org.apache.iceberg.spark.SparkCatalog") \
        .config("spark.sql.catalog.iceberg.type", "hadoop") \
        .config("spark.sql.catalog.iceberg.warehouse", "s3a://warehouse/iceberg") \
        .getOrCreate()


def analyze_table_files(spark, table_name):
    """
    Analyze file sizes and distribution for a table.

    Returns statistics about current file state.
    """
    files_df = spark.sql(f"SELECT * FROM {table_name}.files")

    stats = files_df.agg(
        count("*").alias("file_count"),
        spark_sum("file_size_in_bytes").alias("total_size_bytes"),
        avg("file_size_in_bytes").alias("avg_file_size_bytes")
    ).collect()[0]

    return {
        "file_count": stats["file_count"],
        "total_size_bytes": stats["total_size_bytes"],
        "avg_file_size_bytes": stats["avg_file_size_bytes"],
    }


def needs_compaction(stats, target_size_bytes=256 * 1024 * 1024, max_files=100):
    """
    Determine if table needs compaction.

    Criteria:
    - Many small files (avg < 50% of target)
    - Too many files (> max_files)
    """
    avg_size = stats["avg_file_size_bytes"] or 0
    file_count = stats["file_count"] or 0

    if file_count == 0:
        return False, "Table is empty"

    reasons = []

    # Check for small files
    if avg_size < target_size_bytes * 0.5:
        small_file_pct = (target_size_bytes - avg_size) / target_size_bytes * 100
        reasons.append(f"Small files: avg {avg_size/1024/1024:.1f}MB ({small_file_pct:.0f}% below target)")

    # Check file count
    if file_count > max_files:
        reasons.append(f"Too many files: {file_count} (max {max_files})")

    needs = len(reasons) > 0
    return needs, "; ".join(reasons) if reasons else "OK"


def compact_table(spark, table_name, target_size_bytes=256 * 1024 * 1024):
    """
    Run compaction on a table using rewrite_data_files.

    Args:
        spark: SparkSession
        table_name: Full table name (catalog.db.table)
        target_size_bytes: Target file size in bytes (default 256MB)
    """
    print(f"\nCompacting {table_name}...")

    # Analyze before
    before = analyze_table_files(spark, table_name)
    needs, reason = needs_compaction(before, target_size_bytes)

    if not needs:
        print(f"  Skip: {reason}")
        return

    print(f"  Reason: {reason}")

    # Run compaction
    spark.sql(f"""
        CALL iceberg.system.rewrite_data_files(
            table => '{table_name}',
            options => map(
                'target-file-size-bytes', '{target_size_bytes}',
                'max-concurrent-file-group-rewrites', '10'
            )
        )
    """)

    # Analyze after
    after = analyze_table_files(spark, table_name)

    print(f"  Before: {before['file_count']} files, avg {before['avg_file_size_bytes']/1024/1024:.1f}MB")
    print(f"  After:  {after['file_count']} files, avg {after['avg_file_size_bytes']/1024/1024:.1f}MB")


def compact_partitioned_table(spark, table_name, partition_filter=None):
    """
    Compact specific partitions of a table.

    Args:
        spark: SparkSession
        table_name: Full table name
        partition_filter: Optional partition filter (e.g., "date = '2024-01-01'")
    """
    where_clause = f"WHERE {partition_filter}" if partition_filter else ""

    print(f"\nCompacting {table_name} {where_clause}...")

    spark.sql(f"""
        CALL iceberg.system.rewrite_data_files(
            table => '{table_name}',
            where => '{partition_filter}',
            options => map(
                'target-file-size-bytes', '268435456'
            )
        )
    """)


def remove_orphan_files(spark, table_name, older_than_days=7):
    """
    Remove orphan files not tracked by the table.

    Args:
        spark: SparkSession
        table_name: Full table name
        older_than_days: Only remove files older than this
    """
    print(f"\nRemoving orphan files from {table_name}...")

    result = spark.sql(f"""
        CALL iceberg.system.remove_orphan_files(
            table => '{table_name}',
            older_than => timestamp('{older_than_days} days')
        )
    """)

    deleted = result.collect()[0][0]
    print(f"  Deleted {deleted} orphan files")


def expire_snapshots(spark, table_name, retain_days=7):
    """
    Expire old snapshots to clean up metadata.

    Args:
        spark: SparkSession
        table_name: Full table name
        retain_days: Number of days to retain snapshots
    """
    print(f"\nExpiring snapshots for {table_name} (retain {retain_days} days)...")

    result = spark.sql(f"""
        CALL iceberg.system.expire_snapshots(
            table => '{table_name}',
            older_than => timestamp('{retain_days} days')
        )
    """)

    expired = result.collect()[0][0]
    print(f"  Expired {expired} snapshots")


def main():
    """Run compaction maintenance."""
    spark = create_spark_session()
    print(f"Spark Version: {spark.version}")

    tables = [
        "iceberg.examples.events_identity",
        "iceberg.examples.user_events_bucket",
        "iceberg.examples.logs_daily",
    ]

    for table in tables:
        try:
            compact_table(spark, table)
            expire_snapshots(spark, table, retain_days=7)
        except Exception as e:
            print(f"  Error: {e}")

    print("\n=== Compaction Complete ===")
    spark.stop()


if __name__ == "__main__":
    main()
