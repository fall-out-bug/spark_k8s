# ETL Pipeline Tutorial

This tutorial walks through building a production ETL pipeline with Spark on Kubernetes.

## Overview

You will learn how to:
1. Design a scalable ETL pipeline
2. Process data incrementally
3. Handle errors and retries
4. Monitor and optimize performance

## Prerequisites

- Kubernetes cluster with Spark operator installed
- Basic understanding of Spark and Scala/Python
- Source and destination data systems configured

## Tutorial: Daily ETL Pipeline

### Scenario

Process daily transaction data from Kafka into Parquet files on S3.

### Architecture

```
Kafka → Spark Streaming → S3 (Parquet)
                ↓
         Data Quality Checks
                ↓
           Metrics & Alerts
```

### Step 1: Create the ETL Job

```python
# etl_jobs/daily_transactions.py
from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from delta.tables import DeltaTable
import os

def create_spark_session():
    """Create Spark session with Delta Lake support."""
    builder = SparkSession.builder \
        .appName("daily-transactions-etl") \
        .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension") \
        .config("spark.sql.catalog.spark_catalog", "org.apache.spark.sql.delta.catalog.DeltaCatalog") \
        .config("spark.delta.logStore.class", "org.apache.spark.sql.delta.storage.S3SingleDriverLogStore") \
        .config("spark.hadoop.fs.s3a.access.key", os.getenv("AWS_ACCESS_KEY_ID")) \
        .config("spark.hadoop.fs.s3a.secret.key", os.getenv("AWS_SECRET_ACCESS_KEY")) \
        .config("spark.hadoop.fs.s3a.endpoint", os.getenv("S3_ENDPOINT"))

    return builder.getOrCreate()

def read_transactions(spark, date):
    """Read transactions from Kafka for the given date."""
    df = spark.read \
        .format("kafka") \
        .option("kafka.bootstrap.servers", os.getenv("KAFKA_BROKERS")) \
        .option("subscribe", "transactions") \
        .option("startingOffsets", "earliest") \
        .option("endingOffsets", "latest") \
        .load()

    # Parse and filter for the target date
    parsed = df.select(
        from_json(col("value").cast("string"), transaction_schema()).alias("data")
    ).select("data.*")

    return parsed.filter(col("transaction_date") == date)

def transaction_schema():
    """Define the transaction schema."""
    return """
    {
        "type": "struct",
        "fields": [
            {"name": "transaction_id", "type": "string"},
            {"name": "user_id", "type": "string"},
            {"name": "amount", "type": "double"},
            {"name": "currency", "type": "string"},
            {"name": "transaction_date", "type": "string"},
            {"name": "timestamp", "type": "timestamp"}
        ]
    }
    """

def transform_transactions(df):
    """Apply business transformations."""
    return df \
        .withColumn("amount_usd",
                    when(col("currency") == "USD", col("amount"))
                    .when(col("currency") == "EUR", col("amount") * 1.1)
                    .otherwise(col("amount") * 0.9)) \
        .withColumn("processing_date", current_date()) \
        .withColumn("year", year(col("transaction_date"))) \
        .withColumn("month", month(col("transaction_date"))) \
        .withColumn("day", dayofmonth(col("transaction_date")))

def write_to_s3(df, date):
    """Write transactions to S3 in partitioned Parquet format."""
    s3_path = f"s3a://data-lake/transactions/{date[:4]}/{date[4:6]}/{date[6:]}"

    df.write \
        .mode("overwrite") \
        .partitionBy("year", "month", "day") \
        .format("parquet") \
        .save(s3_path)

    return s3_path

def run_data_quality_checks(spark, s3_path):
    """Run data quality checks on processed data."""
    df = spark.read.parquet(s3_path)

    checks = {
        "total_records": df.count(),
        "null_amounts": df.filter(col("amount_usd").isNull()).count(),
        "negative_amounts": df.filter(col("amount_usd") < 0).count(),
        "duplicate_ids": df.count() - df.select("transaction_id").distinct().count()
    }

    # Fail if quality thresholds not met
    if checks["null_amounts"] > 0:
        raise ValueError(f"Found {checks['null_amounts']} null amounts")

    if checks["negative_amounts"] / checks["total_records"] > 0.01:
        raise ValueError(f"Too many negative amounts: {checks['negative_amounts']}")

    return checks

def main():
    """Main ETL pipeline."""
    import sys
    from datetime import date

    spark = create_spark_session()

    try:
        # Get target date (yesterday by default)
        target_date = sys.argv[1] if len(sys.argv) > 1 else \
            (date.today() - __import__('datetime').timedelta(days=1)).strftime("%Y-%m-%d")

        print(f"Processing transactions for: {target_date}")

        # Read
        raw_df = read_transactions(spark, target_date)
        print(f"Read {raw_df.count()} records")

        # Transform
        transformed_df = transform_transactions(raw_df)

        # Write
        s3_path = write_to_s3(transformed_df, target_date)
        print(f"Wrote to: {s3_path}")

        # Quality checks
        quality_results = run_data_quality_checks(spark, s3_path)
        print(f"Quality checks passed: {quality_results}")

        print("ETL pipeline completed successfully")

    except Exception as e:
        print(f"ETL pipeline failed: {str(e)}")
        sys.exit(1)
    finally:
        spark.stop()

if __name__ == "__main__":
    main()
```

### Step 2: Deploy to Kubernetes

```yaml
# manifests/etl-job.yaml
apiVersion: sparkoperator.k8s.io/v1beta2
kind: SparkApplication
metadata:
  name: daily-transactions-etl
  namespace: spark-prod
spec:
  type: Python
  mode: cluster
  image: your-registry/spark-etl:latest
  imagePullPolicy: Always
  mainApplicationFile: local:///app/etl_jobs/daily_transactions.py
  sparkVersion: "3.5.0"
  restartPolicy:
    type: OnFailure
    onFailureRetries: 3
    onFailureRetryInterval: 60
    onSubmissionFailureRetries: 5
    onSubmissionFailureRetryInterval: 60

  driver:
    cores: 1
    memory: "2g"
    serviceAccount: spark
    env:
      - name: AWS_ACCESS_KEY_ID
        valueFrom:
          secretKeyRef:
            name: aws-credentials
            key: access-key-id
      - name: AWS_SECRET_ACCESS_KEY
        valueFrom:
          secretKeyRef:
            name: aws-credentials
            key: secret-access-key
      - name: KAFKA_BROKERS
        value: "kafka.kafka.svc.cluster.local:9092"

  executor:
    cores: 2
    instances: 10
    memory: "4g"
    env:
      - name: AWS_ACCESS_KEY_ID
        valueFrom:
          secretKeyRef:
            name: aws-credentials
            key: access-key-id
      - name: AWS_SECRET_ACCESS_KEY
        valueFrom:
          secretKeyRef:
            name: aws-credentials
            key: secret-access-key

  deps:
    pyPackages:
      - delta-spark==2.4.0
      - boto3

  schedule: "0 2 * * *"  # Daily at 2 AM
```

### Step 3: Apply the manifest

```bash
kubectl apply -f manifests/etl-job.yaml
```

### Step 4: Monitor the job

```bash
# Watch job status
kubectl get sparkapplication -n spark-prod -w

# View logs
kubectl logs -n spark-prod -l spark-app-name=daily-transactions-etl,spark-role=driver --tail=-1 --follow

# Check metrics
kubectl exec -it -n spark-prod <driver-pod> -- curl localhost:4040/metrics/json
```

## Best Practices

### 1. Incremental Processing

Use watermarks for streaming:

```python
df.withWatermark("timestamp", "1 hour") \
  .groupBy(window(col("timestamp"), "1 hour"))
```

### 2. Error Handling

Implement retry logic:

```python
from tenacity import retry, stop_after_attempt, wait_exponential

@retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=4, max=10))
def write_with_retry(df, path):
    df.write.parquet(path)
```

### 3. Monitoring

Track key metrics:

```python
from pyspark.sql import SparkListener

class ETLMetricsListener(SparkListener):
    def onJobEnd(self, jobEnd):
        print(f"Job {jobEnd.jobId} completed in {jobEnd.time}ms")

spark.sparkContext.addSparkListener(ETLMetricsListener())
```

### 4. Cost Optimization

Use dynamic allocation:

```python
conf = SparkConf().setAll([
    ("spark.dynamicAllocation.enabled", "true"),
    ("spark.dynamicAllocation.minExecutors", "2"),
    ("spark.dynamicAllocation.maxExecutors", "20"),
    ("spark.dynamicAllocation.initialExecutors", "5")
])
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Out of memory | Increase executor memory or reduce data per task |
| Slow writes | Increase parallelism or use larger files |
| Duplicate records | Add deduplication step or use idempotent writes |
| Stuck streaming | Check watermark settings and processing time |

## Next Steps

- [ ] Add data validation framework
- [ ] Implement schema evolution handling
- [ ] Set up alerting for pipeline failures
- [ ] Create rollback procedures

## Related

- [Streaming Tutorial](./streaming.md)
- [Data Quality Guide](../../operations/procedures/cicd/data-quality-gates.md)
- [Cost Optimization](./cost-optimization.md)
