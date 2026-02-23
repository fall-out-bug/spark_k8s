---
title: "Application Master Failures Runbook"
created: "2026-02-11"
spark_version: "3.5.7"
severity: "P1"
tags: ["spark", "runbook", "master", "failures"]
---

# Application Master Failures Runbook

## Overview

This runbook covers diagnosis and recovery procedures for Spark Application Master failures in Kubernetes environments. Application Master is responsible for resource scheduling, executor management, and overall application lifecycle coordination.

## Symptoms

| Symptom | Description | Detection Query |
|----------|-------------|----------------|
| Master not responding | Driver pod running but executors not launching | `spark_master_workers_count == 0` for >5min |
| Frequent master restarts | Master pod restarting unexpectedly | `increase(restart_count) > 3 in 10min` |
| Executor registration timeout | Executors not registering within timeout | `max(executor_registration_time) > 5min` |
| Resource request failures | Unable to request resources from cluster API | `rate(resource_request_failures) > 0.1/sec` |
| Deadlock in scheduler | Jobs stuck waiting for resources | `blocked_tasks > 0` for >10min` |

## Diagnosis

### Step 1: Check Master Pod Status

```bash
# Check if master pod is running
kubectl get pods -n spark-operations -l spark-role=master

# Check master pod logs
kubectl logs -n spark-operations deployment/spark-master -c spark-master --tail=100

# Check restart count
kubectl get pods -n spark-operations -l spark-role=master \
  -o jsonpath='{.items[*].status.containerStatuses[0].restartCount}'
```

### Step 2: Check Cluster Resource Availability

```bash
# Check cluster node resources
kubectl top nodes

# Check pending pods
kubectl get pods -A | grep Pending | wc -l

# Check resource quotas
kubectl describe resourcequota -n spark-operations
```

### Step 3: Check Spark Configuration

```bash
# Connect to Spark Connect to check master status
spark-connect list

# Check dynamic allocation settings
kubectl get configmap -n spark-operations spark-config \
  -o jsonpath='{.data.dynamicAllocation\.enabled}'

# Check executor limits
kubectl get configmap -n spark-operations spark-config \
  -o jsonpath='{.data.dynamicAllocation\.maxExecutors}'
```

### Step 4: Review Master Logs

```bash
# Export master logs for analysis
kubectl logs -n spark-operations deployment/spark-master -c spark-master > master-logs.txt

# Search for errors
grep -i "error\|exception\|failed" master-logs.txt | head -50

# Search for resource requests
grep -i "resource request\|unable to request" master-logs.txt | head -20
```

## Remediation

### Option 1: Restart Master Service

```bash
# Scale down master deployment
kubectl scale deployment -n spark-operations spark-master --replicas=0

# Wait for termination
kubectl wait --for=condition=delete pod -l spark-role=master --timeout=300s

# Scale up master deployment
kubectl scale deployment -n spark-operations spark-master --replicas=1

# Verify master is responding
kubectl exec -n spark-operations deployment/spark-master -c spark-master -- \
  spark-submit --version
```

### Option 2: Clear Persistent State

```bash
# Clear Spark persistent state (if using local storage)
kubectl exec -n spark-operations deployment/spark-master -c spark-master -- \
  rm -rf /tmp/spark-persistent-state

# Restart master pod
kubectl delete pod -n spark-operations -l spark-role=master
```

### Option 3: Adjust Resource Configuration

```bash
# Update max executors to match cluster capacity
kubectl patch configmap spark-config -n spark-operations --type=json \
  -p '{"data":{"dynamicAllocation":{"maxExecutors":10}}}'

# Reduce executor memory requests
kubectl patch configmap spark-config -n spark-operations --type=json \
  -p '{"data":{"executor":{"memory":"2g"}}}'

# Increase request timeout
kubectl patch configmap spark-config -n spark-operations --type=json \
  -p '{"data":{"spark":{"executor.heartbeatInterval":"60s"}}}'
```

### Option 4: Enable Standalone Mode Fallback

If K8s mode master is failing, fallback to standalone mode:

```bash
# Switch to standalone backend
helm upgrade spark-3.5 --install \
  --set connect.backendMode=standalone \
  --set connect.standalone.enabled=true \
  --values custom-values.yaml
```

## Prevention

| Prevention | Implementation |
|-------------|----------------|
| **Resource monitoring** | Set up Prometheus alerts for master health |
| **Capacity planning** | Ensure cluster has 20% buffer for peak loads |
| **High availability** | Use master HA mode (zookeeper ensemble) |
| **Graceful shutdown** | Implement proper drain procedures before maintenance |
| **Configuration validation** | Test all config changes in staging first |
| **Monitoring dashboards** | Use Application Master Metrics dashboard |

## Monitoring

### Prometheus Queries

```promql
# Master restart rate (should be < 0.1/min)
rate(spark_master_restarts_total[5m])

# Executor registration time
histogram_quantile(0.95, spark_executor_registration_time_seconds)

# Resource request failures
rate(spark_master_resource_request_failures_total[5m])

# Deadlocked tasks
max(spark_master_blocked_tasks) > 0
```

### Grafana Dashboard

- **Application Master Metrics** (in F16 observability dashboards)
- **Job Phase Timeline** - shows master operations phase
- **Resource Wait Time** - if master delays executor startup

## Escalation

| Level | Condition | Contact |
|-------|-----------|----------|
| L1 | Master down > 15min | On-call SRE |
| L2 | Multiple restarts in 1 hour | Team Lead |
| L3 | Recurring failures | Engineering Manager |
| L4 | Production outage | Architecture Lead |

## References

- [Spark Application Master Documentation](https://spark.apache.org/docs/latest/cluster-overview.html)
- [Kubernetes Scheduler](https://kubernetes.io/docs/concepts/scheduling-eviction/)
- [Job Stuck Runbook](./job-stuck.md)
- [Executor Failures Runbook](./executor-failures.md)
