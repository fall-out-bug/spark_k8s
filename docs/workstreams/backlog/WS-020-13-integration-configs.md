## WS-020-13: Integration Configs (Celeborn + Spark, Operator + Spark)

### 🎯 Goal

**What should WORK after WS completion:**
- `spark-4.1` chart integrates with Celeborn when both are enabled
- `spark-4.1` chart values are compatible with Spark Operator CRDs
- Example SparkApplication CR demonstrates Spark 4.1.0 + Celeborn + Operator
- Documentation added to values.yaml for integration patterns

**Acceptance Criteria:**
- [ ] `charts/spark-4.1/values.yaml` updated with `celeborn.masterEndpoints` reference
- [ ] `charts/spark-4.1/templates/spark-connect-configmap.yaml` includes Celeborn config when enabled
- [ ] `docs/examples/spark-application-celeborn.yaml` provides example SparkApplication CR
- [ ] `docs/examples/values-spark-41-with-celeborn.yaml` provides overlay for full integration
- [ ] Validation: `helm template` renders correct Celeborn config when enabled

**⚠️ WS is NOT complete until Goal is achieved (all AC ✅).**

---

### Context

Feature F04 includes optional Celeborn and Spark Operator. This WS ensures seamless integration between these components and Spark 4.1.0.

### Dependency

WS-020-06 (Spark Connect template), WS-020-11 (Celeborn chart), WS-020-12 (Spark Operator chart)

### Input Files

**Reference:**
- `charts/spark-4.1/templates/spark-connect-configmap.yaml` — Existing Spark properties
- `charts/celeborn/values.yaml` — Celeborn service endpoints
- `/home/fall_out_bug/projects/spark-connect-kubernetes/charts/spark-connect/values.yaml` — Celeborn integration example

### Steps

1. **Update `charts/spark-4.1/values.yaml`:**
   
   Add Celeborn integration section:
   ```yaml
   celeborn:
     enabled: false
     masterEndpoints: "celeborn-master-0.celeborn-master:9097,celeborn-master-1.celeborn-master:9097,celeborn-master-2.celeborn-master:9097"
   ```

2. **Update `charts/spark-4.1/templates/spark-connect-configmap.yaml`:**
   
   Add Celeborn conditional block (already partially done in WS-020-06):
   ```properties
   {{- if .Values.celeborn.enabled }}
   # Celeborn Remote Shuffle Service
   spark.shuffle.manager=org.apache.spark.shuffle.celeborn.RssShuffleManager
   spark.celeborn.master.endpoints={{ .Values.celeborn.masterEndpoints }}
   spark.celeborn.push.replicate.enabled=true
   spark.celeborn.client.spark.shuffle.writer=hash
   spark.celeborn.client.spark.fetch.throwsFetchFailure=true
   {{- end }}
   ```

3. **Create `docs/examples/spark-application-celeborn.yaml`:**
   
   Example SparkApplication CR for Spark Operator:
   ```yaml
   apiVersion: sparkoperator.k8s.io/v1beta2
   kind: SparkApplication
   metadata:
     name: spark-pi-celeborn
     namespace: default
   spec:
     type: Scala
     mode: cluster
     image: "spark-custom:4.1.0"
     sparkVersion: "4.1.0"
     mainClass: org.apache.spark.examples.SparkPi
     mainApplicationFile: "local:///opt/spark/examples/jars/spark-examples.jar"
     arguments:
       - "1000"
     sparkConf:
       spark.shuffle.manager: "org.apache.spark.shuffle.celeborn.RssShuffleManager"
       spark.celeborn.master.endpoints: "celeborn-master-0.celeborn-master:9097"
       spark.celeborn.push.replicate.enabled: "true"
       spark.eventLog.enabled: "true"
       spark.eventLog.dir: "s3a://spark-logs/4.1/events"
       spark.hadoop.fs.s3a.endpoint: "minio:9000"
     driver:
       cores: 1
       memory: "512m"
       serviceAccount: spark-41
     executor:
       cores: 1
       instances: 2
       memory: "512m"
     restartPolicy:
       type: Never
   ```

4. **Create `docs/examples/values-spark-41-with-celeborn.yaml`:**
   ```yaml
   # Full integration: Spark 4.1.0 + Celeborn
   spark-base:
     enabled: true
     rbac:
       create: true
     minio:
       enabled: true
     postgresql:
       enabled: true
   
   connect:
     enabled: true
     dynamicAllocation:
       enabled: true
       maxExecutors: 20
   
   celeborn:
     enabled: true
     masterEndpoints: "celeborn-master-0.celeborn-master:9097,celeborn-master-1.celeborn-master:9097,celeborn-master-2.celeborn-master:9097"
   
   hiveMetastore:
     enabled: true
   
   historyServer:
     enabled: true
   
   jupyter:
     enabled: true
   ```

5. **Add documentation comments to `values.yaml`:**
   ```yaml
   # Celeborn integration (optional)
   # Requires separate Celeborn deployment:
   #   helm install celeborn charts/celeborn
   #
   # For Spark Operator integration, see:
   #   docs/examples/spark-application-celeborn.yaml
   celeborn:
     enabled: false
     masterEndpoints: "celeborn-master-0.celeborn-master:9097,..."
   ```

6. **Validate integration:**
   ```bash
   # Test Celeborn config rendering
   helm template spark-41 charts/spark-4.1 \
     --set celeborn.enabled=true \
     --set celeborn.masterEndpoints="celeborn-master:9097"
   
   # Verify shuffle manager config
   helm template spark-41 charts/spark-4.1 \
     --set celeborn.enabled=true | \
     grep "spark.shuffle.manager"
   ```

### Expected Result

```
docs/examples/
├── spark-application-celeborn.yaml        # ~60 LOC
└── values-spark-41-with-celeborn.yaml     # ~40 LOC

charts/spark-4.1/
├── values.yaml (updated)                  # +30 LOC comments
└── templates/
    └── spark-connect-configmap.yaml (updated)  # already done in WS-020-06
```

### Scope Estimate

- Files: 2 created, 2 modified
- Lines: ~130 LOC (SMALL)
- Tokens: ~600

### Completion Criteria

```bash
# Template with Celeborn enabled
helm template spark-41 charts/spark-4.1 \
  --set celeborn.enabled=true | \
  grep "RssShuffleManager"

# Validate example SparkApplication
kubectl apply --dry-run=client -f docs/examples/spark-application-celeborn.yaml

# Test overlay values
helm template spark-41 charts/spark-4.1 \
  -f docs/examples/values-spark-41-with-celeborn.yaml
```

### Constraints

- DO NOT deploy Celeborn from spark-4.1 chart (separate chart)
- DO NOT hardcode Celeborn endpoints (use values override)
- ENSURE Celeborn config is conditional (only when enabled)
- PROVIDE clear documentation on integration steps
