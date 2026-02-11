# MinIO Volume Recovery Runbook

## Overview

This runbook covers the detection, diagnosis, and remediation of MinIO data loss, volume corruption, or node failure scenarios.

## Detection

### Symptoms

| Symptom | Severity | Description |
|---------|----------|-------------|
| `No such file or directory` | Critical | Files not accessible from MinIO |
| `XFS corruption` | Critical | Filesystem corruption detected |
| Volume offline | Critical | MinIO volume showing as offline |
| Health check failed | High | MinIO health check returning errors |
| Data unavailable | High | Applications cannot access data |

### Detection Commands

```bash
# Check MinIO pod status
kubectl get pods -n spark-operations -l app=minio

# Check MinIO health
kubectl exec -n spark-operations minio-0 -- curl http://localhost:9000/minio/health/live

# Check volume status
kubectl exec -n spark-operations minio-0 -- mc admin info myminio

# Check for offline drives
kubectl exec -n spark-operations minio-0 -- mc admin heal myminio --dry-run

# Check MinIO logs
kubectl logs -n spark-operations minio-0 --tail=100
```

### Volume Health Check

```bash
# Check disk space
kubectl exec -n spark-operations minio-0 -- df -h /data

# Check for I/O errors
kubectl exec -n spark-operations minio-0 -- dmesg | grep -i error

# Check for filesystem errors
kubectl exec -n spark-operations minio-0 -- xfs_repair -n /dev/xvda1

# Check MinIO cluster status
kubectl exec -n spark-operations minio-0 -- mc admin info myminio --json
```

### Grafana Dashboard Queries

```promql
# MinIO health status
minio_health_status

# MinIO disk usage
minio_disk_used_bytes / minio_disk_total_bytes

# MinIO I/O operations
rate(minio_io_operations_total[5m])

# MinIO network I/O
rate(minio_network_bytes_sent[5m])
rate(minio_network_bytes_received[5m])

# MinIO error rate
rate(minio_errors_total[5m])
```

---

## Diagnosis

### Step 1: Identify Affected Volume/Node

```bash
# Get MinIO pods
kubectl get pods -n spark-operations -l app=minio -o wide

# Check which nodes are affected
kubectl get nodes -o custom-columns=NAME:.metadata.name,STATUS:.status.conditions[-1].reason

# Check MinIO cluster status
kubectl exec -n spark-operations minio-0 -- mc admin info myminio

# Check for offline drives
kubectl exec -n spark-operations minio-0 -- mc admin info myminio | grep "Offline"
```

### Step 2: Verify Data Access

```bash
# List buckets
kubectl exec -n spark-operations minio-0 -- mc ls myminio

# Check specific bucket
kubectl exec -n spark-operations minio-0 -- mc ls myminio/spark-data

# Try to download a test file
kubectl exec -n spark-operations minio-0 -- mc cp myminio/spark-data/test.txt /tmp/

# Check for corrupted files
kubectl exec -n spark-operations minio-0 -- mc find myminio/spark-data --name "*.corrupt"
```

### Step 3: Check Volume Mount Status

```bash
# Check PVC status
kubectl get pvc -n spark-operations -l app=minio

# Check PV status
kubectl get pv | grep minio

# Check volume mount on pod
kubectl exec -n spark-operations minio-0 -- mount | grep data

# Check for volume errors
kubectl describe pvc -n spark-operations minio-data-minio-0
```

### Step 4: Check Storage Class

```bash
# Check storage class
kubectl get storageclass

# Check PV reclaim policy
kubectl get pv -o custom-columns=NAME:.metadata.name,RECLAIM:.spec.persistentVolumeReclaimPolicy

# Check provisioner
kubectl get storageclass -o custom-columns=NAME:.metadata.name,PROVISIONER:.provisioner
```

### Step 5: Identify Recovery Point

```bash
# List available backups
aws s3 ls s3://spark-backups-minio/minio-data/

# Find backup before incident
BACKUP_DATE=$(date -d '1 day ago' +%Y%m%d)
aws s3 ls s3://spark-backups-minio/minio-data/ | grep $BACKUP_DATE

# Check backup integrity
aws s3 cp s3://spark-backups-minio/minio-data/backup-20260210.tar.gz /tmp/
tar -tzf /tmp/backup-20260210.tar.gz | head -20
```

---

## Remediation

### Option 1: Restart MinIO Pod (For transient issues)

**Time to recover**: 5-10 minutes
**Data loss**: None

```bash
# 1. Stop MinIO pod
kubectl delete pod -n spark-operations minio-0

# 2. Wait for pod to restart
kubectl wait --for=condition=ready pod -n spark-operations -l app=minio --timeout=300s

# 3. Verify MinIO is healthy
kubectl exec -n spark-operations minio-0 -- mc admin info myminio

# 4. Check data access
kubectl exec -n spark-operations minio-0 -- mc ls myminio/spark-data
```

### Option 2: Restore from Volume Snapshot (For AWS EBS/Azure Disk)

**Time to recover**: 15-30 minutes
**Data loss**: Up to snapshot interval

```bash
# 1. Identify affected PV
kubectl get pvc -n spark-operations minio-data-minio-0 -o jsonpath='{.spec.volumeName}'

# 2. Find snapshot
aws ec2 describe-snaplights \
  --filters Name=volume-id,Values=<volume-id> \
  --query 'Snapshots[*].[SnapshotId,StartTime]' \
  --output table | sort -k2 -r | head -5

# 3. Create volume from snapshot
aws ec2 create-volume \
  --snapshot-id snap-xxxxxxxx \
  --availability-zone us-east-1a \
  --volume-type gp3 \
  --size 100

# 4. Update PV with new volume
kubectl patch pv <pv-name> -p '{"spec":{"awsElasticBlockStore":{"volumeID":"vol-xxxxxx"}}}'

# 5. Restart MinIO pod
kubectl delete pod -n spark-operations minio-0

# 6. Verify data
kubectl exec -n spark-operations minio-0 -- mc ls myminio/spark-data
```

### Option 3: Restore from Backup (For complete data loss)

**Time to recover**: 1-2 hours
**Data loss**: Up to RPO (24 hours)

```bash
# 1. Scale down MinIO
kubectl scale statefulset minio --replicas=0 -n spark-operations

# 2. Download backup
aws s3 cp s3://spark-backups-minio/minio-data/backup-20260210.tar.gz /tmp/

# 3. Verify backup integrity
tar -tzf /tmp/backup-20260210.tar.gz > /tmp/backup-manifest.txt
cat /tmp/backup-manifest.txt

# 4. Run restore script
scripts/operations/recovery/restore-minio-volume.sh \
  --backup /tmp/backup-20260210.tar.gz \
  --namespace spark-operations

# 5. Scale up MinIO
kubectl scale statefulset minio --replicas=1 -n spark-operations

# 6. Wait for MinIO to be ready
kubectl wait --for=condition=ready pod -n spark-operations -l app=minio --timeout=300s

# 7. Verify data
scripts/operations/recovery/verify-data-integrity.sh --bucket minio --prefix spark-data/
```

### Option 4: Rebuild MinIO Cluster (For node failure)

**Time to recover**: 2-4 hours
**Data loss**: None (if erasure coding enabled)

```bash
# 1. Identify failed node
kubectl exec -n spark-operations minio-0 -- mc admin info myminio

# 2. Remove failed node from cluster
kubectl delete pod -n spark-operations minio-1

# 3. Create new PVC for replacement node
kubectl apply -f manifests/minio-pvc-replacement.yaml

# 4. Wait for new pod to start
kubectl wait --for=condition=ready pod -n spark-operations minio-1 --timeout=300s

# 5. Add new node to cluster
kubectl exec -n spark-operations minio-0 -- mc admin info myminio

# 6. Trigger rebalance
kubectl exec -n spark-operations minio-0 -- mc admin heal myminio --recursive

# 7. Monitor heal progress
kubectl exec -n spark-operations minio-0 -- mc admin heal myminio --monitor
```

### Option 5: Filesystem Repair (For filesystem corruption)

**Time to recover**: 30-60 minutes
**Data loss**: Possible (depends on corruption extent)

```bash
# 1. Unmount filesystem
kubectl exec -n spark-operations minio-0 -- umount /data

# 2. Run filesystem check
kubectl exec -n spark-operations minio-0 -- xfs_repair -n /dev/xvda1

# 3. If repair needed, run repair
kubectl exec -n spark-operations minio-0 -- xfs_repair /dev/xvda1

# 4. Remount filesystem
kubectl exec -n spark-operations minio-0 -- mount -a

# 5. Restart MinIO
kubectl delete pod -n spark-operations minio-0

# 6. Verify data integrity
scripts/operations/recovery/verify-data-integrity.sh --bucket minio
```

---

## Verification

### Post-Restore Checks

```bash
# 1. Verify MinIO is healthy
kubectl exec -n spark-operations minio-0 -- mc admin info myminio

# 2. Check all buckets
kubectl exec -n spark-operations minio-0 -- mc ls myminio

# 3. Verify data counts
for bucket in spark-data spark-output-data spark-checkpoint; do
  echo "Bucket: $bucket"
  kubectl exec -n spark-operations minio-0 -- mc ls myminio/$bucket --recursive | wc -l
done

# 4. Check for corrupted files
kubectl exec -n spark-operations minio-0 -- mc find myminio/spark-data --name "*.tmp"

# 5. Verify data integrity
scripts/operations/recovery/verify-data-integrity.sh --bucket minio --check-checksum
```

### Test Application Access

```bash
# 1. Create test file
kubectl exec -n spark-operations minio-0 -- sh -c 'echo "test" > /tmp/test.txt'

# 2. Upload to MinIO
kubectl exec -n spark-operations minio-0 -- mc cp /tmp/test.txt myminio/spark-data/test.txt

# 3. Download from MinIO
kubectl exec -n spark-operations minio-0 -- mc cp myminio/spark-data/test.txt /tmp/downloaded.txt

# 4. Verify content
kubectl exec -n spark-operations minio-0 -- cat /tmp/downloaded.txt

# 5. Test Spark read
kubectl apply -f tests/integration/minio-read-test-job.yaml
```

---

## Prevention

### 1. Enable Volume Snapshots

```yaml
# Volume snapshot class
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: minio-snapshot
driver: ebs.csi.aws.com
deletionPolicy: Retain
parameters:
  type: gp3
```

### 2. Configure Snapshot Schedule

```yaml
# CronJob for daily snapshots
apiVersion: batch/v1
kind: CronJob
metadata:
  name: minio-snapshot
  namespace: spark-operations
spec:
  schedule: "0 3 * * *"  # 3 AM UTC
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: snapshot
            image: amazon/aws-cli:latest
            command:
            - /scripts/create-minio-snapshot.sh
            env:
            - name: PVC_NAME
              value: minio-data-minio-0
            - name: SNAPSHOT_RETENTION
              value: "7"
```

### 3. Enable Erasure Coding

```bash
# Create MinIO with erasure coding
mc admin config set myminio erasure EC_K=4
mc admin config set myminio erasure EC_M=4
mc admin service restart myminio

# Verify erasure coding
mc admin info myminio | grep Erasure
```

### 4. Enable Bitrot Protection

```bash
# Enable bitrot protection
mc admin config set myminio cache drive
mc admin config set myminio cache expiry 90
mc admin service restart myminio
```

### 5. Implement Regular Backups

```bash
# Daily backup to external S3
mc mirror myminio/spark-data s3://spark-backups-minio/spark-data/ \
  --overwrite \
  --remove \
  --md5

# Schedule via CronJob
kubectl apply -f manifests/minio-backup-cronjob.yaml
```

### 6. Monitor Volume Health

```yaml
# Prometheus alerts
groups:
  - name: minio
    rules:
      - alert: MinIOVolumeOffline
        expr: minio_disk_offline > 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "MinIO volume offline"

      - alert: MinIOStorageLow
        expr: minio_disk_used_bytes / minio_disk_total_bytes > 0.85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "MinIO storage above 85%"
```

---

## Monitoring

### Key Metrics

| Metric | Description | Alert Threshold |
|--------|-------------|-----------------|
| `minio_health_status` | MinIO health | != 1 |
| `minio_disk_offline` | Offline drives | > 0 |
| `minio_storage_used_percent` | Storage usage | > 85% |
| `minio_io_errors_total` | I/O errors | > 100/min |
| `minio_network_errors_total` | Network errors | > 50/min |

### Grafana Dashboard Queries

```promql
# MinIO health status
minio_health_status

# Storage usage percentage
(minio_disk_used_bytes / minio_disk_total_bytes) * 100

# I/O operation rate
rate(minio_io_operations_total[5m])

# Error rate
rate(minio_errors_total[5m])

# Network throughput
rate(minio_network_bytes_sent[5m])
rate(minio_network_bytes_received[5m])

# Disk latency
rate(minio_io_duration_seconds_sum[5m]) / rate(minio_io_duration_seconds_count[5m])
```

---

## Escalation

### Escalation Path

1. **Level 1**: Operations Team (initial diagnosis, 15 min SLA)
2. **Level 2**: Storage Team (volume issues, 1 hour SLA)
3. **Level 3**: Cloud Team (infrastructure issues, 4 hour SLA)
4. **Level 4**: Database Team (data recovery, 24/7 on-call)

### Contact Information

| Team | Contact | Availability |
|------|---------|---------------|
| Operations | `#ops-team` | 24/7 |
| Storage Team | `#storage-team` | Business hours |
| Cloud Team | `#cloud-team` | 24/7 |
| Database Team | `#db-team-oncall` | 24/7 |

---

## Related Runbooks

- [Hive Metastore Restore](./hive-metastore-restore.md)
- [S3 Object Restore](./s3-object-restore.md)
- [Data Integrity Check](./data-integrity-check.md)
- [Restore Procedure](../../procedures/backup-dr/restore-procedure.md)

---

## References

- [MinIO Healing](https://docs.min.io/docs/minio-server-healing-guide.html)
- [MinIO Erasure Coding](https://docs.min.io/docs/minio-erasure-code-calculator.html)
- [Kubernetes Volume Snapshots](https://kubernetes.io/docs/concepts/storage/volume-snapshots/)
- [EBS Snapshots](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/EBSSnapshots.html)
