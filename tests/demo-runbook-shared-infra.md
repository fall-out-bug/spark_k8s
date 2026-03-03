# Shared Infra Demo Runbook

**Deployment paths:**

| Path | Release | Namespace | Use case |
|------|---------|-----------|----------|
| This runbook | spark-infra | spark-infra | deploy-demo-minikube, single release |
| README full-demo | full-demo | demo | Alternative full-stack deploy |

**Persona recipes:** [docs/observability/recipes/](../docs/observability/recipes/) — DevOps, DataOps, Tech Lead, Data Engineer, DS (5-min guides).

## 0) Deploy Observability Stack (Prometheus + Grafana + Loki + demo-metrics-exporter)

> **Note:** demo-metrics-exporter requires Spark Master and Airflow to be running in spark-infra; it will retry until they are up.

```bash
kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f tests/observability/prometheus-demo.yaml
kubectl apply -f tests/observability/demo-metrics-exporter.yaml
kubectl apply -f tests/observability/grafana-dashboards.yaml
kubectl apply -f tests/observability/grafana-dashboards-spark.yaml
kubectl apply -f tests/observability/grafana-dashboard-tech-lead.yaml
kubectl apply -f tests/observability/grafana-dashboard-logs-explorer.yaml
kubectl apply -f tests/observability/loki.yaml
kubectl apply -f tests/observability/promtail.yaml
./scripts/deploy-grafana-with-sidecar.sh
```

> **Promtail:** Log path `/var/log/pods/` is for containerd (minikube default). On Docker runtime, logs may not be collected; use containerd or document workaround.

**Recommended:** `./scripts/tests/minikube/deploy-observability.sh` (deploys OTEL, Prometheus, Loki, Promtail, demo-metrics-exporter, Grafana, dashboards).

## 1) Preconditions

```bash
kubectl get ns
kubectl get pods -n spark-infra
kubectl get pods -n observability
```

Expected: running pods for `spark-infra-spark-standalone-*`, `minio`, `spark-infra-spark-35-history`, `spark-infra-spark-35-metastore`, `spark-infra-spark-base-postgresql`, and `grafana`.

## 2) Ensure shared buckets exist

```bash
kubectl run -n spark-infra minio-bootstrap --rm -i --restart=Never \
  --image=quay.io/minio/mc:latest --command -- /bin/sh -c "
  mc alias set local http://minio:9000 minioadmin minioadmin &&
  mc mb --ignore-existing local/warehouse &&
  mc mb --ignore-existing local/spark-logs &&
  mc mb --ignore-existing local/spark-jobs &&
  mc mb --ignore-existing local/nyc-taxi &&
  echo '' | mc pipe local/spark-logs/events/.keep &&
  echo '' | mc pipe local/spark-logs/4.1/events/.keep &&
  mc ls local"
```

Upload Spark job scripts (required for nyc_taxi, citibike, movielens DAGs):

```bash
./scripts/upload-spark-jobs-to-minio.sh spark-infra
```

## 3) Run real pipelines (critical path)

Trigger полноценные DAGs. Синтетика (spark.range, count) не используется — только реальные пайплайны.

**Precondition:** NYC TLC data в `s3a://nyc-taxi/raw/` (≥4 files).

**Optional DAGs:** `citibike_analytics_pipeline` needs bucket `citibike`; `movielens_recommendation_pipeline` needs bucket `movielens` and data in `raw/`. Add `mc mb local/citibike` and `mc mb local/movielens` if using.

**Data ingestion (if nyc-taxi empty):** Run locally with port-forward to MinIO, or from a pod in spark-infra:
```bash
# From host (port-forward MinIO first: kubectl port-forward -n spark-infra svc/minio 9000:9000)
python scripts/data_ingestion/download_nyc_tlc.py --start-month 2024-01 --end-month 2024-04 \
  --endpoint http://localhost:9000 --bucket nyc-taxi --path raw/ --limit 4
```

```bash
WEB_POD=$(kubectl get pod -n spark-infra -l app.kubernetes.io/component=airflow-webserver -o jsonpath='{.items[0].metadata.name}')

# Unpause
kubectl exec -n spark-infra $WEB_POD -- airflow dags unpause nyc_taxi_ml_full_pipeline
kubectl exec -n spark-infra $WEB_POD -- airflow dags unpause spark_standalone_load_demo
kubectl exec -n spark-infra $WEB_POD -- airflow dags unpause citibike_analytics_pipeline
kubectl exec -n spark-infra $WEB_POD -- airflow dags unpause movielens_recommendation_pipeline

# Trigger (выбери DAG с загруженными данными)
kubectl exec -n spark-infra $WEB_POD -- airflow dags trigger nyc_taxi_ml_full_pipeline --run-id "demo-$(date +%Y%m%d%H%M%S)"
# или spark_standalone_load_demo если nyc-taxi данных нет
```

**Verify completion:**
```bash
kubectl exec -n spark-infra $WEB_POD -- airflow dags list-runs -d nyc_taxi_ml_full_pipeline --output table
# state = success
```

**Verify metrics/dashboards:** History Server → applications; Grafana Tech Lead Morning → phase breakdown; Prometheus `spark_latest_stage_*`, `airflow_dag_runs_state`.

## 4) Verify History Server, Grafana, Loki

```bash
kubectl run -n spark-infra history-http-check --rm -i --restart=Never \
  --image=curlimages/curl:8.11.1 --command -- \
  sh -c "curl -s -o /tmp/out -w '%{http_code}' http://spark-infra-spark-35-history:18080/ && echo"

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
kubectl port-forward -n spark-infra svc/spark-infra-spark-35-history 18080:18080
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

Unpause + trigger — см. section 3.

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
- `ServiceMonitor`: `spark-infra-spark-35-connect`
- `PodMonitor`: `spark-infra-spark-35-executors`
- Dashboard ConfigMaps: `spark-infra-spark-35-dashboard-*`

Quick checks:

```bash
kubectl get servicemonitor,podmonitor -n spark-infra
kubectl get configmap -n spark-infra | grep 'dashboard-'
kubectl get configmap -n spark-infra spark-infra-spark-35-dashboard-job-phase-timeline -o jsonpath='{.metadata.labels.grafana_dashboard}{"\n"}'

# demo-metrics-exporter and Prometheus target
kubectl get pod -n observability -l app=demo-metrics-exporter
curl -s "http://$(minikube ip):30090/api/v1/targets" | grep -A2 demo-metrics-exporter
```

## 9) Verify after pipeline run (section 3)

После успешного DAG run:

```bash
# Event log в MinIO
kubectl run -n spark-infra minio-events-check --rm -i --restart=Never \
  --image=quay.io/minio/mc:latest --command -- /bin/sh -c "
  mc alias set local http://minio:9000 minioadmin minioadmin &&
  mc ls local/spark-logs/events"

# History API — applications
IP=$(minikube ip)
curl -s http://$IP:30081/api/v1/applications
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
