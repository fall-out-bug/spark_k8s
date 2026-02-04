# Troubleshooting Guide

Decision trees and diagnostic procedures for common Apache Spark on Kubernetes issues.

## 🎯 Quick Navigation

| Issue Category | Most Common Symptom | Time to Resolve |
|----------------|---------------------|-----------------|
| [Job Won't Start](#job-wont-start) | Pod stuck in Pending | 5-15 min |
| [Performance](#performance-issues) | Job slower than expected | 15-60 min |
| [Memory Issues](#memory-issues) | OOM killed | 10-30 min |
| [Storage Issues](#storage-issues) | Can't read/write data | 10-20 min |
| [Network Issues](#network-issues) | Connection timeouts | 15-30 min |
| [Spark Connect](#spark-connect-issues) | Can't connect to server | 5-10 min |

---

## Job Won't Start

### Symptom: Pod stuck in `Pending` state

```
kubectl get pods
NAME              READY   STATUS    RESTARTS   AGE
spark-driver-1-1   0/1     Pending   0          5m
```

### Decision Tree

```
Pod Pending
│
├── Run: kubectl describe pod <pod-name>
│
├── Error: "Insufficient cpu/memory"
│   └── Solution: Increase node resources or reduce resource requests
│
├── Error: "PersistentVolumeClaim is not bound"
│   └── Solution: Check storage class, create PV/PVC
│
├── Error: "ImagePullBackOff"
│   └── Solution: Check image name, registry credentials, network
│
└── Error: "Node selectors don't match"
    └── Solution: Fix nodeSelector or taints/tolerations
```

### Quick Diagnostics

```bash
# Check pod events
kubectl describe pod <pod-name> | grep -A 10 Events

# Check resource availability
kubectl describe nodes | grep -A 5 "Allocated resources"

# Check PVC status
kubectl get pvc
kubectl describe pvc <pvc-name>

# Check image pull status
kubectl get pods -o wide
kubectl describe pod <pod-name> | grep -i image
```

### Common Fixes

```yaml
# Fix 1: Reduce resource requests
spark:
  driver:
    memory: "2g"  # Reduce from 4g
    cpu: "1"      # Reduce from 2
  executor:
    memory: "4g"  # Reduce from 8g
    cpu: "2"      # Reduce from 4

# Fix 2: Fix node selector
nodeSelector:
  nodepool: spark  # Match actual node label

# Fix 3: Add tolerations
tolerations:
  - key: "workload"
    operator: "Equal"
    value: "spark"
    effect: "NoSchedule"
```

---

## Performance Issues

### Symptom: Job slower than expected

### Decision Tree

```
Performance Issue
│
├── Check Spark UI (port-forward 18080)
│   ├── Stage duration abnormally high?
│   │   └── Check: Data skew, shuffle partitions
│   └── Executor CPU/Memory usage low?
│       └── Check: Insufficient executors, stragglers
│
├── Run: kubectl top pods
│   ├── High CPU usage?
│   │   └── Increase executors or CPU per executor
│   └── Low CPU usage?
│       └── Increase parallelism
│
└── Check metrics in Grafana
    ├── High GC time?
    │   └── Increase memory
    └── High disk I/O?
        └── Add caching, use SSD storage
```

### Quick Diagnostics

```bash
# Port-forward Spark UI
kubectl port-forward svc/spark-history 18080:18080
open http://localhost:18080

# Check executor resource usage
kubectl top pods -l spark-role=executor

# Check Spark metrics
kubectl exec -it <driver-pod> -- curl localhost:4040/metrics/json

# Check shuffle spills (indicator of memory pressure)
kubectl logs <driver-pod> | grep "shuffle spill"
```

### Common Fixes

```python
# Fix 1: Increase shuffle partitions
spark.conf.set("spark.sql.shuffle.partitions", "200")  # Default: 200

# Fix 2: Increase executors
spark.conf.set("spark.executor.instances", "10")

# Fix 3: Enable caching for repeated operations
df.cache()
df.count()  # Action to materialize cache

# Fix 4: Handle data skew
# Repartition on skewed key
df = df.repartition(200, "skewed_key")

# Fix 5: Use broadcast join for small tables
from pyspark.sql.functions import broadcast
result = large_df.join(broadcast(small_df), "key")
```

---

## Memory Issues

### Symptom: Pod `OOMKilled`

```
kubectl get pods
NAME              READY   STATUS      RESTARTS   AGE
spark-executor-1   0/1     OOMKilled   1          10m
```

### Decision Tree

```
OOM Killed
│
├── Driver OOM?
│   ├── Increase driver memory
│   ├── Reduce driver memory fraction (spark.driver.memoryOverhead)
│   └── Check for cached data in driver
│
└── Executor OOM?
    ├── Increase executor memory
    ├── Increase memory overhead
    ├── Check shuffle spill (increase memory)
    └── Reduce broadcast join size
```

### Quick Diagnostics

```bash
# Check pod termination reason
kubectl describe pod <pod-name> | grep -i "terminated"

# Check memory limits
kubectl get pod <pod-name> -o jsonpath='{.spec.containers[*].resources}'

# Check heap usage
kubectl exec -it <pod-name> -- jmap -heap 1

# Check GC logs
kubectl logs <pod-name> | grep -i "gc"
```

### Common Fixes

```yaml
# Fix 1: Increase memory limits
spark:
  driver:
    memory: "8g"  # Increase from 4g
    memoryOverhead: "2g"
  executor:
    memory: "16g"  # Increase from 8g
    memoryOverhead: "3g"

# Fix 2: Tune memory fraction
spark:
  executor:
    memoryFraction: 0.8  # Default: 0.6
    memoryStorageFraction: 0.3  # Default: 0.5
```

```python
# Fix 3: Reduce off-heap memory usage
spark.conf.set("spark.memory.offHeap.enabled", "false")

# Fix 4: Increase shuffle buffer
spark.conf.set("spark.shuffle.file.buffer", "64k")  # Default: 32k

# Fix 5: Use map-side join
result = df1.join(broadcast(df2), "key")  # Broadcast smaller table
```

---

## Storage Issues

### Symptom: Can't read/write data

### Decision Tree

```
Storage Issue
│
├── Can't read S3/GCS?
│   ├── Check credentials
│   ├── Check bucket permissions
│   └── Check network connectivity
│
├── Can't write to PV/PVC?
│   ├── Check PVC status (Bound?)
│   ├── Check storage class
│   └── Check PV capacity
│
└── Slow I/O performance?
    ├── Check storage type (HDD vs SSD)
    ├── Enable caching
    └── Increase parallelism
```

### Quick Diagnostics

```bash
# Check PVC status
kubectl get pvc
kubectl describe pvc <pvc-name>

# Check PV
kubectl get pv
kubectl describe pv <pv-name>

# Test S3 connectivity
kubectl exec -it <pod-name> -- aws s3 ls s3://bucket/

# Test PV write
kubectl exec -it <pod-name> -- touch /data/test.txt
```

### Common Fixes

```yaml
# Fix 1: Add S3 credentials to secret
apiVersion: v1
kind: Secret
metadata:
  name: aws-credentials
type: Opaque
stringData:
  AWS_ACCESS_KEY_ID: "your-access-key"
  AWS_SECRET_ACCESS_KEY: "your-secret-key"

---
# Fix 2: Mount secret as environment variables
spec:
  containers:
    - name: spark-executor
      envFrom:
        - secretRef:
            name: aws-credentials
```

```python
# Fix 3: Use S3A with proper configuration
spark.conf.set("spark.hadoop.fs.s3a.access.key", "your-access-key")
spark.conf.set("spark.hadoop.fs.s3a.secret.key", "your-secret-key")
spark.conf.set("spark.hadoop.fs.s3a.endpoint", "s3.amazonaws.com")

# Fix 4: Increase parallelism for better throughput
df.repartition(100).write.parquet("s3a://bucket/output/")

# Fix 5: Use faster compression
df.write.parquet("s3a://bucket/output/", compression="snappy")  # Faster than gzip
```

---

## Network Issues

### Symptom: Connection timeouts, DNS failures

### Decision Tree

```
Network Issue
│
├── DNS resolution fails?
│   ├── Check CoreDNS
│   ├── Check network policies
│   └── Check service discovery
│
├── Connection refused?
│   ├── Check service port
│   ├── Check network policies
│   └── Check pod readiness
│
└── High latency?
    ├── Check跨node communication
    ├── Check service mesh (if using)
    └── Enable host network (if appropriate)
```

### Quick Diagnostics

```bash
# Check DNS resolution
kubectl exec -it <pod-name> -- nslookup spark-connect

# Check service endpoints
kubectl get endpoints
kubectl describe svc <service-name>

# Check network policies
kubectl get networkpolicies --all-namespaces

# Test connectivity
kubectl exec -it <pod-name> -- wget -O- http://spark-connect:15002

# Check pod-to-pod connectivity
kubectl exec -it <pod1> -- ping <pod2-ip>
```

### Common Fixes

```yaml
# Fix 1: Allow traffic with network policy
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: spark-allow-all
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/part-of: spark-k8s
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - {}
  egress:
  - {}
```

```yaml
# Fix 2: Enable DNS policy
spec:
  template:
    spec:
      dnsPolicy: ClusterFirst
      # or: ClusterFirstWithHostNet for hostNetwork pods
```

---

## Spark Connect Issues

### Symptom: Can't connect to Spark Connect server

### Decision Tree

```
Spark Connect Issue
│
├── Connection refused?
│   ├── Check service is running
│   ├── Check port is correct
│   └── Check port-forward (if local)
│
├── Authentication failed?
│   ├── Check token configuration
│   └── Check TLS certificates
│
└── Session timeout?
    ├── Increase session timeout
    └── Reconnect with new session
```

### Quick Diagnostics

```bash
# Check Spark Connect service
kubectl get svc spark-connect
kubectl describe svc spark-connect

# Check server status
kubectl logs -f deployment/spark-connect

# Port-forward to local
kubectl port-forward svc/spark-connect 15002:15002

# Test connection
curl http://localhost:15002
```

### Common Fixes

```python
# Fix 1: Check connection URL
spark = SparkSession.builder.remote("sc://spark-connect:15002").getOrCreate()

# Fix 2: Add authentication
spark = SparkSession.builder \
    .remote("sc://spark-connect:15002") \
    .config("spark.connect.auth.token", "your-token") \
    .getOrCreate()

# Fix 3: Increase session timeout
spark.conf.set("spark.connect.grpc.session.keepaliveTimeoutMs", "120000")

# Fix 4: Enable TLS
spark = SparkSession.builder \
    .remote("sc://spark-connect:15002") \
    .config("spark.connect.grpc.tls.enabled", "true") \
    .config("spark.connect.grpc.tls.trustStore", "/path/to/truststore.jks") \
    .getOrCreate()
```

---

## Quick Reference Commands

### General Diagnostics

```bash
# Check all Spark pods
kubectl get pods -l app.kubernetes.io/part-of=spark-k8s

# Check pod logs
kubectl logs -f <pod-name>

# Check pod resource usage
kubectl top pods -l app.kubernetes.io/part-of=spark-k8s

# Check events
kubectl get events --sort-by='.lastTimestamp'

# Check node resources
kubectl describe nodes | grep -A 5 "Allocated resources"
```

### Spark UI Access

```bash
# Spark History Server
kubectl port-forward svc/spark-history 18080:18080
open http://localhost:18080

# Spark Connect UI (if available)
kubectl port-forward svc/spark-connect 4040:4040
open http://localhost:4040

# Driver UI (if driver is running)
kubectl port-forward <driver-pod> 4040:4040
open http://localhost:4040
```

### Metrics & Monitoring

```bash
# Prometheus metrics
kubectl port-forward svc/prometheus 9090:9090
open http://localhost:9090

# Grafana dashboards
kubectl port-forward svc/grafana 3000:3000
open http://localhost:3000

# Query metrics
curl http://prometheus:9090/api/v1/query?query=spark_job_failed_total
```

---

## Escalation Path

### Level 1: Self-Service (0-15 min)
1. Check this troubleshooting guide
2. Run quick diagnostics
3. Try common fixes

### Level 2: Platform Team (15-60 min)
1. Collect logs and metrics
2. Create support ticket
3. Attach diagnostic output

### Level 3: Emergency (>60 min, production impact)
1. Page on-call
2. Follow incident response runbook
3. Escalate to engineering management

---

## Related Resources

- [Production Operations Suite](../drafts/feature-production-operations.md) — 50+ runbooks
- [Incident Response Runbook](operations/runbooks/incident-response.md) — Emergency procedures
- [Performance Tuning Guide](operations/performance-tuning.md) — Optimization strategies
- [Alert Configuration](operations/alert-configuration.md) — Monitoring setup
- [Telegram Community](https://t.me/spark_k8s) — Get help

---

**Last Updated:** 2026-02-04
**Part of:** [F19: Documentation Enhancement](../drafts/feature-documentation-enhancement.md)
