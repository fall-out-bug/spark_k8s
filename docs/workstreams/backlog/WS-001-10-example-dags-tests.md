## WS-001-10: Example DAGs and Tests

### Goal

**What should WORK after WS completion:**
- Spark ETL DAG with synthetic data
- MLflow Training DAG with experiment logging
- E2E tests for all components
- Documentation for running tests

**Acceptance Criteria:**
- [ ] `spark_etl_synthetic.py` DAG created and executable
- [ ] `mlflow_training_synthetic.py` DAG created and executable
- [ ] ETL DAG: generates data → transforms → writes to MinIO
- [ ] MLflow DAG: trains model → logs metrics/params → saves model artifact
- [ ] E2E test script validates full workflow
- [ ] All DAGs visible in Airflow UI
- [ ] DAG runs complete successfully

**WS is NOT complete until Goal is achieved (all AC checked).**

---

### Context

This is the final integration workstream. Creates example DAGs that demonstrate Spark Standalone + Airflow + MLflow integration. Uses synthetic data to avoid external dependencies. Tests validate the complete system works end-to-end.

### Dependency

WS-001-09 (Security Hardening) — all components must be secured

### Input Files

- `docker/optional/airflow/dags/spark_etl_example.py` — existing DAG reference
- `charts/spark-standalone/templates/airflow/configmap.yaml` — DAGs mount point

### Steps

1. Create `docker/spark-standalone/dags/spark_etl_synthetic.py`
2. Create `docker/spark-standalone/dags/mlflow_training_synthetic.py`
3. Update Airflow ConfigMap to include DAGs
4. Create `scripts/test-spark-standalone.sh` E2E test script
5. Test full workflow

### Code

```python
# spark_etl_synthetic.py
"""
Spark ETL DAG with synthetic data generation.
Demonstrates: spark-submit to Standalone cluster via Airflow K8s Executor.
"""
from datetime import datetime, timedelta
from airflow import DAG
from airflow.providers.cncf.kubernetes.operators.pod import KubernetesPodOperator

default_args = {
    'owner': 'data-team',
    'depends_on_past': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=2),
}

SPARK_IMAGE = "spark-custom:3.5.7"
SPARK_MASTER = "spark://spark-sa-master:7077"

# PySpark ETL script (inline for simplicity)
ETL_SCRIPT = '''
from pyspark.sql import SparkSession
from pyspark.sql.functions import rand, expr
import sys

spark = SparkSession.builder.appName("SyntheticETL").getOrCreate()

# Generate synthetic data
df = spark.range(0, 100000).withColumn("value", rand()).withColumn("category", expr("id % 10"))

# Transform: aggregate by category
result = df.groupBy("category").agg({"value": "avg", "id": "count"})

# Write to S3
output_path = sys.argv[1] if len(sys.argv) > 1 else "s3a://processed-data/synthetic/"
result.write.mode("overwrite").parquet(output_path)

print(f"Written {result.count()} rows to {output_path}")
spark.stop()
'''

with DAG(
    'spark_etl_synthetic',
    default_args=default_args,
    description='Spark ETL with synthetic data on Standalone cluster',
    schedule_interval='@daily',
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=['spark', 'etl', 'standalone', 'synthetic'],
) as dag:

    spark_etl = KubernetesPodOperator(
        task_id='spark_etl_synthetic',
        name='spark-etl-{{ ds_nodash }}',
        namespace='{{ var.value.spark_namespace | default("spark") }}',
        image=SPARK_IMAGE,
        cmds=['spark-submit'],
        arguments=[
            '--master', SPARK_MASTER,
            '--deploy-mode', 'client',
            '--conf', 'spark.hadoop.fs.s3a.endpoint=http://minio:9000',
            '--conf', 'spark.hadoop.fs.s3a.path.style.access=true',
            '-e', ETL_SCRIPT,
            's3a://processed-data/synthetic/{{ ds }}/'
        ],
        env_vars={
            'AWS_ACCESS_KEY_ID': '{{ var.value.s3_access_key }}',
            'AWS_SECRET_ACCESS_KEY': '{{ var.value.s3_secret_key }}',
        },
        is_delete_operator_pod=True,
        get_logs=True,
    )
```

```python
# mlflow_training_synthetic.py
"""
MLflow Training DAG with experiment logging.
Demonstrates: spark-submit ML job with MLflow tracking.
"""
from datetime import datetime, timedelta
from airflow import DAG
from airflow.providers.cncf.kubernetes.operators.pod import KubernetesPodOperator

default_args = {
    'owner': 'ml-team',
    'depends_on_past': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=2),
}

SPARK_IMAGE = "spark-custom:3.5.7"
SPARK_MASTER = "spark://spark-sa-master:7077"
MLFLOW_TRACKING_URI = "http://spark-sa-mlflow:5000"

ML_SCRIPT = '''
from pyspark.sql import SparkSession
from pyspark.ml.feature import VectorAssembler
from pyspark.ml.regression import LinearRegression
from pyspark.ml.evaluation import RegressionEvaluator
import mlflow
import mlflow.spark

spark = SparkSession.builder.appName("MLflowTraining").getOrCreate()

# Generate synthetic training data
df = spark.range(0, 10000).selectExpr(
    "id",
    "rand() as feature1",
    "rand() as feature2", 
    "id * 0.5 + rand() * 10 as label"
)

# Prepare features
assembler = VectorAssembler(inputCols=["feature1", "feature2"], outputCol="features")
data = assembler.transform(df)
train, test = data.randomSplit([0.8, 0.2], seed=42)

# Train with MLflow tracking
mlflow.set_tracking_uri("MLFLOW_URI")
mlflow.set_experiment("spark-standalone-training")

with mlflow.start_run(run_name="linear-regression"):
    lr = LinearRegression(featuresCol="features", labelCol="label")
    model = lr.fit(train)
    
    # Evaluate
    predictions = model.transform(test)
    evaluator = RegressionEvaluator(labelCol="label", predictionCol="prediction")
    rmse = evaluator.evaluate(predictions, {evaluator.metricName: "rmse"})
    r2 = evaluator.evaluate(predictions, {evaluator.metricName: "r2"})
    
    # Log to MLflow
    mlflow.log_param("maxIter", lr.getMaxIter())
    mlflow.log_param("regParam", lr.getRegParam())
    mlflow.log_metric("rmse", rmse)
    mlflow.log_metric("r2", r2)
    mlflow.spark.log_model(model, "model")
    
    print(f"Model trained: RMSE={rmse:.4f}, R2={r2:.4f}")

spark.stop()
'''.replace("MLFLOW_URI", MLFLOW_TRACKING_URI)

with DAG(
    'mlflow_training_synthetic',
    default_args=default_args,
    description='ML training with MLflow tracking on Spark Standalone',
    schedule_interval='@weekly',
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=['spark', 'mlflow', 'ml', 'standalone'],
) as dag:

    ml_training = KubernetesPodOperator(
        task_id='mlflow_training',
        name='ml-training-{{ ds_nodash }}',
        namespace='{{ var.value.spark_namespace | default("spark") }}',
        image=SPARK_IMAGE,
        cmds=['spark-submit'],
        arguments=[
            '--master', SPARK_MASTER,
            '--deploy-mode', 'client',
            '--packages', 'org.mlflow:mlflow-spark:2.14.0',
            '-e', ML_SCRIPT,
        ],
        env_vars={
            'AWS_ACCESS_KEY_ID': '{{ var.value.s3_access_key }}',
            'AWS_SECRET_ACCESS_KEY': '{{ var.value.s3_secret_key }}',
            'MLFLOW_TRACKING_URI': MLFLOW_TRACKING_URI,
        },
        is_delete_operator_pod=True,
        get_logs=True,
    )
```

```bash
#!/bin/bash
# scripts/test-spark-standalone.sh
# E2E test script for Spark Standalone chart

set -e

NAMESPACE=${1:-spark}
RELEASE=${2:-spark-sa}

echo "=== Testing Spark Standalone Chart ==="

# 1. Check all pods running
echo "1. Checking pods..."
kubectl get pods -n $NAMESPACE -l "app.kubernetes.io/instance=$RELEASE"
kubectl wait --for=condition=ready pod -l app=spark-master -n $NAMESPACE --timeout=120s
kubectl wait --for=condition=ready pod -l app=spark-worker -n $NAMESPACE --timeout=120s

# 2. Test Spark Master
echo "2. Testing Spark Master..."
MASTER_POD=$(kubectl get pod -n $NAMESPACE -l app=spark-master -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n $NAMESPACE $MASTER_POD -- curl -s http://localhost:8080/ | grep -q "Spark Master"
echo "   Spark Master UI OK"

# 3. Test Worker registration
echo "3. Testing Worker registration..."
WORKER_COUNT=$(kubectl exec -n $NAMESPACE $MASTER_POD -- curl -s http://localhost:8080/json/ | jq '.workers | length')
echo "   Workers registered: $WORKER_COUNT"
[ "$WORKER_COUNT" -ge 1 ] || exit 1

# 4. Test spark-submit (Pi calculation)
echo "4. Testing spark-submit..."
kubectl exec -n $NAMESPACE $MASTER_POD -- spark-submit \
  --master spark://localhost:7077 \
  --class org.apache.spark.examples.SparkPi \
  /opt/spark/examples/jars/spark-examples_2.12-3.5.7.jar 10 | grep -q "Pi is roughly"
echo "   spark-submit OK"

# 5. Test Airflow (if enabled)
if kubectl get deploy -n $NAMESPACE -l app=airflow-webserver &>/dev/null; then
  echo "5. Testing Airflow..."
  kubectl wait --for=condition=ready pod -l app=airflow-webserver -n $NAMESPACE --timeout=120s
  AIRFLOW_POD=$(kubectl get pod -n $NAMESPACE -l app=airflow-webserver -o jsonpath='{.items[0].metadata.name}')
  kubectl exec -n $NAMESPACE $AIRFLOW_POD -- airflow dags list | grep -q "spark_etl_synthetic"
  echo "   Airflow DAGs OK"
fi

# 6. Test MLflow (if enabled)
if kubectl get deploy -n $NAMESPACE -l app=mlflow &>/dev/null; then
  echo "6. Testing MLflow..."
  kubectl wait --for=condition=ready pod -l app=mlflow -n $NAMESPACE --timeout=120s
  MLFLOW_POD=$(kubectl get pod -n $NAMESPACE -l app=mlflow -o jsonpath='{.items[0].metadata.name}')
  kubectl exec -n $NAMESPACE $MLFLOW_POD -- curl -s http://localhost:5000/health | grep -q "OK"
  echo "   MLflow OK"
fi

echo "=== All tests passed ==="
```

### Expected Result

```
docker/spark-standalone/dags/
├── spark_etl_synthetic.py
└── mlflow_training_synthetic.py

scripts/
└── test-spark-standalone.sh
```

### Scope Estimate

- Files: 3 created + 1 modified
- Lines: ~400 (MEDIUM)
- Tokens: ~1200

### Completion Criteria

```bash
# Deploy full chart
helm upgrade --install spark-sa charts/spark-standalone

# Run E2E tests
./scripts/test-spark-standalone.sh spark spark-sa

# Trigger Airflow DAGs
kubectl exec -it deploy/spark-sa-airflow-webserver -- airflow dags trigger spark_etl_synthetic
kubectl exec -it deploy/spark-sa-airflow-webserver -- airflow dags trigger mlflow_training_synthetic

# Check DAG runs
kubectl exec -it deploy/spark-sa-airflow-webserver -- airflow dags list-runs -d spark_etl_synthetic

# Check MLflow experiments
kubectl port-forward svc/spark-sa-mlflow 5000:5000
# Open http://localhost:5000 - should show experiments with logged metrics
```

### Constraints

- DO NOT use real data — synthetic only
- DO NOT create complex ML models — simple LinearRegression is sufficient
- DAGs must be self-contained (no external dependencies)
- Test script must be idempotent (can run multiple times)
