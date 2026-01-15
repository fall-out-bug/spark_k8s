## WS-001-06: Airflow

### Goal

**What should WORK after WS completion:**
- Airflow Webserver + Scheduler running
- Kubernetes Executor configured (tasks as pods)
- PostgreSQL backend for Airflow metadata
- Web UI accessible for DAG management

**Acceptance Criteria:**
- [ ] Airflow Webserver pod starts and serves UI on port 8080
- [ ] Airflow Scheduler pod starts and processes DAGs
- [ ] PostgreSQL for Airflow runs (optional, can use external)
- [ ] Kubernetes Executor configured in airflow.cfg
- [ ] DAG folder mounted from ConfigMap
- [ ] Airflow UI shows "Running" scheduler status
- [ ] Test DAG (BashOperator) executes successfully as K8s pod

**WS is NOT complete until Goal is achieved (all AC checked).**

---

### Context

Airflow orchestrates spark-submit jobs on the Standalone cluster. Uses Kubernetes Executor — each task runs as a separate pod. This allows scaling and isolation. PostgreSQL is optional (for tests), production uses external.

### Dependency

WS-001-03 (Spark Workers — for spark-submit target)

### Input Files

- `docker/optional/airflow/Dockerfile` — existing Airflow image
- `docker/optional/airflow/dags/` — existing DAG examples
- `k8s/optional/mlflow/deployment.yaml` — PostgreSQL pattern reference

### Steps

1. Create `charts/spark-standalone/templates/airflow/webserver.yaml`
2. Create `charts/spark-standalone/templates/airflow/scheduler.yaml`
3. Create `charts/spark-standalone/templates/airflow/postgresql.yaml` (optional)
4. Create `charts/spark-standalone/templates/airflow/configmap.yaml` (airflow.cfg + DAGs)
5. Update values.yaml with airflow section
6. Test DAG execution

### Code

```yaml
# airflow/webserver.yaml
{{- if .Values.airflow.enabled }}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "spark-standalone.fullname" . }}-airflow-webserver
spec:
  replicas: 1
  selector:
    matchLabels:
      app: airflow-webserver
  template:
    spec:
      serviceAccountName: {{ include "spark-standalone.serviceAccountName" . }}
      containers:
      - name: webserver
        image: "{{ .Values.airflow.image.repository }}:{{ .Values.airflow.image.tag }}"
        command: ["airflow", "webserver"]
        env:
        - name: AIRFLOW__DATABASE__SQL_ALCHEMY_CONN
          value: "postgresql://{{ .Values.airflow.postgresql.username }}:{{ .Values.airflow.postgresql.password }}@{{ .Values.airflow.postgresql.host }}:5432/{{ .Values.airflow.postgresql.database }}"
        - name: AIRFLOW__CORE__EXECUTOR
          value: "KubernetesExecutor"
        - name: AIRFLOW__KUBERNETES__NAMESPACE
          value: "{{ .Release.Namespace }}"
        - name: AIRFLOW__KUBERNETES__WORKER_CONTAINER_REPOSITORY
          value: "{{ .Values.sparkMaster.image.repository }}"
        - name: AIRFLOW__KUBERNETES__WORKER_CONTAINER_TAG
          value: "{{ .Values.sparkMaster.image.tag }}"
        ports:
        - containerPort: 8080
        volumeMounts:
        - name: dags
          mountPath: /opt/airflow/dags
      volumes:
      - name: dags
        configMap:
          name: {{ include "spark-standalone.fullname" . }}-airflow-dags
{{- end }}
```

```yaml
# values.yaml - airflow section
airflow:
  enabled: true
  image:
    repository: apache/airflow
    tag: "2.11.0-python3.11"
    pullPolicy: IfNotPresent
  webserver:
    resources:
      requests:
        memory: "512Mi"
        cpu: "250m"
      limits:
        memory: "2Gi"
        cpu: "1000m"
  scheduler:
    resources:
      requests:
        memory: "512Mi"
        cpu: "250m"
      limits:
        memory: "2Gi"
        cpu: "1000m"
  postgresql:
    enabled: true  # Set false for external PostgreSQL
    host: "spark-sa-postgresql-airflow"
    database: "airflow"
    username: "airflow"
    password: "airflow123"
  # Kubernetes Executor settings
  kubernetesExecutor:
    namespace: ""  # defaults to Release.Namespace
    workerImage: ""  # defaults to spark image
```

### Expected Result

```
charts/spark-standalone/templates/airflow/
├── webserver.yaml
├── scheduler.yaml
├── postgresql.yaml
└── configmap.yaml
```

### Scope Estimate

- Files: 4 created + 1 modified
- Lines: ~500 (MEDIUM)
- Tokens: ~1500

### Completion Criteria

```bash
# Deploy with Airflow
helm upgrade --install spark-sa charts/spark-standalone

# Check Airflow pods
kubectl get pods -l app=airflow-webserver
kubectl get pods -l app=airflow-scheduler

# Check Airflow UI
kubectl port-forward svc/spark-sa-airflow-webserver 8080:8080
# Open http://localhost:8080 (admin/admin)

# Trigger test DAG
kubectl exec -it deploy/spark-sa-airflow-webserver -- \
  airflow dags trigger example_bash_operator

# Check task pod created by K8s Executor
kubectl get pods -l airflow-worker=True
```

### Constraints

- DO NOT create complex DAGs — that's WS-001-10
- DO NOT add security contexts — that's WS-001-09
- PostgreSQL must be optional (can use external in prod)
- Use Kubernetes Executor, NOT Celery (no Redis/RabbitMQ needed)
