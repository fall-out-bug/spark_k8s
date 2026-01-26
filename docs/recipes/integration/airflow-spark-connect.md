# Airflow → Spark Connect Integration

**Source:** E2E matrix

## Overview

Настроить Airflow для выполнения Spark jobs через Spark Connect.

## Architecture

```
Airflow (K8s Executor)
    ↓
SparkSubmitOperator
    ↓
Spark Connect Server
    ↓
Executors (K8s or Standalone)
```

## Deployment

### Вариант A: Spark Connect + K8s backend

```bash
# 1. Установить Spark Connect
helm install spark-connect charts/spark-4.1 \
  -n spark \
  -f charts/spark-4.1/values-scenario-airflow-connect-k8s.yaml

# 2. Установить Airflow
helm install airflow charts/spark-3.5/charts/spark-standalone \
  -n spark \
  --set airflow.enabled=true \
  --set airflow.kubernetesExecutor.deleteWorkerPods=false \
  --set airflow.fernetKey=<your-fernet-key>
```

### Вариант B: Spark Connect + Standalone backend

```bash
# 1. Установить Standalone
helm install spark-standalone charts/spark-3.5/charts/spark-standalone \
  -n spark \
  --set sparkMaster.enabled=true \
  --set sparkWorker.replicas=2 \
  --set sparkWorker.cores=2 \
  --set sparkWorker.memory=2g

# 2. Установить Connect
helm install spark-connect charts/spark-4.1 \
  -n spark \
  -f charts/spark-4.1/values-scenario-airflow-connect-standalone.yaml

# 3. Установить Airflow
helm install airflow charts/spark-3.5/charts/spark-standalone \
  -n spark \
  --set airflow.enabled=true \
  --set sparkMaster.enabled=false \
  --set sparkWorker.enabled=false
```

## Airflow Configuration

### Настроить Connection в Airflow UI

```bash
# 1. Получить URL
CONNECT_URL="sc://spark-41-connect.spark.svc.cluster.local:15002"

# 2. Создать Connection через CLI
kubectl exec -n spark deploy/<airflow-webserver> -- \
  airflow connections add spark_connect_default \
    --conn-type spark \
    --conn-host "${CONNECT_URL}" \
    --conn-extra '{"spark.binary.version": "3.5"}'
```

### Создать DAG

```python
# files/airflow/dags/spark_connect_job.py
from datetime import datetime
from airflow import DAG
from airflow.providers.spark.operators.spark_submit import SparkSubmitOperator

default_args = {
    'owner': 'data-team',
    'start_date': datetime(2025, 1, 26),
    'depends_on_past': False,
}

dag = DAG('spark_connect_etl', default_args=default_args, schedule_interval='@daily')

spark_job = SparkSubmitOperator(
    task_id='process_data',
    application='s3a://dags/scripts/etl.py',
    conn_id='spark_connect_default',
    conf={
        'spark.executor.instances': '5',
        'spark.executor.memory': '2g',
        'spark.executor.cores': '2',
        'spark.driver.memory': '1g',
        'spark.sql.shuffle.partitions': '200',
    },
    jars='s3a://jars/extra-jars.jar',
    packages='com.amazonaws:aws-java-sdk-bundle:1.12.262',
    repositories='https://repo1.maven.org/maven2',
    dag=dag
)
```

## Configuration via Preset

Используйте готовый preset: `charts/spark-4.1/values-scenario-airflow-connect-k8s.yaml`

```yaml
# Already configured:
airflow:
  enabled: true
  kubernetesExecutor:
    deleteWorkerPods: false  # для логов

connect:
  enabled: true
  backendMode: k8s
  eventLog:
    enabled: true
```

## Verification

```bash
# 1. Проверить Airflow UI
kubectl port-forward -n spark svc/<airflow-webserver> 8080:8080
# Открыть: http://localhost:8080

# 2. Проверить DAG
kubectl exec -n spark deploy/<airflow-scheduler> -- \
  airflow dags list

# 3. Запустить DAG вручную
kubectl exec -n spark deploy/<airflow-scheduler> -- \
  airflow dags trigger spark_connect_etl

# 4. Проверить выполнение
kubectl logs -n spark -l spark-role=driver --tail=50
kubectl get pods -n spark -l spark-role=executor
```

## Troubleshooting

```bash
# Если DAG не видит Connect
kubectl exec -n spark deploy/<airflow-scheduler> -- \
  airflow connections list

# Если job не запускается
kubectl logs -n spark deploy/<airflow-scheduler> --tail=100

# Если driver pod не стартует
kubectl logs -n spark <driver-pod> --tail=100

# Проверить worker pods
kubectl get pods -n spark -l airflow-worker= --watch
```

## Examples

### ETL Job

```python
from airflow import DAG
from airflow.providers.spark.operators.spark_submit import SparkSubmitOperator
from datetime import datetime

dag = DAG('etl_job', start_date=datetime(2025, 1, 26), schedule_interval='@daily')

etl_task = SparkSubmitOperator(
    task_id='etl',
    application='s3a://dags/etl.py',
    conn_id='spark_connect_default',
    conf={
        'spark.sql.warehouse.dir': 's3a://warehouse/production',
        'spark.hadoop.fs.s3a.aws.credentials.provider': 'com.amazonaws.auth.InstanceProfileCredentialsProvider',
    },
    dag=dag
)
```

### ML Pipeline

```python
dag = DAG('ml_pipeline', start_date=datetime(2025, 1, 26), schedule_interval='@weekly')

ml_task = SparkSubmitOperator(
    task_id='ml_training',
    application='s3a://dags/ml_train.py',
    conn_id='spark_connect_default',
    conf={
        'spark.executor.memory': '4g',
        'spark.executor.instances': '10',
        'spark.mlflow.trackingUri': 'http://mlflow.mlflow.svc.cluster.local:5000',
        'spark.mlflow.experimentName': '/production/experiment',
    },
    dag=dag
)
```

## References

- Usage Guide: `docs/guides/ru/spark-k8s-constructor.md`
- E2E Report: `docs/testing/F06-e2e-matrix-report.md`
- Preset: `charts/spark-4.1/values-scenario-airflow-connect-k8s.yaml`
- Airflow Spark Provider: https://airflow.apache.org/docs/apache-airflow-providers-spark/
