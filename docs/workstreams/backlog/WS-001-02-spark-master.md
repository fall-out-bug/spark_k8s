## WS-001-02: Spark Master

### Goal

**What should WORK after WS completion:**
- Spark Master pod starts and accepts worker connections
- Web UI accessible on port 8080
- HA recovery via S3 configured
- Service exposes Master for workers and spark-submit

**Acceptance Criteria:**
- [ ] Master pod starts with `SPARK_MODE=master`
- [ ] Master Web UI accessible at `spark-master:8080`
- [ ] Master accepts worker connections on port 7077
- [ ] HA recovery directory configured to S3 (`spark.deploy.recoveryMode=FILESYSTEM`)
- [ ] Master logs show "Started daemon with process name"
- [ ] ConfigMap includes master-specific Spark configuration

**WS is NOT complete until Goal is achieved (all AC checked).**

---

### Context

Spark Master is the coordinator for the Standalone cluster. It manages worker registration, job scheduling, and provides Web UI for monitoring. HA is achieved via S3-based recovery (not ZooKeeper) — on restart, Master reads recovery state from S3.

### Dependency

WS-001-01 (Chart Skeleton)

### Input Files

- `charts/spark-standalone/values.yaml` — master configuration section
- `charts/spark-standalone/templates/_helpers.tpl` — helper functions
- `docker/spark/entrypoint.sh` — needs `master` mode added

### Steps

1. Add `master` mode to `docker/spark/entrypoint.sh`
2. Create `charts/spark-standalone/templates/master.yaml` with Deployment + Service
3. Update `charts/spark-standalone/templates/configmap.yaml` with master config
4. Update `charts/spark-standalone/values.yaml` with sparkMaster section
5. Test Master starts and Web UI is accessible

### Code

```bash
# entrypoint.sh - add master mode
master)
  echo "Starting Spark Master..."
  export SPARK_MASTER_HOST=$(hostname -i)
  export SPARK_MASTER_PORT=${SPARK_MASTER_PORT:-7077}
  export SPARK_MASTER_WEBUI_PORT=${SPARK_MASTER_WEBUI_PORT:-8080}
  # HA recovery via S3
  if [ -n "$SPARK_RECOVERY_DIR" ]; then
    export SPARK_DAEMON_JAVA_OPTS="-Dspark.deploy.recoveryMode=FILESYSTEM -Dspark.deploy.recoveryDirectory=$SPARK_RECOVERY_DIR"
  fi
  exec /opt/spark/bin/spark-class org.apache.spark.deploy.master.Master \
    --host $SPARK_MASTER_HOST \
    --port $SPARK_MASTER_PORT \
    --webui-port $SPARK_MASTER_WEBUI_PORT
  ;;
```

```yaml
# master.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "spark-standalone.fullname" . }}-master
spec:
  replicas: 1
  selector:
    matchLabels:
      app: spark-master
  template:
    spec:
      containers:
      - name: spark-master
        image: "{{ .Values.sparkMaster.image.repository }}:{{ .Values.sparkMaster.image.tag }}"
        env:
        - name: SPARK_MODE
          value: "master"
        - name: SPARK_RECOVERY_DIR
          value: "s3a://{{ .Values.s3.recoveryBucket }}/spark-recovery"
        ports:
        - containerPort: 7077  # Master port
        - containerPort: 8080  # Web UI
        - containerPort: 6066  # REST API
```

### Expected Result

- `docker/spark/entrypoint.sh` updated with `master` mode
- `charts/spark-standalone/templates/master.yaml` created
- Master pod running and accepting connections

### Scope Estimate

- Files: 2 created + 2 modified
- Lines: ~250 (SMALL)
- Tokens: ~800

### Completion Criteria

```bash
# Deploy and check master
helm upgrade --install spark-sa charts/spark-standalone --set sparkWorker.enabled=false

# Check master pod
kubectl get pods -l app=spark-master
kubectl logs -l app=spark-master | grep "Started daemon"

# Check Web UI
kubectl port-forward svc/spark-master 8080:8080
curl http://localhost:8080/

# Check master port
kubectl exec -it deploy/spark-sa-master -- nc -zv localhost 7077
```

### Constraints

- DO NOT configure workers here — that's WS-001-03
- DO NOT add security contexts — that's WS-001-09
- Master must work without workers (show empty cluster in UI)
