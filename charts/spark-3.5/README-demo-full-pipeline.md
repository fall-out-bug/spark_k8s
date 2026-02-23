# Full Pipeline Demo

Complete Spark + Airflow + Monitoring stack for batch ETL workloads on Kubernetes.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         User Interface                          │
├─────────────────┬─────────────────┬─────────────────────────────┤
│   Jupyter       │   Airflow UI    │   Spark History Server      │
│   :8888         │   :8080         │   :18080                    │
└────────┬────────┴────────┬────────┴──────────────┬──────────────┘
         │                 │                        │
         │                 │                        │
┌────────▼────────┌────────▼────────┐    ┌─────────▼─────────────┐
│  Spark Connect  │  Airflow        │    │  S3 Event Logs        │
│  :15002         │  Scheduler      │    │  (MinIO)              │
└────────┬────────┴─────────────────┘    └───────────────────────┘
         │
         │
┌────────▼────────────────────────────────────────────────────────┐
│                Spark Standalone Cluster                         │
├─────────────────────────────┬───────────────────────────────────┤
│      Master (:7077/:8080)   │   Workers (2x)                    │
└─────────────────────────────┴───────────────────────────────────┘
         │
         │
┌────────▼────────┬────────────────┬──────────────────────────────┐
│  MinIO (S3)     │  PostgreSQL    │  Hive Metastore              │
│  :9000/:9001    │  :5432         │  :9083                       │
└─────────────────┴────────────────┴──────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    Monitoring Stack                             │
├──────────────────────────┬──────────────────────────────────────┤
│  Prometheus              │  Grafana Dashboards                  │
│  (ServiceMonitor,        │  - Spark Overview                    │
│   PodMonitor)            │  - Executor Metrics                  │
│                          │  - Job Performance                   │
│                          │  - Job Phase Timeline                │
│                          │  - Profiling                         │
└──────────────────────────┴──────────────────────────────────────┘
```

## Components

| Component | Purpose | Port | Resources |
|-----------|---------|------|-----------|
| **Spark Master** | Standalone cluster coordinator | 7077 (RPC), 8080 (UI) | 2-4Gi, 1-2 CPU |
| **Spark Workers** | Task execution (2 replicas) | 8081 (UI) | 4-8Gi, 2-4 CPU each |
| **Airflow Webserver** | DAG management UI | 8080 | 1-2Gi, 0.5-1 CPU |
| **Airflow Scheduler** | Task scheduling | - | 512Mi-1Gi, 0.25-0.5 CPU |
| **Airflow PostgreSQL** | Airflow metadata | 5432 | 256-512Mi, 0.1-0.5 CPU |
| **Spark Connect** | Remote Spark access | 15002 | 2-4Gi, 1-2 CPU |
| **Jupyter** | Interactive development | 8888 | 1-4Gi, 0.5-2 CPU |
| **History Server** | Completed app logs | 18080 | 512Mi-2Gi, 0.2-1 CPU |
| **MinIO** | S3-compatible storage | 9000 (API), 9001 (Console) | 256Mi-1Gi, 0.1-0.5 CPU |
| **Hive Metastore** | Table metadata | 9083 | 512Mi-2Gi, 0.2-1 CPU |

## Prerequisites

1. **Docker images built:**
   ```bash
   # Spark base image
   docker build -t spark-custom:3.5.7 -f docker/spark/Dockerfile docker/spark/

   # Jupyter image
   docker build -t spark-k8s-jupyter:3.5-3.5.7 -f docker/jupyter/Dockerfile docker/jupyter/

   # Airflow image
   docker build -t spark-k8s/airflow:2.11.0 -f docker/optional/airflow/Dockerfile docker/optional/airflow/

   # Hive Metastore image
   docker build -t spark-k8s/hive:3.1.3-pg -f docker/hive/Dockerfile docker/hive/
   ```

2. **Kubernetes cluster** with:
   - At least 16GB RAM and 8 CPU cores available
   - StorageClass for persistent volumes
   - Prometheus Operator (for monitoring)

3. **Helm 3.x** installed

## Quick Start

```bash
# 1. Update Helm dependencies
helm dependency update charts/spark-3.5

# 2. Create namespace
kubectl create namespace demo

# 3. Deploy full pipeline
helm install full-demo charts/spark-3.5 \
  -n demo \
  -f charts/spark-3.5/values-demo-full-pipeline.yaml

# 4. Wait for all pods to be ready
kubectl get pods -n demo -w
```

## Accessing Services

### Option 1: Port Forwarding

```bash
# Airflow UI
kubectl port-forward svc/full-demo-standalone-airflow-webserver 8080:8080 -n demo

# Spark Master UI
kubectl port-forward svc/full-demo-standalone-master 8081:8080 -n demo

# Jupyter
kubectl port-forward svc/full-demo-spark-35-jupyter 8888:8888 -n demo

# History Server
kubectl port-forward svc/full-demo-spark-35-history 18080:18080 -n demo

# MinIO Console
kubectl port-forward svc/full-demo-spark-35-minio 9001:9001 -n demo
```

### Option 2: Ingress (if enabled)

Update `values-demo-full-pipeline.yaml`:
```yaml
ingress:
  enabled: true
  hosts:
    airflow: airflow.demo.local
    spark: spark.demo.local
    jupyter: jupyter.demo.local
    history: history.demo.local
```

## Airflow DAGs

Two example DAGs are included:

1. **spark_etl_operator** - Uses Spark Kubernetes Operator
2. **spark_etl_submit** - Uses spark-submit directly

To trigger a DAG:
1. Open Airflow UI (http://localhost:8080)
2. Find the DAG
3. Toggle it "On"
4. Click "Trigger DAG"

## Monitoring

### Prometheus Metrics

The following metrics are exposed:
- Spark executor metrics (via PodMonitor)
- Spark application metrics (via ServiceMonitor)
- S3A filesystem metrics

### Grafana Dashboards

Five dashboards are pre-configured:
1. **Spark Overview** - Cluster health and resource usage
2. **Executor Metrics** - Per-executor performance
3. **Job Performance** - Job duration and throughput
4. **Job Phase Timeline** - Visual job execution timeline
5. **Profiling** - CPU, memory, and I/O profiling

Import dashboards:
```bash
# Get Grafana dashboards ConfigMap
kubectl get configmap -n demo full-demo-grafana-dashboards -o yaml

# Import to Grafana
# (Follow Grafana documentation for dashboard import)
```

## Customization

### Scaling Workers

```yaml
standalone:
  worker:
    replicas: 4  # Increase to 4 workers
    resources:
      limits:
        memory: "16Gi"
        cpu: "8"
```

### Adding Custom DAGs

1. Add DAG file to `charts/spark-3.5/charts/spark-standalone/dags/`
2. Update values:
   ```yaml
   standalone:
     airflow:
       dags:
         - spark_etl_example.py
         - spark_streaming_example.py
         - my_custom_dag.py  # Add your DAG
   ```

### GPU Support

```yaml
connect:
  executor:
    gpu:
      enabled: true
      count: "1"
      vendor: "nvidia.com/gpu"
```

## Troubleshooting

### Common Issues

1. **Pod stuck in Pending**
   - Check resource requests vs available cluster resources
   - Verify StorageClass exists for PVCs

2. **Airflow DB connection failed**
   - Wait for PostgreSQL to be ready
   - Check logs: `kubectl logs -n demo -l app.kubernetes.io/component=airflow-postgresql`

3. **Spark jobs failing**
   - Check S3/MinIO connectivity
   - Verify Spark image has required dependencies

### Useful Commands

```bash
# List all resources
kubectl get all -n demo

# Check Airflow logs
kubectl logs -n demo -l app.kubernetes.io/component=airflow-scheduler -f

# Check Spark Master logs
kubectl logs -n demo -l app.kubernetes.io/component=spark-master -f

# Describe failed pod
kubectl describe pod <pod-name> -n demo

# Run Spark job manually
kubectl exec -it -n demo <spark-master-pod> -- /opt/spark/bin/spark-submit \
  --master spark://full-demo-standalone-master:7077 \
  --class org.apache.spark.examples.SparkPi \
  local:///opt/spark/examples/jars/spark-examples_2.12-3.5.7.jar 10
```

## Cleanup

```bash
# Delete release
helm uninstall full-demo -n demo

# Delete namespace (removes all resources)
kubectl delete namespace demo

# Remove PVCs if needed
kubectl delete pvc -n demo --all
```

## Files Changed

| File | Purpose |
|------|---------|
| `charts/spark-3.5/charts/spark-standalone/Chart.yaml` | Subchart metadata |
| `charts/spark-3.5/charts/spark-standalone/values.yaml` | Subchart defaults |
| `charts/spark-3.5/charts/spark-standalone/templates/_helpers.tpl` | Template helpers |
| `charts/spark-3.5/charts/spark-standalone/templates/master.yaml` | Spark Master deployment |
| `charts/spark-3.5/charts/spark-3.5/charts/spark-standalone/templates/worker.yaml` | Spark Worker deployment |
| `charts/spark-3.5/charts/spark-standalone/templates/airflow/*.yaml` | Airflow components |
| `charts/spark-3.5/Chart.yaml` | Added standalone dependency |
| `charts/spark-3.5/values-demo-full-pipeline.yaml` | Full demo configuration |
| `charts/spark-standalone` (symlink) | Fixed to point to subchart |
