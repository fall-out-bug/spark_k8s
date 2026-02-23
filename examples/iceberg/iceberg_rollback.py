"""Iceberg rollback and delete operations."""

from pyspark.sql import SparkSession


def rollback_procedures(spark: SparkSession) -> None:
    """Demonstrate rollback procedures."""
    print("\n9. Rollback Procedures")
    print("   Available snapshots:")
    snapshots = spark.sql(
        "SELECT snapshot_id, committed_at, summary FROM iceberg.db_examples.orders.snapshots "
        "ORDER BY committed_at"
    )
    snapshots.show(truncate=False)
    first_snapshot_id = snapshots.collect()[0]["snapshot_id"]
    print(f"\n   Rolling back to snapshot {first_snapshot_id}...")
    spark.sql(
        f"CALL iceberg.system.rollback_to_snapshot('iceberg.db_examples.orders', {first_snapshot_id})"
    )
    print("\n   Data after rollback (should have fewer rows):")
    spark.sql("SELECT COUNT(*) as cnt FROM iceberg.db_examples.orders").show()
    print("\n   Rolling forward to latest snapshot...")
    latest_snapshot_id = snapshots.collect()[-1]["snapshot_id"]
    spark.sql(
        f"CALL iceberg.system.rollback_to_snapshot('iceberg.db_examples.orders', {latest_snapshot_id})"
    )
    print("\n   Data after rolling forward:")
    spark.sql("SELECT COUNT(*) as cnt FROM iceberg.db_examples.orders").show()


def delete_operations(spark: SparkSession) -> None:
    """Demonstrate delete operations."""
    print("\n10. Delete Operations")
    print("   Current orders:")
    spark.sql("SELECT * FROM iceberg.db_examples.orders").show()
    print("\n   Deleting order_id = 1...")
    spark.sql("DELETE FROM iceberg.db_examples.orders WHERE order_id = 1")
    print("\n   After delete:")
    spark.sql("SELECT * FROM iceberg.db_examples.orders").show()
    count = spark.sql("SELECT COUNT(*) as cnt FROM iceberg.db_examples.orders").collect()[0]["cnt"]
    print(f"\n   Total rows: {count}")
