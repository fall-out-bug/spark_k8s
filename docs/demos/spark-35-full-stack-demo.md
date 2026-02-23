# Spark 3.5 + Jupyter + Airflow + Observability Stack Demo

## Обзор стека

Этот демо-стек включает все компоненты для полноценной работы с Apache Spark в Kubernetes:

| Компонент | Namespace | Описание |
|-----------|-----------|----------|
| **Spark Connect** | spark-35-jupyter-sa | Remote Spark sessions |
| **Jupyter** | spark-35-jupyter-sa | Interactive notebooks |
| **Spark Standalone** | spark-35-jupyter-sa | Cluster mode (master + worker) |
| **Airflow + Spark** | spark-35-airflow-sa | Workflow orchestration |
| **MinIO** | spark-infra | S3-compatible storage |
| **Hive Metastore** | spark-infra | Table metadata |
| **PostgreSQL** | spark-infra | Metastore database |
| **History Server** | spark-infra | Spark job UI |
| **Prometheus** | spark-operations | Metrics collection |
| **Grafana** | spark-operations | Dashboards & visualization |
| **Jaeger** | spark-operations | Distributed tracing |
| **Pushgateway** | spark-operations | Push-based metrics |

## Доступ к UI (port-forward)

```bash
# Jupyter Notebooks
kubectl port-forward -n spark-35-jupyter-sa svc/scenario1-spark-35-jupyter 8888:8888
# -> http://localhost:8888

# Spark Master UI
kubectl port-forward -n spark-35-jupyter-sa svc/scenario1-spark-35-standalone-master 8080:8080
# -> http://localhost:8080

# Spark History Server
kubectl port-forward -n spark-infra svc/spark-infra-spark-35-history 18080:18080
# -> http://localhost:18080

# Grafana (admin/prom-operator)
kubectl port-forward -n spark-operations svc/prometheus-stack-grafana 3000:80
# -> http://localhost:3000

# Prometheus
kubectl port-forward -n spark-operations svc/prometheus-stack-kube-prom-prometheus 9090:9090
# -> http://localhost:9090

# Jaeger Tracing
kubectl port-forward -n spark-operations svc/jaeger-query 16686:16686
# -> http://localhost:16686

# MinIO Console (minioadmin/minioadmin)
kubectl port-forward -n spark-infra svc/minio 9001:9001
# -> http://localhost:9001
```

## Тестирование компонентов

### 1. Spark DataFrame Operations

```bash
kubectl exec -n spark-35-jupyter-sa deployment/scenario1-spark-35-connect -- python3 -c "
from pyspark.sql import SparkSession
spark = SparkSession.builder.master('local[2]').appName('test').getOrCreate()
df = spark.range(100)
print(f'Count: {df.count()}')
spark.stop()
"
```

### 2. S3/MinIO Integration

```bash
kubectl exec -n spark-35-jupyter-sa deployment/scenario1-spark-35-connect -- python3 -c "
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, concat, lit
import os

os.environ['AWS_ACCESS_KEY_ID'] = 'minioadmin'
os.environ['AWS_SECRET_ACCESS_KEY'] = 'minioadmin'

spark = SparkSession.builder.master('local[2]').appName('s3-test').getOrCreate()
sc = spark.sparkContext._jsc.hadoopConfiguration()
sc.set('fs.s3a.endpoint', 'http://minio.spark-infra.svc.cluster.local:9000')
sc.set('fs.s3a.path.style.access', 'true')
sc.set('fs.s3a.access.key', 'minioadmin')
sc.set('fs.s3a.secret.key', 'minioadmin')

df = spark.range(10).withColumn('name', concat(lit('item_'), col('id')))
df.write.mode('overwrite').parquet('s3a://spark-logs/demo/test.parquet')
df2 = spark.read.parquet('s3a://spark-logs/demo/test.parquet')
print(f'S3 Read/Write: {df2.count()} rows')
spark.stop()
"
```

### 3. Prometheus Metrics Push

```bash
kubectl exec -n spark-35-jupyter-sa deployment/scenario1-spark-35-connect -- python3 -c "
from prometheus_client import CollectorRegistry, Gauge, push_to_gateway
registry = CollectorRegistry()
g = Gauge('demo_metric', 'Demo metric', registry=registry)
g.set(42)
push_to_gateway('prometheus-pushgateway.spark-operations.svc.cluster.local:9091', job='demo', registry=registry)
print('Metrics pushed successfully')
"
```

## Grafana Dashboards

Полезные запросы для Prometheus:

```promql
# Spark demo job duration
spark_demo_duration

# Rows processed
spark_demo_rows_processed

# JVM memory
jvm_memory_bytes_used{area="heap"}

# Spark executor metrics
spark_executor_memory_bytes_used
```

## Airflow Integration (scenario2)

Airflow scenario находится в namespace `spark-35-airflow-sa` и включает:
- Spark Standalone Master + 2 Workers
- Spark Metrics Exporter

Для запуска ML pipeline через Airflow DAG.

## Архитектура

```
┌─────────────────────────────────────────────────────────────┐
│                     spark-35-jupyter-sa                     │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │   Jupyter   │──│Spark Connect│──│  Spark Standalone   │ │
│  │  (8888)     │  │  (15002)    │  │ Master (8080)       │ │
│  └─────────────┘  └─────────────┘  │ Worker (8081)       │ │
│                                    └─────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                       spark-infra                           │
│  ┌─────────┐  ┌──────────────┐  ┌───────────────────────┐  │
│  │ MinIO   │  │ Hive Metastore│  │ PostgreSQL            │  │
│  │ (9000)  │  │   (9083)     │  │   (5432)              │  │
│  └─────────┘  └──────────────┘  └───────────────────────┘  │
│  ┌─────────────────┐                                       │
│  │ History Server  │                                       │
│  │    (18080)      │                                       │
│  └─────────────────┘                                       │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    spark-operations                         │
│  ┌───────────┐  ┌─────────┐  ┌───────────┐  ┌───────────┐ │
│  │Prometheus │  │ Grafana │  │  Jaeger   │  │Pushgateway│ │
│  │  (9090)   │  │  (80)   │  │  (16686)  │  │  (9091)   │ │
│  └───────────┘  └─────────┘  └───────────┘  └───────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Статус компонентов

```bash
# Проверить все поды
kubectl get pods -n spark-35-jupyter-sa
kubectl get pods -n spark-35-airflow-sa
kubectl get pods -n spark-infra
kubectl get pods -n spark-operations

# Проверить сервисы
kubectl get svc -n spark-35-jupyter-sa
kubectl get svc -n spark-infra
kubectl get svc -n spark-operations
```

## Устранение неполадок

### Hive Metastore падает с SCRAM-SHA-256 ошибкой

```bash
# Установить md5 шифрование
kubectl exec -n spark-infra spark-infra-spark-base-postgresql-0 -- psql -U postgres -c \
  "ALTER SYSTEM SET password_encryption = 'md5'; SELECT pg_reload_conf();"

# Пересоздать пользователя
kubectl exec -n spark-infra spark-infra-spark-base-postgresql-0 -- psql -U postgres -c \
  "SET password_encryption = 'md5'; DROP USER IF EXISTS hive; CREATE USER hive WITH PASSWORD 'hive123';"

# Создать базу
kubectl exec -n spark-infra spark-infra-spark-base-postgresql-0 -- psql -U postgres -c \
  "CREATE DATABASE metastore OWNER hive;"

# Перезапустить metastore
kubectl delete pod -n spark-infra -l app.kubernetes.io/component=hive-metastore
```

### Jupyter не имеет pyspark

```bash
kubectl exec -n spark-35-jupyter-sa deployment/scenario1-spark-35-jupyter -- \
  pip install pyspark grpcio grpcio-status
```
