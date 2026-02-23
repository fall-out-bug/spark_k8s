# JDBC Drivers Intermediate Layer

## Description

Extends custom Spark builds with additional JDBC drivers (MySQL, MSSQL).
Custom builds already include PostgreSQL, Oracle, and Vertica drivers.

## Supported Databases

| Database | Driver | Version | Source |
|----------|--------|---------|--------|
| PostgreSQL | postgresql | 42.7.4 | From custom build |
| Oracle | ojdbc11 | 23.5.0.24.07 | From custom build |
| Vertica | vertica-jdbc | 12.0.4-0 | From custom build |
| MySQL | mysql-connector-j | 9.1.0 | Added by this layer |
| MSSQL | mssql-jdbc | 12.4.2.jre11 | Added by this layer |

## Base Images

Compatible with:
- `localhost/spark-k8s:3.5.7-hadoop3.4.2`
- `localhost/spark-k8s:3.5.8-hadoop3.4.2`
- `localhost/spark-k8s:4.1.0-hadoop3.4.2`
- `localhost/spark-k8s:4.1.1-hadoop3.4.2`

## Build

```bash
cd docker/docker-intermediate/jdbc-drivers

# Build with default base (Spark 3.5.7)
./build.sh

# Build with Spark 3.5.8
BASE_IMAGE=localhost/spark-k8s:3.5.8-hadoop3.4.2 ./build.sh

# Build with Spark 4.1.0
BASE_IMAGE=localhost/spark-k8s:4.1.0-hadoop3.4.2 ./build.sh

# Build with Spark 4.1.1
BASE_IMAGE=localhost/spark-k8s:4.1.1-hadoop3.4.2 ./build.sh

# Build with custom registry
BASE_IMAGE=myregistry/spark-k8s:3.5.7-hadoop3.4.2 ./build.sh
```

## Test

```bash
cd docker/docker-intermediate/jdbc-drivers
./test.sh
```

Tests include:
- SPARK_HOME environment variable (from custom build)
- Spark binaries availability
- All 5 JDBC drivers (PostgreSQL, Oracle, Vertica from custom build; MySQL, MSSQL added)
- Convenience symlinks in /opt/jdbc
- Driver class validation

## Usage

### In Spark Submit

```bash
spark-submit \
  --driver-class-path /opt/spark/jars/postgresql-*.jar \
  --jars /opt/spark/jars/mysql-connector-j.jar \
  your_app.py
```

### In Spark Configuration

```python
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .config("spark.driver.extraClassPath", "/opt/spark/jars/postgresql-*.jar") \
    .config("spark.executor.extraClassPath", "/opt/spark/jars/postgresql-*.jar") \
    .getOrCreate()

# PostgreSQL
df = spark.read \
    .format("jdbc") \
    .option("url", "jdbc:postgresql://localhost:5432/db") \
    .option("dbtable", "table") \
    .option("user", "user") \
    .option("password", "pass") \
    .load()

# MySQL
df = spark.read \
    .format("jdbc") \
    .option("url", "jdbc:mysql://localhost:3306/db") \
    .option("dbtable", "table") \
    .option("user", "user") \
    .option("password", "pass") \
    .load()

# MSSQL
df = spark.read \
    .format("jdbc") \
    .option("url", "jdbc:sqlserver://localhost:1433;databaseName=db") \
    .option("dbtable", "table") \
    .option("user", "user") \
    .option("password", "pass") \
    .load()
```

### In Kubernetes

```yaml
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: spark
    image: spark-k8s-jdbc-drivers:latest
    env:
    - name: SPARK_DRIVER_EXTRA_CLASSPATH
      value: /opt/spark/jars/*jdbc*.jar:/opt/spark/jars/mysql*.jar:/opt/spark/jars/mssql*.jar
    - name: SPARK_EXECUTOR_EXTRA_CLASSPATH
      value: /opt/spark/jars/*jdbc*.jar:/opt/spark/jars/mysql*.jar:/opt/spark/jars/mssql*.jar
```

## Environment Variables

- `SPARK_HOME=/opt/spark` - Set by custom Spark base image
- `JDBC_DRIVERS=/opt/jdbc` - Convenience directory with symlinks

## Driver Locations

All drivers are installed in `${SPARK_HOME}/jars/`:

| Driver | File | Class |
|--------|------|-------|
| PostgreSQL | `${SPARK_HOME}/jars/postgresql-42.7.4.jar` | `org.postgresql.Driver` |
| MySQL | `${SPARK_HOME}/jars/mysql-connector-j.jar` | `com.mysql.cj.jdbc.Driver` |
| Oracle | `${SPARK_HOME}/jars/ojdbc11.jar` | `oracle.jdbc.OracleDriver` |
| MSSQL | `${SPARK_HOME}/jars/mssql-jdbc.jar` | `com.microsoft.sqlserver.jdbc.SQLServerDriver` |
| Vertica | `${SPARK_HOME}/jars/vertica-jdbc-12.0.4-0.jar` | `com.vertica.jdbc.Driver` |

Convenience symlinks in `/opt/jdbc/` for easy reference.

## Health Check

The image includes a health check that verifies all JDBC driver JARs are accessible.

## Version Information

| Component | Version |
|-----------|---------|
| PostgreSQL JDBC | 42.7.4 (from custom build) |
| Oracle JDBC (ojdbc11) | 23.5.0.24.07 (from custom build) |
| Vertica JDBC | 12.0.4-0 (from custom build) |
| MySQL Connector | 9.1.0 (added by this layer) |
| MSSQL JDBC | 12.4.2.jre11 (added by this layer) |

## License

Individual JDBC drivers are subject to their respective licenses:
- PostgreSQL: PostgreSQL License
- MySQL: GPL v2
- Oracle: Oracle Technology Network License
- MSSQL: MIT License
- Vertica: Apache License 2.0
