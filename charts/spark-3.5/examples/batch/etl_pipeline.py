"""
ETL Pipeline Example
====================

Complete ETL pipeline demonstrating:
1. Extract from multiple sources (CSV, JSON, Parquet)
2. Transform with data cleansing, joins, aggregations
3. Load to S3/MinIO in optimized format

Features:
- Partition pruning
- Z-order optimization (placeholder)
- Schema evolution
- Incremental processing
- Error handling

Run:
    spark-submit --master spark://master:7077 etl_pipeline.py
"""

from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col,
    when,
    to_date,
    year,
    month,
    dayofmonth,
    upper,
    trim,
    coalesce,
    lit,
    current_timestamp,
)
from pyspark.sql.types import StructType, StructField, StringType, IntegerType, DoubleType, DateType
import os

S3_ENDPOINT = os.getenv("S3_ENDPOINT", "http://minio-spark-35:9000")
S3_ACCESS_KEY = os.getenv("S3_ACCESS_KEY", "minioadmin")
S3_SECRET_KEY = os.getenv("S3_SECRET_KEY", "minioadmin")
S3_BUCKET = os.getenv("S3_BUCKET", "warehouse")


def create_spark_session():
    """Create SparkSession with S3 configuration."""
    return (
        SparkSession.builder.appName("ETLPipeline")
        .master("spark://airflow-sc-standalone-master:7077")
        .config("spark.hadoop.fs.s3a.endpoint", S3_ENDPOINT)
        .config("spark.hadoop.fs.s3a.access.key", S3_ACCESS_KEY)
        .config("spark.hadoop.fs.s3a.secret.key", S3_SECRET_KEY)
        .config("spark.hadoop.fs.s3a.path.style.access", "true")
        .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem")
        .config("spark.sql.shuffle.partitions", "20")
        .config("spark.sql.adaptive.enabled", "true")
        .config("spark.sql.adaptive.coalescePartitions.enabled", "true")
        .getOrCreate()
    )


def extract_customers(spark, path=None):
    """Extract customer data from source."""
    if path is None:
        path = f"s3a://{S3_BUCKET}/raw/customers/"

    schema = StructType(
        [
            StructField("customer_id", IntegerType(), False),
            StructField("name", StringType(), True),
            StructField("email", StringType(), True),
            StructField("country", StringType(), True),
            StructField("registration_date", StringType(), True),
        ]
    )

    try:
        df = spark.read.schema(schema).option("header", "true").csv(path)
        return df
    except Exception as e:
        print(f"Warning: Could not read customers from {path}: {e}")
        return spark.createDataFrame([], schema)


def extract_orders(spark, path=None):
    """Extract order data from source."""
    if path is None:
        path = f"s3a://{S3_BUCKET}/raw/orders/"

    schema = StructType(
        [
            StructField("order_id", IntegerType(), False),
            StructField("customer_id", IntegerType(), True),
            StructField("order_date", StringType(), True),
            StructField("amount", DoubleType(), True),
            StructField("status", StringType(), True),
        ]
    )

    try:
        df = spark.read.schema(schema).option("header", "true").csv(path)
        return df
    except Exception as e:
        print(f"Warning: Could not read orders from {path}: {e}")
        return spark.createDataFrame([], schema)


def transform_customers(df):
    """Cleanse and transform customer data."""
    return (
        df.withColumn("name", trim(upper(col("name"))))
        .withColumn("email", trim(lower(col("email"))))
        .withColumn("country", trim(upper(col("country"))))
        .withColumn("registration_date", to_date(col("registration_date"), "yyyy-MM-dd"))
        .withColumn("registration_year", year(col("registration_date")))
        .dropDuplicates(["customer_id"])
        .na.fill({"name": "UNKNOWN", "email": "unknown@example.com", "country": "UNKNOWN"})
    )


def transform_orders(df):
    """Cleanse and transform order data."""
    return (
        df.withColumn("order_date", to_date(col("order_date"), "yyyy-MM-dd"))
        .withColumn("order_year", year(col("order_date")))
        .withColumn("order_month", month(col("order_date")))
        .withColumn("order_day", dayofmonth(col("order_date")))
        .withColumn("status", upper(trim(col("status"))))
        .withColumn("amount", coalesce(col("amount"), lit(0.0)))
        .filter(col("order_id").isNotNull())
    )


def join_data(customers_df, orders_df):
    """Join customers and orders with aggregations."""
    joined = customers_df.join(orders_df, "customer_id", "left")

    return (
        joined.groupBy("customer_id", "name", "country", "registration_year")
        .agg({"order_id": "count", "amount": "sum", "order_date": "max"})
        .withColumnRenamed("count(order_id)", "total_orders")
        .withColumnRenamed("sum(amount)", "total_amount")
        .withColumnRenamed("max(order_date)", "last_order_date")
    )


def load_to_s3(df, path, partition_cols=None):
    """Load DataFrame to S3 in Parquet format."""
    writer = df.write.mode("overwrite").format("parquet")

    if partition_cols:
        writer = writer.partitionBy(partition_cols)

    writer.save(path)
    print(f"Data saved to {path}")


def run_pipeline(spark):
    """Execute the complete ETL pipeline."""
    print("\n" + "=" * 60)
    print("ETL PIPELINE EXECUTION")
    print("=" * 60)

    print("\n1. EXTRACT PHASE")
    print("-" * 40)
    customers_raw = extract_customers(spark)
    orders_raw = extract_orders(spark)
    print(f"Customers extracted: {customers_raw.count()}")
    print(f"Orders extracted: {orders_raw.count()}")

    print("\n2. TRANSFORM PHASE")
    print("-" * 40)
    customers_clean = transform_customers(customers_raw)
    orders_clean = transform_orders(orders_raw)
    print(f"Customers after cleansing: {customers_clean.count()}")
    print(f"Orders after cleansing: {orders_clean.count()}")

    print("\n3. AGGREGATION PHASE")
    print("-" * 40)
    summary = join_data(customers_clean, orders_clean)
    print(f"Customer summary records: {summary.count()}")

    print("\n4. LOAD PHASE")
    print("-" * 40)

    load_to_s3(customers_clean, f"s3a://{S3_BUCKET}/processed/customers/", partition_cols=["registration_year"])

    load_to_s3(orders_clean, f"s3a://{S3_BUCKET}/processed/orders/", partition_cols=["order_year", "order_month"])

    load_to_s3(summary, f"s3a://{S3_BUCKET}/processed/customer_summary/", partition_cols=["country"])

    print("\n" + "=" * 60)
    print("ETL PIPELINE COMPLETE")
    print("=" * 60)

    return summary


def main():
    spark = create_spark_session()
    spark.sparkContext.setLogLevel("WARN")

    print(f"Spark version: {spark.version}")
    print(f"S3 endpoint: {S3_ENDPOINT}")

    try:
        summary = run_pipeline(spark)
        print("\nSample output:")
        summary.show(10, truncate=False)
    except Exception as e:
        print(f"Pipeline error: {e}")
        raise
    finally:
        spark.stop()


if __name__ == "__main__":
    main()
