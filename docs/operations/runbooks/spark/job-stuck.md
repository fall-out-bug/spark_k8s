# Job Stuck Runbook

> **Severity:** P2 - Service Degraded
> **Automation:** `scripts/operations/spark/diagnose-stuck-job.sh`
> **Alert:** `SparkJobStuck`

## Overview

A job is considered "stuck" when it makes no progress for an extended period. This can happen due to deadlocks, resource starvation, waiting for executors, or other blocking conditions.

## Detection

### Prometheus Alerts

```yaml
- alert: SparkJobStuck
  expr: spark_app_tasks_completed_total == spark_app_tasks_completed_total offset 10m
  for: 10m
  labels:
    severity: warning
  annotations:
    runbook: "docs/operations/runbooks/spark/job-stuck.md"

- alert: SparkStageNotProgressing
  expr: spark_stage_tasks_total - spark_stage_completed_tasks_total > 0
  and spark_stage_completed_tasks_total == spark_stage_completed_tasks_total offset 15m
  for: 15m
  labels:
    severity: warning
  annotations:
    runbook: "docs/operations/runbooks/spark/job-stuck.md"

- alert: SparkExecutorStarvation
  expr: spark_executors_active < 2
  for: 10m
  labels:
    severity: warning
  annotations:
    runbook: "docs/operations/runbooks/spark/job-stuck.md"
```

### Manual Detection

```bash
# Check for running jobs that haven't completed tasks
kubectl port-forward <driver-pod> 4040:4040 -n <namespace>
# Open UI and check for stages with no progress

# Or use API
curl -s http://localhost:4040/api/v1/applications/<app-id>/jobs | jq '.[] | select(.status == "RUNNING")'
```

## Diagnosis

### Quick Check Script

```bash
scripts/operations/spark/diagnose-stuck-job.sh <namespace> <app-name>
```

### Manual Diagnosis Steps

#### 1. Check Job Status

```bash
# Port-forward to driver
kubectl port-forward <driver-pod> 4040:4040 -n <namespace>

# Get job list
curl -s http://localhost:4040/api/v1/applications/<app-id>/jobs | jq .

# Get running jobs
curl -s http://localhost:4040/api/v1/applications/<app-id>/jobs | jq '.[] | select(.status == "RUNNING")'

# Get stage details
curl -s http://localhost:4040/api/v1/applications/<app-id>/stages | jq '.[] | select(.status == "ACTIVE")'
```

#### 2. Check Active Tasks

```bash
# Get tasks for stuck stage
STAGE_ID=<stuck-stage-id>
ATTEMPT=<attempt-id>
curl -s http://localhost:4040/api/v1/applications/<app-id>/stages/$STAGE_ID/$ATTEMPT/taskList | jq '.[] | select(.status == "RUNNING")'

# Check task duration
curl -s http://localhost:4040/api/v1/applications/<app-id>/stages/$STAGE_ID/$ATTEMPT/taskList | jq '.[] | {taskId: .taskId, duration: .duration, status: .status}'
```

#### 3. Check Executor Status

```bash
# Get executor list
curl -s http://localhost:4040/api/v1/applications/<app-id>/executors | jq .

# Check active tasks per executor
curl -s http://localhost:4040/api/v1/applications/<app-id>/executors | jq '.[] | {id: .id, activeTasks: .activeTasks, runningTasks: .runningTasks}'

# Check if all executors are active
curl -s http://localhost:4040/api/v1/applications/<app-id>/executors | jq 'length'
```

#### 4. Check for Blocked Operations

```bash
# Check logs for blocked/waiting
kubectl logs <driver-pod> -n <namespace> --tail=1000 | grep -i "wait\|block\|lock\|stuck"

# Check for shuffle wait
kubectl logs <driver-pod> -n <namespace> --tail=1000 | grep -i "shuffle"

# Check for external service dependencies
kubectl logs <driver-pod> -n <namespace> --tail=1000 | grep -i "s3\|hdfs\|database\|connection"
```

#### 5. Check Resource Constraints

```bash
# Get executor pods
kubectl get pods -l spark-role=executor -n <namespace>

# Check pod status
kubectl describe pod <executor-pod> -n <namespace>

# Check if waiting for scheduling
kubectl get pods -l spark-role=executor -n <namespace> -o json | jq -r '.items[] | select(.status.phase == "Pending") | .metadata.name'

# Check events
kubectl get events -n <namespace> --sort-by='.lastTimestamp' | tail -50
```

## Remediation

### Scenario 1: No Active Executors

**Symptoms:**
- Job running but no executors
- `No active executor` in logs
- Tasks pending with no resources

**Action:**

```bash
# Check if dynamic allocation is enabled
kubectl get sparkapplication <app-name> -n <namespace> -o json | jq -r '.spec.sparkConf."spark.dynamicAllocation.enabled"'

# If disabled, enable it
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '
{
  "spec": {
    "sparkConf": {
      "spark.dynamicAllocation.enabled": "true",
      "spark.dynamicAllocation.minExecutors": "2",
      "spark.dynamicAllocation.maxExecutors": "10",
      "spark.dynamicAllocation.initialExecutors": "2"
    }
  }
}'

# If using fixed executors, check why they're not starting
kubectl get pods -l spark-role=executor -n <namespace>
kubectl describe pod <executor-pod> -n <namespace>

# Check for node pressure
kubectl top nodes
```

### Scenario 2: Tasks Stuck in Shuffle

**Symptoms:**
- Reduce stage not starting
- Map stage complete but tasks stuck
- Shuffle fetch wait

**Action:**

```bash
# Check shuffle service
# See Shuffle Failure runbook for detailed steps

# Quick fix: Increase timeout
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '
{
  "spec": {
    "sparkConf": {
      "spark.network.timeout": "800s",
      "spark.shuffle.io.connectionTimeout": "120s"
    }
  }
}'

# Restart application if shuffle data corrupted
kubectl delete sparkapplication <app-name> -n <namespace>
kubectl apply -f <app-config>.yaml
```

### Scenario 3: External Service Blocking

**Symptoms:**
- Jobs waiting on external service
- Connection timeout
- Database query blocking

**Action:**

```bash
# Check which external service is being accessed
kubectl logs <driver-pod> -n <namespace> --tail=1000 | grep -i "connection\|timeout"

# Test connectivity to external service
kubectl exec -it <executor-pod> -n <namespace> -- nc -vz <external-host> <port>

# Increase timeout for external service
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '
{
  "spec": {
    "sparkConf": {
      "spark.sql.broadcastTimeout": "1200",
      "spark.network.timeout": "800s"
    }
  }
}'

# Check if external service is healthy
kubectl get svc -n <namespace>
```

### Scenario 4: Data Skew

**Symptoms:**
- Some tasks complete quickly, others stuck
- Stage 99% complete but few tasks remaining
- Large task time variance

**Action:**

```bash
# Identify skewed partitions
curl -s http://localhost:4040/api/v1/applications/<app-id>/stages/<stagger-stage-id>/<attempt-id>/taskList | \
  jq '[.[] | select(.status == "RUNNING")] | group_by(.index) | map({index: .[0].index, attempts: length}) | sort_by(.attempts) | reverse'

# Enable adaptive query execution
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '
{
  "spec": {
    "sparkConf": {
      "spark.sql.adaptive.enabled": "true",
      "spark.sql.adaptive.coalescePartitions.enabled": "true",
      "spark.sql.adaptive.skewJoin.enabled": "true",
      "spark.sql.adaptive.skewJoin.skewedPartitionThresholdInBytes": "256m"
    }
  }
}'

# Increase shuffle partitions
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '
{
  "spec": {
    "sparkConf": {
      "spark.sql.shuffle.partitions": "1000"
    }
  }
}'
```

### Scenario 5: Container/Pod Not Starting

**Symptoms:**
- Executors stuck in Pending
- Image pull errors
- Config map missing

**Action:**

```bash
# Check pod status
kubectl get pods -l spark-role=executor -n <namespace>

# Check pod events
kubectl describe pod <executor-pod> -n <namespace>

# Common fixes:

# Image pull error: Check image exists
kubectl get pods -l spark-role=executor -n <namespace] -o jsonpath='{.items[0].spec.containers[0].image}'

# Config map error: Verify config maps exist
kubectl get configmap -n <namespace>

# Resource quota error: Check quotas
kubectl get resourcequota -n <namespace>

# Fix: Delete stuck application and redeploy
kubectl delete sparkapplication <app-name> -n <namespace>
kubectl apply -f <fixed-config>.yaml
```

### Scenario 6: Deadlock/Thread Issue

**Symptoms:**
- All threads blocked
- No log activity
- Driver non-responsive

**Action:**

```bash
# Get thread dump from driver
kubectl exec -it <driver-pod> -n <namespace> -- jcmd 1 Thread.print

# Or kill and restart
kubectl delete pod <driver-pod> -n <namespace>

# If recurring, analyze thread dump for deadlock pattern
kubectl exec -it <driver-pod> -n <namespace> -- jcmd 1 Thread.print > thread-dump.txt
# Look for BLOCKED state threads
```

### Scenario 7: Waiting for Cluster Resources

**Symptoms:**
- Job queued waiting for resources
- Cluster autoscaler not scaling
- All pods pending

**Action:**

```bash
# Check cluster autoscaler
kubectl get pods -n kube-system -l k8s-app=cluster-autoscaler

# Check autoscaler logs
kubectl logs -n kube-system -l k8s-app=cluster-autoscaler --tail=100

# Check node pool capacity
kubectl nodes

# Manual node scaling if using managed K8s
# (EKS: kubectl scale nodegroup, GKE: gcloud container clusters resize)

# If using node autoscaler, check limits
kubectl get configmap cluster-autoscaler-status -n kube-system -o yaml
```

### Scenario 8: Long Running Query

**Symptoms:**
- Job technically running but very slow
- No apparent stuck state
- Long running single task

**Action:**

```bash
# Check query plan via Spark UI
# SQL tab -> Query -> Detailed Plan

# Enable AQE for better optimization
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '
{
  "spec": {
    "sparkConf": {
      "spark.sql.adaptive.enabled": "true",
      "spark.sql.adaptive.enabled.optSkewedHashed": "true"
    }
  }
}'

# Check for correlated subqueries that might be slow
# This requires code optimization

# Consider query timeout
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '
{
  "spec": {
    "sparkConf": {
      "spark.sql.execution.timeout": "3600s"
    }
  }
}'
```

## Recovery Scripts

### Automated Recovery

```bash
# Idempotent stuck job recovery script
scripts/operations/spark/recover-stuck-job.sh <namespace> <app-name>

# This will:
# 1. Detect why job is stuck
# 2. Apply appropriate remediation
# 3. Monitor for progress resume
```

### Force Restart (Last Resort)

```bash
# Only if job is truly stuck and cannot recover
# This will lose all progress
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

### 2. Enable Dynamic Allocation

```yaml
sparkConf:
  spark.dynamicAllocation.enabled: "true"
  spark.dynamicAllocation.minExecutors: "2"
  spark.dynamicAllocation.maxExecutors: "20"
```

### 3. Set Reasonable Timeouts

```yaml
sparkConf:
  spark.network.timeout: "800s"
  spark.sql.broadcastTimeout: "1200s"
```

### 4. Monitor Stages

Set up alerts for stages not progressing in 15 minutes.

## Monitoring

### Grafana Dashboard Queries

```promql
# Jobs with no progress
spark_app_tasks_completed_total == spark_app_tasks_completed_total offset 10m

# Active executors
spark_executors_active

# Tasks by status
sum by (status) (spark_stage_tasks{app_id="$app_id", stage_id="$stage_id"})
```

## Related Runbooks

- [Executor Failures](executor-failures.md)
- [Shuffle Failure](shuffle-failure.md)
- [Driver Crash Loop](driver-crash-loop.md)

## Escalation

| Time | Action |
|------|--------|
| 15 min | Run diagnostic script |
| 30 min | If no resolution, force restart job |
| 1 hour | If recurring, escalate to Platform team |

## Changelog

| Date | Change |
|------|--------|
| 2025-02-11 | Initial version |
