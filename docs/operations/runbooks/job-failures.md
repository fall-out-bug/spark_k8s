# Job Failures Runbook

Diagnose and resolve failed Spark jobs.

## Common Failure Patterns

### Pattern 1: Driver Pod Crash

**Symptom:** Driver pod restarts repeatedly

```
kubectl get pods
NAME              READY   STATUS    RESTARTS   AGE
spark-driver-1-1   0/1     Running   5          10m
```

**Diagnosis:**
```bash
kubectl logs spark-driver-1-1 --previous
kubectl describe pod spark-driver-1-1
```

**Common Causes & Fixes:**

| Cause | Fix |
|-------|-----|
| OOM | Increase driver memory |
| Uncaught exception | Fix application code |
| Lost connection to executors | Check network |

### Pattern 2: Executor Pod Loss

**Symptom:** Executors fail during job

**Diagnosis:**
```bash
# Check executor logs
kubectl logs -l spark-role=executor --tail=100

# Check Spark UI for failed tasks
kubectl port-forward svc/spark-history 18080:18080
# Open http://localhost:18080
```

**Common Causes & Fixes:**

| Cause | Fix |
|-------|-----|
| Executor OOM | Increase executor memory or reduce data per task |
| Network timeout | Increase `spark.network.timeout` |
| Stragglers | Enable speculative execution |

### Pattern 3: Stage Failures

**Symptom:** Stage retry attempts exceeded

**Diagnosis:**
```bash
# Check driver logs for stage failures
kubectl logs <driver-pod> | grep -i "stage failed"

# Check Spark UI for task details
```

**Common Causes & Fixes:**

| Cause | Fix |
|-------|-----|
| Shuffle fetch failures | Increase retry count, check network |
| Corrupted shuffle data | Re-run stage, check disk health |
| Skew | Repartition data, use salting |

## Resolution Checklist

- [ ] Check pod logs for errors
- [ ] Verify resource limits are adequate
- [ ] Check network connectivity
- [ ] Review Spark UI for task/stage failures
- [ ] Verify data sources are accessible
- [ ] Check for code exceptions

## Escalation

If job continues failing after 3 attempts:
1. Collect full logs: `kubectl logs <pod> > logs.txt`
2. Get thread dump: `kubectl exec <pod> -- jstack 1`
3. Contact platform team with logs
