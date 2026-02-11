# Hive Metastore Restore Runbook

## Overview

This runbook covers the detection, diagnosis, and remediation of Hive Metastore corruption, data loss, or failure scenarios.

## Detection

### Symptoms

| Symptom | Severity | Description |
|---------|----------|-------------|
| `InvalidTableException` | Critical | Queries failing with table not found errors |
| `MetaException` | Critical | Metadata access failures |
| Connection timeout | High | Applications cannot connect to metastore |
| Inconsistent schema | High | Schema mismatch between metastore and actual data |
| Partition not found | Medium | Partition metadata missing |

### Detection Queries

```sql
-- Check if metastore is accessible
SHOW DATABASES;

-- Check table count per database
SELECT DB_LOCATIONS.NAME, COUNT(*) as TABLE_COUNT
FROM TBLS
JOIN DBS ON TBLS.DB_ID = DBS.DB_ID
GROUP BY DB_LOCATIONS.NAME;

-- Check for corrupted partitions
SELECT TBL_NAME, COUNT(*) as PARTITION_COUNT
FROM TBLS
LEFT JOIN PARTITIONS ON TBLS.TBL_ID = PARTITIONS.TBL_ID
GROUP BY TBL_NAME
HAVING COUNT(*) = 0;

-- Verify storage descriptors
SELECT COUNT(*) as INVALID_SD
FROM STORAGE_DESCS
WHERE LOCATION IS NULL OR LOCATION = '';
```

### Monitoring Detection

```bash
# Check metastore health metrics
curl -s http://prometheus:9090/api/v1/query?query=hive_metastore_health

# Check connection pool exhaustion
curl -s http://prometheus:9090/api/v1/query?query=hive_metastore_connection_pool_active

# Check query failure rate
curl -s http://prometheus:9090/api/v1/query?query=rate(hive_metastore_operation_failures[5m])
```

### Grafana Dashboard Queries

```promql
# Metastore availability
up{job="hive-metastore"}

# Query latency
rate(hive_metastore_operation_latency_seconds_sum[5m]) / rate(hive_metastore_operation_latency_seconds_count[5m])

# Error rate
rate(hive_metastore_operation_errors_total[5m])

# Connection pool usage
jvm_memory_used_bytes{area="heap",id="*"}/jvm_memory_max_bytes{area="heap",id="*"}
```

---

## Diagnosis

### Step 1: Verify Metastore Service Status

```bash
# Check metastore pod status
kubectl get pods -n spark-operations -l app=hive-metastore

# Check metastore logs
kubectl logs -n spark-operations spark-hive-metastore-0 --tail=100

# Check pod events
kubectl describe pod -n spark-operations spark-hive-metastore-0

# Check resource usage
kubectl top pod -n spark-operations spark-hive-metastore-0
```

### Step 2: Verify Database Connectivity

```bash
# Get database credentials
kubectl get secret -n spark-operations hive-metastore-db -o yaml

# Connect to database
kubectl exec -it -n spark-operations postgresql-hive-41-0 -- psql -U hive -d metastore_spark41

# Run database checks
\dt                          # List tables
SELECT COUNT(*) FROM DBS;    # Check database count
SELECT COUNT(*) FROM TBLS;   # Check table count
SELECT COUNT(*) FROM PARTITIONS; # Check partition count
```

### Step 3: Check for Schema Corruption

```bash
# Check for orphaned partitions
kubectl exec -n spark-operations spark-hive-metastore-0 -- \
  hive -e "SELECT TBL_NAME, COUNT(*) FROM PARTITIONS P JOIN TBLS T ON P.TBL_ID = T.TBL_ID WHERE T.TBL_ID NOT IN (SELECT TBL_ID FROM TBLS) GROUP BY TBL_NAME;"

# Check for missing storage descriptors
kubectl exec -n spark-operations spark-hive-metastore-0 -- \
  hive -e "SELECT TBL_NAME FROM TBLS WHERE SD_ID NOT IN (SELECT SD_ID FROM STORAGE_DESCS);"

# Check for invalid locations
kubectl exec -n spark-operations spark-hive-metastore-0 -- \
  hive -e "SELECT TBL_NAME, LOCATION FROM TBLS T JOIN STORAGE_DESCS S ON T.SD_ID = S.SD_ID WHERE LOCATION NOT LIKE 's3a://%';"
```

### Step 4: Verify S3 Path Consistency

```bash
# Check if metastore paths exist in S3
kubectl exec -n spark-operations spark-hive-metastore-0 -- \
  hive -e "SELECT DISTINCT CONCAT('s3a://', LOCATIONS.NAME) FROM DBS JOIN TBLS ON DBS.DB_ID = TBLS.DB_ID JOIN STORAGE_DESCS ON TBLS.SD_ID = STORAGE_DESCS.SD_ID;" | \
  while read path; do aws s3 ls "$path" || echo "Missing: $path"; done
```

### Step 5: Identify Last Known Good State

```bash
# List available backups
aws s3 ls s3://spark-backups/hive-metastore/ | tail -20

# Find backup before incident time
aws s3 ls s3://spark-backups/hive-metastore/ | grep "20260211"
```

---

## Remediation

### Option 1: Full Restore from Backup (Recommended for corruption)

**Time to recover**: 15-30 minutes
**Data loss**: Up to RPO (1 hour)

```bash
# 1. Stop all dependent services
kubectl scale deployment spark-history-server --replicas=0 -n spark-operations
kubectl scale deployment jupyter-connect --replicas=0 -n spark-operations
kubectl delete sparkapplications --all -n spark-operations

# 2. Scale down metastore
kubectl scale statefulset spark-hive-metastore --replicas=0 -n spark-operations

# 3. Restore database using script
scripts/operations/recovery/restore-hive-metastore.sh \
  --backup s3://spark-backups/hive-metastore/hive-metastore-backup-20260211-000000.sql \
  --namespace spark-operations

# 4. Scale up metastore
kubectl scale statefulset spark-hive-metastore --replicas=1 -n spark-operations

# 5. Wait for metastore to be ready
kubectl wait --for=condition=ready pod -n spark-operations -l app=hive-metastore --timeout=300s

# 6. Restart dependent services
kubectl scale deployment spark-history-server --replicas=1 -n spark-operations
kubectl scale deployment jupyter-connect --replicas=1 -n spark-operations

# 7. Verify restore
scripts/operations/recovery/verify-hive-metadata.sh --namespace spark-operations
```

### Option 2: Selective Table Recovery (For specific table issues)

**Time to recover**: 5-10 minutes per table
**Data loss**: None for unaffected tables

```bash
# 1. Identify corrupted table
kubectl exec -n spark-operations spark-hive-metastore-0 -- \
  hive -e "DESCRIBE EXTENDED database.corrupted_table;"

# 2. Drop corrupted table metadata
kubectl exec -n spark-operations spark-hive-metastore-0 -- \
  hive -e "DROP TABLE IF EXISTS database.corrupted_table PURGE;"

# 3. Recreate table from S3 data
kubectl exec -n spark-operations spark-hive-metastore-0 -- \
  hive -e "CREATE EXTERNAL TABLE database.corrupted_table (...) LOCATION 's3a://spark-data/database/corrupted_table';"

# 4. Repair partitions
kubectl exec -n spark-operations spark-hive-metastore-0 -- \
  hive -e "MSCK REPAIR TABLE database.corrupted_table;"
```

### Option 3: Metadata Repair (For minor inconsistencies)

**Time to recover**: 10-15 minutes
**Data loss**: None

```bash
# 1. Run metastore consistency check
scripts/operations/recovery/check-metadata-consistency.sh \
  --namespace spark-operations \
  --repair

# 2. Repair specific database
kubectl exec -n spark-operations spark-hive-metastore-0 -- \
  hive -e "REPAIR TABLE database.table_name;"

# 3. Sync partitions
kubectl exec -n spark-operations spark-hive-metastore-0 -- \
  hive -e "MSCK REPAIR TABLE database.table_name;"
```

### Option 4: Point-in-Time Recovery (For specific time restoration)

**Time to recover**: 30-45 minutes
**Data loss**: Data since restore point

```bash
# 1. Stop all writes
kubectl scale deployment spark-history-server --replicas=0 -n spark-operations
kubectl delete sparkapplications --all -n spark-operations

# 2. Identify restore point
aws s3 ls s3://spark-backups/hive-metastore/ | grep "20260210-220000"

# 3. Restore to specific point
scripts/operations/recovery/restore-hive-metastore.sh \
  --backup s3://spark-backups/hive-metastore/hive-metastore-backup-20260210-220000.sql \
  --namespace spark-operations \
  --point-in-time "2026-02-10 22:00:00"

# 4. Restart services
kubectl scale deployment spark-history-server --replicas=1 -n spark-operations
```

---

## Verification

### Post-Restore Checks

```bash
# 1. Verify database connectivity
kubectl exec -n spark-operations spark-hive-metastore-0 -- \
  hive -e "SHOW DATABASES;"

# 2. Verify table count matches expected
kubectl exec -n spark-operations spark-hive-metastore-0 -- \
  hive -e "SELECT COUNT(*) FROM TBLS;"

# 3. Verify specific critical tables
kubectl exec -n spark-operations spark-hive-metastore-0 -- \
  hive -e "SHOW TABLES IN production_critical;"

# 4. Test query execution
kubectl exec -n spark-operations spark-hive-metastore-0 -- \
  hive -e "SELECT COUNT(*) FROM production_critical.fact_table LIMIT 10;"

# 5. Verify partition metadata
kubectl exec -n spark-operations spark-hive-metastore-0 -- \
  hive -e "SHOW PARTITIONS production_critical.fact_table;"
```

### Run Metadata Verification Script

```bash
scripts/operations/recovery/verify-hive-metadata.sh \
  --namespace spark-operations \
  --verbose

# Expected output:
# - Database count: OK
# - Table count: OK
# - Partition count: OK
# - Storage descriptors: OK
# - S3 path consistency: OK
```

### Test Job Verification

```bash
# Run test Spark job
kubectl apply -f tests/integration/hive-metastore-test-job.yaml

# Verify job completion
kubectl logs -n spark-operations -l spark-app-name=hive-metastore-test

# Check job metrics
kubectl describe sparkapplication hive-metastore-test -n spark-operations
```

---

## Prevention

### 1. Enable Automated Backups

```yaml
# CronJob for daily backups
apiVersion: batch/v1
kind: CronJob
metadata:
  name: hive-metastore-backup
  namespace: spark-operations
spec:
  schedule: "0 2 * * *"  # 2 AM UTC
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: postgresql:15
            command:
            - /scripts/create-hive-backup.sh
            - --output
            - s3://spark-backups/hive-metastore/
```

### 2. Enable Metastore High Availability

```yaml
# Configure HA in hive-site.xml
<property>
  <name>hive.metastore.disallow.incompatible.col.type.changes</name>
  <value>false</value>
</property>
<property>
  <name>hive.metastore.event.db.notification.api.auth</name>
  <value>false</value>
</property>
```

### 3. Implement Data Validation

```bash
# Schedule daily metadata consistency checks
apiVersion: batch/v1
kind: CronJob
metadata:
  name: hive-metadata-check
spec:
  schedule: "0 3 * * *"  # 3 AM UTC
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: checker
            image: hive:3.1.3
            command:
            - /scripts/operations/recovery/check-metadata-consistency.sh
            - --namespace
            - spark-operations
```

### 4. Monitor Metastore Health

```yaml
# Alert on metastore issues
groups:
  - name: hive_metastore
    rules:
      - alert: HiveMetastoreDown
        expr: up{job="hive-metastore"} == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Hive Metastore is down"

      - alert: HiveMetastoreHighErrorRate
        expr: rate(hive_metastore_operation_errors_total[5m]) > 10
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High error rate on Hive Metastore"
```

### 5. Implement Connection Pooling

```yaml
# Configure HikariCP for metastore
<property>
  <name>javax.jdo.option.ConnectionPoolName</name>
  <value>HikariCP</value>
</property>
<property>
  <name>javax.jdo.option.ConnectionMaxPoolSize</name>
  <value>50</value>
</property>
```

---

## Monitoring

### Key Metrics

| Metric | Description | Alert Threshold |
|--------|-------------|-----------------|
| `hive_metastore_operation_latency_seconds` | Query latency | p95 > 5s |
| `hive_metastore_operation_errors_total` | Error rate | > 10/min |
| `hive_metastore_connection_pool_active` | Active connections | > 80% max |
| `jvm_memory_used_bytes` | Heap usage | > 85% max |
| `hive_metastore_open_connections` | Open connections | > 1000 |

### Grafana Dashboard Queries

```promql
# Metastore health status
up{job="hive-metastore"}

# Query latency by operation
rate(hive_metastore_operation_latency_seconds_sum{operation="get_table"}[5m]) /
rate(hive_metastore_operation_latency_seconds_count{operation="get_table"}[5m])

# Error rate by operation
rate(hive_metastore_operation_errors_total[5m])

# Connection pool usage
hive_metastore_connection_pool_active / hive_metastore_connection_pool_max

# Database connection latency
rate(hive_metastore_db_query_latency_seconds_sum[5m]) /
rate(hive_metastore_db_query_latency_seconds_count[5m])

# JVM heap usage
jvm_memory_used_bytes{area="heap",id="PS Old Gen"} /
jvm_memory_max_bytes{area="heap",id="PS Old Gen"}
```

---

## Escalation

### Escalation Path

1. **Level 1**: Operations Team (initial diagnosis, 15 min SLA)
2. **Level 2**: Data Engineering Team (complex issues, 1 hour SLA)
3. **Level 3**: Infrastructure Team (infrastructure issues, 4 hour SLA)
4. **Level 4**: Database Team (database corruption, 24/7 on-call)

### Contact Information

| Team | Contact | Availability |
|------|---------|---------------|
| Operations | `#ops-team` | 24/7 |
| Data Engineering | `#data-team` | Business hours |
| Infrastructure | `#infra-team` | 24/7 |
| Database Team | `#db-team-oncall` | 24/7 |

---

## Related Runbooks

- [S3 Object Restore](./s3-object-restore.md)
- [Data Integrity Check](./data-integrity-check.md)
- [Restore Procedure](../../procedures/backup-dr/restore-procedure.md)

---

## References

- [Hive Metastore Administration](https://cwiki.apache.org/confluence/display/Hive/AdminManual+Installation)
- [Hive Metastore Configuration](https://cwiki.apache.org/confluence/display/Hive/Configuration+Properties)
- [PostgreSQL Point-in-Time Recovery](https://www.postgresql.org/docs/current/continuous-archiving.html)
