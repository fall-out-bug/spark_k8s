# Apache Iceberg JARs Intermediate Layer

Docker intermediate layer that adds Apache Iceberg table format JARs to Apache Spark images.

## Overview

This layer provides:
- Apache Iceberg Spark Runtime (version 1.6.1)
- Iceberg AWS Bundle for S3 catalog support
- Pre-configured for Iceberg table operations

## Spark Version Compatibility

| Spark Version | Scala Version | Iceberg Version | Status |
|---------------|---------------|-----------------|--------|
| 3.5.7         | 2.12          | 1.6.1           | Tested |
| 3.5.8         | 2.12          | 1.6.1           | Compatible |
| 4.1.0         | 2.13          | 1.6.1           | Compatible (use scala 2.13 build) |
| 4.1.1         | 2.13          | 1.6.1           | Compatible (use scala 2.13 build) |

## Build

### Build for Spark 3.5.7 (default)

```bash
cd docker/docker-intermediate/jars-iceberg
docker build -t spark-k8s-jars-iceberg:latest .
```

### Build for different Spark versions

```bash
# Spark 3.5.8
docker build \
    --build-arg BASE_IMAGE=apache/spark:3.5.8-scala2.12-java17-ubuntu \
    --build-arg ICEBERG_VERSION=1.6.1 \
    -t spark-k8s-jars-iceberg:3.5.8 \
    .

# Spark 4.1.0 (Scala 2.13)
docker build \
    --build-arg BASE_IMAGE=apache/spark:4.1.0-scala2.13-java17-ubuntu \
    --build-arg ICEBERG_VERSION=1.6.1 \
    --build-arg SCALA_VERSION=2.13 \
    -t spark-k8s-jars-iceberg:4.1.0 \
    .
```

### Build and test

```bash
./test.sh
```

## Testing

Run tests manually:

```bash
# Using default image name
../../test-jars.sh iceberg

# Using custom image name
../../test-jars.sh iceberg my-iceberg-jars:latest
```

### Test Coverage

The test script verifies:
1. Image builds successfully
2. SPARK_HOME is set correctly
3. JARs directory exists
4. Iceberg runtime JAR is present
5. Iceberg AWS bundle JAR is present (optional)
6. JAR files are valid archives
7. Environment variables are set
8. Image size is under limit (200MB)

## Usage

### As base image

```dockerfile
FROM spark-k8s-jars-iceberg:latest

# Add your application-specific configurations
```

### In Spark Configuration

When submitting Spark jobs with Iceberg:

```bash
spark-submit \
    --conf spark.sql.catalog.my_catalog=org.apache.iceberg.spark.SparkCatalog \
    --conf spark.sql.catalog.my_catalog.type=hadoop \
    --conf spark.sql.catalog.my_catalog.warehouse=s3a://my-bucket/warehouse \
    --conf spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions \
    ...
```

### Catalog Configuration Examples

#### Hadoop Catalog (S3)

```bash
--conf spark.sql.catalog.my_catalog=org.apache.iceberg.spark.SparkCatalog \
--conf spark.sql.catalog.my_catalog.type=hadoop \
--conf spark.sql.catalog.my_catalog.warehouse=s3a://my-bucket/warehouse
```

#### Hive Catalog

```bash
--conf spark.sql.catalog.my_catalog=org.apache.iceberg.spark.SparkCatalog \
--conf spark.sql.catalog.my_catalog.type=hive \
--conf spark.sql.catalog.my_catalog.uri=thrift://hive-metastore:9083
```

## Environment Variables

| Variable | Description |
|----------|-------------|
| `SPARK_ICEBERG_VERSION` | Iceberg version (e.g., 1.6.1) |
| `SPARK_SQL_CATALOG_IMPLEMENTATION` | Default catalog implementation class |
| `SPARK_SQL_EXTENSIONS` | Spark SQL extensions (Iceberg extensions) |
| `SPARK_HOME` | Spark installation directory |

## JARs Installed

| JAR | Location |
|-----|----------|
| iceberg-spark-runtime-3.5.7_2.12-1.6.1.jar | `${SPARK_HOME}/jars/` |
| iceberg-aws-bundle-1.6.1.jar | `${SPARK_HOME}/jars/` (optional) |

## Image Size

Approximately 150-200MB.

## Official Sources

- [Apache Iceberg](https://iceberg.apache.org/)
- [Maven Central - Iceberg Spark Runtime](https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-spark-runtime_2.12/)
- [Maven Central - Iceberg AWS Bundle](https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-aws-bundle/)

## Maintenance

### Update Iceberg version

1. Update `ICEBERG_VERSION` build arg in Dockerfile
2. Update test expectations if needed
3. Run full test suite
4. Update README compatibility table

### Troubleshooting

**Catalog not found**: Check SPARK_SQL_CATALOG_IMPLEMENTATION environment variable

**Table not found**: Verify warehouse path and catalog configuration

**S3 access issues**: Ensure iceberg-aws-bundle JAR is present and S3 credentials are configured
