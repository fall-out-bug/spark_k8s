# JDBC Drivers Intermediate Layer

Docker intermediate layer for Spark K8s that provides JDBC drivers for connecting to enterprise databases.

## Overview

This image extends the `spark-k8s-jdk-17:latest` base image and includes JDBC drivers for:
- PostgreSQL (42.7.2)
- MySQL (9.1.0)
- Oracle Database (21.11.0.0)
- Microsoft SQL Server (12.4.2.jre11)
- Vertica (12.0.4-0)

## Base Image

- `spark-k8s-jdk-17:latest`

## Image Details

- **Image Name:** `spark-k8s-jdbc-drivers:latest`
- **Size:** ~87MB
- **User:** `spark` (non-root, UID 1000)
- **Working Directory:** `/opt`
- **Java Version:** 17

## Environment Variables

- `JDBC_DRIVERS=/opt/jdbc` - Path to JDBC drivers directory
- `CLASSPATH` - Includes all JDBC driver JARs

## JDBC Driver Locations

All drivers are installed in `/opt/jdbc/`:

| Driver | File | Class |
|--------|------|-------|
| PostgreSQL | `/opt/jdbc/postgresql.jar` | `org.postgresql.Driver` |
| MySQL | `/opt/jdbc/mysql.jar` | `com.mysql.cj.jdbc.Driver` |
| Oracle | `/opt/jdbc/oracle.jar` | `oracle.jdbc.OracleDriver` |
| MSSQL | `/opt/jdbc/mssql.jar` | `com.microsoft.sqlserver.jdbc.SQLServerDriver` |
| Vertica | `/opt/jdbc/vertica.jar` | `com.vertica.jdbc.Driver` |

## Building

```bash
cd docker/docker-intermediate/jdbc-drivers
docker build -t spark-k8s-jdbc-drivers:latest .
```

## Testing

Run the test suite:

```bash
cd docker/docker-intermediate/jdbc-drivers
./test.sh
```

Tests include:
- Java 17 availability
- JDBC directory existence
- All driver files present
- Driver class validation
- Environment variables
- Image size check

## Usage

### In Docker Compose

```yaml
services:
  spark:
    image: spark-k8s-jdbc-drivers:latest
    environment:
      - SPARK_DRIVER_EXTRA_CLASSPATH=/opt/jdbc/*
      - SPARK_EXECUTOR_EXTRA_CLASSPATH=/opt/jdbc/*
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
      value: /opt/jdbc/*
    - name: SPARK_EXECUTOR_EXTRA_CLASSPATH
      value: /opt/jdbc/*
```

## Spark Configuration

When using this image with Spark, configure JDBC as:

```scala
val df = spark.read
  .format("jdbc")
  .option("url", "jdbc:postgresql://localhost:5432/mydb")
  .option("dbtable", "mytable")
  .option("user", "user")
  .option("password", "password")
  .load()
```

## Health Check

The image includes a health check that verifies all JDBC driver JARs are accessible:

```bash
docker ps --format "{{.Status}}"  # Shows health status
```

## Version Information

- **PostgreSQL JDBC:** 42.7.2
- **MySQL Connector/J:** 9.1.0
- **Oracle JDBC (ojdbc11):** 21.11.0.0
- **MSSQL JDBC:** 12.4.2.jre11
- **Vertica JDBC:** 12.0.4-0

## License

Individual JDBC drivers are subject to their respective licenses:
- PostgreSQL: PostgreSQL License
- MySQL: GPL v2
- Oracle: Oracle Technology Network License
- MSSQL: MIT License
- Vertica: Apache License 2.0

## Maintainer

spark-k8s-platform
