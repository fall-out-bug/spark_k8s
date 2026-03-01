"""
Batch Examples Catalog
======================

Batch processing examples for Apache Spark on Kubernetes.

Available Examples:
1. etl_pipeline.py - ETL pipeline with S3/MinIO
2. data_quality.py - Data quality checks and validation
3. partition_optimization.py - Partition pruning and optimization
4. parquet_to_delta.py - Convert Parquet to Delta Lake format

Usage:
    spark-submit --master spark://master:7077 etl_pipeline.py
"""

__all__ = ["etl_pipeline", "data_quality", "partition_optimization", "parquet_to_delta"]
