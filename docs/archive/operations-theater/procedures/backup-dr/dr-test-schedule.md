# Disaster Recovery Test Schedule

> **Last Updated:** 2026-02-13
> **Owner:** Platform Team
> **Related:** [Backup Verification](./backup-verification.md), [Restore Procedure](./restore-procedure.md)

## Overview

This document defines the schedule and procedures for Disaster Recovery (DR) testing. Regular DR testing ensures that recovery procedures work correctly and RTO/RPO targets are met.

## Testing Schedule

### Monthly Tests (First Thursday of each month)

| Time | Activity | Duration | Owner |
|------|----------|----------|-------|
| 09:00-10:00 | Hive Metastore restore to staging | 1h | DataOps |
| 10:00-11:00 | MinIO data verification | 1h | DataOps |
| 11:00-12:00 | Airflow metadata restore | 1h | DataOps |
| 13:00-14:00 | Functional testing (queries, jobs) | 1h | QA |
| 14:00-15:00 | RTO/RPO measurement | 1h | SRE |
| 15:00-16:00 | Post-test review | 1h | All |

### Quarterly Tests (January, April, July, October)

Full-scale DR test including:
- Complete cluster restore
- Cross-region failover
- Network connectivity validation
- Performance testing under load
- Documentation update

### Annual Test

Complete DR drill including:
- Simulated region failure
- Full failover to DR region
- 24-hour operation on DR infrastructure
- Failback to primary region

## Monthly DR Test Procedure

### Pre-Test Checklist (Day Before)

- [ ] Notify stakeholders of scheduled test
- [ ] Verify staging environment is available
- [ ] Confirm backup availability for test date
- [ ] Prepare test data and queries
- [ ] Set up monitoring and logging

### Test Execution

#### 1. Environment Preparation (09:00-09:15)

```bash
# Clean staging environment
kubectl delete ns spark-staging
kubectl create ns spark-staging

# Deploy core services
helm install spark-staging ./charts/spark-base --namespace spark-staging
```

#### 2. Hive Metastore Restore (09:15-10:00)

```bash
# Get latest backup
BACKUP_DATE=$(scripts/operations/backup/verify-backups.sh --latest --type hive)

# Restore to staging
./scripts/operations/backup/test-restore-to-staging.sh \
  --backup-type hive \
  --backup-date "$BACKUP_DATE" \
  --namespace spark-staging
```

**Validation:**
```bash
# Verify database count
kubectl exec -n spark-staging deployment/hive-metastore -- \
  psql -U hive -d metastore -c "SELECT COUNT(*) FROM DBS"

# Expected: Production count ±10%
```

#### 3. MinIO Data Verification (10:00-10:45)

```bash
# List backed-up data
mc ls --recursive minio/spark-backups/

# Verify sample data
mc stat minio/spark-backups/$(date +%Y%m%d)/sample-data.parquet

# Count objects
OBJECT_COUNT=$(mc ls --recursive minio/spark-backups/$(date +%Y%m%d) | wc -l)
echo "Total objects: $OBJECT_COUNT"
```

**Validation:** Object count within 5% of production

#### 4. Airflow Metadata Restore (10:45-11:30)

```bash
# Restore Airflow metadata
./scripts/operations/backup/test-restore-to-staging.sh \
  --backup-type airflow \
  --backup-date "$BACKUP_DATE" \
  --namespace spark-staging
```

**Validation:**
```bash
# Verify DAG count
kubectl exec -n spark-staging deployment/airflow-webserver -- \
  python -c "from airflow import models; session = models.Session; print(session.query(models.DagBag).count())"
```

#### 5. Functional Testing (13:00-14:00)

```bash
# Deploy test Spark job
kubectl apply -f tests/dr/spark-pi-job.yaml

# Wait for completion
kubectl wait --for=condition=complete job/spark-pi-test -n spark-staging

# Check logs
kubectl logs -n spark-staging job/spark-pi-test
```

**Test Cases:**
- [ ] Spark SQL query completes successfully
- [ ] Parquet file reads work
- [ ] Job writes to MinIO successfully
- [ ] Hive table access works

#### 6. RTO/RPO Measurement (14:00-15:00)

Record metrics:
```
| Component       | RTO (actual) | RTO (target) | RPO (actual) | RPO (target) |
|-----------------|--------------|--------------|--------------|--------------|
| Hive Metastore  | __ min       | 30 min       | __ min       | 60 min       |
| MinIO Data      | __ min       | 240 min      | __ min       | 60 min       |
| Airflow         | __ min       | 30 min       | __ min       | 60 min       |
```

#### 7. Post-Test Review (15:00-16:00)

Discuss and document:
- What worked well
- What failed
- Action items for improvement
- Changes to procedures needed

### Post-Test Actions

1. **Clean up staging environment**
   ```bash
   kubectl delete ns spark-staging
   ```

2. **Generate test report**
   ```bash
   ./scripts/operations/backup/generate-dr-test-report.sh \
     --date "$TEST_DATE" \
     --output reports/dr-test-$(date +%Y%m%d).md
   ```

3. **Update documentation**
   - Document any procedure changes
   - Update RTO/RPO measurements
   - Record lessons learned

4. **Create action items** for any failures or improvements needed

## Quarterly Full-Scale Test

### Test Plan

**Duration:** 2 days

**Scope:**
- Complete cluster provisioning in DR region
- Full data restore from backups
- Application deployment and testing
- Performance testing with production-like load

### Day 1: Infrastructure and Data Restore

| Time | Activity |
|------|----------|
| 08:00-10:00 | Provision DR cluster |
| 10:00-12:00 | Restore all backups |
| 13:00-15:00 | Deploy applications |
| 15:00-17:00 | Smoke testing |

### Day 2: Load Testing and Failback

| Time | Activity |
|------|----------|
| 08:00-10:00 | Deploy load testing tools |
| 10:00-12:00 | Run load tests |
| 13:00-15:00 | Performance analysis |
| 15:00-17:00 | Failback to primary |

## Success Criteria

### Monthly Test

- [ ] All components restored successfully
- [ ] RTO targets met (Hive < 30m, MinIO < 4h, Airflow < 30m)
- [ ] RPO targets met (all < 1h)
- [ ] Functional tests pass
- [ ] No data corruption detected
- [ ] Test report completed

### Quarterly Test

- [ ] All monthly criteria plus:
- [ ] Performance within 80% of production
- [ ] No manual intervention required
- [ ] Documentation updated

### Annual Test

- [ ] All quarterly criteria plus:
- [ ] 24-hour DR operation successful
- [ ] Failback completed without data loss
- [ ] Team training completed

## Failure Handling

### Test Failure Procedure

1. **Stop the test** if critical failure occurs
2. **Document the failure** in incident tracking
3. **Root cause analysis** within 24 hours
4. **Create improvement plan**
5. **Retest** within 30 days

### Common Failure Scenarios

| Scenario | Action | Prevention |
|----------|--------|------------|
| Backup corrupt | Restore from previous backup | Multiple backup copies |
| Storage quota | Pre-allocate sufficient storage | Monitor usage |
| Network issues | Verify DR network connectivity | Regular connectivity tests |
| Schema mismatch | Validate schema before restore | Automated schema checks |

## Notifications

### Pre-Test Notification (3 days before)

```
Subject: DR Test Scheduled - [Date]

Team,

This is a reminder that the monthly DR test is scheduled for [Date].

Staging will be unavailable 09:00-16:00.

Please plan accordingly.
```

### Test Results Notification (within 24 hours)

```
Subject: DR Test Results - [Date]

Team,

The monthly DR test completed [SUCCESSFULLY / WITH ISSUES].

Summary:
- Hive Metastore: [PASS/FAIL] - RTO: [X] min
- MinIO Data: [PASS/FAIL] - RTO: [X] min
- Airflow: [PASS/FAIL] - RTO: [X] min

[Attach detailed report]
```

## Dashboard

Monitor DR test status on Grafana:
- Dashboard: `backup-status.json`
- Panel: DR Test Status
- Panel: RTO/RPO Measurements

## References

- [Backup Verification](./backup-verification.md)
- [Restore Procedure](./restore-procedure.md)
- [Incident Response](../incidents/incident-response.md)
