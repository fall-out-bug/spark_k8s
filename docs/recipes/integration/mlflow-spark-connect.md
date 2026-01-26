# MLflow → Spark Connect Integration

**Source:** Integration recipes

## Overview

Настроить MLflow для experiment tracking при выполнении Spark jobs через Spark Connect.

## Architecture

```
Jupyter / Airflow
    ↓
Spark Connect → Spark Job
    ↓
MLflow Tracking Server
    ↓
S3 (MLflow artifacts)
```

## Deployment

### Шаг 1: Установить MLflow

```bash
# Spark 3.5 + Standalone
helm install mlflow charts/spark-3.5/charts/spark-standalone \
  -n mlflow \
  --set mlflow.enabled=true \
  --set mlflow.postgresql.enabled=true \
  --set mlflow.backendUri=postgresql://mlflow-db:5432/mlflow
```

### Шаг 2: Настроить Spark Connect с MLflow

```bash
# Spark 4.1
helm upgrade spark-connect charts/spark-4.1 -n spark \
  --set connect.sparkConf.spark\\.extraListeners=org.apache.spark.mlflow.MLflowExecutionListener \
  --set connect.sparkConf.spark\\.mlflow.trackingUri=http://mlflow.mlflow.svc.cluster.local:5000 \
  --set connect.sparkConf.spark\\.mlflow.experimentName=/production/experiments \
  --reuse-values

# Spark 3.5
helm upgrade spark-connect charts/spark-3.5/charts/spark-connect -n spark \
  --set sparkConnect.sparkConf.spark\\.extraListeners=org.apache.spark.mlflow.MLflowExecutionListener \
  --set sparkConnect.sparkConf.spark\\.mlflow.trackingUri=http://mlflow.mlflow.svc.cluster.local:5000 \
  --reuse-values
```

### Шаг 3: Настроить MLflow artifact storage

```bash
# S3 artifacts
helm upgrade mlflow charts/spark-3.5/charts/spark-standalone -n mlflow \
  --set mlflow.backendUri=postgresql://mlflow-db:5432/mlflow \
  --set mlflow.artifactRoot=s3a://mlflow/artifacts \
  --set mlflow.sparkConf.spark\\.hadoop\\.fs.s3a.aws.credentials.provider=com.amazonaws.auth.InstanceProfileCredentialsProvider \
  --reuse-values
```

## Jupyter Integration

### Установить mlflow в Jupyter image

```dockerfile
# docker/jupyter-4.1/Dockerfile
FROM jupyter-spark:4.1.0

RUN pip install mlflow pyspark==3.5.0
```

### Использование в Jupyter

```python
from pyspark.sql import SparkSession
import mlflow

# Настроить tracking
mlflow.set_tracking_uri("http://mlflow.mlflow.svc.cluster.local:5000")
mlflow.set_experiment("/production/experiments")

# Создать Spark session с MLflow
spark = SparkSession.builder \
    .remote("sc://spark-connect:15002") \
    .config("spark.mlflow.trackingUri", "http://mlflow.mlflow.svc.cluster.local:5000") \
    .config("spark.extraListeners", "org.apache.spark.mlflow.MLflowExecutionListener") \
    .getOrCreate()

# Training с logging
with mlflow.start_run():
    mlflow.log_param("learning_rate", 0.01)
    mlflow.log_param("epochs", 10)

    # Ваш код
    from sklearn.linear_model import LinearRegression
    import numpy as np

    X = np.random.rand(1000, 10)
    y = np.random.rand(1000)

    model = LinearRegression()
    model.fit(X, y)

    # Log metrics
    mlflow.log_metric("train_score", model.score(X, y))

    # Log model
    mlflow.sklearn.log_model(model, "model")

    # Log artifacts
    mlflow.log_artifact("config.json")

spark.stop()
```

## Airflow Integration

### DAG с MLflow

```python
from airflow import DAG
from airflow.providers.spark.operators.spark_submit import SparkSubmitOperator
from datetime import datetime

dag = DAG('ml_training', start_date=datetime(2025, 1, 26), schedule_interval='@weekly')

ml_task = SparkSubmitOperator(
    task_id='train_model',
    application='s3a://dags/ml_train.py',
    conn_id='spark_connect_default',
    conf={
        'spark.mlflow.trackingUri': 'http://mlflow.mlflow.svc.cluster.local:5000',
        'spark.mlflow.experimentName': '/production/experiment',
        'spark.mlflow.mlflowBackend': 'mlflow',
        'spark.mlflow.artifactRoot': 's3a://mlflow/artifacts',
        'spark.executor.memory': '4g',
        'spark.executor.instances': '10',
    },
    env_vars={
        'MLFLOW_TRACKING_URI': 'http://mlflow.mlflow.svc.cluster.local:5000',
        'MLFLOW_S3_ENDPOINT_URL': 's3a://mlflow/artifacts',
    },
    dag=dag
)
```

## Verification

```bash
# 1. Проверить MLflow UI
kubectl port-forward -n mlflow svc/mlflow 5000:5000
# Открыть: http://localhost:5000

# 2. Проверить experiment
kubectl exec -n mlflow deploy/mlflow -- \
  mlflow experiments list

# 3. Запустить тестовый job
kubectl exec -n spark deploy/jupyter -- \
  python3 -c "
import mlflow
mlflow.set_tracking_uri('http://mlflow.mlflow.svc.cluster.local:5000')
with mlflow.start_run():
    mlflow.log_param('test', 1)
    mlflow.log_metric('test_metric', 0.95)
"

# 4. Проверить в UI что run появился
# http://localhost:5000/#/experiments/1/runs/...
```

## Model Registry

### Регистрация модели

```python
from pyspark.sql import SparkSession
import mlflow
import mlflow.spark

spark = SparkSession.builder.remote("sc://spark-connect:15002").getOrCreate()

# Training
train_df = spark.read.parquet("s3a://data/train")
test_df = spark.read.parquet("s3a://data/test")

with mlflow.start_run():
    # Обучение
    from pyspark.ml.regression import LinearRegression
    lr = LinearRegression(featuresCol="features", labelCol="label")
    model = lr.fit(train_df)

    # Log модель в MLflow
    mlflow.spark.log_model(
        spark_model=model,
        artifact_path="model",
        registered_model_name="production_model",
        await_registration_for=60
    )

    # Evaluation
    predictions = model.transform(test_df)
    from pyspark.ml.evaluation import RegressionEvaluator
    evaluator = RegressionEvaluator(labelCol="label")
    rmse = evaluator.evaluate(predictions)
    mlflow.log_metric("rmse", rmse)

spark.stop()
```

### Loading модели для inference

```python
import mlflow
import mlflow.spark

spark = SparkSession.builder.remote("sc://spark-connect:15002").getOrCreate()

# Load модель
model_uri = "models:/production_model/Production"
model = mlflow.spark.load_model(model_uri)

# Inference
predictions = model.transform(test_data)
predictions.show()
spark.stop()
```

## Best Practices

1. **Experiment naming**
   ```python
   # Хорошо
   experiment = "/team/project/feature-name"

   # Плохо
   experiment = "test"
   ```

2. **Artifact storage**
   ```python
   # S3 для production
   mlflow.set_artifact_location("s3a://mlflow/artifacts/prod")

   # Local для dev
   mlflow.set_artifact_location("file:///tmp/mlflow")
   ```

3. **Model versioning**
   ```python
   # Production staging
   mlflow.spark.log_model(
       model=model,
       registered_model_name="model_name",
       await_registration_for=60
   )

   # Archive old versions через MLflow UI
   ```

## References

- MLflow Docs: https://mlflow.org/docs/latest/index.html
- Spark Integration: https://mlflow.org/docs/latest/tracking.html#spark
- Usage Guide: `docs/guides/ru/spark-k8s-constructor.md`
