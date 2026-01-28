# Disaster Recovery Guide for Spark K8s

Basic disaster recovery procedures for Spark K8s Constructor.

## Backup Strategy

### RTO/RPO

- **RTO** (Recovery Time Objective): 1-4 hours
- **RPO** (Recovery Point Objective): 24 hours

### What Gets Backed Up

✅ **Backed Up:**
- Hive Metastore database
- Airflow PostgreSQL database
- GitHub repositories (code, configs)
- Great Expectations suites

❌ **NOT Backed Up:**
- S3 datasets (use replication instead)
- Spark event logs (ephemeral)
- Executor logs (ephemeral)

## Backup Schedule

### Daily Backups (2 AM UTC)

Automated via Kubernetes CronJob.

```bash
# List backups
mc ls minio/backups/hive-metastore/
mc ls minio/backups/airflow/
```

### Retention

- Daily backups: 30 days
- Weekly backups: 12 weeks
- Monthly backups: 12 months

## Restore Procedures

### Restore Hive Metastore

```bash
# 1. Scale down Hive Metastore
kubectl scale statefulset/spark-hive-metastore --replicas=0

# 2. Restore database
kubectl exec -it postgresql-hive-41-0 -- \
  pg_restore -U hive -d metastore_spark41 < /backups/hive_latest.dump

# 3. Scale up
kubectl scale statefulset/spark-hive-metastore --replicas=1
```

### Restore Airflow

```bash
# 1. Scale down Airflow
kubectl scale deployment/airflow-web --replicas=0
kubectl scale deployment/airflow-scheduler --replicas=0

# 2. Restore database
kubectl exec -it postgresql-airflow-0 -- \
  pg_restore -U airflow -d airflow < /backups/airflow_latest.dump

# 3. Scale up
kubectl scale deployment/airflow-web --replicas=1
kubectl scale deployment/airflow-scheduler --replicas=1
```

## Disaster Scenarios

### Scenario 1: Hive Metastore Database Corrupted

**Symptoms:** Queries failing with "Table not found" errors

**Recovery:**
1. Identify last good backup
2. Restore Hive Metastore DB
3. Verify table listings
4. Run test queries

**Downtime:** 1-2 hours

### Scenario 2: Airflow Database Lost

**Symptoms:** Airflow UI not accessible, DAGs not running

**Recovery:**
1. Restore Airflow PostgreSQL
2. Verify DAG sync from git
3. Check connections
4. Resume scheduled runs

**Downtime:** 2-4 hours

### Scenario 3: S3 Bucket Deleted

**Symptoms:** Data not found, queries failing

**Prevention:**
- Enable S3 versioning
- Enable S3 cross-region replication
- Use lifecycle policies

**Recovery:**
1. Restore from versioned objects
2. Or restore from replicated bucket
3. Verify data integrity
4. Update warehouse location

**Downtime:** 4-24 hours

## Testing

### Monthly DR Test

1. Verify backups exist
2. Test restore procedure
3. Validate data integrity
4. Document findings

### Backup Verification

```bash
# Verify backup integrity
mc ls --rewind 7d minio/backups/

# Test restore to staging
kubectl apply -f manifests/restore-job-test.yaml
```

## Best Practices

1. **Test restores regularly** - Don't wait for disaster
2. **Document procedures** - Keep runbooks updated
3. **Monitor backups** - Alert on failures
4. **Use immutable backups** - Prevent tampering
5. **Encrypt backups** - At rest and in transit
