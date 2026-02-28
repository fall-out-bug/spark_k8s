"""
Structured Streaming Examples Catalog
======================================

This module demonstrates various streaming patterns for Apache Spark on Kubernetes.
Each example is self-contained and can be run independently.

Available Examples:
1. file_stream_basic.py - Basic file-based streaming (no Kafka required)
2. kafka_stream_backpressure.py - Kafka streaming with backpressure
3. kafka_exactly_once.py - Exactly-once processing with Kafka
4. stream_join.py - Stream-to-stream and stream-to-batch joins
5. stream_aggregation.py - Windowed aggregations and watermarking

Usage:
    spark-submit --master spark://master:7077 file_stream_basic.py
"""

# Re-export examples for convenience
# from file_stream_basic import main as file_stream_basic
# from kafka_stream_backpressure import main as kafka_stream_backpressure
# from kafka_exactly_once import main as kafka_exactly_once

__all__ = ["file_stream_basic", "kafka_stream_backpressure", "kafka_exactly_once", "stream_join", "stream_aggregation"]
