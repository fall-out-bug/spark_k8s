# Data Connectors Guide

Comprehensive guide to Spark data source connectors.

## Overview

Supported connectors:
- File systems (local, S3, GCS, Azure)
- Kafka and Kinesis
- JDBC databases
- NoSQL stores (Cassandra, HBase, MongoDB)
- Data warehouses (Snowflake, Redshift, BigQuery)
- Delta Lake and Iceberg

## File System Connectors

### S3 (S3A)

```python
# Configure S3 access
spark = SparkSession.builder \
    .appName("s3-example") \
    .config("spark.hadoop.fs.s3a.access.key", os.getenv("AWS_ACCESS_KEY_ID")) \
    .config("spark.hadoop.fs.s3a.secret.key", os.getenv("AWS_SECRET_ACCESS_KEY")) \
    .config("spark.hadoop.fs.s3a.endpoint", "s3.amazonaws.com") \
    .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem") \
    .getOrCreate()

# Read from S3
df = spark.read.parquet("s3a://my-bucket/path/to/data/")

# Write to S3
df.write.parquet("s3a://my-bucket/output/")

# S3 optimization
spark.conf.set("spark.hadoop.fs.s3a.multipart.size", "104857600")  # 100MB parts
spark.conf.set("spark.hadoop.fs.s3a.fast.upload", "true")
```

### GCS (GC)

```python
# Configure GCS access
spark = SparkSession.builder \
    .appName("gcs-example") \
    .config("spark.hadoop.google.cloud.auth.service.account.enable", "true") \
    .config("spark.hadoop.google.cloud.auth.service.account.json.keyfile", "/path/to/key.json") \
    .config("spark.hadoop.fs.gs.impl", "com.google.cloud.hadoop.fs.gcs.GoogleHadoopFileSystem") \
    .getOrCreate()

# Read from GCS
df = spark.read.parquet("gs://my-bucket/path/to/data/")
```

### Azure Data Lake (ABFS)

```python
# Configure Azure access
spark = SparkSession.builder \
    .appName("azure-example") \
    .config("spark.hadoop.fs.azure.account.auth.type", "OAuth") \
    .config("spark.hadoop.fs.azure.account.oauth.client.id", os.getenv("AZURE_CLIENT_ID")) \
    .config("spark.hadoop.fs.azure.account.oauth.client.secret", os.getenv("AZURE_CLIENT_SECRET")) \
    .config("spark.hadoop.fs.azure.account.oauth.client.endpoint", os.getenv("AZURE_ENDPOINT")) \
    .config("spark.hadoop.fs.abfs.impl", "org.apache.hadoop.fs.azurebfs.AzureBlobFileSystem") \
    .getOrCreate()

# Read from ADLS
df = spark.read.parquet("abfss://container@storageaccount.dfs.core.windows.net/path/")
```

## Streaming Connectors

### Kafka

```python
# Read from Kafka
kafka_df = spark.readStream \
    .format("kafka") \
    .option("kafka.bootstrap.servers", "kafka1:9092,kafka2:9092") \
    .option("subscribe", "transactions") \
    .option("startingOffsets", "earliest") \
    .option("kafka.security.protocol", "SASL_SSL") \
    .option("kafka.sasl.mechanism", "PLAIN") \
    .option("kafka.sasl.jaas.config",
            'org.apache.kafka.common.security.plain.PlainLoginModule required username="user" password="pass";') \
    .load()

# Write to Kafka
query = df.selectExpr(
    "CAST(key AS STRING)",
    "CAST(value AS STRING)"
).writeStream \
    .format("kafka") \
    .option("kafka.bootstrap.servers", "kafka:9092") \
    .option("topic", "output") \
    .option("checkpointLocation", "s3a://checkpoints/kafka-sink") \
    .start()
```

### Kinesis

```python
# Read from Kinesis
kinesis_df = spark.readStream \
    .format("kinesis") \
    .option("streamName", "my-stream") \
    .option("region", "us-west-2") \
    .option("initialPosition", "latest") \
    .option("awsAccessKeyId", os.getenv("AWS_ACCESS_KEY_ID")) \
    .option("awsSecretKey", os.getenv("AWS_SECRET_ACCESS_KEY")) \
    .load()

# Write to Kinesis
query = df.writeStream \
    .format("kinesis") \
    .option("streamName", "output-stream") \
    .option("region", "us-west-2") \
    .option("checkpointLocation", "s3a://checkpoints/kinesis") \
    .start()
```

## JDBC Connectors

### PostgreSQL

```python
# Read from PostgreSQL
jdbc_url = "jdbc:postgresql://host:5432/database"
properties = {
    "user": "username",
    "password": "password",
    "driver": "org.postgresql.Driver"
}

df = spark.read \
    .jdbc(url=jdbc_url,
           table="public.users",
           properties=properties)

# With partitioning
df = spark.read \
    .jdbc(url=jdbc_url,
           table="public.transactions",
           column="id",
           lowerBound=1,
           upperBound=1000000,
           numPartitions=10,
           properties=properties)

# Write to PostgreSQL
df.write \
    .jdbc(url=jdbc_url,
           table="public.output",
           mode="overwrite",
           properties=properties)
```

### MySQL

```python
# MySQL with replication
jdbc_url = "jdbc:mysql://host:3306/database"

df = spark.read \
    .jdbc(url=jdbc_url,
           table="users",
           properties={
               "user": "root",
               "password": "password",
               "driver": "com.mysql.jdbc.Driver",
               "zeroDateTimeBehavior": "convertToNull"
           })
```

### Snowflake

```python
# Snowflake connector
sfOptions = {
    "sfUrl": "account.snowflakecomputing.com",
    "sfUser": "user",
    "sfPassword": "password",
    "sfDatabase": "database",
    "sfSchema": "public",
    "sfWarehouse": "compute_wh"
}

SNOWFLAKE_SOURCE_NAME = "snowflake"

df = spark.read \
    .format(SNOWFLAKE_SOURCE_NAME) \
    .options(**sfOptions) \
    .option("dbtable", "users") \
    .load()

# Write to Snowflake
df.write \
    .format(SNOWFLAKE_SOURCE_NAME) \
    .options(**sfOptions) \
    .option("dbtable", "output") \
    .mode("overwrite") \
    .save()
```

### BigQuery

```python
# BigQuery connector
bq_params = {
    "parentProject": "project-id",
    "project": "project-id",
    "dataset": "dataset",
    "table": "table"
}

df = spark.read \
    .format("bigquery") \
    .options(**bq_params) \
    .load()

# Write to BigQuery
df.write \
    .format("bigquery") \
    .options(**bq_params) \
    .option("table", "project:dataset.output") \
    .mode("overwrite") \
    .save()
```

## NoSQL Connectors

### Cassandra

```python
# Cassandra connector
df = spark.read \
    .format("org.apache.spark.sql.cassandra") \
    .options(table="users", keyspace="mykeyspace") \
    .load()

# Write to Cassandra
df.write \
    .format("org.apache.spark.sql.cassandra") \
    .options(table="output", keyspace="mykeyspace") \
    .mode("append") \
    .save()
```

### MongoDB

```python
# MongoDB connector
df = spark.read \
    .format("mongo") \
    .option("uri", "mongodb://host:27017/database.collection") \
    .load()

# Write to MongoDB
df.write \
    .format("mongo") \
    .option("uri", "mongodb://host:27017/database.output") \
    .mode("overwrite") \
    .save()
```

### HBase

```python
# HBase connector
df = spark.read \
    .format("org.apache.hadoop.hbase.spark") \
    .option("hbase.columns", "cf1:col1,cf2:col2") \
    .option("hbase.table", "mytable") \
    .load()
```

## Lakehouse Connectors

### Delta Lake

```python
from delta.tables import DeltaTable

# Read Delta table
df = spark.read.format("delta").load("s3a://lake/path/")

# Write Delta table
df.write.format("delta") \
    .mode("overwrite") \
    .save("s3a://lake/output/")

# Upsert with Delta
delta_table = DeltaTable.forPath(spark, "s3a://lake/target/")

delta_table.alias("target") \
    .merge(
        df.alias("source"),
        "target.id = source.id"
    ) \
    .whenMatchedUpdateAll() \
    .whenNotMatchedInsertAll() \
    .execute()
```

### Apache Iceberg

```python
# Configure Iceberg catalog
spark.conf.set("spark.sql.catalog.my_catalog", "org.apache.iceberg.spark.SparkCatalog")
spark.conf.set("spark.sql.catalog.my_catalog.type", "hadoop")
spark.conf.set("spark.sql.catalog.my_catalog.warehouse", "s3a://iceberg-warehouse/")

# Create Iceberg table
spark.sql("""
    CREATE TABLE my_catalog.db.users (
        id BIGINT,
        name STRING,
        created_at TIMESTAMP
    ) USING iceberg
    PARTITIONED BY (days(created_at))
""")

# Write to Iceberg
df.writeTo("my_catalog.db.users").append()
```

## Advanced Configurations

### Connection Pooling

```python
# JDBC connection pool for parallel reads
properties = {
    "user": "username",
    "password": "password",
    "driver": "org.postgresql.Driver",
    "fetchsize": "10000",
    "numPartitions": "10",
    "partitionColumn": "id",
    "lowerBound": "1",
    "upperBound": "100000",
    "batchsize": "5000"
}
```

### Parallel Reads

```python
# Read from multiple files in parallel
df = spark.read \
    .option("maxFilesPerTrigger", 1000) \
    .parquet("s3a://data/large_dataset/")

# Set parallelism
spark.conf.set("spark.sql.files.maxPartitionBytes", "134217728")  # 128MB
```

### Schema Evolution

```python
# Auto-merge schema
df.write \
    .mode("overwrite") \
    .option("overwriteSchema", "true") \
    .parquet("s3a://output/")
```

## Performance Tips

| Connector | Optimization |
|-----------|-------------|
| S3 | Use multipart upload, enable fast upload |
| Kafka | Increase maxOffsetsPerTrigger |
| JDBC | Use partitioning, fetchsize, connection pool |
| Delta | Enable ZORDER by clustering keys |
| Iceberg | Use partition evolution |

## Troubleshooting

| Issue | Connector | Solution |
|-------|-----------|----------|
| Slow read | JDBC | Increase partitions, reduce fetchsize |
| Memory error | Kafka | Decrease maxOffsetsPerTrigger |
| Timeout | Snowflake | Increase warehouse size |
| Small files | S3 | Coalesce before write |
| Schema mismatch | JDBC | Use mergeSchema option |

## Related

- [Streaming Patterns](./streaming-patterns.md)
- [Storage Guide](../guides/storage/)
