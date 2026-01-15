## WS-001-07: MLflow

### Goal

**What should WORK after WS completion:**
- MLflow Tracking Server running with PostgreSQL backend
- Artifacts stored in MinIO bucket `mlflow-artifacts`
- Web UI accessible for experiment tracking
- Spark jobs can log metrics/models to MLflow

**Acceptance Criteria:**
- [ ] MLflow server pod starts and serves UI on port 5000
- [ ] PostgreSQL for MLflow runs (optional, can use external)
- [ ] MinIO bucket `mlflow-artifacts` created
- [ ] MLflow UI shows experiments list
- [ ] Test experiment logs metrics successfully
- [ ] Artifacts visible in MinIO bucket

**WS is NOT complete until Goal is achieved (all AC checked).**

---

### Context

MLflow provides experiment tracking for ML jobs on Spark. Uses PostgreSQL for metadata and MinIO for artifact storage. This enables tracking metrics, parameters, and models from spark-submit ML jobs.

### Dependency

WS-001-01 (Chart Skeleton — for S3 credentials)

### Input Files

- `k8s/optional/mlflow/deployment.yaml` — existing MLflow deployment reference
- `charts/spark-standalone/values.yaml` — mlflow section

### Steps

1. Create `charts/spark-standalone/templates/mlflow/server.yaml`
2. Create `charts/spark-standalone/templates/mlflow/postgresql.yaml` (optional)
3. Add MinIO bucket creation to minio init job
4. Update values.yaml with mlflow section
5. Test experiment logging

### Code

```yaml
# mlflow/server.yaml
{{- if .Values.mlflow.enabled }}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "spark-standalone.fullname" . }}-mlflow
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mlflow
  template:
    spec:
      containers:
      - name: mlflow
        image: "{{ .Values.mlflow.image.repository }}:{{ .Values.mlflow.image.tag }}"
        command:
        - mlflow
        - server
        - --host=0.0.0.0
        - --port=5000
        - --backend-store-uri=postgresql://$(POSTGRES_USER):$(POSTGRES_PASSWORD)@{{ .Values.mlflow.postgresql.host }}:5432/{{ .Values.mlflow.postgresql.database }}
        - --default-artifact-root=s3://{{ .Values.mlflow.artifactBucket }}/
        - --serve-artifacts
        env:
        - name: POSTGRES_USER
          value: "{{ .Values.mlflow.postgresql.username }}"
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: {{ include "spark-standalone.fullname" . }}-mlflow-secret
              key: postgresql-password
        - name: AWS_ACCESS_KEY_ID
          valueFrom:
            secretKeyRef:
              name: {{ include "spark-standalone.fullname" . }}-s3-secret
              key: access-key
        - name: AWS_SECRET_ACCESS_KEY
          valueFrom:
            secretKeyRef:
              name: {{ include "spark-standalone.fullname" . }}-s3-secret
              key: secret-key
        - name: MLFLOW_S3_ENDPOINT_URL
          value: "{{ .Values.s3.endpoint }}"
        ports:
        - containerPort: 5000
        readinessProbe:
          httpGet:
            path: /health
            port: 5000
          initialDelaySeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: {{ include "spark-standalone.fullname" . }}-mlflow
spec:
  ports:
  - port: 5000
    targetPort: 5000
  selector:
    app: mlflow
{{- end }}
```

```yaml
# values.yaml - mlflow section
mlflow:
  enabled: true
  image:
    repository: ghcr.io/mlflow/mlflow
    tag: "v2.14.0"
    pullPolicy: IfNotPresent
  artifactBucket: "mlflow-artifacts"
  postgresql:
    enabled: true  # Set false for external PostgreSQL
    host: "spark-sa-postgresql-mlflow"
    database: "mlflow"
    username: "mlflow"
    password: "mlflow123"
  resources:
    requests:
      memory: "256Mi"
      cpu: "100m"
    limits:
      memory: "1Gi"
      cpu: "500m"
```

### Expected Result

```
charts/spark-standalone/templates/mlflow/
├── server.yaml
└── postgresql.yaml
```

### Scope Estimate

- Files: 2 created + 1 modified
- Lines: ~300 (SMALL)
- Tokens: ~900

### Completion Criteria

```bash
# Deploy with MLflow
helm upgrade --install spark-sa charts/spark-standalone

# Check MLflow pod
kubectl get pods -l app=mlflow
kubectl logs -l app=mlflow | grep "Listening"

# Check MLflow UI
kubectl port-forward svc/spark-sa-mlflow 5000:5000
# Open http://localhost:5000

# Test experiment logging
kubectl exec -it deploy/spark-sa-mlflow -- python -c "
import mlflow
mlflow.set_tracking_uri('http://localhost:5000')
mlflow.set_experiment('test-experiment')
with mlflow.start_run():
    mlflow.log_param('test_param', 'value')
    mlflow.log_metric('test_metric', 0.95)
print('Experiment logged successfully')
"

# Check artifacts bucket
kubectl exec -it deploy/minio -- mc ls myminio/mlflow-artifacts/
```

### Constraints

- DO NOT create ML training jobs — that's WS-001-10
- DO NOT add security contexts — that's WS-001-09
- PostgreSQL must be optional (can use external in prod)
- Use existing MinIO, just add new bucket
