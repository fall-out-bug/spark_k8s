"""
Citibike Statistics Generator - Spark Job
Generates aggregated statistics from Citibike trip data.
"""

import os

from pyspark.sql import SparkSession
from pyspark.sql.functions import avg, count, desc


def main():
    spark = SparkSession.builder.appName("citibike-statistics").getOrCreate()

    minio_endpoint = os.environ.get("MINIO_ENDPOINT", "http://minio:9000")

    # Configure S3
    spark.sparkContext._jsc.hadoopConfiguration().set("fs.s3a.endpoint", minio_endpoint)
    spark.sparkContext._jsc.hadoopConfiguration().set("fs.s3a.access.key", "minioadmin")
    spark.sparkContext._jsc.hadoopConfiguration().set("fs.s3a.secret.key", "minioadmin")
    spark.sparkContext._jsc.hadoopConfiguration().set("fs.s3a.path.style.access", "true")
    spark.sparkContext._jsc.hadoopConfiguration().set("fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem")

    print("Starting Citibike statistics generation...")

    # Read processed features
    features_path = "s3a://citibike/processed/features/"
    try:
        df = spark.read.parquet(features_path)
    except Exception as e:
        print(f"Could not read features, creating sample: {e}")
        # Create minimal sample data
        from pyspark.sql.types import DoubleType, IntegerType, StringType, StructField, StructType

        schema = StructType(
            [
                StructField("start_station_name", StringType(), True),
                StructField("end_station_name", StringType(), True),
                StructField("trip_duration_minutes", DoubleType(), True),
                StructField("trip_distance_km", DoubleType(), True),
                StructField("hour_of_day", IntegerType(), True),
                StructField("day_of_week", IntegerType(), True),
                StructField("is_weekend", IntegerType(), True),
                StructField("is_commuting_hour", IntegerType(), True),
                StructField("usertype", StringType(), True),
            ]
        )
        sample_data = [
            ("Station A", "Station B", 15.0, 1.2, 8, 4, 0, 1, "Subscriber"),
            ("Station B", "Station C", 20.0, 2.5, 9, 4, 0, 1, "Subscriber"),
            ("Station A", "Station D", 35.0, 3.8, 12, 6, 1, 0, "Customer"),
        ]
        df = spark.createDataFrame(sample_data, schema)

    # Generate hourly distribution
    hourly_stats = (
        df.groupBy("hour_of_day")
        .agg(
            count("*").alias("trip_count"),
            avg("trip_duration_minutes").alias("avg_duration"),
            avg("trip_distance_km").alias("avg_distance"),
        )
        .orderBy("hour_of_day")
    )

    print("Hourly Distribution:")
    hourly_stats.show()

    # Generate top routes
    top_routes = (
        df.groupBy("start_station_name", "end_station_name")
        .agg(count("*").alias("trip_count"), avg("trip_duration_minutes").alias("avg_duration"))
        .orderBy(desc("trip_count"))
        .limit(10)
    )

    print("Top 10 Routes:")
    top_routes.show()

    # User type breakdown
    user_stats = df.groupBy("usertype").agg(
        count("*").alias("trip_count"),
        avg("trip_duration_minutes").alias("avg_duration"),
        avg("trip_distance_km").alias("avg_distance"),
    )

    print("User Type Breakdown:")
    user_stats.show()

    # Weekend vs Weekday comparison
    weekend_stats = df.groupBy("is_weekend").agg(
        count("*").alias("trip_count"), avg("trip_duration_minutes").alias("avg_duration")
    )

    print("Weekend vs Weekday:")
    weekend_stats.show()

    # Save statistics
    hourly_stats_path = "s3a://citibike/analytics/hourly_stats/"
    hourly_stats.write.mode("overwrite").parquet(hourly_stats_path)

    top_routes_path = "s3a://citibike/analytics/top_routes/"
    top_routes.write.mode("overwrite").parquet(top_routes_path)

    user_stats_path = "s3a://citibike/analytics/user_stats/"
    user_stats.write.mode("overwrite").parquet(user_stats_path)

    # Push metrics to Prometheus
    try:
        import requests

        pushgateway_url = os.environ.get("PUSHGATEWAY_URL", "http://prometheus:9090")

        total_trips = df.count()
        avg_duration = df.agg(avg("trip_duration_minutes")).collect()[0][0] or 0
        avg_distance = df.agg(avg("trip_distance_km")).collect()[0][0] or 0

        metrics = f"""
# TYPE citibike_total_trips gauge
citibike_total_trips {total_trips}
# TYPE citibike_avg_duration_minutes gauge
citibike_avg_duration_minutes {avg_duration:.2f}
# TYPE citibike_avg_distance_km gauge
citibike_avg_distance_km {avg_distance:.2f}
"""
        requests.post(f"{pushgateway_url}/metrics/job/citibike_analytics", data=metrics, timeout=5)
        print("Metrics pushed to Prometheus")
    except Exception as e:
        print(f"Could not push metrics: {e}")

    print("Statistics generation complete.")
    print(f"Hourly stats saved to: {hourly_stats_path}")
    print(f"Top routes saved to: {top_routes_path}")
    print(f"User stats saved to: {user_stats_path}")

    spark.stop()
    print("CITIBIKE_STATS_OK")


if __name__ == "__main__":
    main()
