# Spark Connect Issues Runbook

> **Severity:** P1 - Performance Degraded
> **Automation:** `scripts/operations/spark/diagnose-connect-issue.sh`
> **Alert:** `SparkConnectFailure`

## Overview

Spark Connect issues occur when clients cannot connect to the Spark Connect server, or when the connection is unstable. This affects remote clients like Python, R, and Scala applications.

## Detection

### Prometheus Alerts

```yaml
- alert: SparkConnectFailure
  expr: rate(spark_connect_server_errors_total[5m]) > 0.1
  for: 5m
  labels:
    severity: warning
  annotations:
    runbook: "docs/operations/runbooks/spark/connect-issues.md"

- alert: SparkConnectHighLatency
  expr: histogram_quantile(0.95, rate(spark_connect_request_duration_seconds_bucket[5m])) > 30
  for: 10m
  labels:
    severity: warning
  annotations:
    runbook: "docs/operations/runbooks/spark/connect-issues.md"

- alert: SparkConnectServerDown
  expr: up{job="spark-connect"} == 0
  for: 2m
  labels:
    severity: critical
  annotations:
    runbook: "docs/operations/runbooks/spark/connect-issues.md"
```

### Manual Detection

```bash
# Check Spark Connect server pods
kubectl get pods -l app=spark-connect -n <namespace>

# Check connectivity
nc -vz <spark-connect-service> 15002

# Check client error logs in Spark Connect server
kubectl logs <spark-connect-pod> -n <namespace> --tail=1000
```

## Diagnosis

### Quick Check Script

```bash
scripts/operations/spark/diagnose-connect-issue.sh <namespace> <service-name>
```

### Manual Diagnosis Steps

#### 1. Check Server Status

```bash
# Check pod status
kubectl get pods -l app=spark-connect -n <namespace>

# Check events
kubectl describe pod <spark-connect-pod> -n <namespace>

# Check server health endpoint
kubectl exec -it <spark-connect-pod> -n <namespace> -- \
  curl -s http://localhost:15002/health
```

#### 2. Check Client Connections

```bash
# Check active sessions
kubectl exec -it <spark-connect-pod> -n <namespace> -- \
  curl -s http://localhost:15002/api/v1/sessions

# Check server logs for client errors
kubectl logs <spark-connect-pod> -n <namespace> --tail=1000 | grep -i "error\|exception\|failed"

# Search for specific client IDs
kubectl logs <spark-connect-pod> -n <namespace> --tail=1000 | grep "user-id"
```

#### 3. Check Network Connectivity

```bash
# Test from client perspective (replace with actual client test)
# From a test pod:
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -v http://spark-connect.<namespace>.svc:15002

# Check DNS
kubectl exec -it <spark-connect-pod> -n <namespace> -- \
  nslookup spark-connect.<namespace>.svc

# Check service endpoints
kubectl get endpoints spark-connect -n <namespace>
```

#### 4. Check Resource Usage

```bash
# CPU and memory
kubectl top pod -l app=spark-connect -n <namespace>

# Check for resource limits
kubectl get pod <spark-connect-pod> -n <namespace> -o jsonpath='{.spec.containers[0].resources}'

# Check JVM metrics
kubectl exec -it <spark-connect-pod> -n <namespace> -- \
  curl -s http://localhost:4040/api/v1/applications/*/executors | jq .
```

#### 5. Check Client Library Compatibility

```bash
# Check Spark Connect server version
kubectl exec -it <spark-connect-pod> -n <namespace> -- \
  spark-submit --version

# Verify version compatibility (client and server must match minor version)
# Spark 4.1.0 server works with 4.x clients
# Spark 3.5.7 server works with 3.5.x clients
```

## Remediation

### Scenario 1: Connection Refused

**Symptoms:**
- `Connection refused` on port 15002
- Cannot reach Spark Connect server
- Service not responding

**Action:**

```bash
# Check if server is running
kubectl get pods -l app=spark-connect -n <namespace>

# If not running, describe to see why
kubectl describe pod -l app=spark-connect -n <namespace>

# Restart the server
kubectl delete pod -l app=spark-connect -n <namespace>

# Check service configuration
kubectl get svc spark-connect -n <namespace> -o yaml

# Verify port is correct
kubectl get svc spark-connect -n <namespace] -o jsonpath='{.spec.ports[0].port}'
```

### Scenario 2: Session Creation Failures

**Symptoms:**
- Clients cannot create sessions
- `Session creation failed` errors
- `SessionManager` exceptions

**Action:**

```bash
# Check session manager status
kubectl logs <spark-connect-pod> -n <namespace> --tail=1000 | grep -i "session"

# Increase session timeout
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '
{
  "spec": {
    "sparkConf": {
      "spark.connect.server.sessionManager.timeout": "30d",
      "spark.connect.server.sessionManager.defaultSessionTimeout": "30d"
    }
  }
}'

# Increase session pool size
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '
{
  "spec": {
    "sparkConf": {
      "spark.connect.server.sessionManager.maxSessions": "1000"
    }
  }
}'
```

### Scenario 3: Query Execution Failures

**Symptoms:**
- Queries fail after connection
- `Query execution failed` errors
- `AnalysisException` or other Spark errors

**Action:**

```bash
# Check application logs
kubectl logs <spark-connect-pod> -n <namespace> --tail=1000 | grep -i "error\|exception"

# Enable debug logging
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '
{
  "spec": {
    "sparkConf": {
      "spark.driver.extraJavaOptions": "-Dlog4j.logger.org.apache.spark.connect=DEBUG"
    }
  }
}'

# Check if catalog/database exists
kubectl exec -it <spark-connect-pod> -n <namespace> -- \
  spark-sql -e "SHOW DATABASES;"
```

### Scenario 4: High Latency

**Symptoms:**
- Queries take longer than expected
- Client timeouts
- High P95 request duration

**Action:**

```bash
# Check server resources
kubectl top pod -l app=spark-connect -n <namespace>

# Scale up resources if needed
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '
{
  "spec": {
    "driver": {
      "cores": 4,
      "memory": "8g"
    }
  }
}'

# Check for slow operations in logs
kubectl logs <spark-connect-pod> -n <namespace> --tail=1000 | grep -i "slow\|latency"

# Enable result chunking for large results
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '
{
  "spec": {
    "sparkConf": {
      "spark.connect.result.arrow.maxRecordsPerBatch": "10000",
      "spark.connect.result.reuseArrow": "true"
    }
  }
}'
```

### Scenario 5: Authentication Issues

**Symptoms:**
- `Authentication failed` errors
- `Unauthorized` responses
- Token validation failures

**Action:**

```bash
# Check authentication config
kubectl get sparkapplication <app-name> -n <namespace> -o json | jq -r '.spec.sparkConf | keys | .[] | select(contains("auth"))'

# For Airflow integration, verify token
kubectl get secret spark-connect-token -n <namespace> -o yaml

# Regenerate token if needed
kubectl delete secret spark-connect-token -n <namespace>
# Token will be regenerated by operator

# Verify token from client perspective
# Connect with: spark.remote.token=<token>
```

### Scenario 6: Schema/Catalog Issues

**Symptoms:**
- Cannot find tables
- `Table or view not found` errors
- Catalog not available

**Action:**

```bash
# Check Hive Metastore connection
kubectl exec -it <spark-connect-pod> -n <namespace> -- \
  curl -s http://hive-metastore:9083/health

# Check catalog configuration
kubectl get sparkapplication <app-name> -n <namespace> -o json | jq -r '.spec.sparkConf."spark.sql.catalogImplementation"'

# Verify Iceberg catalog if using
kubectl get sparkapplication <app-name> -n <namespace> -o json | jq -r '.spec.sparkConf | keys | .[] | select(contains("iceberg"))'

# Test catalog access
kubectl exec -it <spark-connect-pod> -n <namespace> -- \
  spark-sql -e "SHOW TABLES IN <database>;"
```

### Scenario 7: Resource Exhaustion

**Symptoms:**
- Server OOM
- Too many open files
- Thread exhaustion

**Action:**

```bash
# For OOM: Increase memory
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '
{
  "spec": {
    "driver": {
      "memory": "8g",
      "memoryOverhead": "2g"
    }
  }
}'

# For file descriptor issues: Increase limit in pod template
# Edit SparkApplication spec:
podTemplate:
  spec:
    containers:
      - name: spark-kubernetes-driver
        resources:
          limits:
            memory: "8g"
        securityContext:
          runAsUser: 1000
        # Add volume mount for increasing limits via sysctl on host
    # Note: May require node-level configuration

# For thread issues: Increase thread pools
kubectl patch sparkapplication <app-name> -n <namespace> --type=merge -p '
{
  "spec": {
    "sparkConf": {
      "spark.connect.server.execution.contextPool.size": "100",
      "spark.connect.server.execution.commandThreadPool.size": "20"
    }
  }
}'
```

## Recovery Scripts

### Automated Recovery

```bash
# Idempotent connect recovery script
scripts/operations/spark/recover-connect.sh <namespace> <service-name>

# This will:
# 1. Check server health
# 2. Identify failure mode
# 3. Apply appropriate remediation
# 4. Verify connectivity restored
```

### Client Connection Test

```bash
# Test connection from a client pod
scripts/operations/spark/test-connect-client.sh <namespace> <connect-url>
```

## Prevention

### 1. Health Checks

```yaml
# Add readiness probe to Spark Connect server
podTemplate:
  spec:
    containers:
      - name: spark-kubernetes-driver
        readinessProbe:
          httpGet:
            path: /
            port: 15002
          initialDelaySeconds: 30
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /
            port: 15002
          initialDelaySeconds: 60
          periodSeconds: 30
```

### 2. Resource Limits

```yaml
driver:
  cores: 4
  memory: "8g"
  memoryOverhead: "2g"
```

### 3. Session Management

```yaml
sparkConf:
  spark.connect.server.sessionManager.maxSessions: "1000"
  spark.connect.server.sessionManager.timeout: "30d"
```

### 4. Monitoring

Link to Grafana dashboard: `Spark Connect Health`

## Monitoring

### Grafana Dashboard Queries

```promql
# Request rate
rate(spark_connect_requests_total[5m])

# Error rate
rate(spark_connect_server_errors_total[5m])

# Latency
histogram_quantile(0.95, rate(spark_connect_request_duration_seconds_bucket[5m]))

# Active sessions
spark_connect_active_sessions
```

## Related Runbooks

- [Driver Crash Loop](driver-crash-loop.md)
- [Executor Failures](executor-failures.md)
- [OOM Kill Mitigation](oom-kill-mitigation.md)

## Escalation

| Time | Action |
|------|--------|
| 5 min | Check server health and logs |
| 15 min | If server down, restart |
| 30 min | If persistent issues, escalate to Platform team |

## Changelog

| Date | Change |
|------|--------|
| 2025-02-11 | Initial version |
