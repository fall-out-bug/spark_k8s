# RAPIDS Plugin JARs Intermediate Layer

## Description
Adds NVIDIA RAPIDS GPU acceleration JARs to custom Spark builds.

## Compatibility

| Spark Version | Scala Version | Image Tag |
|--------------|---------------|-----------|
| 3.5.7 | 2.12 | spark-k8s-jars-rapids:3.5.7 |
| 4.1.0 | 2.13 | spark-k8s-jars-rapids:4.1.0 |

## Base Images

- `localhost/spark-k8s:3.5.7-hadoop3.4.2`
- `localhost/spark-k8s:4.1.0-hadoop3.4.2`

## Build

```bash
cd docker/docker-intermediate/jars-rapids

# Spark 3.5.7 (Scala 2.12)
./build-3.5.7.sh

# Spark 4.1.0 (Scala 2.13)
./build-4.1.0.sh

# Custom RAPIDS version
RAPIDS_VERSION=24.12.0 ./build-3.5.7.sh
```

## Test

```bash
# Test 3.5.7
IMAGE_NAME=spark-k8s-jars-rapids:3.5.7 ./test.sh

# Test 4.1.0
IMAGE_NAME=spark-k8s-jars-rapids:4.1.0 ./test.sh
```

## Usage

### Spark Configuration

```python
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .config("spark.plugins", "com.nvidia.spark.SQLPlugin") \
    .config("spark.rapids.sql.concurrentGpuTasks", "2") \
    .config("spark.rapids.memory.pinnedPool.size", "2G") \
    .getOrCreate()
```

### Spark Submit

```bash
spark-submit \
  --conf spark.plugins=com.nvidia.spark.SQLPlugin \
  --conf spark.rapids.sql.concurrentGpuTasks=2 \
  your_app.py
```

## Versions

| Component | Version |
|-----------|---------|
| RAPIDS | 24.10.0 |
| CUDA | 12 |
| Spark | 3.5.7 / 4.1.0 |

## Environment Variables

| Variable | Description |
|----------|-------------|
| `SPARK_RAPIDS_VERSION` | RAPIDS plugin version (e.g., 24.10.0) |
| `SPARK_RAPIDS_CUDA_VERSION` | CUDA version (e.g., 12) |
| `SPARK_RAPIDS_JAR` | Full path to RAPIDS plugin JAR |
| `SPARK_HOME` | Spark installation directory |

## Official Sources

- [RAPIDS Accelerator for Apache Spark](https://nvidia.github.io/spark-rapids/)
- [Maven Central - RAPIDS](https://repo1.maven.org/maven2/com/nvidia/rapids-4-spark_2.12/)
