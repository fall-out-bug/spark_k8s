#!/usr/bin/env python3
"""Iceberg time travel examples for querying historical data."""

from pyspark.sql import SparkSession
from pyspark.sql.functions import col


def create_spark_session():
    """Create Spark session with Iceberg config."""
    return SparkSession.builder \
        .appName("Iceberg Time Travel") \
        .config("spark.sql.extensions",
                "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions") \
        .config("spark.sql.catalog.iceberg",
                "org.apache.iceberg.spark.SparkCatalog") \
        .config("spark.sql.catalog.iceberg.type", "hadoop") \
        .config("spark.sql.catalog.iceberg.warehouse", "s3a://warehouse/iceberg") \
        .getOrCreate()


def setup_example_table(spark):
    """Create example table with multiple snapshots."""
    spark.sql("CREATE NAMESPACE IF NOT EXISTS iceberg.examples")

    spark.sql("""
        CREATE TABLE IF NOT EXISTS iceberg.examples.time_travel_demo (
            id BIGINT,
            value STRING,
            version INT
        ) USING iceberg
    """)

    # Clear existing data
    spark.sql("DELETE FROM iceberg.examples.time_travel_demo")

    # Insert version 1
    spark.sql("""
        INSERT INTO iceberg.examples.time_travel_demo
        VALUES (1, 'initial', 1), (2, 'initial', 1), (3, 'initial', 1)
    """)

    # Insert version 2
    spark.sql("""
        INSERT INTO iceberg.examples.time_travel_demo
        VALUES (4, 'added_v2', 2), (5, 'added_v2', 2)
    """)

    # Update to version 3
    spark.sql("""
        UPDATE iceberg.examples.time_travel_demo
        SET value = 'updated_v3', version = 3
        WHERE id = 1
    """)

    # Delete in version 4
    spark.sql("DELETE FROM iceberg.examples.time_travel_demo WHERE id = 3")


def list_snapshots(spark, table_name):
    """List all snapshots for a table."""
    print(f"\n=== Snapshots for {table_name} ===")

    snapshots = spark.sql(f"""
        SELECT
            snapshot_id,
            committed_at,
            operation,
            summary['spark.app.id'] as app_id
        FROM {table_name}.snapshots
        ORDER BY committed_at DESC
    """)

    snapshots.show(truncate=False)
    return snapshots.collect()


def query_by_snapshot_id(spark, table_name, snapshot_id):
    """
    Query table as of a specific snapshot.

    Args:
        spark: SparkSession
        table_name: Full table name
        snapshot_id: Snapshot ID to query
    """
    print(f"\n=== Query as of snapshot {snapshot_id} ===")

    df = spark.sql(f"""
        SELECT * FROM {table_name}
        VERSION AS OF {snapshot_id}
    """)

    df.show()
    return df


def query_by_timestamp(spark, table_name, timestamp):
    """
    Query table as of a specific timestamp.

    Args:
        spark: SparkSession
        table_name: Full table name
        timestamp: Timestamp string (ISO format)
    """
    print(f"\n=== Query as of timestamp {timestamp} ===")

    df = spark.sql(f"""
        SELECT * FROM {table_name}
        TIMESTAMP AS OF '{timestamp}'
    """)

    df.show()
    return df


def compare_versions(spark, table_name):
    """Compare data between two snapshots."""
    print(f"\n=== Comparing Versions ===")

    # Get first and last snapshots
    snapshots = spark.sql(f"""
        SELECT snapshot_id, committed_at
        FROM {table_name}.snapshots
        ORDER BY committed_at
    """).collect()

    if len(snapshots) < 2:
        print("Need at least 2 snapshots for comparison")
        return

    first_snapshot = snapshots[0]["snapshot_id"]
    last_snapshot = snapshots[-1]["snapshot_id"]

    # Count at first snapshot
    first_count = spark.sql(f"""
        SELECT count(*) as cnt FROM {table_name}
        VERSION AS OF {first_snapshot}
    """).collect()[0]["cnt"]

    # Count at last snapshot
    last_count = spark.sql(f"""
        SELECT count(*) as cnt FROM {table_name}
        VERSION AS OF {last_snapshot}
    """).collect()[0]["cnt"]

    print(f"First snapshot ({first_snapshot}): {first_count} rows")
    print(f"Last snapshot ({last_snapshot}): {last_count} rows")
    print(f"Difference: {last_count - first_count} rows")


def rollback_to_snapshot(spark, table_name, snapshot_id):
    """
    Rollback table to a previous snapshot.

    WARNING: This modifies the table!
    """
    print(f"\n=== Rolling back to snapshot {snapshot_id} ===")

    spark.sql(f"""
        CALL iceberg.system.rollback_to_snapshot(
            '{table_name}',
            {snapshot_id}
        )
    """)

    print("Rollback complete")
    spark.sql(f"SELECT * FROM {table_name}").show()


def audit_changes(spark, table_name):
    """Audit what changed between snapshots."""
    print(f"\n=== Auditing Changes ===")

    # Get recent snapshots
    snapshots = spark.sql(f"""
        SELECT snapshot_id, committed_at, operation,
               summary['added-records'] as added,
               summary['deleted-records'] as deleted
        FROM {table_name}.snapshots
        ORDER BY committed_at DESC
        LIMIT 5
    """)

    print("Recent changes:")
    snapshots.show(truncate=False)


def main():
    """Run time travel examples."""
    spark = create_spark_session()
    print(f"Spark Version: {spark.version}")

    setup_example_table(spark)

    # List all snapshots
    snapshots = list_snapshots(spark, "iceberg.examples.time_travel_demo")

    if len(snapshots) >= 2:
        # Query previous snapshot
        prev_snapshot = snapshots[1]["snapshot_id"]
        query_by_snapshot_id(spark, "iceberg.examples.time_travel_demo", prev_snapshot)

        # Query by timestamp
        prev_timestamp = snapshots[1]["committed_at"]
        query_by_timestamp(spark, "iceberg.examples.time_travel_demo", prev_timestamp)

    # Compare versions
    compare_versions(spark, "iceberg.examples.time_travel_demo")

    # Audit changes
    audit_changes(spark, "iceberg.examples.time_travel_demo")

    print("\n=== Time Travel Examples Complete ===")
    spark.stop()


if __name__ == "__main__":
    main()
