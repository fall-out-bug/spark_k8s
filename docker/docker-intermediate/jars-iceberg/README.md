# Apache Iceberg JARs Intermediate Layer

## Description
Adds Apache Iceberg table format support to custom Spark builds.

## Compatibility

| Spark Version | Scala Version | Image Tag |
|--------------|---------------|-----------|
| 3.5.7 | 2.12 | spark-k8s-jars-iceberg:3.5.7 |
| 4.1.0 | 2.13 | spark-k8s-jars-iceberg:4.1.0 |

## Base Images

- `localhost/spark-k8s:3.5.7-hadoop3.4.2`
- `localhost/spark-k8s:4.1.0-hadoop3.4.2`

## Build

```bash
cd docker/docker-intermediate/jars-iceberg

# Spark 3.5.7 (Scala 2.12)
./build-3.5.7.sh

# Spark 4.1.0 (Scala 2.13)
./build-4.1.0.sh

# Custom Iceberg version
ICEBERG_VERSION=1.7.0 ./build-3.5.7.sh
```

## Test

```bash
# Test 3.5.7
IMAGE_NAME=spark-k8s-jars-iceberg:3.5.7 ./test.sh

# Test 4.1.0
IMAGE_NAME=spark-k8s-jars-iceberg:4.1.0 ./test.sh
```

## Usage

### Spark Configuration

```python
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .config("spark.sql.catalog.my_catalog", "org.apache.iceberg.spark.SparkCatalog") \
    .config("spark.sql.catalog.my_catalog.type", "hadoop") \
    .config("spark.sql.catalog.my_catalog.warehouse", "s3a://my-bucket/warehouse") \
    .config("spark.sql.extensions", "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions") \
    .getOrCreate()

# Create Iceberg table
spark.sql("""
    CREATE TABLE my_catalog.my_db.my_table (
        id BIGINT,
        name STRING
    ) USING iceberg
""")
```

### Spark Submit

```bash
spark-submit \
  --conf spark.sql.catalog.my_catalog=org.apache.iceberg.spark.SparkCatalog \
  --conf spark.sql.catalog.my_catalog.type=hadoop \
  --conf spark.sql.catalog.my_catalog.warehouse=s3a://my-bucket/warehouse \
  --conf spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions \
  your_app.py
```

## Versions

| Component | Version |
|-----------|---------|
| Iceberg | 1.6.1 |
| Spark | 3.5.7 / 4.1.0 |

## Environment Variables

| Variable | Description |
|----------|-------------|
| `SPARK_ICEBERG_VERSION` | Iceberg version (e.g., 1.6.1) |
| `SPARK_SQL_CATALOG_IMPLEMENTATION` | Default catalog implementation class |
| `SPARK_SQL_EXTENSIONS` | Spark SQL extensions (Iceberg extensions) |
| `SPARK_HOME` | Spark installation directory |

## Official Sources

- [Apache Iceberg](https://iceberg.apache.org/)
- [Maven Central - Iceberg Spark Runtime](https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-spark-runtime_2.12/)
