# Shared Infra Demo Runbook

**Persona recipes:** [docs/observability/recipes/](../docs/observability/recipes/) — DevOps, DataOps, Tech Lead, Data Engineer, DS (5-min guides).

## 0) Deploy Observability Stack (Prometheus + Grafana + Loki + demo-metrics-exporter)

> **Note:** demo-metrics-exporter requires Spark Master and Airflow to be running in spark-infra; it will retry until they are up.

```bash
kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f tests/observability/prometheus-demo.yaml
kubectl apply -f tests/observability/demo-metrics-exporter.yaml
kubectl apply -f tests/observability/grafana-dashboards.yaml
kubectl apply -f tests/observability/grafana-dashboards-spark.yaml
kubectl apply -f tests/observability/loki.yaml
kubectl apply -f tests/observability/promtail.yaml
./scripts/deploy-grafana-with-sidecar.sh
```

**Recommended:** `./scripts/tests/minikube/deploy-observability.sh` (deploys OTEL, Prometheus, Loki, Promtail, demo-metrics-exporter, Grafana, dashboards).

## 1) Preconditions

```bash
kubectl get ns
kubectl get pods -n spark-infra
kubectl get pods -n observability
```

Expected: running pods for `spark-infra-spark-standalone-*`, `minio`, `spark-shared-spark-35-history`, `spark-shared-spark-35-metastore`, `spark-shared-spark-base-postgresql`, and `grafana`.

## 2) Ensure shared buckets exist

```bash
kubectl run -n spark-infra minio-bootstrap --rm -i --restart=Never \
  --image=quay.io/minio/mc:latest --command -- /bin/sh -c "
  mc alias set local http://minio:9000 minioadmin minioadmin &&
  mc mb --ignore-existing local/warehouse &&
  mc mb --ignore-existing local/spark-logs &&
  mc mb --ignore-existing local/spark-jobs &&
  echo '' | mc pipe local/spark-logs/events/.keep &&
  mc ls local"
```

Upload Spark job scripts (required for nyc_taxi, citibike, movielens DAGs):

```bash
./scripts/upload-spark-jobs-to-minio.sh spark-infra
```

## 3) Run demo validation job (Spark + S3 + Metastore)

```bash
MASTER_POD=$(kubectl get pod -n spark-infra -l app.kubernetes.io/component=spark-master -o jsonpath='{.items[0].metadata.name}')

cat > /tmp/demo-verify.py <<'PY'
from pyspark.sql import SparkSession
from pyspark.sql.functions import col

spark = (SparkSession.builder
    .appName('shared-demo-verify')
    .config('spark.hadoop.fs.s3a.endpoint', 'http://minio:9000')
    .config('spark.hadoop.fs.s3a.access.key', 'minioadmin')
    .config('spark.hadoop.fs.s3a.secret.key', 'minioadmin')
    .config('spark.hadoop.fs.s3a.path.style.access', 'true')
    .config('spark.hadoop.fs.s3a.impl', 'org.apache.hadoop.fs.s3a.S3AFileSystem')
    .config('spark.hadoop.hive.metastore.uris', 'thrift://spark-shared-spark-35-metastore:9083')
    .config('spark.sql.warehouse.dir', 's3a://warehouse/spark-35')
    .enableHiveSupport()
    .getOrCreate())

print('SMOKE_COUNT=', spark.range(1000).count())

df = spark.range(10000).withColumn('g', col('id') % 16)
df.write.mode('overwrite').parquet('s3a://spark-jobs/demo-shared-verify/')
print('S3_COUNT=', spark.read.parquet('s3a://spark-jobs/demo-shared-verify/').count())

spark.sql('CREATE DATABASE IF NOT EXISTS demo_shared LOCATION "s3a://warehouse/spark-35/demo_shared.db"')
spark.sql('DROP TABLE IF EXISTS demo_shared.metrics')
spark.sql('CREATE TABLE demo_shared.metrics (value INT) USING PARQUET LOCATION "s3a://warehouse/spark-35/demo_shared.db/metrics"')
spark.sql('INSERT INTO demo_shared.metrics VALUES (42)')
print('HIVE_VALUE=', spark.sql('SELECT value FROM demo_shared.metrics').collect()[0][0])

spark.stop()
PY

kubectl cp /tmp/demo-verify.py spark-infra/$MASTER_POD:/tmp/demo-verify.py

kubectl exec -n spark-infra $MASTER_POD -- bash -lc '
DRIVER_HOST=$(hostname -i)
spark-submit \
  --master spark://spark-infra-spark-standalone-master:7077 \
  --conf spark.driver.host=$DRIVER_HOST \
  --conf spark.driver.bindAddress=0.0.0.0 \
  --conf spark.eventLog.enabled=true \
  --conf spark.eventLog.dir=s3a://spark-logs/events \
  /tmp/demo-verify.py'
```

Expected output markers:
- `SMOKE_COUNT= 1000`
- `S3_COUNT= 10000`
- `HIVE_VALUE= 42`

## 4) Verify History Server, Grafana, Loki

```bash
kubectl run -n spark-infra history-http-check --rm -i --restart=Never \
  --image=curlimages/curl:8.11.1 --command -- \
  sh -c "curl -s -o /tmp/out -w '%{http_code}' http://spark-shared-spark-35-history:18080/ && echo"

kubectl run -n observability grafana-http-check --rm -i --restart=Never \
  --image=curlimages/curl:8.11.1 --command -- \
  sh -c "curl -s -o /tmp/out -w '%{http_code}' http://grafana:3000/login && echo"

kubectl run -n observability loki-http-check --rm -i --restart=Never \
  --image=curlimages/curl:8.11.1 --command -- \
  sh -c "curl -s -o /tmp/out -w '%{http_code}' http://loki:3100/ready && echo"
```

Expected: HTTP `200` from all commands.

**Grafana dashboards:** Tech Lead Morning (overview), Logs Explorer (Airflow+Spark logs), Spark Cluster, Airflow All DAGs.

**Verify per recipes:**
```bash
./scripts/tests/minikube/verify-observability-recipes.sh
```

## 5) Optional local access for live demo

```bash
kubectl port-forward -n spark-infra svc/spark-infra-spark-standalone-master 8080:8080
kubectl port-forward -n spark-infra svc/spark-shared-spark-35-history 18080:18080
kubectl port-forward -n observability svc/grafana 3000:3000
kubectl port-forward -n spark-infra svc/minio 9000:9000 9001:9001
```

Open:
- Spark Master UI: http://localhost:8080
- History Server: http://localhost:18080
- Grafana: http://localhost:3000
- MinIO Console: http://localhost:9001

## 6) Browser URLs (NodePort, ready for demo)

```bash
MINIKUBE_IP=$(minikube ip)
echo "Airflow:    http://$MINIKUBE_IP:30080"
echo "Jupyter:    http://$MINIKUBE_IP:30088/lab"
echo "Grafana:    http://$MINIKUBE_IP:30030/login"
echo "Prometheus: http://$MINIKUBE_IP:30090"
echo "History:    http://$MINIKUBE_IP:30081"
echo "Loki:       (via Grafana Explore, datasource Loki)"
```

| Persona | Entry point |
|---------|-------------|
| DevOps | [devops-5min](../docs/observability/recipes/devops-5min.md) |
| Tech Lead | [techlead-5min](../docs/observability/recipes/techlead-5min.md) → Grafana Tech Lead Morning |
| DataOps | [dataops-5min](../docs/observability/recipes/dataops-5min.md) → Logs Explorer, phase breakdown |
| Data Engineer | [data-engineer-5min](../docs/observability/recipes/data-engineer-5min.md) |

Credentials:
- Airflow: `admin` / `admin123`
- Grafana: `admin` / `admin` (or anonymous access if enabled)
- Jupyter: token disabled in this environment

## 7) Demo pipelines and notebooks

Airflow DAGs expected in UI:

- `nyc_taxi_ml_full_pipeline`
- `spark_standalone_load_demo`
- `citibike_analytics_pipeline`
- `movielens_recommendation_pipeline`

Verify from CLI:

```bash
WEB_POD=$(kubectl get pod -n spark-infra -l app.kubernetes.io/component=airflow-webserver -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n spark-infra $WEB_POD -- airflow dags list
```

Unpause all demo DAGs:

```bash
kubectl exec -n spark-infra $WEB_POD -- airflow dags unpause nyc_taxi_ml_full_pipeline
kubectl exec -n spark-infra $WEB_POD -- airflow dags unpause spark_standalone_load_demo
kubectl exec -n spark-infra $WEB_POD -- airflow dags unpause citibike_analytics_pipeline
kubectl exec -n spark-infra $WEB_POD -- airflow dags unpause movielens_recommendation_pipeline
```

Jupyter notebooks expected:

- `nyc_taxi_pipeline_demo.ipynb`
- `spark_shared_infra_quickstart.ipynb`

Verify from CLI:

```bash
JUPYTER_POD=$(kubectl get pod -n spark-infra -l app.kubernetes.io/component=jupyter -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n spark-infra $JUPYTER_POD -- ls -la /home/jupyter/notebooks
```

## 8) Metrics and dashboards sync status

Applied from chart monitoring templates:
- `ServiceMonitor`: `spark-shared-spark-35-connect`
- `PodMonitor`: `spark-shared-spark-35-executors`
- Dashboard ConfigMaps: `spark-shared-spark-35-dashboard-*`

Quick checks:

```bash
kubectl get servicemonitor,podmonitor -n spark-infra
kubectl get configmap -n spark-infra | grep 'dashboard-'
kubectl get configmap -n spark-infra spark-shared-spark-35-dashboard-job-phase-timeline -o jsonpath='{.metadata.labels.grafana_dashboard}{"\n"}'

# demo-metrics-exporter and Prometheus target
kubectl get pod -n observability -l app=demo-metrics-exporter
curl -s "http://$(minikube ip):30090/api/v1/targets" | grep -A2 demo-metrics-exporter
```

## 9) Trigger DAG and verify History/Grafana logs

```bash
WEB_POD=$(kubectl get pod -n spark-infra -l app.kubernetes.io/component=airflow-webserver -o jsonpath='{.items[0].metadata.name}')
RUN_ID="demo-history-$(date +%Y%m%d%H%M%S)"
kubectl exec -n spark-infra $WEB_POD -- airflow dags trigger spark_standalone_load_demo --run-id "$RUN_ID"
kubectl exec -n spark-infra $WEB_POD -- airflow dags list-runs -d spark_standalone_load_demo --output table

# Event log in MinIO
kubectl run -n spark-infra minio-events-check --rm -i --restart=Never \
  --image=quay.io/minio/mc:latest --command -- /bin/sh -c "
  mc alias set local http://minio:9000 minioadmin minioadmin &&
  mc ls local/spark-logs/events"

# History API should include new app
IP=$(minikube ip)
curl -s http://$IP:30081/api/v1/applications

# History and Grafana pod logs
kubectl logs -n spark-infra deployment/spark-shared-spark-35-history --tail=200
kubectl logs -n observability deployment/grafana --tail=200
```

## 10) Prometheus + metrics checks

Prometheus UI:

```bash
MINIKUBE_IP=$(minikube ip)
echo "Prometheus: http://$MINIKUBE_IP:30090"
```

Health and target checks:

```bash
curl -s "http://$(minikube ip):30090/api/v1/targets"
curl -s "http://$(minikube ip):30090/api/v1/label/__name__/values"
```

Key metric queries (required for demo):

```bash
# Spark queue state
curl -s "http://$(minikube ip):30090/api/v1/query?query=spark_apps_waiting"

# Workers / executors
curl -s "http://$(minikube ip):30090/api/v1/query?query=spark_workers_alive"
curl -s "http://$(minikube ip):30090/api/v1/query?query=spark_executor_active"
curl -s "http://$(minikube ip):30090/api/v1/query?query=spark_executor_total_tasks"

# Airflow pipeline state
curl -s "http://$(minikube ip):30090/api/v1/query?query=airflow_dag_runs_state"
curl -s "http://$(minikube ip):30090/api/v1/query?query=airflow_task_instances_state"

# Data read/write + shuffle/spill
curl -s "http://$(minikube ip):30090/api/v1/query?query=spark_latest_stage_input_bytes"
curl -s "http://$(minikube ip):30090/api/v1/query?query=spark_latest_stage_output_bytes"
curl -s "http://$(minikube ip):30090/api/v1/query?query=spark_latest_stage_shuffle_read_bytes"
curl -s "http://$(minikube ip):30090/api/v1/query?query=spark_latest_stage_shuffle_write_bytes"
curl -s "http://$(minikube ip):30090/api/v1/query?query=spark_latest_stage_memory_spill_bytes"
curl -s "http://$(minikube ip):30090/api/v1/query?query=spark_latest_stage_disk_spill_bytes"
```
