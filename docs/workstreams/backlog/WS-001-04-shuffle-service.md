## WS-001-04: External Shuffle Service

### Goal

**What should WORK after WS completion:**
- External Shuffle Service runs as DaemonSet on worker nodes
- Spark jobs use external shuffle for stability
- Shuffle data persists across executor restarts

**Acceptance Criteria:**
- [ ] Shuffle Service pods run on each node (DaemonSet)
- [ ] Spark config includes `spark.shuffle.service.enabled=true`
- [ ] Shuffle Service port 7337 accessible from workers
- [ ] Jobs with multiple stages complete successfully (shuffle works)
- [ ] Shuffle Service logs show "Started external shuffle service"

**WS is NOT complete until Goal is achieved (all AC checked).**

---

### Context

External Shuffle Service (ESS) allows shuffle data to persist independently of executors. This is critical for job stability — if an executor fails, shuffle data is not lost. ESS runs as a DaemonSet so each node has shuffle service available.

### Dependency

WS-001-03 (Spark Workers)

### Input Files

- `charts/spark-standalone/values.yaml` — shuffle service config
- `charts/spark-standalone/templates/configmap.yaml` — Spark configuration
- `docker/spark/entrypoint.sh` — needs `shuffle` mode

### Steps

1. Add `shuffle` mode to `docker/spark/entrypoint.sh`
2. Create `charts/spark-standalone/templates/shuffle-service.yaml` with DaemonSet
3. Update ConfigMap with shuffle service configuration
4. Update values.yaml with shuffleService section
5. Test multi-stage job completes successfully

### Code

```bash
# entrypoint.sh - add shuffle mode
shuffle)
  echo "Starting External Shuffle Service..."
  export SPARK_SHUFFLE_SERVICE_PORT=${SPARK_SHUFFLE_SERVICE_PORT:-7337}
  exec /opt/spark/bin/spark-class org.apache.spark.deploy.ExternalShuffleService
  ;;
```

```yaml
# shuffle-service.yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: {{ include "spark-standalone.fullname" . }}-shuffle
  labels:
    app: spark-shuffle
spec:
  selector:
    matchLabels:
      app: spark-shuffle
  template:
    metadata:
      labels:
        app: spark-shuffle
    spec:
      containers:
      - name: shuffle-service
        image: "{{ .Values.shuffleService.image.repository }}:{{ .Values.shuffleService.image.tag }}"
        env:
        - name: SPARK_MODE
          value: "shuffle"
        ports:
        - containerPort: 7337
          hostPort: 7337
        volumeMounts:
        - name: shuffle-data
          mountPath: /tmp/spark-shuffle
      volumes:
      - name: shuffle-data
        hostPath:
          path: /tmp/spark-shuffle
          type: DirectoryOrCreate
---
apiVersion: v1
kind: Service
metadata:
  name: {{ include "spark-standalone.fullname" . }}-shuffle
spec:
  clusterIP: None  # Headless for direct pod access
  selector:
    app: spark-shuffle
  ports:
  - port: 7337
    targetPort: 7337
```

```yaml
# ConfigMap addition
spark.shuffle.service.enabled: "true"
spark.shuffle.service.port: "7337"
spark.dynamicAllocation.shuffleTracking.enabled: "true"
```

### Expected Result

- `docker/spark/entrypoint.sh` updated with `shuffle` mode
- `charts/spark-standalone/templates/shuffle-service.yaml` created
- Shuffle service running on each node

### Scope Estimate

- Files: 1 created + 2 modified
- Lines: ~150 (SMALL)
- Tokens: ~500

### Completion Criteria

```bash
# Deploy with shuffle service
helm upgrade --install spark-sa charts/spark-standalone

# Check shuffle pods (should be on each node)
kubectl get pods -l app=spark-shuffle -o wide

# Check shuffle service logs
kubectl logs -l app=spark-shuffle | grep "Started external shuffle"

# Run multi-stage job (word count with shuffle)
kubectl exec -it deploy/spark-sa-master -- spark-submit \
  --master spark://spark-sa-master:7077 \
  --conf spark.shuffle.service.enabled=true \
  /opt/spark/examples/jars/spark-examples_2.12-3.5.7.jar
```

### Constraints

- DO NOT use PersistentVolumes for shuffle — hostPath is sufficient for standalone
- DO NOT add security contexts — that's WS-001-09
- Shuffle Service must be optional (enabled: true/false in values)
