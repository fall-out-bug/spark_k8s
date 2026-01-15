## WS-001-05: Hive Metastore

### Goal

**What should WORK after WS completion:**
- Hive Metastore service runs with PostgreSQL backend
- Spark can create and query managed tables
- Metastore data persists across restarts
- Warehouse location in S3

**Acceptance Criteria:**
- [ ] Metastore pod starts and initializes schema
- [ ] PostgreSQL for metastore runs (optional, can use external)
- [ ] Spark session connects to metastore (thrift://metastore:9083)
- [ ] `CREATE TABLE` and `SELECT` work from spark-submit
- [ ] Tables stored in S3 warehouse location
- [ ] Metastore logs show "Starting hive metastore"

**WS is NOT complete until Goal is achieved (all AC checked).**

---

### Context

Hive Metastore provides metadata storage for Spark SQL tables. This is a SEPARATE instance from spark-platform's metastore (as per requirements) to allow independent operation of Standalone and Connect clusters. Uses existing `metastore` mode from entrypoint.sh.

### Dependency

WS-001-01 (Chart Skeleton — for PostgreSQL template reference)

### Input Files

- `charts/spark-platform/templates/hive-metastore.yaml` — reference
- `charts/spark-platform/templates/postgresql.yaml` — reference
- `docker/spark/entrypoint.sh` — already has `metastore` mode
- `charts/spark-standalone/values.yaml` — hiveMetastore section

### Steps

1. Create `charts/spark-standalone/templates/hive-metastore.yaml`
2. Create `charts/spark-standalone/templates/postgresql-metastore.yaml` (optional)
3. Update ConfigMap with metastore connection settings
4. Update values.yaml with hiveMetastore section
5. Test table creation and query

### Code

```yaml
# hive-metastore.yaml
{{- if .Values.hiveMetastore.enabled }}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "spark-standalone.fullname" . }}-metastore
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hive-metastore
  template:
    spec:
      initContainers:
      - name: wait-for-postgres
        image: busybox
        command: ['sh', '-c', 'until nc -z {{ .Values.hiveMetastore.postgresql.host }} 5432; do sleep 2; done']
      containers:
      - name: metastore
        image: "{{ .Values.hiveMetastore.image.repository }}:{{ .Values.hiveMetastore.image.tag }}"
        env:
        - name: SPARK_MODE
          value: "metastore"
        - name: HIVE_METASTORE_WAREHOUSE_DIR
          value: "{{ .Values.hiveMetastore.warehouseDir }}"
        # PostgreSQL connection via javax.jdo properties
        - name: METASTORE_DB_HOST
          value: "{{ .Values.hiveMetastore.postgresql.host }}"
        ports:
        - containerPort: 9083
---
apiVersion: v1
kind: Service
metadata:
  name: {{ include "spark-standalone.fullname" . }}-metastore
spec:
  ports:
  - port: 9083
    targetPort: 9083
  selector:
    app: hive-metastore
{{- end }}
```

```yaml
# values.yaml - hiveMetastore section
hiveMetastore:
  enabled: true
  image:
    repository: spark-custom
    tag: "3.5.7"
    pullPolicy: IfNotPresent
  warehouseDir: "s3a://warehouse/standalone"
  postgresql:
    enabled: true  # Set false for external PostgreSQL
    host: "spark-sa-postgresql-metastore"
    database: "metastore_standalone"
    username: "hive"
    password: "hive123"
  resources:
    requests:
      memory: "512Mi"
      cpu: "200m"
    limits:
      memory: "2Gi"
      cpu: "1000m"
```

### Expected Result

- `charts/spark-standalone/templates/hive-metastore.yaml` created
- `charts/spark-standalone/templates/postgresql-metastore.yaml` created (optional)
- Metastore running and accessible

### Scope Estimate

- Files: 2 created + 2 modified
- Lines: ~300 (SMALL)
- Tokens: ~900

### Completion Criteria

```bash
# Deploy with metastore
helm upgrade --install spark-sa charts/spark-standalone

# Check metastore pod
kubectl get pods -l app=hive-metastore
kubectl logs -l app=hive-metastore | grep "Starting hive metastore"

# Test table creation
kubectl exec -it deploy/spark-sa-master -- spark-sql \
  --master spark://spark-sa-master:7077 \
  --conf spark.sql.catalogImplementation=hive \
  --conf spark.hadoop.hive.metastore.uris=thrift://spark-sa-metastore:9083 \
  -e "CREATE TABLE test_table (id INT, name STRING); SHOW TABLES;"

# Verify warehouse in S3
kubectl exec -it deploy/minio -- mc ls myminio/warehouse/standalone/
```

### Constraints

- DO NOT share metastore with spark-platform — must be independent
- DO NOT add security contexts — that's WS-001-09
- PostgreSQL must be optional (can use external in prod)
