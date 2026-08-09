# Horizontal Pod Autoscaler (HPA) Runbook

## Overview

This runbook covers Horizontal Pod Autoscaler (HPA) configuration and operations for Spark on Kubernetes components.

## Detection

### When to Scale

Monitor these metrics to determine if scaling is needed:

```bash
# Check CPU/Memory usage across pods
kubectl top pods -n spark-operations

# Check HPA status
kubectl get hpa -n spark-operations

# Check current replica counts
kubectl get deployments -n spark-operations
```

### Indicators

- **CPU Usage > 70%** sustained for 5+ minutes
- **Memory Usage > 80%** sustained for 5+ minutes
- **Pod OOMKilled** events increasing
- **High request latency** for Spark Connect

## Diagnosis

### Step 1: Check Current HPA Status

```bash
# List all HPAs
kubectl get hpa -A

# Describe specific HPA
kubectl describe hpa jupyter-connect -n spark-operations
kubectl describe hpa spark-history-server -n spark-operations
```

### Step 2: Check Resource Utilization

```bash
# Get current metrics
kubectl top nodes
kubectl top pods -n spark-operations

# Check resource requests vs limits
kubectl get deployment jupyter-connect -n spark-operations -o yaml | grep -A 5 resources
```

### Step 3: Check Metrics Server

```bash
# Verify metrics server is running
kubectl get pods -n kube-system | grep metrics-server

# Check metrics API
kubectl get --raw /apis/metrics.k8s.io/v1beta1/nodes
```

## Remediation

### Immediate Actions

#### 1. Manual Scale (Immediate Relief)

```bash
# Scale up immediately
kubectl scale deployment jupyter-connect --replicas=4 -n spark-operations

# Scale statefulsets
kubectl scale statefulset spark-history-server --replicas=2 -n spark-operations
```

#### 2. Adjust HPA Parameters

```bash
# Edit HPA for more aggressive scaling
kubectl edit hpa jupyter-connect -n spark-operations
```

Example configuration:

```yaml
spec:
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 60  # Lower threshold = more aggressive
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 70
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 10
        periodSeconds: 60
```

### Long-term Solutions

#### 1. Create/Update HPA

```bash
# Apply HPA manifest
kubectl apply -f - <<EOF
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: jupyter-connect-hpa
  namespace: spark-operations
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: jupyter-connect
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
      - type: Percent
        value: 50
        periodSeconds: 15
      - type: Pods
        value: 1
        periodSeconds: 15
      selectPolicy: Max
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 10
        periodSeconds: 60
EOF
```

#### 2. Configure Multiple Metrics

```yaml
metrics:
- type: Resource
  resource:
    name: cpu
    target:
      type: Utilization
      averageUtilization: 70
- type: Resource
  resource:
    name: memory
    target:
      type: Utilization
      averageUtilization: 80
- type: Pods
  pods:
    metric:
      name: spark_connect_active_sessions
    target:
      type: AverageValue
      averageValue: "5"
```

## Prevention

### 1. Pre-scale for Known Events

```bash
# Before high load periods
kubectl scale deployment jupyter-connect --replicas=6 -n spark-operations

# Schedule scale-up via CronJob
cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: CronJob
metadata:
  name: pre-scale-jupyter
  namespace: spark-operations
spec:
  schedule: "0 8 * * 1-5"  # 8 AM weekdays
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: kubectl
            image: bitnami/kubectl:latest
            command:
            - /bin/sh
            - -c
            - kubectl scale deployment jupyter-connect --replicas=6 -n spark-operations
          restartPolicy: OnFailure
EOF
```

### 2. Set Appropriate Resource Requests

```yaml
resources:
  requests:
    cpu: "500m"
    memory: "1Gi"
  limits:
    cpu: "2000m"
    memory: "4Gi"
```

### 3. Monitor HPA Events

```bash
# Watch HPA events
kubectl get events --sort-by=.metadata.creationTimestamp -n spark-operations | grep hpa

# Set up alerting on replica count changes
```

## Validation

```bash
# Verify HPA is working
kubectl get hpa -n spark-operations -w

# Check if autoscaling is triggered
kubectl describe hpa jupyter-connect -n spark-operations | grep -A 10 "Metrics:"
```

## Troubleshooting

### HPA Not Scaling

1. **Check metrics server**: `kubectl get pods -n kube-system | grep metrics`
2. **Check resource requests**: Must be set for target resource utilization
3. **Check if at maxReplicas**: HPA won't scale beyond maxReplicas
4. **Check current metrics**: `kubectl describe hpa <name>`

### Overscaling

1. **Increase stabilizationWindowSeconds**: Prevents rapid scale changes
2. **Adjust scaleDown policies**: Slower scale-down reduces churn
3. **Set higher minReplicas**: Maintains baseline capacity

## Related Runbooks

- [Vertical Pod Autoscaler](./vertical-pod-autoscaler.md)
- [Cluster Scaling](./cluster-scaling.md)
- [Spark Executor Scaling](./spark-executor-scaling.md)

## References

- [Kubernetes HPA Documentation](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [Spark on Kubernetes Scaling Guide](../procedures/capacity/capacity-planning.md)
