# Examples Catalog

==================

Production-ready examples for Apache Spark on Kubernetes.

## Directory Structure

```
charts/spark-3.5/examples/
├── batch/              # Batch processing examples
│   ├── __init__.py
│   ├── etl_pipeline.py      # Complete ETL with extract, transform, load
│   └── data_quality.py     # Data quality validation framework
├── ml/                 # Machine learning examples
│   ├── __init__.py
│   ├── classification_catboost.py  # Binary classification with CatBoost/MLlib
│   └── regression_spark_ml.py  # Regression with Spark MLlib
└── streaming/         # Structured streaming examples
    ├── __init__.py
    ├── file_stream_basic.py     # Rate source, windowed aggregations
    ├── kafka_stream_backpressure.py  # Kafka with backpressure
    └── kafka_exactly_once.py   # Exactly-once semantics
```

## Quick Start

### Run Batch ETL Example
```bash
spark-submit --master spark://master:7077 \
    examples/batch/etl_pipeline.py
```

### Run ML Classification Example
```bash
spark-submit --master spark://master:7077 \
    examples/ml/classification_catboost.py
```

### Run Streaming Example (local)
```bash
spark-submit --master spark://master:7077 \
    examples/streaming/file_stream_basic.py
```

### Run Streaming Example (Kafka)
```bash
spark-submit --master spark://master:7077 \
    --conf spark.kafka.bootstrap.servers="kafka:9092" \
    examples/streaming/kafka_stream_backpressure.py
```

## Testing
```bash
./scripts/test-examples.sh
```

## Supported Spark Versions
- Spark 3.5.7 / 3.5.8
- Spark 4.1.0 / 4.1.1

## Requirements
- Kubernetes 1.24+
- Helm 3.x
- Prometheus Operator (optional, for alerts)
- Grafana Operator (optional, for dashboards)
