#!/usr/bin/env python3
"""
Apache Iceberg Examples for Spark on Kubernetes

This notebook demonstrates Apache Iceberg features:
- ACID transactions
- Time travel (snapshot queries)
- Schema evolution
- Rollback procedures
- Partition evolution

Prerequisites:
- Iceberg-enabled Spark cluster (use presets/iceberg-values.yaml)
- S3 or compatible storage
- Hive Metastore with Iceberg support
"""

from pyspark.sql import SparkSession
from pyspark.sql.functions import col, current_timestamp, lit
import time

# Initialize Spark Session with Iceberg
spark = SparkSession.builder \
    .appName("Iceberg Examples") \
    .config("spark.sql.extensions", "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions") \
    .config("spark.sql.catalog.spark_catalog", "org.apache.iceberg.spark.SparkSessionCatalog") \
    .config("spark.sql.catalog.spark_catalog.type", "hadoop") \
    .config("spark.sql.catalog.iceberg", "org.apache.iceberg.spark.SparkCatalog") \
    .config("spark.sql.catalog.iceberg.type", "hadoop") \
    .config("spark.sql.catalog.iceberg.warehouse", "s3a://warehouse/iceberg") \
    .getOrCreate()

print("=" * 80)
print("Apache Iceberg Examples")
print("=" * 80)
print(f"\nSpark Version: {spark.version}")
print(f"Iceberg Catalog: iceberg")
print(f"Warehouse: s3a://warehouse/iceberg")
print("\n" + "=" * 80)


def setup_database():
    """Create database and setup environment."""
    print("\n1. Setting up Iceberg database...")

    # Create database
    spark.sql("CREATE DATABASE IF NOT EXISTS iceberg.db_examples")
    spark.sql("USE iceberg.db_examples")

    print("   Database 'iceberg.db_examples' created")


def create_iceberg_table():
    """
    Create an Iceberg table with initial schema.

    Iceberg supports ACID transactions, schema evolution, and time travel.
    """
    print("\n2. Creating Iceberg table...")

    # Drop table if exists
    spark.sql("DROP TABLE IF EXISTS iceberg.db_examples.orders")

    # Create Iceberg table
    spark.sql("""
        CREATE TABLE iceberg.db_examples.orders (
            order_id BIGINT,
            customer_id BIGINT,
            product_id BIGINT,
            quantity INT,
            price DOUBLE,
            order_timestamp TIMESTAMP
        ) USING iceberg
        PARTITIONED BY (days(order_timestamp))
        LOCATION 's3a://warehouse/iceberg/db_examples/orders'
    """)

    print("   Table 'orders' created with partitioning on order_timestamp")

    # Describe table
    print("\n   Table schema:")
    spark.sql("DESCRIBE EXTENDED iceberg.db_examples.orders").show(truncate=False)


def insert_initial_data():
    """Insert initial data into Iceberg table."""
    print("\n3. Inserting initial data...")

    # Create sample data
    data = [
        (1, 100, 1000, 2, 99.99, "2024-01-01 10:00:00"),
        (2, 101, 1001, 1, 149.99, "2024-01-01 11:00:00"),
        (3, 100, 1002, 3, 49.99, "2024-01-02 09:00:00"),
        (4, 102, 1000, 1, 99.99, "2024-01-02 14:00:00"),
        (5, 103, 1003, 2, 199.99, "2024-01-03 16:00:00"),
    ]

    df = spark.createDataFrame(data, [
        "order_id", "customer_id", "product_id",
        "quantity", "price", "order_timestamp_str"
    ])

    # Convert string to timestamp
    df = df.withColumn(
        "order_timestamp",
        col("order_timestamp_str").cast("timestamp")
    ).drop("order_timestamp_str")

    # Write to Iceberg table
    df.writeTo("iceberg.db_examples.orders").append()

    count = spark.sql("SELECT COUNT(*) as cnt FROM iceberg.db_examples.orders").collect()[0]["cnt"]
    print(f"   Inserted {count} rows")


def time_travel_example():
    """
    Demonstrate time travel feature.

    Iceberg snapshots allow querying historical data.
    """
    print("\n4. Time Travel Example")
    print("   Creating snapshot 1...")

    # Get current snapshot
    snapshot1 = spark.sql(
        "SELECT snapshot_id FROM iceberg.db_examples.orders.snapshots"
    ).collect()[0]["snapshot_id"]

    print(f"   Snapshot 1 ID: {snapshot1}")

    # Query current data
    print("\n   Current data:")
    spark.sql("SELECT * FROM iceberg.db_examples.orders").show()

    # Add more data (create new snapshot)
    print("\n   Adding more data for snapshot 2...")
    new_data = [
        (6, 104, 1004, 1, 79.99, "2024-01-04 10:00:00"),
        (7, 105, 1005, 2, 129.99, "2024-01-04 15:00:00"),
    ]

    df = spark.createDataFrame(new_data, [
        "order_id", "customer_id", "product_id",
        "quantity", "price", "order_timestamp_str"
    ])

    df = df.withColumn(
        "order_timestamp",
        col("order_timestamp_str").cast("timestamp")
    ).drop("order_timestamp_str")

    df.writeTo("iceberg.db_examples.orders").append()

    # Get new snapshot
    snapshot2 = spark.sql(
        "SELECT snapshot_id FROM iceberg.db_examples.orders.snapshots"
    ).orderBy("committed_at", ascending=False).limit(1).collect()[0]["snapshot_id"]

    print(f"   Snapshot 2 ID: {snapshot2}")

    # Query latest data
    print("\n   Latest data (7 rows):")
    spark.sql("SELECT * FROM iceberg.db_examples.orders").show()

    # Query using snapshot ID (time travel)
    print(f"\n   Time travel to snapshot 1 (5 rows):")
    spark.sql(
        f"SELECT * FROM iceberg.db_examples.orders VERSION AS OF {snapshot1}"
    ).show()

    # Query using timestamp
    print("\n   List all snapshots:")
    spark.sql(
        "SELECT snapshot_id, committed_at, summary FROM iceberg.db_examples.orders.snapshots"
    ).show(truncate=False)


def schema_evolution_add_column():
    """
    Demonstrate schema evolution - adding a column.

    Iceberg supports schema evolution without breaking existing queries.
    """
    print("\n5. Schema Evolution - Add Column")

    # Current schema
    print("   Current schema:")
    spark.sql("DESCRIBE iceberg.db_examples.orders").select(
        "col_name", "data_type"
    ).show(truncate=False)

    # Add new column
    print("\n   Adding 'discount' column...")
    spark.sql(
        "ALTER TABLE iceberg.db_examples.orders ADD COLUMN discount DOUBLE"
    )

    # Update new column for existing rows
    spark.sql(
        "UPDATE iceberg.db_examples.orders SET discount = 0.0 WHERE discount IS NULL"
    )

    # New schema
    print("\n   New schema:")
    spark.sql("DESCRIBE iceberg.db_examples.orders").select(
        "col_name", "data_type"
    ).show(truncate=False)

    # Query with new column
    print("\n   Data with new column (default 0.0):")
    spark.sql("SELECT * FROM iceberg.db_examples.orders").show()


def schema_evolution_change_type():
    """
    Demonstrate schema evolution - changing column type.

    Iceberg supports safe type changes (e.g., INT -> BIGINT).
    """
    print("\n6. Schema Evolution - Change Column Type")

    # Change quantity from INT to BIGINT
    print("   Changing quantity from INT to BIGINT...")
    spark.sql(
        "ALTER TABLE iceberg.db_examples.orders ALTER COLUMN quantity TYPE BIGINT"
    )

    # Verify change
    print("\n   Updated schema:")
    spark.sql(
        "DESCRIBE iceberg.db_examples.orders"
    ).filter("col_name == 'quantity'").select("col_name", "data_type").show(truncate=False)


def schema_evolution_rename_column():
    """
    Demonstrate schema evolution - renaming a column.
    """
    print("\n7. Schema Evolution - Rename Column")

    # Rename column
    print("   Renaming 'price' to 'unit_price'...")
    spark.sql(
        "ALTER TABLE iceberg.db_examples.orders RENAME COLUMN price TO unit_price"
    )

    # Verify change
    print("\n   Updated schema:")
    spark.sql(
        "DESCRIBE iceberg.db_examples.orders"
    ).filter("col_name IN ('price', 'unit_price')").select(
        "col_name", "data_type"
    ).show(truncate=False)


def partition_evolution():
    """
    Demonstrate partition evolution.

    Iceberg allows changing partitioning without rewriting data.
    """
    print("\n8. Partition Evolution")

    # Current partitions
    print("   Current partitions:")
    spark.sql("DESCRIBE EXTENDED iceberg.db_examples.orders PARTITIONED BY").show(
        truncate=False
    )

    # Add new partition
    print("\n   Adding partition on customer_id...")
    spark.sql(
        "ALTER TABLE iceberg.db_examples.orders ADD PARTITION FIELD customer_id"
    )

    # New partitions
    print("\n   Updated partitions:")
    spark.sql("DESCRIBE EXTENDED iceberg.db_examples.orders PARTITIONED BY").show(
        truncate=False
    )


def rollback_procedures():
    """
    Demonstrate rollback procedures.

    Iceberg supports rolling back to previous snapshots.
    """
    print("\n9. Rollback Procedures")

    # List all snapshots
    print("   Available snapshots:")
    snapshots = spark.sql(
        "SELECT snapshot_id, committed_at, summary FROM iceberg.db_examples.orders.snapshots"
        " ORDER BY committed_at"
    )
    snapshots.show(truncate=False)

    # Get first snapshot
    first_snapshot_id = snapshots.collect()[0]["snapshot_id"]

    print(f"\n   Rolling back to snapshot {first_snapshot_id}...")

    # Rollback using ALTER TABLE
    spark.sql(
        f"CALL iceberg.system.rollback_to_snapshot('iceberg.db_examples.orders', {first_snapshot_id})"
    )

    # Verify rollback
    print("\n   Data after rollback (should have fewer rows):")
    result = spark.sql("SELECT COUNT(*) as cnt FROM iceberg.db_examples.orders")
    result.show()

    # Rollback forward to latest
    print("\n   Rolling forward to latest snapshot...")
    latest_snapshot_id = snapshots.collect()[-1]["snapshot_id"]
    spark.sql(
        f"CALL iceberg.system.rollback_to_snapshot('iceberg.db_examples.orders', {latest_snapshot_id})"
    )

    print("\n   Data after rolling forward:")
    result = spark.sql("SELECT COUNT(*) as cnt FROM iceberg.db_examples.orders")
    result.show()


def delete_operations():
    """
    Demonstrate delete operations (Iceberg supports row-level deletes).
    """
    print("\n10. Delete Operations")

    # Show current data
    print("   Current orders:")
    spark.sql("SELECT * FROM iceberg.db_examples.orders").show()

    # Delete specific rows
    print("\n   Deleting order_id = 1...")
    spark.sql("DELETE FROM iceberg.db_examples.orders WHERE order_id = 1")

    # Verify delete
    print("\n   After delete:")
    spark.sql("SELECT * FROM iceberg.db_examples.orders").show()

    # Count rows
    count = spark.sql("SELECT COUNT(*) as cnt FROM iceberg.db_examples.orders").collect()[0]["cnt"]
    print(f"\n   Total rows: {count}")


def main():
    """Main execution flow."""
    print("\n" + "=" * 80)
    print("Starting Iceberg Examples Demo")
    print("=" * 80)

    # Setup
    setup_database()

    # Create table
    create_iceberg_table()

    # Insert initial data
    insert_initial_data()

    # Time travel
    time_travel_example()

    # Schema evolution
    schema_evolution_add_column()
    schema_evolution_change_type()
    schema_evolution_rename_column()

    # Partition evolution
    partition_evolution()

    # Rollback procedures
    rollback_procedures()

    # Delete operations
    delete_operations()

    print("\n" + "=" * 80)
    print("Iceberg Examples Demo Complete!")
    print("=" * 80)
    print("\nKey Takeaways:")
    print("- ACID transactions: INSERT, UPDATE, DELETE supported")
    print("- Time travel: Query historical snapshots")
    print("- Schema evolution: Add/modify columns without breaking queries")
    print("- Partition evolution: Change partitioning strategy")
    print("- Rollback: Restore previous snapshots")
    print("=" * 80)


if __name__ == "__main__":
    main()
