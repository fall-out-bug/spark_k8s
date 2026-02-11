# S3 Write Slow Diagnosis

## Problem
S3 multipart uploads are slow, causing write stage to dominate job duration.

## Diagnosis Steps

### 1. Check S3A Metrics

**Dashboard**: Custom Prometheus dashboard required (not included in basic setup)

| Metric | Target | Action |
|--------|--------|--------|
| `s3a_write_duration` > 1000ms | Slow | Increase multipart size |
| `s3a_aborted_uploads` > 0 | Failures present | Check network, credentials |
| `s3a_write_total` count | Upload count | Verify expected rate |
| `s3a_write_bytes_total` | Total bytes | Trend analysis |

### 2. Check Multipart Configuration

```bash
# Current multipart size (default 128MB)
kubectl get configmap spark-3.5-connect-config -o json | \
  jq -r '.data["spark-properties.conf.template"]' | grep -o "spark.hadoop.fs.s3a.multipart" || echo "Not set"
```

**Target**: `spark.hadoop.fs.s3a.multipart.size` should be 64-256MB

### 3. Check Network

```bash
# Test S3 connectivity from executors
kubectl exec -n spark-load-test -c spark-connect -- \
  curl -w "time_total" -o /dev/null -s "http://minio:9000/raw-data/" | head -1
```

### 4. Check Spark Configuration

```python
# Check if adaptive query execution is enabled
from pyspark.sql import SparkSession

spark = SparkSession.builder.getOrCreate()
conf = spark.sparkContext._conf
print(f"spark.sql.adaptive.enabled: {conf.get('spark.sql.adaptive.enabled', 'false')}")
print(f"spark.sql.adaptive.coalescePartitions.enabled: {conf.get('spark.sql.adaptive.coalescePartitions.enabled', 'false')}")
```

## Solutions

| Solution | When to Use |
|---------|--------------|
| Increase multipart.size | `spark.hadoop.fs.s3a.multipart.size=268435456` (256MB) |
| Enable fast upload | Check network, endpoint optimization |
| Use direct S3A client | Bypass some abstraction layers |
| Optimize data size | Write larger batches, not all rows at once |

## Related Dashboards

- **S3A Metrics** dashboard (when created): Upload latency, throughput, error rate
- **Job Phase Timeline**: S3 Write time vs Compute time

## Recipe Checklist

- [ ] Create S3A metrics dashboard (AC4)
- [ ] Check s3a_write_duration metrics
- [ ] Verify multipart.size setting
- [ ] Test S3 connectivity from executor pods
- [ ] Implement optimization based on findings
- [ ] Monitor s3a_aborted_uploads metric
