# Spark Executor Scaling Runbook

## Overview

This runbook covers dynamic executor scaling for Spark jobs using Kubernetes and KEDA (Kubernetes Event-driven Autoscaling).

## Detection

### When to Scale Executors

Monitor these metrics to determine if executor scaling is needed:

```bash
# Check pending tasks in Spark UI
# Check executor count vs workload
# Check job completion times
# Check resource utilization

# Via kubectl:
kubectl get sparkapps -A
kubectl describe sparkapp <app-name>
```

### Indicators

- **Long job queue times** (jobs waiting for executors)
- **Underutilized executors** (idle resources)
- **Job timeouts** due to insufficient executors
- **Cost inefficiency** from over-provisioned executors

## Diagnosis

### Step 1: Check Current Executor Configuration

```bash
# Describe Spark application
kubectl describe sparkapp <app-name> -n spark-operations

# Check current executor count
kubectl get pods -n spark-operations -l spark-role=executor

# Check Spark UI for executor metrics
# Port-forward to Spark UI
kubectl port-forward -n spark-operations <driver-pod> 4040:4040
# Open http://localhost:4040
```

### Step 2: Analyze Job Requirements

```bash
# Check job type and resource needs
kubectl get sparkapp <app-name> -n spark-operations -o yaml | grep -A 10 "spark.*executor"

# Check historical job metrics
# - Average executor count
# - Average task duration
# - Average memory per executor
```

### Step 3: Check Dynamic Allocation Status

```bash
# Check if dynamic allocation is enabled
kubectl logs <driver-pod> -n spark-operations | grep "dynamicAllocation"

# Check executor add/remove events
kubectl logs <driver-pod> -n spark-operations | grep -i "executor.*added\|executor.*removed"
```

## Remediation

### Option 1: Spark Dynamic Allocation

Configure dynamic allocation in Spark application:

```yaml
apiVersion: sparkoperator.k8s.io/v1beta2
kind: SparkApplication
metadata:
  name: analytics-job
  namespace: spark-operations
spec:
  type: Scala
  mode: cluster
  image: spark:3.5.0
  mainClass: com.example.AnalyticsJob
  mainApplicationFile: local:///opt/spark/examples/jars/xxx.jar
  sparkVersion: 3.5.0
  restartPolicy:
    type: OnFailure
  driver:
    cores: 1
    coreLimit: "1200m"
    memory: "512m"
    memoryOverhead: 512m
    serviceAccount: spark
  executor:
    cores: 2
    coreLimit: "2000m"
    instances: 2  # Initial instances
    memory: "2g"
    memoryOverhead: 1g
    serviceAccount: spark
  dynamicAllocation:
    enabled: true
    initialExecutors: 2
    minExecutors: 1
    maxExecutors: 20
    executorAllocationRatio: 0.5  # Pending task ratio to trigger scaling
    shuffleTrackingEnabled: true
    cachedExecutorIdleTimeout: "60s"
    sustainedSchedulerBacklogTimeout: "5s"
```

### Option 2: KEDA ScaledObject (External Trigger)

Scale based on external metrics like S3 queue depth:

```bash
# Install KEDA
kubectl apply -f https://github.com/kedacore/keda/releases/download/v2.12.0/keda-2.12.0.yaml

# Create S3 scaler
kubectl apply -f - <<EOF
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: spark-executor-scaler
  namespace: spark-operations
spec:
  scaleTargetRef:
    name: analytics-job-executor  # Target deployment/statefulset
  pollingInterval: 30
  cooldownPeriod: 300
  minReplicaCount: 1
  maxReplicaCount: 20
  triggers:
  - type: aws-s3
    metadata:
      bucketName: spark-input-data
      prefix: "pending/"
      awsRegion: us-east-1
      targetSize: "1000"  # 1000 objects per executor
      activationTargetSize: "500"
    authenticationRef:
      name: keda-aws-credentials
EOF
```

### Option 3: Schedule-Based Scaling

Scale based on time schedules:

```bash
kubectl apply -f - <<EOF
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: spark-executor-schedule-scaler
  namespace: spark-operations
spec:
  scaleTargetRef:
    name: analytics-job-executor
  pollingInterval: 30
  cooldownPeriod: 300
  minReplicaCount: 2
  maxReplicaCount: 15
  triggers:
  - type: cron
    metadata:
      timezone: America/New_York
      start: 0 8 * * *  # 8 AM
      end: 0 18 * * *   # 6 PM
      desiredReplicas: "10"
EOF
```

### Option 4: Manual Executor Scaling

```bash
# Scale executors manually (update SparkApplication)
kubectl patch sparkapp analytics-job -n spark-operations --type='json' -p='[
  {"op": "replace", "path": "/spec/executor/instances", "value": 10}
]'

# Or via Spark UI REST API
# POST /api/v1/applications/{app-id}/executors/threadDump
# GET /api/v1/applications/{app-id}/executors
```

## Best Practices

### 1. Right-size Executor Cores

```yaml
# For CPU-bound workloads: 2-4 cores per executor
# For memory-bound workloads: 1-2 cores per executor
# Avoid too many cores (poor parallelism)
# Avoid too few cores (overhead per executor)

# Example:
executor:
  cores: 2  # Good balance for most workloads
  coreLimit: "2000m"  # Match cores to limit
```

### 2. Right-size Executor Memory

```yaml
# Formula: executor.memory = (total_worker_memory / num_executors) - memory_overhead

# Example: 64GB worker, 4 executors
# 64GB / 4 = 16GB per executor
# 16GB - 2GB (overhead) = 14GB memory

executor:
  memory: "14g"
  memoryOverhead: 2g  # Typically 10-20% of memory
```

### 3. Configure Appropriate Scaling Bounds

```yaml
dynamicAllocation:
  minExecutors: 1  # Minimum to keep alive
  maxExecutors: 20  # Maximum cluster capacity / executor cores
  initialExecutors: 3  # Start with reasonable baseline
```

### 4. Enable Shuffle Tracking

```yaml
dynamicAllocation:
  shuffleTrackingEnabled: true  # Better scaling decisions
```

### 5. Set Timeouts

```yaml
dynamicAllocation:
  cachedExecutorIdleTimeout: "60s"  # Keep executors briefly after shuffle complete
  shuffleServiceFetchRddTimeout: "30s"
```

## Prevention

### 1. Profile Workloads

```bash
# Run test job with monitoring
scripts/scaling/profile-workload.sh <job-name>

# Analyze results:
# - Peak executor count needed
# - Average executor utilization
# - Optimal executor size
```

### 2. Set Resource Quotas

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: spark-executor-quota
  namespace: spark-operations
spec:
  hard:
    requests.cpu: "100"
    requests.memory: 200Gi
    limits.cpu: "200"
    limits.memory: 400Gi
    pods: "200"
```

### 3. Use PriorityClasses

```bash
# Ensure critical jobs can scale
kubectl apply -f - <<EOF
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: spark-executor-high
value: 500
globalDefault: false
description: "High priority for production Spark executors"
EOF
```

### 4. Monitor Scaling Events

```bash
# Set up monitoring for executor scaling
kubectl logs -n spark-operations <driver-pod> | grep -i "scale"

# Prometheus queries
# - spark_executor_count
# - spark_executor_memory_used
# - spark_executor_cpu_used
```

## Validation

```bash
# Verify dynamic allocation is working
kubectl logs -n spark-operations <driver-pod> | grep "DynamicAllocation"

# Check current executor count
kubectl get pods -n spark-operations -l spark-role=executor

# Port-forward to Spark UI
kubectl port-forward -n spark-operations <driver-pod> 4040:4040

# Check executor metrics
curl http://localhost:4040/api/v1/applications/<app-id>/executors | jq '.'
```

## Troubleshooting

### Executors Not Scaling Up

1. **Check maxExecutors limit**: May be at maximum
2. **Check resource availability**: Cluster may be at capacity
3. **Check dynamicAllocation.enabled**: Ensure it's enabled
4. **Check shuffle service**: External shuffle service may be needed
5. **Check scheduler backlog**: May need to adjust thresholds

### Executors Scaling Down Too Aggressively

1. **Increase cachedExecutorIdleTimeout**: Keep executors longer
2. **Check for shuffle data**: Ensure shuffles are tracked
3. **Adjust executorAllocationRatio**: Lower threshold for scaling

### Executors Not Releasing Resources

1. **Check for cached data**: Executors holding cached RDDs
2. **Check for streaming queries**: Executors held for streaming
3. **Force release**: `sparkContext.killExecutors(executorIds)`

## Monitoring

### Key Metrics

```bash
# Executor count
sum(spark_executor_count{namespace="spark-operations"})

# Executor CPU utilization
rate(spark_executor_cpu_time_seconds_total[5m]) / spark_executor_cores

# Executor memory utilization
spark_executor_memory_used_bytes / spark_executor_memory_max_bytes

# Pending tasks
spark_pending_tasks_total
```

### Grafana Dashboard

Create a dashboard showing:
- Active executor count over time
- Executor resource utilization
- Pending task count
- Job completion times

## Related Runbooks

- [Horizontal Pod Autoscaler](./horizontal-pod-autoscaler.md)
- [Cluster Scaling](./cluster-scaling.md)
- [Capacity Planning](../procedures/capacity/capacity-planning.md)

## References

- [Spark Dynamic Allocation](https://spark.apache.org/docs/latest/job-scheduling.html#dynamic-resource-allocation)
- [KEDA Documentation](https://keda.sh/docs/2.12/concepts/)
- [Spark on Kubernetes Scaling Guide](https://spark.apache.org/docs/latest/running-on-kubernetes.html)
