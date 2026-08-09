# Vertical Pod Autoscaler (VPA) Runbook

## Overview

This runbook covers Vertical Pod Autoscaler (VPA) recommendations and operations for Spark on Kubernetes stateful components.

## Detection

### When to Use VPA

Monitor these metrics to determine if vertical scaling is needed:

```bash
# Check pods with OOMKilled status
kubectl get pods -A | grep -i oom

# Check resource usage vs requests
kubectl top pods -n spark-operations | awk '{print $2, $3, $4}'

# Check pods nearing resource limits
kubectl describe pods -n spark-operations | grep -A 5 "Limits"
```

### Indicators

- **Pods OOMKilled** regularly
- **CPU throttling** (usage near request but below limit)
- **Underutilized resources** (usage << request)
- **High eviction rate** due to resource pressure

## Diagnosis

### Step 1: Identify Stateful Components

Stateful components that benefit from VPA:

- **Spark History Server**
- **Hive Metastore**
- **PostgreSQL** (if deployed)
- **Airflow Scheduler** (stateful)
- **MinIO** (stateful)

### Step 2: Check Current Resource Usage

```bash
# Get detailed metrics for specific pod
kubectl top pod spark-history-server-0 -n spark-operations --containers

# Check resource allocation
kubectl get pod spark-history-server-0 -n spark-operations -o jsonpath='{.spec.containers[*].resources}'

# Compare request vs usage
kubectl get pods -n spark-operations -o json | jq -r '.items[] | "\(.metadata.name): CPU Request=\(.spec.containers[0].resources.requests.cpu), Usage=$(kubectl top pod \(.metadata.name) -n spark-operations --no-headers | awk \'{print $2}\')"'
```

### Step 3: Analyze Historical Data

```bash
# Check Prometheus for historical trends
# CPU usage over 7 days
kubectl exec -n monitoring prometheus-0 -- promtool query instant 'container_cpu_usage_seconds_total{namespace="spark-operations",pod=~"spark-history-server.*"}[7d]'

# Memory usage over 7 days
kubectl exec -n monitoring prometheus-0 -- promtool query instant 'container_memory_working_set_bytes{namespace="spark-operations",pod=~"spark-history-server.*"}[7d]'
```

## Remediation

### VPA Options

#### Option 1: VPA in Recommend-Only Mode (Safe)

Apply VPA in recommend-only mode first:

```bash
kubectl apply -f - <<EOF
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: spark-history-server-vpa
  namespace: spark-operations
spec:
  targetRef:
    apiVersion: apps/v1
    kind: StatefulSet
    name: spark-history-server
  updatePolicy:
    updateMode: "Off"  # Recommend only
  resourcePolicy:
    containerPolicies:
    - containerName: "*"
      minAllowed:
        cpu: "250m"
        memory: "512Mi"
      maxAllowed:
        cpu: "4000m"
        memory: "8Gi"
      controlledResources: ["cpu", "memory"]
EOF
```

View recommendations:

```bash
# After 24 hours, check recommendations
kubectl describe vpa spark-history-server-vpa -n spark-operations | grep -A 20 "Target:"

# Or use this command
kubectl get vpa spark-history-server-vpa -n spark-operations -o jsonpath='{.status.recommendation}'
```

#### Option 2: Apply Recommendations Manually

Based on VPA recommendations, manually update resources:

```bash
# Edit StatefulSet
kubectl edit statefulset spark-history-server -n spark-operations

# Update resources section
resources:
  requests:
    cpu: "500m"    # Based on VPA recommendation
    memory: "2Gi"  # Based on VPA recommendation
  limits:
    cpu: "2000m"
    memory: "4Gi"
```

#### Option 3: VPA in Auto Mode (Use with Caution)

Enable VPA to automatically update resources (requires pod restart):

```bash
kubectl patch vpa spark-history-server-vpa -n spark-operations --type='json' -p='[{"op": "replace", "path": "/spec/updatePolicy/updateMode", "value":"Recreate"}]'
```

## Component-Specific Recommendations

### Spark History Server

```yaml
resources:
  requests:
    cpu: "500m"
    memory: "2Gi"
  limits:
    cpu: "2000m"
    memory: "4Gi"
```

Rationale:
- History Server memory scales with number of applications
- CPU spikes during log parsing
- Needs burst capacity for UI rendering

### Hive Metastore

```yaml
resources:
  requests:
    cpu: "250m"
    memory: "1Gi"
  limits:
    cpu: "1000m"
    memory: "4Gi"
```

Rationale:
- Metastore is I/O bound, not CPU bound
- Memory usage scales with number of tables/partitions
- Needs memory buffer for large queries

### PostgreSQL

```yaml
resources:
  requests:
    cpu: "250m"
    memory: "512Mi"
  limits:
    cpu: "1000m"
    memory: "2Gi"
```

Rationale:
- PostgreSQL has internal memory management
- Over-allocating can degrade performance
- Keep memory:cpu ratio around 2:1

## Prevention

### 1. Regular VPA Review

```bash
# Schedule weekly VPA review
cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: CronJob
metadata:
  name: vpa-review
  namespace: spark-operations
spec:
  schedule: "0 9 * * 1"  # Weekly Monday 9 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: vpa-reviewer
            image: bitnami/kubectl:latest
            command:
            - /bin/sh
            - -c
            - |
              for vpa in $(kubectl get vpa -n spark-operations -o name); do
                echo "=== $vpa ==="
                kubectl describe $vpa -n spark-operations | grep -A 10 "Target:"
              done
          restartPolicy: OnFailure
EOF
```

### 2. Rightsizing Alerts

```yaml
# Prometheus alert for over-provisioned pods
groups:
- name: vertical_scaling
  rules:
  - alert: PodOverProvisioned
    expr: |
      (sum(container_memory_working_set_bytes{namespace="spark-operations"}) by (pod)
       /
       sum(kube_pod_container_resource_requests{namespace="spark-operations", resource="memory"}) by (pod)) < 0.3
    for: 1d
    annotations:
      summary: "Pod {{ $labels.pod }} is over-provisioned"
      description: "Memory usage is <30% of request for 24 hours"
EOF
```

### 3. Baseline Testing

```bash
# Run baseline load test to establish resource requirements
scripts/load-tests/run-baseline-test.sh spark-history-server
```

## Validation

```bash
# Verify pods are running with updated resources
kubectl get pods -n spark-operations -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].resources.requests}{"\n"}{end}'

# Check for OOMKilled events after changes
kubectl get events -n spark-operations --field-selector reason=OOMKilled --sort-by=.metadata.creationTimestamp

# Verify performance hasn't degraded
kubectl logs -n spark-operations spark-history-server-0 --tail=100 | grep -i "error\|exception"
```

## Troubleshooting

### VPA Not Generating Recommendations

1. **Check VPA is running**: `kubectl get pods -n spark-operations | grep vpa`
2. **Wait 24 hours**: VPA needs historical data
3. **Check targetRef matches**: Ensure VPA targets correct workload
4. **Check metrics-server**: `kubectl get apiservice | grep metrics`

### Pods Restarting After VPA Auto

1. **This is expected** in Recreate mode
2. **Use UpdateMode: Initial** to prevent restarts
3. **Migrate to Recommend-Only** if restarts are unacceptable

### Conflicts with HPA

- **VPA and HPA don't mix well** for the same resource (CPU/memory)
- **Use VPA for stateful** components only
- **Use HPA for stateless** components

## Related Runbooks

- [Horizontal Pod Autoscaler](./horizontal-pod-autoscaler.md)
- [Cluster Scaling](./cluster-scaling.md)
- [Capacity Planning](../procedures/capacity/capacity-planning.md)

## References

- [Kubernetes VPA Documentation](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [VPA Best Practices](https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler)
