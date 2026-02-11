# Shuffle Failure Runbook

> **Severity:** P1 - Performance Degraded
> **Automation:** `scripts/operations/spark/diagnose-shuffle-failure.sh`
> **Alert:** `SparkShuffleFailure`

## Overview

Shuffle failures occur when Spark cannot transfer data between stages. This is especially common when using Celeborn shuffle service. Failures can cause job slowdowns or complete failures.

## Detection

### Prometheus Alerts

```yaml
- alert: SparkShuffleFailure
  expr: rate(spark_shuffle_fetch_failures_total[5m]) > 0.1
  for: 5m
  labels:
    severity: warning
  annotations:
    runbook: "docs/operations/runbooks/spark/shuffle-failure.md"

- alert: SparkShuffleServiceDown
  expr: up{job="celeborn"} == 0
  for: 1m
  labels:
    severity: critical
  annotations:
    runbook: "docs/operations/runbooks/spark/shuffle-failure.md"

- alert: CelebornWorkerDown
  expr: celeborn_worker_alive == 0
  for: 2m
  labels:
    severity: critical
  annotations:
    runbook: "docs/operations/runbooks/spark/shuffle-failure.md"
```

### Manual Detection

```bash
# Check for shuffle fetch failures
kubectl logs <executor-pod> -n <namespace> --tail=1000 | grep -i "shuffle.*fail\|fetch.*fail"

# Check Celeborn status
kubectl get celeborncluster -n <namespace>
kubectl get pods -l app=celeborn -n <namespace>
```

## Diagnosis

### Quick Check Script

```bash
scripts/operations/spark/diagnose-shuffle-failure.sh <namespace> <app-name>
```

### Manual Diagnosis Steps

#### 1. Identify Failure Type

```bash
# Check executor logs for shuffle errors
kubectl logs <executor-pod> -n <namespace> --tail=1000 | grep -i "fetchfailedexception\|shuffle"

# Check if using Celeborn
kubectl get sparkapplication <app-name> -n <namespace> -o json | jq -r '.spec.sparkConf | keys | .[] | select(contains("celeborn"))'

# Common patterns:
# - FetchFailedException (built-in shuffle)
# - Celeborn RPC errors (Celeborn shuffle)
# - Connection refused (network issues)
```

#### 2. Check Celeborn Status (if using Celeborn)

```bash
# Check Celeborn workers
kubectl get pods -l app=celeborn-worker -n <namespace>

# Check Celeborn master status
kubectl exec -it <celeborn-master-pod> -n <namespace> -- \
  curl -s http://localhost:9097/api/v1/workers

# Check Celeborn metrics
kubectl exec -it <celeborn-worker-pod> -n <namespace> -- \
  curl -s http://localhost:9096/metrics | grep shuffle
```

#### 3. Check Network Connectivity

```bash
# Test connectivity between executors
EXECUTOR_1=<executor-pod-1>
EXECUTOR_2=<executor-pod-2>

kubectl exec -it $EXECUTOR_1 -n <namespace> -- \
  ping -c 3 $(kubectl get pod $EXECUTOR_2 -n <namespace> -o jsonpath='{.status.podIP}')

# Check network policies
kubectl get networkpolicies -n <namespace> -o yaml | grep -A 5 -B 5 spark
```

#### 4. Check Disk Space

```bash
# Check worker disk space (for Celeborn or built-in shuffle)
kubectl exec -it <executor-pod> -n <namespace> -- df -h

# Check Celeborn worker storage
kubectl exec -it <celeborn-worker-pod> -n <namespace> -- df -h /mnt/celeborn
```

## Remediation

### Scenario 1: Built-in Shuffle Service Failures

**Symptoms:**
- `FetchFailedException`
- `Connection refused` from peer executors
- Flaky network connectivity

**Action:**

```bash
# Increase shuffle retry settings
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '
{
  "spec": {
    "sparkConf": {
      "spark.shuffle.fetch.retry.count": "5",
      "spark.shuffle.fetch.retry.waitMs": "5000",
      "spark.shuffle.fetch.retry.maxWaitTimeMs": "60000",
      "spark.reducer.maxSizeInFlight": "96m",
      "spark.shuffle.maxChunksBeingTransferred": "2147483647"
    }
  }
}'

# Enable shuffle service
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '
{
  "spec": {
    "sparkConf": {
      "spark.shuffle.service.enabled": "true"
    }
  }
}'
```

### Scenario 2: Celeborn Worker Down

**Symptoms:**
- `Celeborn RPC timeout`
- Cannot connect to Celeborn worker
- Lost shuffle data

**Action:**

```bash
# Check worker status
kubectl get pods -l app=celeborn-worker -n <namespace>

# Restart failed worker
kubectl delete pod <celeborn-worker-pod> -n <namespace>

# Check if Celeborn cluster needs scaling
kubectl get celeborncluster -n <namespace> -o yaml

# Scale workers if needed
kubectl patch celeborncluster celeborn -n <namespace> --type=merge -p '
{
  "spec": {
    "worker": {
      "replicas": 5
    }
  }
}'
```

### Scenario 3: Celeborn Master Issues

**Symptoms:**
- Cannot register new workers
- Shuffle allocation failures
- Leadership issues

**Action:**

```bash
# Check master logs
kubectl logs -l app=celeborn-master -n <namespace> --tail=1000

# Restart master (if HA enabled, will failover gracefully)
kubectl delete pod -l app=celeborn-master -n <namespace>

# Check master configuration
kubectl get configmap celeborn-config -n <namespace] -o yaml
```

### Scenario 4: Shuffle Disk Full

**Symptoms:**
- `No space left on device`
- Cannot write shuffle files
- Disk pressure on nodes

**Action:**

```bash
# For built-in shuffle: Clean old shuffle files
kubectl exec -it <node-daemonset> -n <kube-system> -- \
  find /mnt/shuffle -type f -mtime +1 -delete

# For Celeborn: Clean old shuffle data
kubectl exec -it <celeborn-worker-pod> -n <namespace> -- \
  find /mnt/celeborn/shuffle -type f -mtime +1 -delete

# Configure Celeborn for automatic cleanup
kubectl patch celeborncluster celeborn -n <namespace> --type=merge -p '
{
  "spec": {
    "worker": {
      "config": [
        {
          "name": "celeborn.worker.flusher.threads",
          "value": "40"
        },
        {
          "name": "celeborn.worker.storage.cleaner.interval",
          "value": "300"
        }
      ]
    }
  }
}'

# Add disk monitoring
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: celeborn-shuffle-pvc
  namespace: <namespace>
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 100Gi
EOF
```

### Scenario 5: Large Shuffle Files

**Symptoms:**
- Shuffle files too large
- Long fetch times
- OOM during shuffle

**Action:**

```bash
# Increase shuffle partitions
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '
{
  "spec": {
    "sparkConf": {
      "spark.sql.shuffle.partitions": "400",
      "spark.default.parallelism": "400"
    }
  }
}'

# Enable compression
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '
{
  "spec": {
    "sparkConf": {
      "spark.shuffle.compress": "true",
      "spark.shuffle.spill.compress": "true",
      "spark.io.compression.codec": "snappy"
    }
  }
}'

# For Celeborn: Configure chunk size
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '
{
  "spec": {
    "sparkConf": {
      "spark.celebn.shuffle.chunk.size": "8m",
      "spark.celebn.shuffle.writer.buffer.size": "3m"
    }
  }
}'
```

### Scenario 6: Network Issues During Shuffle

**Symptoms:**
- Intermittent connection failures
- `Broken pipe` errors
- High shuffle fetch latency

**Action:**

```bash
# Increase network timeout
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '
{
  "spec": {
    "sparkConf": {
      "spark.network.timeout": "800s",
      "spark.sql.broadcastTimeout": "1200",
      "spark.shuffle.io.connectionTimeout": "120s"
    }
  }
}'

# Check for CNI issues
kubectl logs -n kube-system -l k8s-app=calico-node --tail=100

# For Celeborn: Enable push shuffle mode (more resilient)
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '
{
  "spec": {
    "sparkConf": {
      "spark.celebn.shuffle.push.mode": "true",
      "spark.celebn.shuffle.push.threads": "50"
    }
  }
}'
```

### Scenario 7: Shuffle Service Not Found

**Symptoms:**
- `Shuffle service not registered`
- Cannot connect to shuffle service

**Action:**

```bash
# Verify shuffle service is running
kubectl get pods -l app=spark-shuffle-service -n <namespace>

# Deploy shuffle service if missing
kubectl apply -f charts/spark/shuffle-service/

# Verify connection from executors
kubectl exec -it <executor-pod> -n <namespace> -- \
  nc -vz spark-shuffle-service 7337
```

## Recovery Scripts

### Automated Recovery

```bash
# Idempotent shuffle recovery script
scripts/operations/spark/fix-shuffle-failure.sh <namespace> <app-name>

# This will:
# 1. Detect shuffle service type (built-in or Celeborn)
# 2. Check shuffle service health
# 3. Apply appropriate remediation
# 4. Monitor for successful retry
```

### Celeborn-Specific Recovery

```bash
# Restart Celeborn workers safely
scripts/operations/spark/restart-celeborn-worker.sh <namespace>

# Migrate to Celeborn if not using it
scripts/operations/spark/migrate-to-celeborn.sh <namespace> <app-name>
```

## Prevention

### 1. Use Celeborn Shuffle Service

```yaml
sparkConf:
  spark.shuffle.service.enabled: "false"
  spark.shuffle.service.factory: "org.apache.spark.deployCelebornShuffleServiceFactory"
  spark.celebn.master.endpoints: "celeborn-master:9097"
```

### 2. Configure Adequate Resources

```yaml
# Celeborn worker storage
worker:
  replicas: 3
  storage:
    - type: "emptyDir"
      name: "shuffle"
      size: "50Gi"
```

### 3. Enable Shuffle Monitoring

```yaml
# Add Prometheus annotations
podTemplate:
  metadata:
    annotations:
      prometheus.io/scrape: "true"
      prometheus.io/port: "9096"
```

### 4. Configure Sensible Partitions

```yaml
sparkConf:
  spark.sql.shuffle.partitions: "200"
  spark.sql.adaptive.enabled: "true"
  spark.sql.adaptive.coalescePartitions.enabled: "true"
```

## Monitoring

### Grafana Dashboard Queries

```promql
# Shuffle read/write bytes
rate(spark_shuffle_read_bytes_total[5m])
rate(spark_shuffle_write_bytes_total[5m])

# Shuffle fetch failures
rate(spark_shuffle_fetch_failures_total[5m])

# Celeborn worker metrics
celeborn_worker_shuffle_bytes_written
celeborn_worker_shuffle_bytes_read
celeborn_worker_active_partitions
```

## Related Runbooks

- [Executor Failures](executor-failures.md)
- [Task Failure Recovery](task-failure-recovery.md)
- [OOM Kill Mitigation](oom-kill-mitigation.md)

## Escalation

| Time | Action |
|------|--------|
| 5 min | Check shuffle service health |
| 15 min | If Celeborn workers down, restart |
| 30 min | If persistent issues, escalate to Platform team |

## Changelog

| Date | Change |
|------|--------|
| 2025-02-11 | Initial version |
