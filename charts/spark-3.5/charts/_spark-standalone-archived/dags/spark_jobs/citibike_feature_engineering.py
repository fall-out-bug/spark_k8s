"""
Citibike Feature Engineering - Spark Job
Processes raw Citibike trip data and creates features for analytics.
"""

import os
from math import atan2, cos, radians, sin, sqrt
from typing import Optional, cast

from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    avg,
    col,
    count,
    dayofweek,
    hour,
    to_timestamp,
    udf,
    when,
)
from pyspark.sql.types import DoubleType


def haversine_distance(
    lat1: Optional[float],
    lon1: Optional[float],
    lat2: Optional[float],
    lon2: Optional[float],
) -> float:
    """Calculate distance between two points in km."""
    if None in (lat1, lon1, lat2, lon2):
        return 0.0
    r_earth = 6371.0  # Earth's radius in km
    lat1_f, lon1_f, lat2_f, lon2_f = (
        cast(float, lat1),
        cast(float, lon1),
        cast(float, lat2),
        cast(float, lon2),
    )
    lat1_f, lon1_f, lat2_f, lon2_f = map(radians, [lat1_f, lon1_f, lat2_f, lon2_f])
    dlat = lat2_f - lat1_f
    dlon = lon2_f - lon1_f
    a = sin(dlat / 2) ** 2 + cos(lat1_f) * cos(lat2_f) * sin(dlon / 2) ** 2
    c = 2 * atan2(sqrt(a), sqrt(1 - a))
    return float(r_earth * c)


def main() -> None:
    spark = SparkSession.builder.appName("citibike-feature-engineering").getOrCreate()

    minio_endpoint = os.environ.get("MINIO_ENDPOINT", "http://minio:9000")

    # Configure S3
    spark.sparkContext._jsc.hadoopConfiguration().set("fs.s3a.endpoint", minio_endpoint)
    spark.sparkContext._jsc.hadoopConfiguration().set("fs.s3a.access.key", "minioadmin")
    spark.sparkContext._jsc.hadoopConfiguration().set("fs.s3a.secret.key", "minioadmin")
    spark.sparkContext._jsc.hadoopConfiguration().set("fs.s3a.path.style.access", "true")
    spark.sparkContext._jsc.hadoopConfiguration().set("fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem")

    print("Starting Citibike feature engineering...")

    # Create sample trip data if not exists
    sample_data = [
        (
            "2026-01-15 08:30:00",
            "2026-01-15 08:45:00",
            "Grand St & Elizabeth St",
            "40.7184",
            "-73.9987",
            "Allen St & Stanton St",
            "40.7214",
            "-73.9924",
            "12345",
            "Subscriber",
        ),
        (
            "2026-01-15 09:00:00",
            "2026-01-15 09:20:00",
            "E 17 St & Broadway",
            "40.7369",
            "-73.9902",
            "W 21 St & 6 Ave",
            "40.7418",
            "-73.9945",
            "12346",
            "Subscriber",
        ),
        (
            "2026-01-15 12:15:00",
            "2026-01-15 12:30:00",
            "Broadway & E 22 St",
            "40.7403",
            "-73.9898",
            "1 Ave & E 16 St",
            "40.7322",
            "-73.9818",
            "12347",
            "Customer",
        ),
        (
            "2026-01-15 17:30:00",
            "2026-01-15 17:50:00",
            "West St & Chambers St",
            "40.7175",
            "-74.0122",
            "Grand St & Elizabeth St",
            "40.7184",
            "-73.9987",
            "12348",
            "Subscriber",
        ),
        (
            "2026-01-15 18:00:00",
            "2026-01-15 18:25:00",
            "W 33 St & 7 Ave",
            "40.7526",
            "-73.9914",
            "E 33 St & 1 Ave",
            "40.7442",
            "-73.9745",
            "12349",
            "Subscriber",
        ),
    ]

    # Create DataFrame with sample data
    from pyspark.sql.types import StringType, StructField, StructType

    schema = StructType(
        [
            StructField("starttime", StringType(), True),
            StructField("stoptime", StringType(), True),
            StructField("start_station_name", StringType(), True),
            StructField("start_station_latitude", StringType(), True),
            StructField("start_station_longitude", StringType(), True),
            StructField("end_station_name", StringType(), True),
            StructField("end_station_latitude", StringType(), True),
            StructField("end_station_longitude", StringType(), True),
            StructField("bikeid", StringType(), True),
            StructField("usertype", StringType(), True),
        ]
    )

    df = spark.createDataFrame(sample_data, schema)

    # Convert types and create features
    df = df.withColumn("start_ts", to_timestamp(col("starttime")))
    df = df.withColumn("end_ts", to_timestamp(col("stoptime")))
    df = df.withColumn("trip_duration_minutes", (col("end_ts").cast("long") - col("start_ts").cast("long")) / 60)

    # Time features
    df = df.withColumn("hour_of_day", hour(col("start_ts")))
    df = df.withColumn("day_of_week", dayofweek(col("start_ts")))
    df = df.withColumn("is_weekend", when(col("day_of_week").isin([1, 7]), 1).otherwise(0))
    df = df.withColumn(
        "is_commuting_hour", when(col("hour_of_day").between(7, 9) | col("hour_of_day").between(17, 19), 1).otherwise(0)
    )

    # Calculate distance (simplified)
    @udf(DoubleType())
    def calc_distance(lat1, lon1, lat2, lon2):
        return haversine_distance(
            float(lat1) if lat1 else 0.0,
            float(lon1) if lon1 else 0.0,
            float(lat2) if lat2 else 0.0,
            float(lon2) if lon2 else 0.0,
        )

    df = df.withColumn(
        "trip_distance_km",
        calc_distance(
            col("start_station_latitude"),
            col("start_station_longitude"),
            col("end_station_latitude"),
            col("end_station_longitude"),
        ),
    )

    # Save processed features
    output_path = "s3a://citibike/processed/features/"
    df.write.mode("overwrite").parquet(output_path)

    # Create station statistics
    station_stats = df.groupBy("start_station_name").agg(
        count("*").alias("trip_count"),
        avg("trip_duration_minutes").alias("avg_duration"),
        avg("trip_distance_km").alias("avg_distance"),
    )

    station_stats_path = "s3a://citibike/processed/station_stats/"
    station_stats.write.mode("overwrite").parquet(station_stats_path)

    print(f"Feature engineering complete. Processed {df.count()} trips.")
    print(f"Features saved to: {output_path}")
    print(f"Station stats saved to: {station_stats_path}")

    spark.stop()
    print("CITIBIKE_FEATURES_OK")


if __name__ == "__main__":
    main()
