# Kafka → Iceberg Structured Streaming Example

Real-time pipeline: Kafka source → transformation → Iceberg sink with exactly-once semantics.

## Prerequisites

- Spark 3.5 or 4.1 with Kafka and Iceberg support
- MinIO or S3 for checkpoint and Iceberg warehouse
- Kafka (local via Docker Compose or cluster)

## Setup

### 1. Start Kafka and Schema Registry (local)

```bash
docker compose -f examples/streaming/docker-compose.yaml up -d
```

### 2. Create Kafka topic and produce test data

```bash
# From repo root
cd /path/to/spark_k8s

# Create topic
docker compose -f examples/streaming/docker-compose.yaml exec kafka \
  kafka-topics --create --topic events --bootstrap-server localhost:9092 --partitions 3

# Produce sample JSON (run in loop for streaming)
for i in $(seq 1 100); do
  echo '{"id":"'$i'","user_id":"u'$((i % 10))'","amount":'$((i * 10))'.5,"event_ts":'$(date +%s)000'}' | \
  docker compose -f examples/streaming/docker-compose.yaml exec -T kafka \
  kafka-console-producer --broker-list localhost:9092 --topic events
done
```

### 3. Run streaming job

**Spark 4.1:**

```bash
spark-submit \
  --packages org.apache.spark:spark-sql-kafka-0-10_2.13:4.1.0,org.apache.iceberg:iceberg-spark-runtime-3.5_2.13:1.5.0 \
  --conf spark.hadoop.fs.s3a.endpoint=http://minio:9000 \
  --conf spark.hadoop.fs.s3a.access.key=minioadmin \
  --conf spark.hadoop.fs.s3a.secret.key=minioadmin \
  --conf spark.hadoop.fs.s3a.path.style.access=true \
  examples/streaming/kafka_to_iceberg.py
```

**Spark 3.5:**

```bash
spark-submit \
  --packages org.apache.spark:spark-sql-kafka-0-10_2.12:3.5.0,org.apache.iceberg:iceberg-spark-runtime-3.5_2.12:1.5.0 \
  --conf spark.hadoop.fs.s3a.endpoint=http://minio:9000 \
  examples/streaming/kafka_to_iceberg.py
```

### 4. Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| KAFKA_BOOTSTRAP_SERVERS | localhost:9092 | Kafka brokers |
| KAFKA_TOPIC | events | Source topic |
| CHECKPOINT_LOCATION | s3a://checkpoints/kafka-iceberg | Exactly-once checkpoint |
| ICEBERG_WAREHOUSE | s3a://warehouse/iceberg | Iceberg warehouse path |
| S3_ENDPOINT | http://minio:9000 | S3/MinIO endpoint |

## Verification

- Job runs for 60s, processes ≥100 records
- Check Iceberg table: `SELECT * FROM iceberg.db_streaming.events`
- Checkpoint enables exactly-once and resume after restart
