## WS-020-21: Celeborn Guide EN

### 🎯 Goal

**What should WORK after WS completion:**
- English guide `docs/guides/CELEBORN-GUIDE.md` exists
- Guide explains when/why to use Celeborn, architecture, deployment, integration with Spark 4.1.0
- Guide includes troubleshooting and performance tuning

**Acceptance Criteria:**
- [ ] `docs/guides/CELEBORN-GUIDE.md` exists (~250 LOC)
- [ ] Guide sections: Overview, Architecture, When to Use, Deployment, Spark Integration, Troubleshooting
- [ ] Example values overlay for Celeborn deployment
- [ ] Guide links to integration test script

**⚠️ WS is NOT complete until Goal is achieved (all AC ✅).**

---

### Context

Feature F04 includes Celeborn as optional component. This guide educates users on its benefits and integration.

### Dependency

WS-020-11 (Celeborn chart), WS-020-13 (integration configs)

### Input Files

**Reference:**
- [Apache Celeborn Documentation](https://celeborn.apache.org/docs/latest/)
- `docs/drafts/idea-spark-410-charts.md` — Celeborn benefits section

### Steps

1. **Create `docs/guides/CELEBORN-GUIDE.md`:**
   
   Structure:
   ```markdown
   # Apache Celeborn Integration Guide
   
   ## Overview
   
   Apache Celeborn (formerly RSS - Remote Shuffle Service) is a disaggregated shuffle service for Apache Spark.
   
   ## Why Celeborn?
   
   Benefits:
   - **Stability**: Shuffle data survives executor failures
   - **Performance**: Optimized for large-scale shuffles (>100GB)
   - **Cost**: Enables aggressive executor scaling (spot instances)
   - **Skew Handling**: Optimizes skewed partitions
   
   ## When to Use Celeborn
   
   ✅ Use Celeborn when:
   - Shuffle data > 100GB
   - Frequent OOM or shuffle fetch failures
   - Using spot instances or dynamic allocation
   - Production workloads with SLAs
   
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
   │   Celeborn Masters (HA)     │ ← Coordination
   │   (3 replicas)              │
   └────────┬────────────────────┘
            │
   ┌────────▼────────────────────┐
   │   Celeborn Workers          │ ← Shuffle data storage
   │   (StatefulSet + PVC)       │
   └─────────────────────────────┘
   ```
   
   ## Deployment
   
   ### 1. Deploy Celeborn
   
   ```bash
   helm install celeborn charts/celeborn \\
     --set master.replicas=3 \\
     --set worker.replicas=5 \\
     --set worker.storage.size=200Gi \\
     --wait
   ```
   
   ### 2. Deploy Spark 4.1.0 with Celeborn
   
   ```bash
   helm install spark-41 charts/spark-4.1 \\
     --set celeborn.enabled=true \\
     --set celeborn.masterEndpoints="celeborn-master-0.celeborn-master:9097,celeborn-master-1.celeborn-master:9097,celeborn-master-2.celeborn-master:9097" \\
     --wait
   ```
   
   ### 3. Verify Integration
   
   ```bash
   # Check Celeborn workers are running
   kubectl get pods -l app=celeborn-worker
   
   # Run shuffle-heavy job
   kubectl run spark-shuffle-test --image=spark-custom:4.1.0 \\
     --restart=Never --rm -i \\
     -- /opt/spark/bin/spark-submit \\
     --conf spark.shuffle.manager=org.apache.spark.shuffle.celeborn.RssShuffleManager \\
     --conf spark.celeborn.master.endpoints=celeborn-master-0.celeborn-master:9097 \\
     --class org.apache.spark.examples.GroupByTest \\
     local:///opt/spark/examples/jars/spark-examples.jar 10 500 2
   
   # Check Celeborn worker logs
   kubectl logs -l app=celeborn-worker --tail=100 | grep shuffle
   ```
   
   ## Spark Integration Details
   
   Configuration (auto-applied when `celeborn.enabled=true`):
   
   ```properties
   spark.shuffle.manager=org.apache.spark.shuffle.celeborn.RssShuffleManager
   spark.celeborn.master.endpoints=<endpoints>
   spark.celeborn.push.replicate.enabled=true
   spark.celeborn.client.spark.shuffle.writer=hash
   ```
   
   ## Performance Tuning
   
   ### Worker Storage
   
   - Use SSDs for `/mnt/celeborn` (high IOPS)
   - Size: 100-500GB per worker (depends on shuffle volume)
   
   ### Worker Count
   
   - Rule of thumb: 1 worker per 50 executors
   - Monitor disk usage: `kubectl exec celeborn-worker-0 -- df -h /mnt/celeborn`
   
   ### Master HA
   
   - Always use 3 replicas (quorum-based HA)
   - Masters are stateless (safe to restart)
   
   ## Troubleshooting
   
   ### Issue 1: Worker Disk Full
   
   **Symptom:** Shuffle failures, worker logs show "disk full"
   
   **Solution:**
   - Increase PVC size: `helm upgrade celeborn --set worker.storage.size=500Gi`
   - Enable cleanup: `celeborn.worker.cleanup.enabled=true`
   
   ### Issue 2: Connection Refused
   
   **Symptom:** Spark job fails with "Connection refused: celeborn-master"
   
   **Solution:**
   - Check master endpoints: `kubectl get svc celeborn-master`
   - Verify network policy allows Spark → Celeborn traffic
   
   ### Issue 3: Slower than Standard Shuffle
   
   **Symptom:** Jobs slower with Celeborn than without
   
   **Solution:**
   - Check worker disk IOPS (must be SSD)
   - Increase worker count
   - Disable Celeborn for small shuffles (<10GB)
   
   ## Monitoring
   
   Key metrics (Celeborn exposes Prometheus metrics):
   
   - `celeborn_worker_disk_usage` — Disk space usage
   - `celeborn_worker_active_connections` — Active shuffle connections
   - `celeborn_master_registered_workers` — Worker health
   
   ## References
   
   - [Apache Celeborn Documentation](https://celeborn.apache.org/)
   - [Spark Shuffle Manager Configuration](https://spark.apache.org/docs/latest/configuration.html#shuffle-behavior)
   - [Integration Test Script](../../scripts/test-spark-41-integrations.sh)
   ```

2. **Update README.md:**
   ```markdown
   - [Celeborn Integration Guide (EN)](docs/guides/CELEBORN-GUIDE.md)
   ```

### Expected Result

```
docs/guides/
└── CELEBORN-GUIDE.md    # ~250 LOC
```

### Scope Estimate

- Files: 1 created, 1 modified (README.md)
- Lines: ~250 LOC (SMALL)
- Tokens: ~1200

### Completion Criteria

```bash
# Check guide exists
ls docs/guides/CELEBORN-GUIDE.md

# Validate markdown
markdownlint docs/guides/CELEBORN-GUIDE.md || echo "Linter not installed, skip"

# Manual review for technical accuracy
```

### Constraints

- DO NOT include Spark 2.x or 3.x specific content (focus on 4.1.0)
- DO NOT recommend Celeborn for all use cases (be clear about tradeoffs)
- ENSURE all commands are tested
- USE diagrams where helpful (ASCII art or PlantUML)
