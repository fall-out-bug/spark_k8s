# Restore Procedure

## Overview

This procedure defines the restore process for Spark on Kubernetes components from backups.

## Prerequisites

- Access to backup storage (S3/MinIO)
- Access to Kubernetes cluster
- Backup verification completed
- Restore environment prepared
- Maintenance window approved (if production)

## Pre-Restore Checklist

- [ ] Backup identified and verified
- [ ] Checksum validated
- [ ] Restore target environment ready
- [ ] Stakeholders notified
- [ ] Maintenance window scheduled (if production)
- [ ] Rollback plan documented

---

## Restore Procedures

### 1. Hive Metastore Restore

**Estimated Time**: 15-30 minutes

#### Step 1: Stop Affected Services

```bash
# Stop Spark applications
kubectl delete sparkapplications -l environment=production -n spark-operations

# Stop services that depend on Hive Metastore
kubectl scale deployment spark-history-server --replicas=0 -n spark-operations
kubectl scale deployment jupyter-connect --replicas=0 -n spark-operations
```

#### Step 2: Download Backup

```bash
# Download from S3/MinIO
aws s3 cp s3://spark-backups/hive-metastore/backup-20260211.sql /tmp/hive-restore.sql

# Verify checksum
echo "expected_checksum  /tmp/hive-restore.sql" | md5sum -c
```

#### Step 3: Restore Database

```bash
# Restore Hive Metastore
scripts/operations/recovery/restore-hive-metastore.sh \
  --backup /tmp/hive-restore.sql \
  --namespace spark-operations
```

#### Step 4: Verify Restore

```bash
# Verify tables are present
kubectl exec -it -n spark-operations hive-metastore-0 -- \
  hive -e "SHOW TABLES;"

# Verify partition metadata
kubectl exec -it -n spark-operations hive-metastore-0 -- \
  hive -e "SHOW PARTITIONS <table_name>;"

# Verify data integrity
scripts/operations/recovery/verify-hive-metadata.sh \
  --namespace spark-operations
```

#### Step 5: Restart Services

```bash
# Restart services
kubectl scale deployment spark-history-server --replicas=1 -n spark-operations
kubectl scale deployment jupyter-connect --replicas=1 -n spark-operations

# Verify connectivity
kubectl logs -n spark-operations -l app=spark-history-server --tail=50
```

---

### 2. MinIO/S3 Data Restore

**Estimated Time**: 1-4 hours (depends on data volume)

#### Option A: S3 Version Restore (for specific files)

```bash
# List versions of an object
aws s3api list-object-versions \
  --bucket spark-output-data \
  --prefix results/job-123/

# Restore specific version
aws s3api get-object \
  --bucket spark-output-data \
  --key results/job-123/output.parquet \
  --version-id specific-version-id \
  /tmp/restored-file.parquet

# Upload restored file
aws s3 cp /tmp/restored-file.parquet \
  s3://spark-output-data/results/job-123/output.parquet
```

#### Option B: Full MinIO Restore

```bash
# Restore MinIO data from backup
scripts/operations/recovery/restore-minio-volume.sh \
  --backup s3://spark-backups-minio/minio-data/backup-20260211.tar.gz \
  --namespace spark-operations
```

#### Option C: Cross-Region Replication Restore

```bash
# Copy from DR region
aws s3 cp \
  s3://spark-backups-dr/spark-output-data/results/ \
  s3://spark-output-data/results/ \
  --recursive
```

#### Verification

```bash
# Verify data integrity
scripts/operations/recovery/verify-data-integrity.sh \
  --bucket spark-output-data \
  --prefix results/job-123/

# Verify checksums
aws s3api head-object \
  --bucket spark-output-data \
  --key results/job-123/output.parquet \
  --query 'Metadata.checksum'
```

---

### 3. Airflow Metadata Restore

**Estimated Time**: 15-30 minutes

#### Step 1: Stop Airflow

```bash
# Stop Airflow components
kubectl scale deployment airflow-scheduler --replicas=0 -n spark-operations
kubectl scale deployment airflow-web --replicas=0 -n spark-operations
kubectl scale deployment airflow-worker --replicas=0 -n spark-operations
```

#### Step 2: Download Backup

```bash
# Download from S3/MinIO
aws s3 cp s3://spark-backups/airflow/backup-20260211.sql /tmp/airflow-restore.sql
```

#### Step 3: Restore Database

```bash
# Restore Airflow PostgreSQL database
scripts/operations/recovery/restore-airflow-db.sh \
  --backup /tmp/airflow-restore.sql \
  --namespace spark-operations
```

#### Step 4: Verify DAGs

```bash
# Sync DAGs if needed
kubectl cp /local/dags/ -n spark-operations \
  airflow-scheduler-0:/opt/airflow/dags/

# Verify DAGs are loaded
kubectl exec -n spark-operations airflow-scheduler-0 -- \
  python -c "from airflow.models import DagBag; DagBag(); print('DAGs loaded')"
```

#### Step 5: Restart Airflow

```bash
# Restart Airflow components
kubectl scale deployment airflow-scheduler --replicas=1 -n spark-operations
kubectl scale deployment airflow-web --replicas=1 -n spark-operations
kubectl scale deployment airflow-worker --replicas=2 -n spark-operations

# Verify Airflow is accessible
kubectl port-forward -n spark-operations svc/airflow-web 8080:8080
```

---

### 4. MLflow Restore

**Estimated Time**: 10-20 minutes

#### Step 1: Stop MLflow

```bash
# Stop MLflow server
kubectl scale deployment mlflow-server --replicas=0 -n spark-operations
```

#### Step 2: Restore Backend Store

```bash
# Download backup
aws s3 cp s3://spark-backups/mlflow/backup-20260211.sql /tmp/mlflow-restore.sql

# Restore database
scripts/operations/recovery/restore-mlflow-db.sh \
  --backup /tmp/mlflow-restore.sql \
  --namespace spark-operations
```

#### Step 3: Verify Artifacts

```bash
# Verify artifact store access
kubectl exec -n spark-operations mlflow-server-0 -- \
  ls /mlflow/artifacts/

# Test MLflow UI
kubectl port-forward -n spark-operations svc/mlflow 5000:5000
```

#### Step 4: Restart MLflow

```bash
kubectl scale deployment mlflow-server --replicas=1 -n spark-operations
```

---

## Post-Restore Validation

### Checklist

- [ ] All services started successfully
- [ ] Hive Metastore connectivity verified
- [ ] Tables and partitions accessible
- [ ] Data integrity verified (checksums)
- [ ] Airflow DAGs loaded successfully
- [ ] MLflow experiments accessible
- [ ] Test job completed successfully
- [ ] Monitoring shows healthy state

### Test Job

```bash
# Run a test Spark job to verify end-to-end functionality
kubectl apply -f tests/integration/test-spark-job.yaml

# Verify job completion
kubectl logs -n spark-operations -l spark-app-name=test-job

# Check metrics
kubectl top pods -n spark-operations
```

---

## Rollback Procedure

If restore fails or causes issues:

### Option 1: Revert to Previous State

```bash
# Stop services
kubectl scale deployment --all --replicas=0 -n spark-operations

# Revert database changes
scripts/operations/recovery/rollback-hive-metastore.sh \
  --namespace spark-operations

# Restart services
kubectl scale deployment --all --replicas=1 -n spark-operations
```

### Option 2: Use Point-in-Time Recovery

```bash
# Recover database to specific point in time
scripts/operations/recovery/pitr-hive-metastore.sh \
  --restore-to "2026-02-11 08:00:00" \
  --namespace spark-operations
```

---

## Troubleshooting

### Restore Failed: Database Connection Error

**Diagnosis**:
```bash
# Check database is running
kubectl get pods -n spark-operations -l app=hive-metastore

# Check database logs
kubectl logs -n spark-operations hive-metastore-0
```

**Resolution**:
1. Ensure database pod is running
2. Verify database credentials
3. Check network policies
4. Restart database if needed

### Restore Failed: Checksum Mismatch

**Diagnosis**:
```bash
# Verify backup integrity
md5sum /tmp/restore-file.sql

# Compare with stored checksum
aws s3api head-object \
  --bucket spark-backups \
  --key hive-metastore/backup-20260211.sql \
  --query 'Metadata.md5checksum'
```

**Resolution**:
1. Re-download backup from S3
2. Try previous day's backup
3. If all backups corrupted, escalate to DR restore

### Services Not Starting After Restore

**Diagnosis**:
```bash
# Check service status
kubectl get pods -n spark-operations

# Check service logs
kubectl logs -n spark-operations <pod-name>

# Check events
kubectl get events -n spark-operations --sort-by='.metadata.creationTimestamp'
```

**Resolution**:
1. Check configuration files
2. Verify secrets/configmaps are present
3. Check resource limits
4. Validate restore completed successfully

---

## Monitoring During Restore

### Metrics to Watch

```bash
# Database metrics
kubectl top pods -n spark-operations -l app=hive-metastore

# Service metrics
kubectl get pods -n spark-operations

# Storage metrics
df -h /var/lib/kubernetes
```

### Grafana Dashboard

Monitor "Restore Progress" dashboard for:
- Restore completion percentage
- Database connection status
- Service health
- Error rates

---

## Related Procedures

- [Daily Backup](./daily-backup.md)
- [Backup Verification](./backup-verification.md)
- [DR Test Schedule](./dr-test-schedule.md)

## References

- [Hive Metastore Recovery](https://cwiki.apache.org/confluence/display/Hive/AdminManual+Installation)
- [PostgreSQL Point-in-Time Recovery](https://www.postgresql.org/docs/current/continuous-archiving.html)
- [S3 Versioning](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Versioning.html)
