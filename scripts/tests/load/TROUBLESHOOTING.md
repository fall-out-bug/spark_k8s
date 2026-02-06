# Load Testing Troubleshooting Guide

Part of WS-013-11: CI/CD Integration & Documentation

## Common Errors and Solutions

### Workflow Errors

#### Error: Workflow submission failed

**Symptoms:**
```
Error: Failed to submit workflow
```

**Causes:**
1. Argo Workflows not installed
2. Invalid workflow YAML
3. Namespace doesn't exist

**Solutions:**
```bash
# Check Argo installation
kubectl get pods -n argo

# Reinstall Argo
./scripts/argocd/argo-workflows/install.sh

# Validate workflow
argo lint scripts/tests/load/workflows/load-test-workflow.yaml
```

#### Error: Workflow stuck in Pending

**Symptoms:**
```
STATUS   PHASE      MESSAGE
Pending   Pending   Workflow is waiting for a mutex
```

**Causes:**
1. Another workflow is running
2. Resource mutex held by failed workflow

**Solutions:**
```bash
# Check active workflows
argo list -n argo

# Release stuck mutex
kubectl delete configmap mutex-config -n argo

# Terminate stuck workflow
argo terminate <workflow-name> -n argo
```

### Execution Errors

#### Error: Pod ImagePullBackOff

**Symptoms:**
```
STATUS    READY   MESSAGE
Pulling   0/1     Pulling image
Error     0/1     ImagePullBackOff
```

**Causes:**
1. Image doesn't exist
2. Invalid image tag
3. Registry authentication required

**Solutions:**
```bash
# Check image exists
docker pull <image>

# Preload image to Minikube
minikube image load <image>

# Verify image in cluster
kubectl get pods -o jsonpath='{.items[*].spec.containers[*].image}'
```

#### Error: Pod OOMKilled

**Symptoms:**
```
STATUS    READY   MESSAGE
OOMKilled 0/1     Container was killed due to OOM
```

**Causes:**
1. Insufficient memory allocation
2. Memory leak in application
3. Large dataset exceeds heap

**Solutions:**
```bash
# Check pod resource usage
kubectl top pods -n load-test-*

# Increase memory in Helm values
# Edit values.yaml:
# executor.memory: "8g" -> "12g"

# Enable dynamic allocation
spark.dynamicAllocation.enabled: "true"
```

#### Error: Task failed with FetchFailed

**Symptoms:**
```
ERROR executor.Executor: Exception in task 0.0 in stage 0.0
org.apache.spark.shuffle.FetchFailedException
```

**Causes:**
1. Executor lost during shuffle
2. Network issues
3. Insufficient shuffle space

**Solutions:**
```bash
# Increase shuffle partitions
--conf spark.sql.shuffle.partitions=400

# Enable external shuffle service
spark.shuffle.service.enabled: "true"

# Check executor logs
kubectl logs <executor-pod> -n load-test-*
```

### Infrastructure Errors

#### Error: Minio connection refused

**Symptoms:**
```
ERROR: Failed to connect to Minio
Connection refused: http://minio.load-testing.svc.cluster.local:9000
```

**Causes:**
1. Minio pod not running
2. Service not exposed
3. Network policy blocking

**Solutions:**
```bash
# Check Minio status
kubectl get pods -n load-testing -l app=minio

# Port-forward for testing
kubectl port-forward -n load-testing svc/minio 9000:9000

# Test connection
curl http://localhost:9000/minio/health/live
```

#### Error: Postgres connection failed

**Symptoms:**
```
ERROR: Could not connect to Postgres
Connection refused: postgres-load-testing.load-testing.svc.cluster.local:5432
```

**Causes:**
1. Postgres pod not running
2. Wrong credentials
3. Database not created

**Solutions:**
```bash
# Check Postgres status
kubectl get pods -n load-testing -l app.kubernetes.io/name=postgresql

# Get credentials
kubectl get secret -n load-testing postgres-load-testing -o jsonpath='{.data.password}' | base64 -d

# Test connection
kubectl run psql-client --rm -it --image=postgres:15 -- psql postgresql://postgres:sparktest@postgres-load-testing.load-testing.svc.cluster.local:5432/spark_db
```

#### Error: History Server not accessible

**Symptoms:**
```
ERROR: Failed to fetch application history
Connection refused: http://spark-history-server.load-testing.svc.cluster.local:18080
```

**Causes:**
1. History Server pod not running
2. Event logs not in S3
3. Wrong S3 configuration

**Solutions:**
```bash
# Check History Server status
kubectl get pods -n load-testing -l app=spark-history-server

# Check event logs in S3
mc ls local/spark-logs/events/

# Verify S3 configuration
kubectl get configmap spark-history-server-config -n load-testing -o yaml
```

### Data Errors

#### Error: Test data not found

**Symptoms:**
```
ERROR: Path does not exist: s3a://test-data/nyc-taxi/...
```

**Causes:**
1. Data not uploaded to Minio
2. Wrong path in workload script
3. Bucket doesn't exist

**Solutions:**
```bash
# Check buckets
mc alias set local http://minio.load-testing.svc.cluster.local:9000 minioadmin minioadmin
mc ls local/

# Regenerate test data
python3 scripts/tests/load/data/generate-nyc-taxi.py --size 1gb --upload

# Verify data exists
mc ls local/test-data/nyc-taxi/
```

#### Error: Parquet file corruption

**Symptoms:**
```
ERROR: Invalid Parquet file
Parquet file is corrupted or incomplete
```

**Causes:**
1. Incomplete upload
2. Data generation interrupted
3. Storage corruption

**Solutions:**
```bash
# Remove corrupted data
mc rm --recursive --force local/test-data/nyc-taxi/

# Regenerate data
python3 scripts/tests/load/data/generate-nyc-taxi.py --size 1gb --upload

# Verify checksums
md5sum <local-file>
```

### Performance Issues

#### Error: Slow query execution

**Symptoms:**
- Queries take much longer than expected
- High executor memory usage

**Causes:**
1. Too many partitions
2. Skewed data distribution
3. Insufficient resources

**Solutions:**
```bash
# Adjust partitions
--conf spark.sql.shuffle.partitions=200

# Check data skew
# Add logging to identify skew

# Increase resources
# Edit values.yaml:
# executor.instances: 2 -> 4
```

#### Error: High shuffle spill

**Symptoms:**
- "Spill on shuffle" warnings
- Slow execution
- High disk I/O

**Causes:**
1. Insufficient memory
2. Large shuffles
3. Inefficient join keys

**Solutions:**
```bash
# Increase memory fraction
spark.memory.fraction: "0.8"
spark.memory.storageFraction: "0.3"

# Use broadcast join
--conf spark.sql.autoBroadcastJoinThreshold=10m

# Check shuffle metrics
# History Server: Stages -> Metrics -> Shuffle Read
```

## Debug Tips

### Enable Debug Logging

```bash
# Spark executor logs
--conf spark.executor.extraJavaOptions="-Dlog4j.logLevel=DEBUG"

# Argo workflow logs
argo logs <workflow-name> -n argo --follow
```

### Capture Diagnostic Data

```bash
# Capture pod logs
kubectl logs <pod-name> -n <namespace> > pod.log

# Capture pod events
kubectl get events -n <namespace> > events.log

# Capture pod description
kubectl describe pod <pod-name> -n <namespace> > pod.describe

# Capture cluster state
kubectl get all -n <namespace> -o yaml > cluster-state.yaml
```

### Interactive Debugging

```bash
# Port-forward to service
kubectl port-forward -n <namespace> svc/<service> <local-port>:<service-port>

# Open shell in pod
kubectl exec -it <pod-name> -n <namespace> -- /bin/bash

# Attach to running pod
kubectl attach <pod-name> -n <namespace> -c <container>
```

## Getting Help

### Collect Debug Information

Before requesting help, collect:

1. **Workflow information:**
   ```bash
   argo get <workflow-name> -n argo
   ```

2. **Pod status:**
   ```bash
   kubectl get pods -n <namespace>
   kubectl describe pod <pod-name> -n <namespace>
   ```

3. **Logs:**
   ```bash
   kubectl logs <pod-name> -n <namespace>
   ```

4. **Error messages:**
   - Copy exact error text
   - Include stack traces
   - Note the exact step where it failed

### Useful Resources

- **Setup Guide:** `scripts/tests/load/SETUP.md`
- **Architecture:** `scripts/tests/load/ARCHITECTURE.md`
- **User Guide:** `docs/guides/load-testing-guide.md`
- **Argo Documentation:** https://argoproj.github.io/argo-workflows/
- **Spark Documentation:** https://spark.apache.org/docs/latest/
