# Daily Backup Procedure

## Overview

This procedure defines the daily backup process for Spark on Kubernetes components including Hive Metastore, MinIO/S3 data, Airflow metadata, and MLflow experiments.

## Prerequisites

- Kubernetes cluster access
- S3/MinIO access credentials
- Database backup tools installed
- Sufficient storage for backups

## Backup Components

### 1. Hive Metastore Backup

**Frequency**: Daily (after midnight)
**RPO**: 1 hour
**RTO**: 30 minutes

#### Automated Backup

The Hive Metastore backup is automated via Kubernetes CronJob:

```bash
kubectl get cronjob -n spark-operations hive-metastore-backup
```

#### Manual Backup

```bash
# Backup Hive Metastore database
scripts/operations/backup/create-hive-backup.sh \
  --namespace spark-operations \
  --output s3://spark-backups/hive-metastore/
```

#### Backup Contents

- Database schema
- Table metadata
- Partition information
- Privileges and grants

---

### 2. MinIO/S3 Data Backup

**Frequency**: Daily (continuous)
**RPO**: 1 hour
**RTO**: 2 hours

#### MinIO Backup

```bash
# Backup MinIO data
scripts/operations/backup/create-minio-backup.sh \
  --namespace spark-operations \
  --output s3://spark-backups-minio/minio-data/
```

#### S3 Versioning

Enable versioning on S3 buckets:

```bash
# Enable versioning
aws s3api put-bucket-versioning \
  --bucket spark-input-data \
  --versioning-configuration Status=Enabled

# Check versioning status
aws s3api get-bucket-versioning --bucket spark-input-data
```

#### Backup Contents

- Input data (if not externally backed up)
- Output data (business critical)
- Checkpoint data
- Shuffle data (if using external shuffle service)

---

### 3. Airflow Metadata Backup

**Frequency**: Daily
**RPO**: 1 hour
**RTO**: 1 hour

#### Automated Backup

```bash
# Backup Airflow PostgreSQL database
scripts/operations/backup/create-airflow-backup.sh \
  --namespace spark-operations \
  --output s3://spark-backups/airflow/
```

#### Backup Contents

- DAG definitions
- Task instance states
- XCom data
- Connection configurations
- Variable definitions
- SLA misses

---

### 4. MLflow Experiments Backup

**Frequency**: Daily
**RPO**: 1 hour
**RTO**: 1 hour

#### Automated Backup

```bash
# Backup MLflow backend store
scripts/operations/backup/create-mlflow-backup.sh \
  --namespace spark-operations \
  --output s3://spark-backups/mlflow/
```

#### Backup Contents

- Experiment metadata
- Run information
- Metrics and parameters
- Model metadata (not artifacts)

---

## Backup Schedule

| Time (UTC) | Component | Type | Retention |
|------------|-----------|------|-----------|
| 00:00 | Hive Metastore | Full | Daily: 7d, Weekly: 4w, Monthly: 12m |
| 00:30 | MinIO | Incremental | Daily: 7d, Weekly: 4w |
| 01:00 | Airflow | Full | Daily: 7d, Weekly: 4w, Monthly: 12m |
| 01:30 | MLflow | Full | Daily: 7d, Weekly: 4w, Monthly: 12m |
| 02:00 | Backup Verification | Check | - |
| 03:00 | Replication to DR | Copy | - |

---

## Backup Retention Policy

### Daily Backups
- **Retention**: 7 days
- **Purpose**: Quick recovery from recent failures
- **Cleanup**: Automated via CronJob

### Weekly Backups
- **Retention**: 4 weeks
- **Purpose**: Recovery from data corruption
- **Cleanup**: Manual approval required

### Monthly Backups
- **Retention**: 12 months
- **Purpose**: Compliance and long-term recovery
- **Cleanup**: Annual review

### DR Replicas
- **Retention**: Same as primary
- **Location**: Separate region/zone

---

## Verification

### Automated Verification

```bash
# Run backup verification
scripts/operations/backup/verify-backups.sh

# Includes:
# - Checksum validation
# - Restore test (to staging)
# - Integrity checks
# - Size validation
```

### Manual Verification

#### 1. Check Backup Existence

```bash
# List recent backups
aws s3 ls s3://spark-backups/hive-metastore/ | tail -10
aws s3 ls s3://spark-backups/minio-data/ | tail -10
aws s3 ls s3://spark-backups/airflow/ | tail -10
```

#### 2. Verify Backup Integrity

```bash
# Check checksums
scripts/operations/backup/verify-backup-checksum.sh \
  --backup s3://spark-backups/hive-metastore/backup-20260211.sql
```

#### 3. Test Restore to Staging

```bash
# Test restore to staging environment
scripts/operations/backup/test-restore-to-staging.sh \
  --backup s3://spark-backups/hive-metastore/backup-20260211.sql \
  --environment staging
```

---

## Troubleshooting

### Backup Failed

**Symptoms**:
- Alert received for backup failure
- No new backup file in S3

**Diagnosis**:
```bash
# Check CronJob status
kubectl get cronjob -n spark-operations

# Check job logs
kubectl logs -n spark-operations -l job-name=hive-metastore-backup-*

# Check for errors
kubectl describe job -n spark-operations hive-metastore-backup-xxx
```

**Resolution**:
1. Identify error from logs
2. Fix underlying issue (e.g., S3 credentials, disk space)
3. Manually trigger backup:
   ```bash
   kubectl create job --from=cronjob/hive-metastore-backup manual-backup-$(date +%Y%m%d) -n spark-operations
   ```

### Backup Verification Failed

**Symptoms**:
- Checksum mismatch
- Restore test failed

**Diagnosis**:
```bash
# Check verification logs
kubectl logs -n spark-operations backup-verification-xxx

# Download and verify backup manually
aws s3 cp s3://spark-backups/hive-metastore/backup-20260211.sql /tmp/
md5sum /tmp/backup-20260211.sql
```

**Resolution**:
1. If checksum mismatch: Rerun backup
2. If restore failed: Fix restore script or staging environment
3. Document findings in incident report

### Backup Too Large

**Symptoms**:
- Backup size growing significantly
- Backup duration increasing

**Diagnosis**:
```bash
# Check backup size trend
aws s3 ls s3://spark-backups/ --recursive --summarize | tail -5

# Identify large components
# For Hive: Check table count
# For MinIO: Check data volume
```

**Resolution**:
1. Implement data lifecycle policies
2. Archive old data
3. Consider compression
4. Review retention policy

---

## Monitoring

### Prometheus Metrics

```yaml
# Backup success rate
backup_success_total{component="hive-metastore",status="success"}

# Backup duration
backup_duration_seconds{component="hive-metastore"}

# Backup size
backup_size_bytes{component="hive-metastore"}

# Backup age
backup_age_seconds{component="hive-metastore"}
```

### Grafana Dashboard

Use the "Backup Status" dashboard to monitor:
- Last backup time
- Backup success rate
- Backup duration
- Backup size trends
- Verification status

### Alerts

| Alert | Condition | Severity |
|-------|-----------|----------|
| BackupFailed | No successful backup in 25 hours | Critical |
| BackupVerificationFailed | Checksum mismatch or restore failed | Warning |
| BackupSizeAnomaly | Size > 2x average | Warning |
| BackupDurationHigh | Duration > 2x average | Warning |

---

## Related Procedures

- [Restore Procedure](./restore-procedure.md)
- [Backup Verification](./backup-verification.md)
- [DR Test Schedule](./dr-test-schedule.md)

## References

- [Hive Metastore Backup](https://cwiki.apache.org/confluence/display/Hive/AdminManual+Installation)
- [MinIO Backup](https://docs.min.io/docs/minio-server-configuration-guide.html)
- [S3 Versioning](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Versioning.html)
