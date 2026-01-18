# Apache Celeborn Integration Guide (Spark 4.1.0)

This guide explains when and how to use Apache Celeborn with Spark 4.1.0
in Kubernetes, including deployment, integration, tuning, and troubleshooting.

## Overview

Apache Celeborn is a disaggregated shuffle service for Apache Spark. It
stores shuffle data outside of executors, improving stability and enabling
aggressive scaling in production workloads.

## Why Celeborn?

Key benefits:

- **Stability:** Shuffle data survives executor failures
- **Performance:** Better behavior for large shuffles (>100GB)
- **Cost:** Enables spot/preemptible executors
- **Skew handling:** Optimized for uneven partitions

## When to Use Celeborn

✅ Use Celeborn when:

- Shuffle data is large (>100GB)
- Jobs see OOM or fetch failures during shuffle
- You use dynamic allocation or spot instances
- Production workloads have strict SLAs

❌ Skip Celeborn when:

- Dev/testing environments
- Small datasets (<10GB)
- Spark Standalone mode (use External Shuffle Service instead)

## Architecture

```
┌─────────────────┐
│  Spark Driver   │
└────────┬────────┘
         │
┌────────▼────────────────────┐
│   Celeborn Masters (HA)     │  (3 replicas)
└────────┬────────────────────┘
         │
┌────────▼────────────────────┐
│   Celeborn Workers          │  (StatefulSet + PVC)
└─────────────────────────────┘
```

## Deployment

### 1) Deploy Celeborn

```bash
helm install celeborn charts/celeborn \
  --set master.replicas=3 \
  --set worker.replicas=5 \
  --set worker.storage.size=200Gi \
  --wait
```

### 2) Deploy Spark 4.1.0 with Celeborn

```bash
helm install spark-41 charts/spark-4.1 \
  --set celeborn.enabled=true \
  --set celeborn.masterEndpoints="celeborn-master-0.celeborn-master:9097,celeborn-master-1.celeborn-master:9097,celeborn-master-2.celeborn-master:9097" \
  --wait
```

### 3) Example values overlay

Use the existing overlay:

- `docs/examples/values-spark-41-with-celeborn.yaml`

```bash
helm install spark-41 charts/spark-4.1 \
  -f docs/examples/values-spark-41-with-celeborn.yaml \
  --wait
```

## Spark Integration Details

When `celeborn.enabled=true`, the chart applies:

```properties
spark.shuffle.manager=org.apache.spark.shuffle.celeborn.RssShuffleManager
spark.celeborn.master.endpoints=<endpoints>
spark.celeborn.push.replicate.enabled=true
spark.celeborn.client.spark.shuffle.writer=hash
```

## Verification

```bash
# Check Celeborn workers
kubectl get pods -l app=celeborn-worker

# Run a shuffle-heavy job
kubectl run spark-shuffle-test \
  --image=spark-custom:4.1.0 \
  --restart=Never --rm -i \
  -- /opt/spark/bin/spark-submit \
  --conf spark.shuffle.manager=org.apache.spark.shuffle.celeborn.RssShuffleManager \
  --conf spark.celeborn.master.endpoints=celeborn-master-0.celeborn-master:9097 \
  --class org.apache.spark.examples.GroupByTest \
  local:///opt/spark/examples/jars/spark-examples.jar 10 500 2

# Check worker logs
kubectl logs -l app=celeborn-worker --tail=100 | grep -i shuffle
```

## Performance Tuning

### Worker Storage

- Use SSD-backed storage for `/mnt/celeborn`
- Typical size: 100-500Gi per worker (depends on shuffle volume)

### Worker Count

- Rule of thumb: 1 worker per 50 executors
- Monitor disk usage:
  `kubectl exec celeborn-worker-0 -- df -h /mnt/celeborn`

### Master HA

- Use 3 replicas (quorum-based HA)
- Masters are stateless, safe to restart

## Troubleshooting

### Issue: Worker Disk Full

**Symptom:** Shuffle failures, worker logs mention disk full.

**Fix:**

- Increase PVC size: `helm upgrade celeborn --set worker.storage.size=500Gi`
- Enable cleanup (if available in values): `worker.cleanup.enabled=true`

### Issue: Connection Refused

**Symptom:** Spark job fails with `Connection refused: celeborn-master`.

**Fix:**

- Verify endpoints: `kubectl get svc celeborn-master`
- Ensure network policy allows Spark → Celeborn traffic

### Issue: Slower than Standard Shuffle

**Symptom:** Jobs are slower with Celeborn for small datasets.

**Fix:**

- Use Celeborn only for large shuffles
- Increase worker count or storage IOPS

## Monitoring

Celeborn exposes Prometheus metrics. Key signals:

- `celeborn_worker_disk_usage`
- `celeborn_worker_active_connections`
- `celeborn_master_registered_workers`

## Integration Tests

Run the integration suite:

- `scripts/test-spark-41-integrations.sh`

## References

- [Apache Celeborn Documentation](https://celeborn.apache.org/docs/latest/)
- [Spark Shuffle Configuration](https://spark.apache.org/docs/latest/configuration.html#shuffle-behavior)
