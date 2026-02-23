# Backup Verification

> **Last Updated:** 2026-02-13
> **Owner:** Platform Team
> **Related:** [Daily Backup](./daily-backup.md), [Restore Procedure](./restore-procedure.md)

## Overview

Backup verification ensures that backups are valid and can be restored when needed. This procedure covers automated verification methods and manual validation steps.

## Verification Strategy

### Three-Tier Verification

1. **Quick Check** (after each backup)
   - File existence check
   - Checksum verification
   - Size validation

2. **Integrity Check** (daily)
   - Metadata consistency
   - Schema validation
   - Data sampling

3. **Restore Test** (monthly)
   - Full restore to staging
   - Data integrity validation
   - Functional testing

## Automated Verification

### Hive Metastore Verification

```bash
#!/bin/bash
# Verify Hive Metastore backup

BACKUP_FILE=$1
CHECKSUM_FILE="${BACKUP_FILE}.sha256"

# 1. Check file exists
if [[ ! -f "$BACKUP_FILE" ]]; then
  echo "ERROR: Backup file not found: $BACKUP_FILE"
  exit 1
fi

# 2. Verify checksum
if [[ -f "$CHECKSUM_FILE" ]]; then
  if ! sha256sum -c "$CHECKSUM_FILE"; then
    echo "ERROR: Checksum verification failed"
    exit 1
  fi
fi

# 3. Validate SQL syntax
if ! docker run --rm -v "$BACKUP_FILE:/backup.sql" \
  postgres:15 psql -f /backup.sql --list; then
  echo "ERROR: SQL validation failed"
  exit 1
fi

# 4. Check database size
MIN_SIZE=1000  # KB
ACTUAL_SIZE=$(du -k "$BACKUP_FILE" | cut -f1)
if [[ $ACTUAL_SIZE -lt $MIN_SIZE ]]; then
  echo "WARNING: Backup size suspiciously small: ${ACTUAL_SIZE}KB"
fi

echo "✓ Hive Metastore backup verified"
```

### MinIO/S3 Verification

```bash
#!/bin/bash
# Verify MinIO backup

BUCKET=$1
BACKUP_PREFIX=$2

# 1. Count backup objects
OBJECT_COUNT=$(mc ls --json "minio/$BUCKET/$BACKUP_PREFIX" | jq '. | length')

if [[ $OBJECT_COUNT -eq 0 ]]; then
  echo "ERROR: No backup objects found"
  exit 1
fi

# 2. Verify latest backup
LATEST_BACKUP=$(mc ls --json "minio/$BUCKET/$BACKUP_PREFIX" | \
  jq -r 'sort_by(.time) | reverse[0].key')

echo "Latest backup: $LATEST_BACKUP"

# 3. Sample data integrity
mc cat "minio/$BUCKET/$LATEST_BACKUP" | head -c 1000 | \
  grep -q "data_version" || echo "WARNING: Data format可疑"

echo "✓ MinIO backup verified ($OBJECT_COUNT objects)"
```

### Airflow Metadata Verification

```bash
#!/bin/bash
# Verify Airflow metadata backup

BACKUP_FILE=$1

# 1. Check file exists and is not empty
if [[ ! -s "$BACKUP_FILE" ]]; then
  echo "ERROR: Airflow backup is empty"
  exit 1
fi

# 2. Validate JSON structure
if jq empty "$BACKUP_FILE" 2>/dev/null; then
  echo "✓ JSON is valid"
else
  echo "ERROR: Invalid JSON in Airflow backup"
  exit 1
fi

# 3. Check required tables
REQUIRED_TABLES=("dag" "task_instance" "dag_run")
for table in "${REQUIRED_TABLES[@]}"; do
  if ! jq -e ".[] | select(.table == \"$table\")" "$BACKUP_FILE" >/dev/null; then
    echo "WARNING: Table '$table' not found in backup"
  fi
done

echo "✓ Airflow metadata backup verified"
```

## Restore Testing

### Monthly Restore Test to Staging

```bash
#!/bin/bash
# Test restore to staging environment

set -euo pipefail

BACKUP_DATE=$1
STAGING_NAMESPACE="spark-staging"

echo "=== Testing Restore from $BACKUP_DATE ==="

# 1. Restore Hive Metastore
echo "Restoring Hive Metastore..."
kubectl exec -n "$STAGING_NAMESPACE" deployment/hive-metastore -- \
  bash -c "psql -U hive -d metastore < /backups/hive-${BACKUP_DATE}.sql"

# 2. Verify restored data
echo "Verifying restored data..."
kubectl exec -n "$STAGING_NAMESPACE" deployment/hive-metastore -- \
  psql -U hive -d metastore -c "SELECT COUNT(*) FROM DBS"

# 3. Test MinIO restore
echo "Testing MinIO data access..."
kubectl exec -n "$STAGING_NAMESPACE" deployment/spark-driver -- \
  aws s3 ls "s3://spark-test-data/"

# 4. Run validation query
echo "Running validation query..."
kubectl exec -n "$STAGING_NAMESPACE" deployment/spark-driver -- \
  spark-sql -e "SELECT COUNT(*) FROM test_db.test_table"

echo "✓ Restore test completed successfully"
```

## Verification Metrics

Track these metrics in Prometheus:

```yaml
# Prometheus recording rules
groups:
  - name: backup_verification
    interval: 1h
    rules:
      - record: backup:verification_success_rate
        expr: |
          sum(rate(backup_verification_success_total[24h])) /
          sum(rate(backup_verification_total[24h]))

      - record = backup:last_verification_age_seconds
        expr: |
          time() - max(backup_verification_timestamp_seconds)

      - record = backup:size_bytes
        expr: |
          sum(kube_persistentvolumeclaim_resource_requests{namespace="backup"})
```

## Alerts

### Verification Failure Alert

```yaml
- alert: BackupVerificationFailed
  expr: backup_verification_success == 0
  for: 5m
  labels:
    severity: critical
  annotations:
    summary: "Backup verification failed for {{ $labels.backup_type }}"
    description: "Backup {{ $labels.backup_name }} verification failed"
```

### Stale Backup Alert

```yaml
- alert: BackupStale
  expr: backup:last_verification_age_seconds > 86400
  for: 1h
  labels:
    severity: warning
  annotations:
    summary: "Backup not verified in 24h"
    description: "{{ $labels.backup_name }} last verified {{ $value | humanizeDuration }} ago"
```

## Verification Checklist

### Daily Verification
- [ ] All backup jobs completed successfully
- [ ] Checksums verified
- [ ] File sizes within expected range
- [ ] No error logs in backup jobs

### Weekly Verification
- [ ] Metadata consistency checks passed
- [ ] Sample data integrity verified
- [ ] Backup retention policy applied
- [ ] Replication to DR region completed

### Monthly Verification
- [ ] Full restore test to staging
- [ ] Functional testing completed
- [ ] RTO/RPO metrics updated
- [ ] Verification report generated

## Troubleshooting

### Checksum Mismatch

**Symptom:** SHA256 checksum verification fails

**Diagnosis:**
```bash
# Check for file corruption
sha256sum backup-file.sql
sha256sum -c backup-file.sql.sha256
```

**Resolution:**
- Check storage system health
- Verify network transfer integrity
- Re-run backup if needed

### Restore Test Failure

**Symptom:** Staging restore fails

**Diagnosis:**
```bash
# Check restore logs
kubectl logs -n spark-staging job/restore-test-${BACKUP_DATE}

# Verify backup file integrity
scripts/operations/backup/verify-backups.sh --type hive --date ${BACKUP_DATE}
```

**Resolution:**
- Verify backup exists and is valid
- Check staging resource availability
- Review schema compatibility

## Best Practices

1. **Automate verification:** Run verification after every backup
2. **Test restores:** Monthly staging restore tests
3. **Track metrics:** Monitor verification success rate
4. **Alert on failures:** Immediate notification on verification failure
5. **Document results:** Maintain verification history

## References

- [Daily Backup Procedure](./daily-backup.md)
- [Restore Procedure](./restore-procedure.md)
- [Data Recovery Runbooks](../runbooks/data/)
