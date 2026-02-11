# Executor Failures Runbook

> **Severity:** P1 - Performance Degraded
> **Automation:** `scripts/operations/spark/diagnose-executor-failure.sh`
> **Alert:** `SparkExecutorFailureRate`

## Overview

Executor failures occur when executor pods are terminated, lost, or fail during task execution. While Spark can retry tasks, excessive executor failures cause job slowdowns or failures.

## Detection

### Prometheus Alerts

```yaml
- alert: SparkExecutorFailureRate
  expr: rate(spark_executor_errors_total[5m]) > 0.1
  for: 10m
  labels:
    severity: warning
  annotations:
    runbook: "docs/operations/runbooks/spark/executor-failures.md"

- alert: SparkExecutorPodKillRate
  expr: rate(kube_pod_container_status_terminated_reason{container="spark-executor",reason="Error"}[5m]) > 0.05
  for: 5m
  labels:
    severity: critical
  annotations:
    runbook: "docs/operations/runbooks/spark/executor-failures.md"
```

### Manual Detection

```bash
# Check executor pod status
kubectl get pods -l spark-role=executor -n <namespace>

# Check Spark UI metrics
curl -s http://<driver-pod>:4040/api/v1/applications/<app-id>/executors | jq '.[] | select(.activeTasks == 0)'
```

## Diagnosis

### Quick Check Script

```bash
scripts/operations/spark/diagnose-executor-failure.sh <namespace> <app-name>
```

### Manual Diagnosis Steps

#### 1. Check Failed Executors

```bash
# List all executor pods including failed ones
kubectl get pods -l spark-role=executor -n <namespace> --show-labels

# Check events for failed pods
kubectl describe pod <executor-pod> -n <namespace>

# Check recent pod terminations
kubectl get events -n <namespace> --field-selector reason=FailedScheduling
```

#### 2. Check Executor Logs

```bash
# Get failed executor logs
kubectl logs <executor-pod> -n <namespace> --tail=500

# Search for error patterns
kubectl logs <executor-pod> -n <namespace> --tail=500 | grep -i "error\|exception\|failed\|killed"
```

**Common patterns:**
- `Container killed` - OOM or resource limits
- `Lost worker` - Network/node issues
- `ExecutorLostFailure` - Heartbeat timeout
- `Connection refused` - Service discovery issues

#### 3. Check Spark UI

```bash
# Port-forward to driver
kubectl port-forward <driver-pod> -n <namespace> 4040:4040

# Or use kubectl exec
kubectl exec -it <driver-pod> -n <namespace> -- curl -s http://localhost:4040/api/v1/applications/<app-id>/executors | jq .
```

**Key metrics:**
- `activeTasks` - Should be 0 for failed executors
- `failedTasks` - Count of failed tasks
- `memoryUsed` - Check for OOM patterns
- `totalDuration` - Lifetime of executor

#### 4. Check Node Health

```bash
# Get executor node
NODE=$(kubectl get pod <executor-pod> -n <namespace> -o jsonpath='{.spec.nodeName}')

# Check node status
kubectl describe node $NODE

# Check for resource pressure
kubectl get node $NODE -o jsonpath='{.status.conditions[?(@.type=="MemoryPressure")].message}'
```

#### 5. Check Resource Usage

```bash
# Current executor pods resource requests
kubectl top pod -l spark-role=executor -n <namespace>

# Compare to limits
kubectl get pod <executor-pod> -n <namespace> -o jsonpath='{.spec.containers[0].resources}'
```

## Remediation

### Scenario 1: Executor OOM

**Symptoms:**
- Exit code 137
- `ContainerKilled` events
- `OutOfMemoryError` in logs

**Action:**

```bash
# Option 1: Increase executor memory (if app supports dynamic allocation)
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '
{
  "spec": {
    "executor": {
      "memory": "4g",
      "memoryOverhead": "1g"
    }
  }
}'

# Option 2: Reduce cores per executor (more executors, less memory each)
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '
{
  "spec": {
    "executor": {
      "cores": 2,
      "instances": 10
    }
  }
}'
```

**Prevention:**
- Enable off-heap memory: `spark.memory.offHeap.enabled=true`
- Tune memory fraction: `spark.memory.fraction=0.6`
- Use `spark.executor.memoryOverhead` for container overhead

### Scenario 2: Node Loss/Preemption

**Symptoms:**
- Pods in `Unknown` state
- Node not ready
- Cluster autoscaler activity

**Action:**

```bash
# Check cluster autoscaler logs
kubectl logs -n kube-system -l k8s-app=cluster-autoscaler --tail=100

# Check node events
kubectl get events --all-namespaces --field-selector reason=NodeNotReady

# Verify pod disruption budgets
kubectl get pdb -n <namespace>

# Restart SparkApplication to request new executors
kubectl delete pod <driver-pod> -n <namespace>
```

**Prevention:**
- Set appropriate Pod Disruption Budgets
- Use node selectors for critical workloads
- Enable Spark dynamic allocation

### Scenario 3: Network Issues

**Symptoms:**
- `ExecutorLostFailure` - Heartbeat timeout
- `Connection refused` errors
- DNS resolution failures

**Action:**

```bash
# Check network policies
kubectl get networkpolicies -n <namespace>

# Test DNS
kubectl exec -it <executor-pod> -n <namespace> -- nslookup <driver-service>

# Increase heartbeat timeout
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '
{
  "spec": {
    "sparkConf": {
      "spark.executor.heartbeatInterval": "60s",
      "spark.network.timeout": "800s"
    }
  }
}'
```

**Prevention:**
- Use proper service discovery
- Set appropriate timeouts
- Monitor network latency

### Scenario 4: Shuffle Fetch Failures

**Symptoms:**
- `FetchFailedException`
- `Connection refused` from peer executors
- Tasks failing on shuffle

**Action:**

```bash
# See Shuffle Failure runbook for detailed steps
# Quick fix: Increase retry attempts
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '
{
  "spec": {
    "sparkConf": {
      "spark.task.maxFailures": "8",
      "spark.shuffle.fetch.retry.count": "5"
    }
  }
}'

# Or enable Celeborn shuffle service
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '
{
  "spec": {
    "sparkConf": {
      "spark.shuffle.service.enabled": "false",
      "spark.shuffle.service.enabled": "true",
      "spark.shuffle.service.factory": "org.apache.spark.deployCelebornShuffleServiceFactory"
    }
  }
}'
```

### Scenario 5: Excessive Task Failures on Executor

**Symptoms:**
- High `failedTasks` count in UI
- Consistent failures on same executor
- No OOM errors

**Action:**

```bash
# Check for bad executor (hardware issue)
kubectl describe pod <executor-pod> -n <namespace>

# Check node logs for hardware errors
kubectl logs -n kube-system <node-name> --tail=100 | grep -i "hardware\|error\|fail"

# Blacklist bad node in Spark config
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '
{
  "spec": {
    "nodeSelector": {
      "node.kubernetes.io/exclude-from-schedulers": "false"
    }
  }
}'
```

## Recovery Scripts

### Automated Recovery

```bash
# Idempotent recovery script
scripts/operations/spark/recover-executor-failures.sh <namespace> <app-name>

# This will:
# 1. Identify failure pattern
# 2. Apply appropriate remediation
# 3. Verify recovery successful
```

### Manual Recovery

```bash
# Option 1: Delete failed executor pods (Spark will recreate)
kubectl delete pod <executor-pod> -n <namespace>

# Option 2: Scale down then up (for dynamic allocation)
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '
{
  "spec": {
    "executor": {
      "instances": 1
    }
  }
}'
# Wait, then scale back up
```

## Prevention

### 1. Dynamic Allocation

```yaml
sparkConf:
  spark.dynamicAllocation.enabled: "true"
  spark.dynamicAllocation.minExecutors: "2"
  spark.dynamicAllocation.maxExecutors: "20"
  spark.dynamicAllocation.initialExecutors: "5"
  spark.shuffle.service.enabled: "true"
```

### 2. Resource Padding

```yaml
executor:
  cores: 2
  memory: "4g"
  memoryOverhead: "1g"
  instance: 5
```

### 3. Monitoring

Link to Grafana dashboard: `Spark Executor Health`

### 4. Graceful Shutdown

```yaml
podTemplate:
  spec:
    terminationGracePeriodSeconds: 60
```

## Related Runbooks

- [Driver Crash Loop](driver-crash-loop.md)
- [OOM Kill Mitigation](oom-kill-mitigation.md)
- [Shuffle Failure](shuffle-failure.md)

## Escalation

| Time | Action |
|------|--------|
| 10 min | Run automated diagnosis |
| 30 min | If failure rate > 50%, investigate immediately |
| 1 hour | If job at risk, escalate to Platform team |

## Changelog

| Date | Change |
|------|--------|
| 2025-02-11 | Initial version |
