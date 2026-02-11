# Task Failure Recovery Runbook

> **Severity:** P1 - Performance Degraded
> **Automation:** `scripts/operations/spark/diagnose-task-failure.sh`
> **Alert:** `SparkTaskFailureRate`

## Overview

Task failures occur when individual Spark tasks fail during execution. While Spark retries failed tasks, excessive task failures can cause stage failures and job failures.

## Detection

### Prometheus Alerts

```yaml
- alert: SparkTaskFailureRate
  expr: rate(spark_stage_failedTasks_total[5m]) > 10
  for: 5m
  labels:
    severity: warning
  annotations:
    runbook: "docs/operations/runbooks/spark/task-failure-recovery.md"

- alert: SparkStageFailure
  expr: increase(spark_stage_failed_tasks_total[5m]) > 100
  for: 2m
  labels:
    severity: critical
  annotations:
    runbook: "docs/operations/runbooks/spark/task-failure-recovery.md"
```

### Manual Detection

```bash
# Check Spark UI for failed tasks
kubectl port-forward <driver-pod> 4040:4040 -n <namespace>

# Check via API
curl -s http://localhost:4040/api/v1/applications/<app-id>/stages | jq '.[] | select(.numFailedTasks > 0)'
```

## Diagnosis

### Quick Check Script

```bash
scripts/operations/spark/diagnose-task-failure.sh <namespace> <app-name>
```

### Manual Diagnosis Steps

#### 1. Check Failed Tasks

```bash
# Get stage information
curl -s http://<driver-pod>.<namespace>.svc:4040/api/v1/applications/<app-id>/stages | jq .

# Get task details for failed stage
STAGE_ID=<failed-stage-id>
ATTEMPT=<attempt-id>
curl -s http://<driver-pod>.<namespace>.svc:4040/api/v1/applications/<app-id>/stages/$STAGE_ID/$ATTEMPT/taskList | jq '.[] | select(.failed == true)'
```

#### 2. Check Task Logs

```bash
# Get executor pod for failed task
EXECUTOR_POD=<executor-pod-name>

# Check executor logs
kubectl logs $EXECUTOR_POD -n <namespace> --tail=1000 | grep -i "error\|exception"

# Check specific task attempt
kubectl logs $EXECUTOR_POD -n <namespace> --tail=1000 | grep -A 10 "task $TASK_ID"
```

#### 3. Analyze Failure Pattern

```bash
# Check if failures are localized to specific executors
curl -s http://<driver-pod>.<namespace>.svc:4040/api/v1/applications/<app-id>/executors | \
  jq '.[] | {id: .id, hostPort: .hostPort, failedTasks: .failedTasks, activeTasks: .activeTasks}'

# Check if same task fails consistently
curl -s http://<driver-pod>.<namespace>.svc:4040/api/v1/applications/<app-id>/stages/$STAGE_ID/$ATTEMPT/taskList | \
  jq '[.[] | select(.failed == true)] | group_by(.index) | map({index: .[0].index, attempts: length}) | sort_by(.attempts) | reverse'
```

#### 4. Check Error Types

```bash
# Common error patterns in logs
kubectl logs <executor-pod> -n <namespace> --tail=1000 | grep -i "exception" | sort | uniq -c

# Check for specific errors
kubectl logs <executor-pod> -n <namespace> --tail=1000 | grep -i "timeout\|connection\|classnotfound\|oom\|shuffle"
```

## Remediation

### Scenario 1: Transient Network Errors

**Symptoms:**
- `java.net.UnknownHostException`
- `java.net.ConnectException`
- `java.io.IOException: Connection reset`

**Action:**

```bash
# Increase timeout settings
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '
{
  "spec": {
    "sparkConf": {
      "spark.network.timeout": "800s",
      "spark.executor.heartbeatInterval": "60s",
      "spark.storageBlockManagerTimeoutIntervalMs": "600000"
    }
  }
}'

# Increase retry attempts
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '
{
  "spec": {
    "sparkConf": {
      "spark.task.maxFailures": "8",
      "spark.speculation": "true"
    }
  }
}'
```

### Scenario 2: Shuffle Fetch Failures

**Symptoms:**
- `org.apache.spark.shuffle.FetchFailedException`
- `Connection refused` from peer executors
- Tasks fail on reduce stages

**Action:**

```bash
# Increase shuffle fetch retry
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '
{
  "spec": {
    "sparkConf": {
      "spark.shuffle.fetch.retry.count": "5",
      "spark.shuffle.fetch.retry.waitMs": "5000",
      "spark.reducer.maxSizeInFlight": "96m"
    }
  }
}'

# Enable shuffle service if not already
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '
{
  "spec": {
    "sparkConf": {
      "spark.shuffle.service.enabled": "true"
    }
  }
}'

# See Shuffle Failure runbook for more details
```

### Scenario 3: Executor Loss

**Symptoms:**
- `ExecutorLostFailure`
- Tasks fail because executor disappeared
- `Slave lost` errors

**Action:**

```bash
# This is typically an infrastructure issue
# See Executor Failures runbook for diagnosis

# Quick mitigation: Enable speculation
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '
{
  "spec": {
    "sparkConf": {
      "spark.speculation": "true",
      "spark.speculation.multiplier": "2",
      "spark.speculation.quantile": "0.9"
    }
  }
}'
```

### Scenario 4: Serialized Task Errors

**Symptoms:**
- `java.io.NotSerializableException`
- `java.io.InvalidClassException`
- Task serialization failures

**Action:**

```bash
# This is a code issue - fix required in application
# Workaround: Use Kryo serialization
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '
{
  "spec": {
    "sparkConf": {
      "spark.serializer": "org.apache.spark.serializer.KryoSerializer",
      "spark.kryo.registrationRequired": "false"
    }
  }
}'
```

### Scenario 5: Class Not Found

**Symptoms:**
- `java.lang.ClassNotFoundException`
- `java.lang.NoClassDefFoundError`
- Dependencies missing from classpath

**Action:**

```bash
# Verify dependencies are included
kubectl exec -it <driver-pod> -n <namespace> -- ls -la /opt/spark/jars/

# Add missing dependencies via SparkApplication config
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '
{
  "spec": {
    "deps": {
      "jars": [
        "s3://my-bucket/jars/missing-dependency.jar"
      ]
    }
  }
}'

# Or use packages
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '
{
  "spec": {
    "sparkConf": {
      "spark.jars.packages": "com.example:library:1.0.0"
    }
  }
}'
```

### Scenario 6: Out of Memory in Task

**Symptoms:**
- `java.lang.OutOfMemoryError` in task
- `Container killed` in executor
- Individual task memory issues

**Action:**

```bash
# Increase memory per executor (more memory per task)
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '
{
  "spec": {
    "executor": {
      "memory": "8g",
      "memoryOverhead": "2g"
    },
    "sparkConf": {
      "spark.executor.memory": "8g",
      "spark.task.memory": "2g",
      "spark.executor.memoryOverhead": "2g"
    }
  }
}'

# Reduce cores (less parallel tasks per executor, more memory each)
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '
{
  "spec": {
    "executor": {
      "cores": 1
    }
  }
}'

# See OOM Kill Mitigation runbook for more details
```

### Scenario 7: Task Timeout

**Symptoms:**
- `TaskKilled` due to timeout
- Tasks take too long to complete
- Speculation kills slow tasks

**Action:**

```bash
# Increase task timeout
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '
{
  "spec": {
    "sparkConf": {
      "spark.task.maxFailures": "8",
      "spark.speculation.multiplier": "3"
    }
  }
}'

# Check for data skew
kubectl port-forward <driver-pod> 4040:4040 -n <namespace>
# Review task duration distribution in UI

# Mitigate data skew
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '
{
  "spec": {
    "sparkConf": {
      "spark.sql.adaptive.enabled": "true",
      "spark.sql.adaptive.skewJoin.enabled": "true",
      "spark.sql.adaptive.skewJoin.skewedPartitionThresholdInBytes": "256m"
    }
  }
}'
```

### Scenario 8: Hadoop/HDFS Errors

**Symptoms:**
- `org.apache.hadoop.ipc.RemoteException`
- HDFS connection errors
- File not found errors

**Action:**

```bash
# Check HDFS/Hadoop service availability
kubectl exec -it <driver-pod> -n <namespace> -- hdfs dfs -ls /path/to/data

# Increase Hadoop retry settings
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '
{
  "spec": {
    "sparkConf": {
      "spark.hadoop.fs.defaultFS.retry.policy": " exponential.backoff",
      "spark.hadoop.fs.defaultFS.retry.interval.ms": "1000",
      "spark.hadoop.fs.defaultFS.retry.limit": "10"
    }
  }
}'
```

## Recovery Scripts

### Automated Recovery

```bash
# Idempotent task failure recovery script
scripts/operations/spark/recover-task-failure.sh <namespace> <app-name>

# This will:
# 1. Analyze failure pattern
# 2. Apply appropriate configuration changes
# 3. Monitor for improvement
```

### Manual Retry

```bash
# Retry failed stage via Spark UI
# Or restart application
kubectl delete sparkapplication <app-name> -n <namespace>
kubectl apply -f <app-config>.yaml
```

## Prevention

### 1. Enable Adaptive Query Execution

```yaml
sparkConf:
  spark.sql.adaptive.enabled: "true"
  spark.sql.adaptive.coalescePartitions.enabled: "true"
  spark.sql.adaptive.skewJoin.enabled: "true"
```

### 2. Enable Speculation

```yaml
sparkConf:
  spark.speculation: "true"
  spark.speculation.quantile: "0.9"
  spark.speculation.multiplier: "2"
```

### 3. Set Appropriate Retries

```yaml
sparkConf:
  spark.task.maxFailures: "8"
  spark.stage.maxConsecutiveAttempts: "4"
```

### 4. Monitor Data Skew

```bash
# Identify skewed partitions
scripts/operations/spark/check-skew.sh <namespace> <app-name>
```

## Related Runbooks

- [Executor Failures](executor-failures.md)
- [OOM Kill Mitigation](oom-kill-mitigation.md)
- [Shuffle Failure](shuffle-failure.md)

## Escalation

| Time | Action |
|------|--------|
| 5 min | Check for common patterns |
| 15 min | If failure rate > 50%, investigate immediately |
| 30 min | If code issue, escalate to development team |

## Changelog

| Date | Change |
|------|--------|
| 2025-02-11 | Initial version |
