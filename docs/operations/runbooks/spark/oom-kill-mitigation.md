# OOM Kill Mitigation Runbook

> **Severity:** P1 - Performance Degraded
> **Automation:** `scripts/operations/spark/diagnose-oom.sh`
> **Alert:** `SparkPodOOMKilled`

## Overview

Out of Memory (OOM) kills occur when containers exceed their memory limits, causing the Kubernetes OOM killer to terminate the process. This results in job failures and requires investigation.

## Detection

### Prometheus Alerts

```yaml
- alert: SparkPodOOMKilled
  expr: increase(kube_pod_container_status_terminated_reason{reason="OOMKilled"}[5m]) > 0
  for: 1m
  labels:
    severity: critical
  annotations:
    runbook: "docs/operations/runbooks/spark/oom-kill-mitigation.md"

- alert: SparkMemoryApproachingLimit
  expr: sum(container_memory_working_set_bytes{pod=~"spark.*"}) by (pod) / sum(container_spec_memory_limit_bytes{pod=~"spark.*"}) by (pod) > 0.9
  for: 5m
  labels:
    severity: warning
  annotations:
    runbook: "docs/operations/runbooks/spark/oom-kill-mitigation.md"
```

### Manual Detection

```bash
# Check for OOMKilled pods
kubectl get pods -n <namespace> -o json | jq -r '.items[] | select(.status.containerStatuses[].lastState.terminated.reason == "OOMKilled") | .metadata.name'

# Check events
kubectl get events -n <namespace> --field-selector reason=OOMKilling
```

## Diagnosis

### Quick Check Script

```bash
scripts/operations/spark/diagnose-oom.sh <namespace> <pod-name>
```

### Manual Diagnosis Steps

#### 1. Identify OOM Kill

```bash
# Check pod status
kubectl describe pod <pod-name> -n <namespace>

# Look for:
# Last State: Terminated
# Reason: OOMKilled
# Exit Code: 137

# Check termination details
kubectl get pod <pod-name> -n <namespace> -o json | jq -r '.status.containerStatuses[].lastState'
```

#### 2. Analyze Memory Usage

```bash
# Get memory stats from node
NODE=$(kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.spec.nodeName}')
kubectl exec -n <namespace> <pod-name> -- cat /sys/fs/cgroup/memory/memory.usage_in_bytes
kubectl exec -n <namespace> <pod-name> -- cat /sys/fs/cgroup/memory/memory.limit_in_bytes

# Or use kubectl top
kubectl top pod <pod-name> -n <namespace> --containers

# Check memory trends via Prometheus
# query: container_memory_working_set_bytes{pod="<pod-name>"}
```

#### 3. Check Memory Configuration

```bash
# Get SparkApplication config
kubectl get sparkapplication <app-name> -n <namespace> -o yaml

# Check memory settings
kubectl get sparkapplication <app-name> -n <namespace> -o json | jq -r '.spec.driver.memory'
kubectl get sparkapplication <app-name> -n <namespace> -o json | jq -r '.spec.executor.memory'
kubectl get sparkapplication <app-name> -n <namespace> -o json | jq -r '.spec.driver.memoryOverhead'
kubectl get sparkapplication <app-name> -n <namespace> -o json | jq -r '.spec.executor.memoryOverhead'
```

#### 4. Analyze Application Memory Profile

```bash
# If using Spark 3.3+ with memory profiling
kubectl exec -it <driver-pod> -n <namespace> -- \
  curl -s http://localhost:4040/api/v1/applications/<app-id>/memoryprofiler

# Check for memory leaks in logs
kubectl logs <pod-name> -n <namespace> --previous | grep -i "memory\|heap\|gc"

# Check Spark UI - Storage Memory tab
kubectl port-forward <driver-pod> 4040:4040 -n <namespace>
```

#### 5. Check JVM Heap Settings

```bash
# Get actual JVM heap settings from logs
kubectl logs <pod-name> -n <namespace> --previous | grep -i "xmx\|xms\|maxheap"

# Check if off-heap is enabled
kubectl get sparkapplication <app-name> -n <namespace> -o json | jq -r '.spec.sparkConf."spark.memory.offHeap.enabled"'
```

## Remediation

### Scenario 1: Driver OOM

**Symptoms:**
- Driver pod OOMKilled
- Application fails to start

**Action:**

```bash
# Calculate appropriate memory
# Container memory = heap + off-heap + overhead
# Increase driver memory
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '
{
  "spec": {
    "driver": {
      "memory": "4g",
      "memoryOverhead": "1g"
    },
    "sparkConf": {
      "spark.driver.memory": "4g",
      "spark.driver.memoryOverhead": "1g",
      "spark.memory.offHeap.enabled": "true",
      "spark.memory.offHeap.size": "512m"
    }
  }
}'

# Delete existing pod to apply changes
kubectl delete pod <driver-pod> -n <namespace>
```

### Scenario 2: Executor OOM

**Symptoms:**
- Executor pods OOMKilled
- Tasks fail with `OutOfMemoryError`

**Action:**

```bash
# Option 1: Increase memory per executor
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '
{
  "spec": {
    "executor": {
      "memory": "6g",
      "memoryOverhead": "2g"
    }
  }
}'

# Option 2: Reduce memory per executor (more, smaller executors)
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '
{
  "spec": {
    "executor": {
      "cores": 2,
      "memory": "3g",
      "memoryOverhead": "1g",
      "instances": 10
    }
  }
}'

# Option 3: Reduce cores per executor (less parallelism per executor)
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '
{
  "spec": {
    "executor": {
      "cores": 1,
      "memory": "4g"
    }
  }
}'
```

### Scenario 3: Spark Memory Misconfiguration

**Symptoms:**
- OOM despite sufficient container memory
- `java.lang.OutOfMemoryError: Java heap space`

**Action:**

```bash
# Tune Spark memory management
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '
{
  "spec": {
    "sparkConf": {
      "spark.memory.fraction": "0.5",
      "spark.memory.storageFraction": "0.3",
      "spark.memory.offHeap.enabled": "true",
      "spark.memory.offHeap.size": "1g",
      "spark.executor.memoryOverhead": "1g"
    }
  }
}'

# Explanation:
# - memory.fraction: Fraction of heap for execution/storage (default 0.6)
# - storageFraction: Fraction of memory for caching (default 0.5)
# - Lower fractions = more reserved memory = less OOM
```

### Scenario 4: Broadcast Join OOM

**Symptoms:**
- OOM during join operations
- Tasks fail on `BroadcastHashJoin`

**Action:**

```bash
# Disable broadcast for large tables
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '
{
  "spec": {
    "sparkConf": {
      "spark.sql.autoBroadcastJoinThreshold": "-1",
      "spark.sql.broadcastTimeout": "1200"
    }
  }
}'

# Or set threshold to a reasonable value (e.g., 100MB)
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '
{
  "spec": {
    "sparkConf": {
      "spark.sql.autoBroadcastJoinThreshold": "104857600"
    }
  }
}'
```

### Scenario 5: Cached Data OOM

**Symptoms:**
- OOM after caching large datasets
- Storage memory grows continuously

**Action:**

```bash
# Reduce storage fraction
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '
{
  "spec": {
    "sparkConf": {
      "spark.memory.storageFraction": "0.2",
      "spark.memory.fraction": "0.5"
    }
  }
}'

# Unpersist cached data if application allows
# Add to code: df.unpersist()

# Use disk persistence instead of memory
# In code: df.persist(StorageLevel.DISK_ONLY)
```

### Scenario 6: Collection OOM

**Symptoms:**
- OOM during `collect()`, `toLocalIterator()`, or `take()`
- Driver memory exhaustion

**Action:**

```bash
# Increase driver memory
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '
{
  "spec": {
    "driver": {
      "memory": "8g",
      "memoryOverhead": "2g"
    },
    "sparkConf": {
      "spark.driver.maxResultSize": "4g"
    }
  }
}'

# Application changes needed:
# - Use foreachPartition instead of collect
# - Use take() with limit instead of collect()
# - Use toLocalIterator() for streaming
# - Write output to storage instead of collecting
```

## Recovery Scripts

### Automated Recovery

```bash
# Idempotent OOM recovery script
scripts/operations/spark/recover-oom.sh <namespace> <app-name>

# This will:
# 1. Identify component (driver/executor)
# 2. Analyze memory pattern
# 3. Recommend/configure appropriate memory settings
# 4. Restart application with new settings
```

### Manual Recovery

```bash
# After fixing configuration, restart application
kubectl delete sparkapplication <app-name> -n <namespace>
# Apply updated configuration
kubectl apply -f <updated-config>.yaml
```

## Prevention

### 1. Right-size Memory Initially

```bash
# Use memory profiling on test workload
scripts/operations/spark/profile-memory.sh <test-app>

# Review recommended settings in output
```

### 2. Enable Monitoring

```yaml
# Add Prometheus annotations
podTemplate:
  metadata:
    annotations:
      prometheus.io/scrape: "true"
      prometheus.io/port: "4040"
```

### 3. Set Memory Limits Based on Node Size

```bash
# Node with 32GB RAM
# Safe executor config:
executor:
  cores: 4
  memory: "8g"
  memoryOverhead: "2g"
  instances: 3  # Leaves 8GB for system
```

### 4. Use Dynamic Allocation

```yaml
sparkConf:
  spark.dynamicAllocation.enabled: "true"
  spark.dynamicAllocation.minExecutors: "1"
  spark.dynamicAllocation.maxExecutors: "10"
```

### 5. Memory Safety Margins

```bash
# Always include 20% overhead
# For 4GB heap, allocate at least 5GB container
```

## Monitoring

### Grafana Dashboard Queries

```promql
# Memory approaching limit
sum(container_memory_working_set_bytes{namespace="spark"}) by (pod)
  / sum(container_spec_memory_limit_bytes{namespace="spark"}) by (pod)

# Heap usage
jvm_memory_used_bytes{area="heap",namespace="spark"}
  / jvm_memory_max_bytes{area="heap",namespace="spark"}

# GC time rate
rate(jvm_gc_pause_seconds_sum{namespace="spark"}[5m])
```

## Related Runbooks

- [Driver Crash Loop](driver-crash-loop.md)
- [Executor Failures](executor-failures.md)
- [Task Failure Recovery](task-failure-recovery.md)

## Escalation

| Time | Action |
|------|--------|
| Immediate | Increase memory limits if job critical |
| 15 min | Run memory profiling if recurring |
| 1 hour | Review application code for memory leaks |

## Changelog

| Date | Change |
|------|--------|
| 2025-02-11 | Initial version |
