# Driver Crash Loop Runbook

> **Severity:** P0 - Service Down
> **Automation:** `scripts/operations/spark/diagnose-driver-crash.sh`
> **Alert:** `SparkDriverCrashLoop`

## Overview

Driver pod crash loops occur when the Spark driver container repeatedly exits and restarts. This prevents application initialization and causes job failures.

## Detection

### Prometheus Alerts

```yaml
- alert: SparkDriverCrashLoop
  expr: kube_pod_container_status_restarts_total{container="spark-driver"} > 5
  for: 5m
  labels:
    severity: critical
  annotations:
    runbook: "docs/operations/runbooks/spark/driver-crash-loop.md"
```

### Manual Detection

```bash
kubectl get pods -l spark-role=driver --all-namespaces
kubectl describe pod <driver-pod> | grep -A 10 "State: Running"
```

## Diagnosis

### Quick Check Script

```bash
scripts/operations/spark/diagnose-driver-crash.sh <namespace> <driver-pod>
```

### Manual Diagnosis Steps

#### 1. Check Pod Events

```bash
kubectl describe pod <driver-pod> -n <namespace>
```

**Look for:**
- `FailedScheduling` - Resource issues
- `Failed` - Container exit errors
- `Back-off` - Crash loop backoff

#### 2. Check Driver Logs

```bash
# Current container
kubectl logs <driver-pod> -n <namespace> --tail=500

# Previous container (if crashed)
kubectl logs <driver-pod> -n <namespace> --previous --tail=500
```

**Search patterns:**

```bash
# OOM errors
kubectl logs <driver-pod> -n <namespace> --previous | grep -i "out of memory\|oom"

# Classpath issues
kubectl logs <driver-pod> -n <namespace> --previous | grep -i "classnotfound\|noclassdeffound"

# Config errors
kubectl logs <driver-pod> -n <namespace> --previous | grep -i "illegalargument\|configuration"

# K8s resource issues
kubectl logs <driver-pod> -n <namespace> --previous | grep -i "killed\|container\|exit"
```

#### 3. Check Resource Limits

```bash
kubectl get pod <driver-pod> -n <namespace> -o json | jq '.spec.containers[] | select(.name=="spark-driver") | .resources'
```

**Verify:**
- Memory requests/limits appropriate for workload
- CPU requests sufficient
- No resource limits too low

#### 4. Check Node Conditions

```bash
kubectl get pod <driver-pod> -n <namespace> -o jsonpath='{.spec.nodeName}' | xargs kubectl describe node
```

**Look for:**
- Memory pressure
- Disk pressure
- PID pressure
- Kubelet issues

## Remediation

### Scenario 1: Out of Memory (OOM)

**Symptoms:**
- Exit code 137
- Logs show `java.lang.OutOfMemoryError`
- `Last State: Terminated; Reason: OOMKilled`

**Action:**

```bash
# Increase driver memory
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '
{
  "spec": {
    "driver": {
      "memory": "4g",
      "memoryOverhead": "1g"
    }
  }
}'

# Or delete and redeploy with adjusted values
kubectl delete sparkapplication <app-name> -n <namespace>
# Apply updated config with increased memory
```

**Prevention:**
- Set `spark.driver.memory` to at least 2x peak heap usage
- Enable `spark.memory.offHeap.enabled`
- Set appropriate `spark.memory.fraction`

### Scenario 2: Configuration Errors

**Symptoms:**
- Exit code 1
- Logs show `IllegalArgumentException`, `ConfigurationException`

**Action:**

```bash
# Check current config
kubectl get sparkapplication <app-name> -n <namespace> -o yaml

# Validate configuration
scripts/operations/spark/validate-spark-config.sh <app-name> <namespace>

# Fix configuration
kubectl edit sparkapplication <app-name> -n <namespace>
```

**Common fixes:**
- Fix invalid property names
- Correct port conflicts
- Resolve missing dependency paths
- Fix malformed Hadoop/K8s config

### Scenario 3: Classpath Issues

**Symptoms:**
- `ClassNotFoundException`
- `NoClassDefFoundError`
- Application JAR not found

**Action:**

```bash
# Verify dependencies mounted
kubectl exec -it <driver-pod> -n <namespace> -- ls -la /opt/spark/work-dir/

# Check init containers completed
kubectl describe pod <driver-pod> -n <namespace> | grep -A 5 "Init Containers"

# Fix: Add missing dependencies to SparkImage config
# or fix upload paths for remote dependencies
```

### Scenario 4: Node/Infrastructure Issues

**Symptoms:**
- Pod stuck in `ContainerCreating`
- `FailedScheduling` events
- Node not ready

**Action:**

```bash
# Check node status
kubectl get nodes -o wide

# Cordon problematic node
kubectl cordon <node-name>

# Delete pod to reschedule
kubectl delete pod <driver-pod> -n <namespace>

# Or delete SparkApplication to recreate
kubectl delete sparkapplication <app-name> -n <namespace>
```

### Scenario 5: Network Issues

**Symptoms:**
- Cannot connect to K8s API
- Cannot connect to resource managers (YARN/K8s)
- DNS resolution failures

**Action:**

```bash
# Test DNS from pod
kubectl exec -it <driver-pod> -n <namespace> -- nslookup kubernetes.default

# Check network policies
kubectl get networkpolicies -n <namespace>

# Check CNI logs (if applicable)
kubectl logs -n kube-system -l k8s-app=calico-node --tail=100
```

## Recovery Scripts

### Automated Recovery

```bash
# Safe to re-run recovery script
scripts/operations/spark/recover-driver-crash.sh <namespace> <app-name>

# This will:
# 1. Diagnose root cause
# 2. Attempt safe remediation
# 3. Provide manual steps if automation cannot fix
```

### Force Restart (Last Resort)

```bash
# Delete and recreate SparkApplication
kubectl delete sparkapplication <app-name> -n <namespace>
# Wait for operator to recreate
kubectl get sparkapplication <app-name> -n <namespace> -w
```

## Prevention

### 1. Resource Quotas

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: spark-driver-quota
  namespace: spark
spec:
  hard:
    requests.cpu: "10"
    requests.memory: "20Gi"
    limits.cpu: "20"
    limits.memory: "40Gi"
```

### 2. Pre-flight Checks

```bash
# Before deployment
scripts/operations/spark/preflight-check.sh <app-config>
```

### 3. Monitoring Dashboards

Link to Grafana dashboard: `Spark Driver Health`

### 4. Startup Probes

```yaml
startupProbe:
  exec:
    command:
    - /bin/sh
    - -c
    - ps aux | grep spark | grep -v grep
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 30
```

## Related Runbooks

- [Executor Failures](executor-failures.md)
- [OOM Kill Mitigation](oom-kill-mitigation.md)
- [Task Failure Recovery](task-failure-recovery.md)

## Escalation

| Time | Action |
|------|--------|
| 15 min | Run automated diagnosis |
| 30 min | If unresolved, escalate to Platform team |
| 1 hour | If impacting production, page on-call |

## Changelog

| Date | Change |
|------|--------|
| 2025-02-11 | Initial version |
