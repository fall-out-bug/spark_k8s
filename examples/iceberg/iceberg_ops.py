"""Iceberg operations - setup, create, insert, time travel, schema evolution."""

from pyspark.sql import SparkSession
from pyspark.sql.functions import col


def setup_database(spark: SparkSession) -> None:
    """Create database and setup environment."""
    print("\n1. Setting up Iceberg database...")
    spark.sql("CREATE DATABASE IF NOT EXISTS iceberg.db_examples")
    spark.sql("USE iceberg.db_examples")
    print("   Database 'iceberg.db_examples' created")


def create_iceberg_table(spark: SparkSession) -> None:
    """Create Iceberg table with initial schema."""
    print("\n2. Creating Iceberg table...")
    spark.sql("DROP TABLE IF EXISTS iceberg.db_examples.orders")
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
    spark.sql("DESCRIBE EXTENDED iceberg.db_examples.orders").show(truncate=False)


def insert_initial_data(spark: SparkSession) -> None:
    """Insert initial data into Iceberg table."""
    print("\n3. Inserting initial data...")
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
    df = df.withColumn(
        "order_timestamp",
        col("order_timestamp_str").cast("timestamp")
    ).drop("order_timestamp_str")
    df.writeTo("iceberg.db_examples.orders").append()
    count = spark.sql("SELECT COUNT(*) as cnt FROM iceberg.db_examples.orders").collect()[0]["cnt"]
    print(f"   Inserted {count} rows")


def time_travel_example(spark: SparkSession) -> None:
    """Demonstrate time travel feature."""
    print("\n4. Time Travel Example")
    print("   Creating snapshot 1...")
    snapshot1 = spark.sql(
        "SELECT snapshot_id FROM iceberg.db_examples.orders.snapshots"
    ).collect()[0]["snapshot_id"]
    print(f"   Snapshot 1 ID: {snapshot1}")
    print("\n   Current data:")
    spark.sql("SELECT * FROM iceberg.db_examples.orders").show()
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
    snapshot2 = spark.sql(
        "SELECT snapshot_id FROM iceberg.db_examples.orders.snapshots"
    ).orderBy("committed_at", ascending=False).limit(1).collect()[0]["snapshot_id"]
    print(f"   Snapshot 2 ID: {snapshot2}")
    print("\n   Latest data (7 rows):")
    spark.sql("SELECT * FROM iceberg.db_examples.orders").show()
    print(f"\n   Time travel to snapshot 1 (5 rows):")
    spark.sql(
        f"SELECT * FROM iceberg.db_examples.orders VERSION AS OF {snapshot1}"
    ).show()
    print("\n   List all snapshots:")
    spark.sql(
        "SELECT snapshot_id, committed_at, summary FROM iceberg.db_examples.orders.snapshots"
    ).show(truncate=False)


def schema_evolution_add_column(spark: SparkSession) -> None:
    """Demonstrate schema evolution - adding a column."""
    print("\n5. Schema Evolution - Add Column")
    print("   Current schema:")
    spark.sql("DESCRIBE iceberg.db_examples.orders").select("col_name", "data_type").show(truncate=False)
    print("\n   Adding 'discount' column...")
    spark.sql("ALTER TABLE iceberg.db_examples.orders ADD COLUMN discount DOUBLE")
    spark.sql("UPDATE iceberg.db_examples.orders SET discount = 0.0 WHERE discount IS NULL")
    print("\n   New schema:")
    spark.sql("DESCRIBE iceberg.db_examples.orders").select("col_name", "data_type").show(truncate=False)
    print("\n   Data with new column (default 0.0):")
    spark.sql("SELECT * FROM iceberg.db_examples.orders").show()


def schema_evolution_change_type(spark: SparkSession) -> None:
    """Demonstrate schema evolution - changing column type."""
    print("\n6. Schema Evolution - Change Column Type")
    print("   Changing quantity from INT to BIGINT...")
    spark.sql("ALTER TABLE iceberg.db_examples.orders ALTER COLUMN quantity TYPE BIGINT")
    print("\n   Updated schema:")
    spark.sql("DESCRIBE iceberg.db_examples.orders").filter("col_name == 'quantity'").select("col_name", "data_type").show(truncate=False)


def schema_evolution_rename_column(spark: SparkSession) -> None:
    """Demonstrate schema evolution - renaming a column."""
    print("\n7. Schema Evolution - Rename Column")
    print("   Renaming 'price' to 'unit_price'...")
    spark.sql("ALTER TABLE iceberg.db_examples.orders RENAME COLUMN price TO unit_price")
    print("\n   Updated schema:")
    spark.sql("DESCRIBE iceberg.db_examples.orders").filter("col_name IN ('price', 'unit_price')").select("col_name", "data_type").show(truncate=False)


def partition_evolution(spark: SparkSession) -> None:
    """Demonstrate partition evolution."""
    print("\n8. Partition Evolution")
    print("   Current partitions:")
    spark.sql("DESCRIBE EXTENDED iceberg.db_examples.orders PARTITIONED BY").show(truncate=False)
    print("\n   Adding partition on customer_id...")
    spark.sql("ALTER TABLE iceberg.db_examples.orders ADD PARTITION FIELD customer_id")
    print("\n   Updated partitions:")
    spark.sql("DESCRIBE EXTENDED iceberg.db_examples.orders PARTITIONED BY").show(truncate=False)
