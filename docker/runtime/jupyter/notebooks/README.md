# Jupyter Notebooks for Spark

This directory contains example notebooks for working with Spark.

## Getting Started

1. Start JupyterLab:
   ```bash
   docker run -p 8888:8888 spark-k8s-jupyter:3.5-3.5.7-baseline
   ```

2. Open your browser to `http://localhost:8888`

3. Create a new notebook and run:
   ```python
   from pyspark.sql import SparkSession
   spark = SparkSession.builder.getOrCreate()
   df = spark.createDataFrame([(1, "a"), (2, "b")], ["id", "value"])
   df.show()
   ```

## Available Spark Runtime Images

### Spark 3.5
- `spark-k8s-jupyter:3.5-3.5.7-baseline`
- `spark-k8s-jupyter:3.5-3.5.7-gpu`
- `spark-k8s-jupyter:3.5-3.5.7-iceberg`
- `spark-k8s-jupyter:3.5-3.5.7-gpu-iceberg`

### Spark 4.1
- `spark-k8s-jupyter:4.1-4.1.0-baseline`
- `spark-k8s-jupyter:4.1-4.1.0-gpu`
- `spark-k8s-jupyter:4.1-4.1.0-iceberg`
- `spark-k8s-jupyter:4.1-4.1.0-gpu-iceberg`
