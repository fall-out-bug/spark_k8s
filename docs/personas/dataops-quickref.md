# DataOps Quick Reference

Quick reference guide for common DataOps tasks.

## Deploy Jobs

```bash
# Deploy to dev
helm upgrade --install my-job charts/spark-job \
  --namespace spark-dev \
  --values values/dev.yaml

# Deploy to prod
helm upgrade --install my-job charts/spark-job \
  --namespace spark-prod \
  --values values/prod.yaml \
  --wait --timeout 10m
```

## Monitor Jobs

```bash
# Job status
kubectl get sparkapplication -n spark-prod

# Job logs
kubectl logs -f -n spark-prod \
  -l spark-app-name=my-job,spark-role=driver

# Spark UI
kubectl port-forward -n spark-prod <driver-pod> 4040:4040
```

## Scale Resources

```bash
# Scale executors
kubectl patch sparkapplication my-job -n spark-prod \
  --type='json' \
  -p='[{"op": "replace", "path": "/spec/executor/instances", "value": 20}]'

# Scale memory
kubectl patch sparkapplication my-job -n spark-prod \
  --type='json' \
  -p='[{"op": "replace", "path": "/spec/executor/memory", "value": "16g"}]'
```

## Debug Issues

```bash
# Describe pod
kubectl describe pod -n spark-prod <pod-name>

# Check events
kubectl get events -n spark-prod --sort-by='.lastTimestamp'

# Executor logs
kubectl logs -n spark-prod -l spark-app-name=my-job,spark-role=executor --tail=-1
```

## Quality Checks

```bash
# Run quality gate
python scripts/quality/run-checks.py \
  --table s3a://prod-data/output \
  --suite prod_expectations

# Validate schema
python scripts/quality/validate-schema.py \
  --table s3a://prod-data/output \
  --schema schemas/expected.json
```

## Cost Management

```bash
# Check job cost
./scripts/operations/cost/calculate-job-cost.sh \
  --app-id my-job \
  --start-date 2024-01-01

# Rightsize job
./scripts/operations/cost/rightsize-jobs.sh \
  --namespace spark-prod
```

## Backup & Recovery

```bash
# Backup job outputs
aws s3 sync s3://prod-data/ s3://prod-backups/$(date +%Y%m%d)/

# Restore from backup
./scripts/operations/restore.sh \
  --backup-date 2024-01-15 \
  --target s3a://prod-restored/
```

## Common Commands

```bash
# List all jobs
kubectl get sparkapplication -A

# Delete completed jobs
kubectl delete sparkapplication -l spark-app-state-completed=true

# Restart job
kubectl delete sparkapplication my-job -n spark-prod
kubectl apply -f manifests/my-job.yaml

# Get job metrics
curl http://prometheus.observability.svc.cluster.local:9090/api/v1/query?query=spark_job_status
```

## Alerts

| Alert | Severity | Action |
|-------|----------|--------|
| Job failed | Critical | Check logs, restart job |
| High memory | Warning | Scale or optimize |
| Data skew | Warning | Tune partitions |
| Quality fail | Critical | Quarantine data, investigate |
| Cost spike | Warning | Check for runaway jobs |
