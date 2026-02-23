# DataOps Best Practices

Collection of best practices for DataOps engineers.

## Deployment

### 1. Immutable Infrastructure

**❌ Bad:**
```bash
# SSH into nodes and make changes
kubectl exec -it <pod> -- bash
# ... make changes ...
```

**✅ Good:**
```bash
# Update manifest and redeploy
kubectl apply -f manifests/job.yaml
```

### 2. Configuration Management

**❌ Bad:**
```yaml
# Hardcoded values
spec:
  executor:
    memory: "8g"
    instances: 50
```

**✅ Good:**
```yaml
# External values
spec:
  executor:
    memory: {{ .Values.executor.memory }}
    instances: {{ .Values.executor.instances }}
```

### 3. Resource Limits

**❌ Bad:**
```yaml
# No limits
spec:
  executor:
    memory: "8g"
```

**✅ Good:**
```yaml
# With limits
spec:
  executor:
    memory: "8g"
    memoryOverhead: "1g"
    cores: 4
```

## Monitoring

### 1. Meaningful Metrics

**❌ Bad:**
```promql
# Too generic
up{job="spark"}
```

**✅ Good:**
```promql
# Specific and actionable
rate(spark_task_failed_total{app_id="my-job"}[5m]) / rate(spark_task_completed_total{app_id="my-job"}[5m]) > 0.05
```

### 2. Alert on Symptoms

**❌ Bad:**
```yaml
# Alert on everything
- alert: HighCPU
  expr: cpu_usage > 50
```

**✅ Good:**
```yaml
# Alert on impact
- alert: JobFailed
  expr: spark_job_status == 2
  annotations:
    runbook: "docs/runbooks/job-failure.md"
```

## Data Quality

### 1. Validate Early

**❌ Bad:**
```python
# Check at end
df.write.parquet(output)
validate(output)
```

**✅ Good:**
```python
# Check during processing
df = validate_schema(df)
df = validate_values(df)
df.write.parquet(output)
```

### 2. Fail Fast

**❌ Bad:**
```python
# Continue with bad data
if df.filter(col("id").isNull()).count() > 0:
    log.warning("Null IDs found")
```

**✅ Good:**
```python
# Stop immediately
null_count = df.filter(col("id").isNull()).count()
if null_count > 0:
    raise ValueError(f"Found {null_count} null IDs")
```

## Cost Optimization

### 1. Rightsize Resources

**❌ Bad:**
```yaml
# Always use max
spec:
  executor:
    instances: 100
    memory: "32g"
```

**✅ Good:**
```yaml
# Use dynamic allocation
spec:
  executor:
    instances: 50
  sparkConf:
    spark.dynamicAllocation.enabled: "true"
    spark.dynamicAllocation.maxExecutors: "100"
```

### 2. Use Spot Instances

**❌ Bad:**
```yaml
# All on-demand
spec:
  executor:
    nodeSelector:
      instance-type: "on-demand"
```

**✅ Good:**
```yaml
# Mixed spot and on-demand
spec:
  driver:
    nodeSelector:
      instance-type: "on-demand"
  executor:
    nodeSelector:
      instance-type: "spot"
    tolerations:
    - key: "spot"
      operator: "Exists"
```

## Security

### 1. No Secrets in Code

**❌ Bad:**
```python
# Hardcoded credentials
aws_key = "AKIAIOSFODNN7EXAMPLE"
```

**✅ Good:**
```python
# From environment
aws_key = os.getenv("AWS_ACCESS_KEY_ID")
```

### 2. Principle of Least Privilege

**❌ Bad:**
```yaml
# Admin access
apiVersion: v1
kind: ServiceAccount
metadata:
  name: spark
  namespace: spark-prod
```

**✅ Good:**
```yaml
# Role-based access
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: spark-operator
rules:
- apiGroups: [""]
  resources: ["pods", "configmaps"]
  verbs: ["get", "list", "watch", "create"]
```

## CI/CD

### 1. Test Everything

**❌ Bad:**
```yaml
# Deploy without tests
- name: Deploy
  run: kubectl apply -f job.yaml
```

**✅ Good:**
```yaml
# Test before deploy
- name: Lint
  run: ./scripts/cicd/lint-python.sh --dir jobs/
- name: Test
  run: pytest tests/
- name: Deploy
  run: kubectl apply -f job.yaml
```

### 2. Rollback Capability

**❌ Bad:**
```bash
# Destructive changes
kubectl apply -f job.yaml --force
```

**✅ Good:**
```bash
# Versioned with rollback
helm upgrade --install job charts/spark-job \
  --values values/prod.yaml \
  --history-max 10
helm rollback job  # If issues
```

## Documentation

### 1. Document Decisions

**❌ Bad:**
```yaml
# No comments
spec:
  executor:
    instances: 50
```

**✅ Good:**
```yaml
# 50 executors based on load test 2024-01-15
# See docs/load-tests/results.md
spec:
  executor:
    instances: 50
```

### 2. Update Runbooks

**❌ Bad:**
```bash
# Fix issue, no documentation
kubectl patch ...
```

**✅ Good:**
```bash
# Fix and document
kubectl patch ...
# Update runbook with new resolution steps
```

## Communication

### 1. Notify Impact

**❌ Bad:**
```bash
# Deploy without notice
kubectl apply -f prod-job.yaml
```

**✅ Good:**
```bash
# Notify team
slack-send "Deploying my-job to prod, expect 5min downtime"
kubectl apply -f prod-job.yaml
```

### 2. Share Learnings

**❌ Bad:**
```
# Keep knowledge to yourself
```

**✅ Good:**
```
# Document and share
- Update runbook
- Present at team meeting
- Write incident report
```

## Summary

| Practice | Benefit |
|----------|---------|
| Immutable infrastructure | Reproducible deployments |
| Resource limits | Cost control |
| Early validation | Faster feedback |
| Dynamic allocation | Cost optimization |
| Spot instances | 50%+ savings |
| Security best practices | Compliance |
| Comprehensive testing | Fewer incidents |
| Rollback capability | Faster recovery |
| Good documentation | Knowledge sharing |
| Clear communication | Team alignment |
