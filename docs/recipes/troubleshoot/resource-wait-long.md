# Resource Wait Long Diagnosis

## Problem
Application takes long time to start, even though resources are available.

## Diagnosis Steps

### 1. Check Resource Wait Metrics

**Dashboard**: Job Phase Timeline → "Resource Wait" panel

```
# Compare Resource Wait vs Compute time
resource_wait_seconds = 360s (> 5 minutes) is HIGH
```

### 2. Check K8s Scheduler

```bash
# Check pod pending times
kubectl get events -n spark-load-test --field-selector reason=FailedScheduling -o json | \
  jq -r '.items[] | [.lastTimestamp, .message] | select(.lastTimestamp, .message)'
```

### 3. Review PriorityClass

```bash
# Check PriorityClass for spark-executors
kubectl get pods -n spark-load-test -l spark-role=executor -o json | \
  jq -r '.items[] | .spec.priorityClassName'
```

| PriorityClass | Description | Action |
|-------------|-----------|--------|
| (default) | Best effort, may wait for resources | OK for batch |
| | None or low priority | Gets scheduled when high-priority pods finish | Not ideal for batch |
| | guaranteed | Preemptible, lower priority | Avoid for critical workloads |

## Solutions

| Solution | When to Use |
|---------|--------------|
| Set correct PriorityClass | Use `guaranteed` for executors |
| Reduce resource contention | Lower concurrent applications on cluster |
| Request specific node affinity | Ensure executors scheduled on data nodes |
| Increase cluster capacity | More worker nodes, scale K8s control plane |
| Tune dynamic allocation | Adjust min/max executors based on load |

## Related Dashboards

- **Job Phase Timeline**: Resource Wait tracking
- **Spark Profiling**: (not directly related, shows executor starvation)

## Recipe Checklist

- [ ] Check Resource Wait percentage in Job Phase Timeline
- [ ] Review K8s events for FailedScheduling
- [ ] Verify PriorityClass for executor pods
- [ ] Check cluster resource utilization
- [ ] Implement solution based on root cause
- [ ] Monitor after fix to verify improvement
