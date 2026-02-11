# S3 Object Restore Runbook

## Overview

This runbook covers the detection, diagnosis, and remediation of S3 data loss, corruption, or accidental deletion scenarios using S3 versioning.

## Detection

### Symptoms

| Symptom | Severity | Description |
|---------|----------|-------------|
| FileNotFoundException | Critical | Spark jobs failing to read input data |
| ETag mismatch | High | Data corruption detected |
| AccessDenied | Medium | Permission issues |
| Incorrect data | High | Data content doesn't match expected |
| Missing partitions | High | Partition files missing |

### Detection Queries

```bash
# Check for missing files in a partition
aws s3 ls s3://spark-data/production/fact_table/dt=2026-02-11/

# Compare object counts
aws s3 ls s3://spark-data/production/fact_table/ --recursive | wc -l

# Check for unversioned objects
aws s3api list-objects-v2 \
  --bucket spark-data \
  --prefix "production/fact_table/" \
  --query 'Contents[?contains(Key, `dt=2026-02-11`)].{Key:Key,Size:Size}'

# Check for delete markers
aws s3api list-object-versions \
  --bucket spark-data \
  --prefix "production/fact_table/dt=2026-02-11/" \
  --query 'DeleteMarkers'
```

### Spark Job Detection

```scala
// Add checksum validation to Spark jobs
val df = spark.read.parquet("s3a://spark-data/production/fact_table")

// Verify row count
val count = df.count()
if (count < expectedCount) {
  throw new Exception(s"Data loss detected: expected $expectedCount, got $count")
}

// Verify schema
val expectedSchema = expectedStructType
if (!df.schema.equals(expectedSchema)) {
  throw new Exception(s"Schema mismatch: ${df.schema} vs $expectedSchema")
}
```

### Grafana Dashboard Queries

```promql
# S3 operation error rate
rate(s3_operations_errors_total[5m])

# S3 4xx error rate
rate(s3_requests_total{status="4xx"}[5m])

# S3 5xx error rate
rate(s3_requests_total{status="5xx"}[5m])

# S3 object count
s3_objects_total{bucket="spark-data"}

# S3 bucket size
s3_bucket_size_bytes{bucket="spark-data"}
```

---

## Diagnosis

### Step 1: Identify Affected Objects

```bash
# Get list of missing objects from Spark job logs
kubectl logs -n spark-operations spark-job-xxx | grep "FileNotFoundException"

# Parse S3 paths from logs
kubectl logs -n spark-operations spark-job-xxx | \
  grep "s3a://spark-data" | \
  grep -oE 's3a://[^ ]+' > /tmp/missing-objects.txt

# Check which objects exist
cat /tmp/missing-objects.txt | while read path; do
  s3path=$(echo $path | sed 's|s3a://|s3://|')
  aws s3 ls "$s3path" || echo "MISSING: $s3path"
done
```

### Step 2: Check Object Version History

```bash
# List all versions of an object
aws s3api list-object-versions \
  --bucket spark-data \
  --prefix "production/fact_table/dt=2026-02-11/part-00000.parquet" \
  --output table

# Get version details
aws s3api get-object \
  --bucket spark-data \
  --key "production/fact_table/dt=2026-02-11/part-00000.parquet" \
  --version-id VERSION_ID \
  /tmp/object.parquet

# Compare versions
aws s3api list-object-versions \
  --bucket spark-data \
  --prefix "production/fact_table/dt=2026-02-11/" \
  --query 'Versions[?IsLatest==`false`]'
```

### Step 3: Verify Checksums

```bash
# Get ETag (MD5 checksum for non-multipart)
aws s3api head-object \
  --bucket spark-data \
  --key "production/fact_table/dt=2026-02-11/part-00000.parquet" \
  --query 'ETag'

# Calculate local checksum
md5sum /tmp/object.parquet

# Compare checksums
aws s3api head-object \
  --bucket spark-data \
  --key "production/fact_table/dt=2026-02-11/part-00000.parquet" \
  --query 'Metadata.checksum'
```

### Step 4: Identify Deletion Timeline

```bash
# Check delete markers
aws s3api list-object-versions \
  --bucket spark-data \
  --prefix "production/fact_table/" \
  --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId,LastModified:LastModified}' \
  --output table

# Find when objects were deleted
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue=spark-data \
  --start-time $(date -d '2 days ago' -u +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --query 'Events[?EventName==`DeleteObjects`]'
```

### Step 5: Check Replication Status

```bash
# Check if replication is configured
aws s3api get-bucket-replication \
  --bucket spark-data

# Check replication status
aws s3api get-bucket-replication \
  --bucket spark-data \
  --query 'ReplicationConfiguration.Rules[].Status'

# List DR region objects
aws s3 ls s3://spark-data-dr/production/fact_table/ --recursive
```

---

## Remediation

### Option 1: Restore from Versioning (Recommended)

**Time to recover**: Minutes to hours (depends on data volume)
**Data loss**: None (if version exists)

```bash
# 1. Identify object to restore
OBJECT_KEY="production/fact_table/dt=2026-02-11/part-00000.parquet"
VERSION_ID="tx1Z_example_version_id"

# 2. Download previous version
aws s3api get-object \
  --bucket spark-data \
  --key "$OBJECT_KEY" \
  --version-id "$VERSION_ID" \
  /tmp/restored-object.parquet

# 3. Verify checksum
RESTORED_CHECKSUM=$(md5sum /tmp/restored-object.parquet | awk '{print $1}')
echo "Restored checksum: $RESTORED_CHECKSUM"

# 4. Upload restored object (creates new version)
aws s3 cp /tmp/restored-object.parquet \
  s3://spark-data/"$OBJECT_KEY" \
  --metadata "restore-source=version-id:$VERSION_ID,restore-date=$(date -u +%Y-%m-%d)"

# 5. Batch restore using script
scripts/operations/recovery/restore-s3-bucket.sh \
  --bucket spark-data \
  --prefix "production/fact_table/dt=2026-02-11/" \
  --restore-to "2026-02-11 12:00:00"
```

### Option 2: Restore from Cross-Region Replication

**Time to recover**: Hours (depends on data volume and replication lag)
**Data loss**: Up to replication lag (typically minutes)

```bash
# 1. Check DR region has the data
aws s3 ls s3://spark-data-dr/production/fact_table/dt=2026-02-11/

# 2. Sync from DR region
aws s3 sync \
  s3://spark-data-dr/production/fact_table/ \
  s3://spark-data/production/fact_table/ \
  --source-region us-east-1 \
  --region us-west-2 \
  --dry-run

# 3. Actual sync
aws s3 sync \
  s3://spark-data-dr/production/fact_table/ \
  s3://spark-data/production/fact_table/ \
  --source-region us-east-1 \
  --region us-west-2

# 4. Verify sync
aws s3 ls s3://spark-data/production/fact_table/dt=2026-02-11/ | wc -l
```

### Option 3: Restore from Backup Archive

**Time to recover**: Hours to days
**Data loss**: Up to RPO (24 hours)

```bash
# 1. List backup archives
aws s3 ls s3://spark-backups/archive/production/fact_table/

# 2. Download from archive
aws s3 cp \
  s3://spark-backups/archive/production/fact_table/fact_table_backup_20260210.tar.gz \
  /tmp/

# 3. Extract to temporary location
tar -xzf /tmp/fact_table_backup_20260210.tar.gz -C /tmp/restore

# 4. Upload restored files
aws s3 sync /tmp/restore/ s3://spark-data/production/fact_table/

# 5. Verify data integrity
scripts/operations/recovery/verify-data-integrity.sh \
  --bucket spark-data \
  --prefix "production/fact_table/"
```

### Option 4: Recompute from Source Data

**Time to recover**: Hours to days
**Data loss**: None

```bash
# 1. Identify source data location
SOURCE="s3://spark-input-data/raw_events/dt=2026-02-11/"
TARGET="s3://spark-data/production/fact_table/dt=2026-02-11/"

# 2. Submit recomputation job
kubectl apply -f - <<EOF
apiVersion: sparkoperator.k8s.io/v1beta2
kind: SparkApplication
metadata:
  name: recompute-fact-table-$(date +%Y%m%d-%H%M%S)
  namespace: spark-operations
spec:
  type: Scala
  mode: cluster
  image: spark:3.5.0
  mainClass: com.example.RecomputeFactTable
  arguments:
    - --source
    - $SOURCE
    - --target
    - $TARGET
  driver:
    cores: 1
    memory: 2g
  executor:
    cores: 2
    instances: 10
    memory: 4g
EOF

# 3. Monitor job
kubectl get sparkapplication -n spark-operations \
  -l spark-app-name=recompute-fact-table \
  -w
```

---

## Verification

### Post-Restore Checks

```bash
# 1. Verify object count
aws s3 ls s3://spark-data/production/fact_table/dt=2026-02-11/ | wc -l
# Expected: 100 (example)

# 2. Verify object sizes
aws s3api list-objects-v2 \
  --bucket spark-data \
  --prefix "production/fact_table/dt=2026-02-11/" \
  --query 'Contents[].{Key:Key,Size:Size}' \
  --output table

# 3. Verify checksums
scripts/operations/recovery/verify-data-integrity.sh \
  --bucket spark-data \
  --prefix "production/fact_table/dt=2026-02-11/" \
  --check-checksum

# 4. Test Spark read
kubectl apply -f tests/integration/s3-read-test-job.yaml

# 5. Verify job completion
kubectl logs -n spark-operations -l spark-app-name=s3-read-test
```

### Data Integrity Verification

```bash
# Run checksum validation
scripts/operations/recovery/verify-data-integrity.sh \
  --bucket spark-data \
  --prefix "production/fact_table/" \
  --verbose

# Expected output:
# - Objects verified: 1000
# - Checksums valid: 1000
# - Missing objects: 0
# - Corrupted objects: 0
# - Total size: 50GB
```

---

## Prevention

### 1. Enable S3 Versioning

```bash
# Enable versioning on all data buckets
for bucket in spark-data spark-output-data spark-checkpoint; do
  aws s3api put-bucket-versioning \
    --bucket $bucket \
    --versioning-configuration Status=Enabled

  # Verify
  aws s3api get-bucket-versioning --bucket $bucket
done
```

### 2. Enable MFA Delete

```bash
# Enable MFA delete for critical buckets
aws s3api put-bucket-versioning \
  --bucket spark-data \
  --versioning-configuration \
    Status=Enabled,MFADelete=Enabled
```

### 3. Configure Cross-Region Replication

```json
{
  "Role": "arn:aws:iam::123456789012:role/s3-replication-role",
  "Rules": [
    {
      "Status": "Enabled",
      "Priority": 1,
      "Filter": {},
      "Destination": {
        "Bucket": "arn:aws:s3:::spark-data-dr",
        "ReplicationTime": {
          "Status": "Enabled",
          "Time": {
            "Minutes": 15
          }
        }
      },
      "DeleteMarkerReplication": {
        "Status": "Enabled"
      }
    }
  ]
}
```

### 4. Enable S3 Object Lock

```bash
# Enable object lock for compliance
aws s3api put-object-lock-configuration \
  --bucket spark-data \
  --object-lock-configuration \
    ObjectLockEnabled=Enabled

# Create objects with WORM (Write Once Read Many) protection
aws s3api put-object \
  --bucket spark-data \
  --key "critical-data/file.parquet" \
  --object-lock-retain-until-date 2027-02-11 \
  --object-lock-mode GOVERNANCE
```

### 5. Implement Lifecycle Policies

```json
{
  "Rules": [
    {
      "Id": "Archive old versions",
      "Status": "Enabled",
      "Prefix": "production/",
      "Transitions": [
        {
          "Days": 30,
          "StorageClass": "STANDARD_IA"
        },
        {
          "Days": 90,
          "StorageClass": "GLACIER"
        }
      ],
      "NoncurrentVersionTransitions": [
        {
          "NoncurrentDays": 7,
          "StorageClass": "GLACIER"
        }
      ]
    }
  ]
}
```

### 6. Monitor S3 Operations

```yaml
# CloudWatch Alarms
resources:
  - name: S3DeleteAlert
    type: AWS::CloudWatch::Alarm
    properties:
      AlarmDescription: "Alert on S3 delete operations"
      MetricName: DeleteObjectCount
      Namespace: AWS/S3
      Statistic: Sum
      Period: 300
      EvaluationPeriods: 1
      Threshold: 10
      ComparisonOperator: GreaterThanThreshold
```

---

## Monitoring

### Key Metrics

| Metric | Description | Alert Threshold |
|--------|-------------|-----------------|
| `s3_operations_errors_total` | S3 operation errors | > 100/hour |
| `s3_delete_operations_total` | Delete operations | > 10/hour |
| `s3_4xx_errors_total` | Client errors (403, 404) | > 1% rate |
| `s3_5xx_errors_total` | Server errors (500, 503) | > 0.1% rate |
| `s3_replication_lag_seconds` | Replication delay | > 15 minutes |

### Grafana Dashboard Queries

```promql
# S3 operation rate by type
rate(s3_requests_total{bucket="spark-data"}[5m])

# S3 error rate by status code
rate(s3_requests_total{bucket="spark-data",status=~"4.."}[5m])

# S3 replication lag
s3_replication_lag_seconds{bucket="spark-data"}

# S3 object count trend
s3_objects_total{bucket="spark-data"}

# S3 bucket size
s3_bucket_size_bytes{bucket="spark-data"}

# Delete operation rate
rate(s3_delete_operations_total{bucket="spark-data"}[5m])
```

---

## Escalation

### Escalation Path

1. **Level 1**: Operations Team (initial diagnosis, 15 min SLA)
2. **Level 2**: Data Engineering Team (recompute jobs, 1 hour SLA)
3. **Level 3**: Cloud Team (S3 issues, 4 hour SLA)
4. **Level 4**: Data Steward (data loss decisions, 24/7 on-call)

### Contact Information

| Team | Contact | Availability |
|------|---------|---------------|
| Operations | `#ops-team` | 24/7 |
| Data Engineering | `#data-team` | Business hours |
| Cloud Team | `#cloud-team` | 24/7 |
| Data Steward | `#data-steward` | Business hours |

---

## Related Runbooks

- [Hive Metastore Restore](./hive-metastore-restore.md)
- [Data Integrity Check](./data-integrity-check.md)
- [Restore Procedure](../../procedures/backup-dr/restore-procedure.md)

---

## References

- [S3 Versioning](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Versioning.html)
- [S3 Replication](https://docs.aws.amazon.com/AmazonS3/latest/userguide/replication.html)
- [S3 Object Lock](https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-lock.html)
- [S3 Lifecycle Policies](https://docs.aws.amazon.com/AmazonS3/latest/userguide/lifecycle-transition-general-considerations.html)
