# Spark 3.5.7 Demo Results

## Date: 2026-02-25

## ✅ Working Components

| Component | Namespace | Status | Notes |
|-----------|----------|--------|-------|
| Spark 3.5.7 | spark-infra | Running | Target version |
| Spark Connect | spark-infra | Running | sc://...connect:15002 |
| Spark Standalone Master | spark-infra | Running | spark://...standalone-master:7077 |
| Spark Standalone Workers | spark-infra | Running (3 replicas) 1 core each |
| Jupyter | spark-infra | Running | :8888 |
| MinIO | spark-infra | Running | S3-compatible storage |
| PostgreSQL | spark-infra | Running | Backend for Hive Metastore |
| Hive Metastore | spark-infra | CrashLoopBackOff | Missing S3A jars (needs custom image) |
| Spark History Server | spark-infra | Running | Event logs from S3 |
| Prometheus | spark-infra | Running | Metrics collection |
| Grafana | spark-infra | Running | Dashboards |
| Airflow + Spark Standalone | spark-airflow | Running | :8080 |
| Spark Standalone Master | spark-airflow | Running | spark://...standalone-master:7077 |
| Spark Standalone Worker | spark-airflow | Running | 1 core |

## ✅ Successful Demos

### 1. Jupyter + Spark Connect + Spark Standalone
- Pi calculation: 3.32 (200 partitions)
- NYC Taxi data read: 220,857 rows
- Data processing: ✅ Saved to s3a://spark-jobs/processed/

### 2. Airflow + Spark Standalone
- Pi calculation: 3.14 (50 partitions)
- Driver host: POD_IP (critical fix!)
- Executors: Successfully connected

### 3. MinIO S3 Storage
- nyc-taxi bucket: 4 parquet files
- spark-jobs bucket: Test data written
- spark-logs bucket: Event logs stored

### 4. Observability Stack
- Prometheus: Running
- Grafana: Running

## ⚠️ Known Issues
1. Hive Metastore: Missing S3A filesystem classes in stock Hive image

## Next Steps
1. Update Hive Metastore image to include Hadoop S3A dependencies
2. Update Airflow DAG to use POD IP for driver host
