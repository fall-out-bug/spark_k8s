# Spark K8s for Data Scientists

Complete guide for data scientists to run ML workloads and interactive analysis on Apache Spark with Kubernetes.

## 🎯 Your Journey

### Who Is This For?

You are a **Data Scientist** who needs to:
- Run large-scale data processing without infrastructure setup
- Train ML models on big data
- Perform interactive exploratory analysis
- Deploy models to production
- Collaborate with data engineering teams

---

## 🚀 Quick Start (10 Minutes)

### Interactive Analysis

1. **Local Setup**: [Local Development](../getting-started/local-dev.md)
2. **Jupyter Access**: Port-forward and connect
3. **First Query**: Run PySpark in notebook

```bash
# Access Jupyter
kubectl port-forward svc/jupyter 8888:8888
open http://localhost:8888

# Connect to Spark Connect
# In your notebook:
from pyspark.sql import SparkSession
spark = SparkSession.builder.remote("sc://localhost:15002").build()
```

---

## 📚 Learning Path

### Phase 1: Foundations (1-2 days)

**Goal:** Run your first analysis

1. [ ] Complete local setup with Kind/Minikube
2. [ ] Connect Jupyter to Spark Connect
3. [ ] Run exploratory queries on sample data
4. [ ] Understand DataFrame operations

**Resources:**
- [Getting Started](../getting-started/)
- [Spark SQL Guide](https://spark.apache.org/docs/latest/sql-programming-guide.html)
- [PySpark Documentation](https://spark.apache.org/docs/latest/api/python/)

### Phase 2: ML Workflows (1 week)

**Goal:** Train and deploy ML models

1. [ ] Use MLflow for experiment tracking
2. [ ] Train distributed ML models
3. [ ] Hyperparameter tuning at scale
4. [ ] Model versioning and registry

**Resources:**
- [MLflow Integration](../recipes/integration/mlflow.md)
- [ML Pipelines](https://spark.apache.org/docs/latest/ml-pipeline.html)
- [Hyperparameter Tuning](../recipes/advanced/hyperparameter-tuning.md)

### Phase 3: Production ML (2-4 weeks)

**Goal:** Deploy models to production

1. [ ] Model serving with Spark Structured Streaming
2. [ ] Batch inference pipelines
3. [ ] GPU acceleration for deep learning
4. [ ] Monitoring model performance

**Resources:**
- [Model Deployment](../recipes/ml/model-deployment.md)
- [GPU Support](../recipes/integration/gpu-support.md)
- [Monitoring ML Pipelines](../guides/en/observability/ml-monitoring.md)

---

## 🎓 Key Skills

### Required Skills

| Skill | Why Important | Resources |
|-------|---------------|------------|
| **PySpark / Spark SQL** | Data manipulation and analysis | [PySpark API](https://spark.apache.org/docs/latest/api/python/) |
| **MLflow** | Experiment tracking | [MLflow Docs](https://mlflow.org/docs/latest/) |
| **Jupyter Notebooks** | Interactive development | [Jupyter Docs](https://jupyter.org/documentation) |

### Nice to Have

- Python (pandas, scikit-learn)
- SQL fundamentals
- ML basics (training, evaluation)
- Data visualization tools

---

## 🔧 Common Tasks

### Interactive Data Exploration

```python
# Connect to Spark Connect
from pyspark.sql import SparkSession
spark = SparkSession.builder \
    .remote("sc://spark-connect:15002") \
    .getOrCreate()

# Load data
df = spark.read.parquet("s3a://data-lake/events/")

# Explore
df.printSchema()
df.show()
df.describe().show()

# SQL queries
df.createOrReplaceTempView("events")
result = spark.sql("""
    SELECT user_id, COUNT(*) as event_count
    FROM events
    GROUP BY user_id
    ORDER BY event_count DESC
    LIMIT 10
""")

result.show()
```

### Train ML Model

```python
from pyspark.ml.feature import VectorAssembler
from pyspark.ml.regression import RandomForestRegressor
from pyspark.ml.evaluation import RegressionEvaluator
import mlflow

# Prepare data
assembler = VectorAssembler(
    inputCols=["feature1", "feature2", "feature3"],
    outputCol="features"
)
data = assembler.transform(df)

# Split data
train, test = data.randomSplit([0.8, 0.2])

# Track with MLflow
with mlflow.start_run():
    # Train model
    rf = RandomForestRegressor(
        labelCol="target",
        numTrees=100
    )
    model = rf.fit(train)

    # Evaluate
    predictions = model.transform(test)
    evaluator = RegressionEvaluator(
        labelCol="target",
        predictionCol="prediction"
    )
    rmse = evaluator.setMetricName("rmse").evaluate(predictions)

    # Log metrics
    mlflow.log_metric("rmse", rmse)
    mlflow.spark.log_model(model, "model")
```

### Batch Inference

```python
# Load trained model
import mlflow.pyfunc

model = mlflow.pyfunc.load_model("models:/spam-classifier/production")

# Run inference on new data
new_data = spark.read.parquet("s3a://data-lake/new_predictions/")
predictions = model.predict(new_data.toPandas())

# Save results
predictions_df = spark.createDataFrame(predictions)
predictions_df.write.parquet("s3a://predictions/output/")
```

### Hyperparameter Tuning

```python
from pyspark.ml.tuning import ParamGridBuilder, CrossValidator

# Define parameter grid
param_grid = ParamGridBuilder() \
    .addGrid(rf.numTrees, [50, 100, 200]) \
    .addGrid(rf.maxDepth, [5, 10, 15]) \
    .build()

# Cross-validation
cv = CrossValidator(
    estimator=rf,
    estimatorParamMaps=param_grid,
    evaluator=evaluator,
    numFolds=3,
    parallelism=4
)

cv_model = cv.fit(train)

# Best model
best_model = cv_model.bestModel
print(f"Best numTrees: {best_model.getNumTrees}")
```

---

## 🧪 GPU Acceleration

### Enable GPU for Deep Learning

```python
from pyspark.sql import SparkSession

# Configure GPU support
spark = SparkSession.builder \
    .remote("sc://spark-connect:15002") \
    .config("spark.task.resource.gpu.amount", "1") \
    .config("spark.executor.resource.gpu.amount", "1") \
    .getOrCreate()

# Use TensorFlow on Spark
# See: docs/recipes/integration/gpu-support.md
```

---

## 📊 Experiment Tracking

### MLflow Integration

```python
import mlflow
import mlflow.spark

# Set tracking URI
mlflow.set_tracking_uri("http://mlflow:5000")
mlflow.set_experiment("customer-churn-prediction")

# Log parameters, metrics, and models
with mlflow.start_run():
    # Log parameters
    mlflow.log_params({
        "num_trees": 100,
        "max_depth": 10,
        "learning_rate": 0.01
    })

    # Train and log metrics
    model = train_model(train_data)
    metrics = evaluate_model(model, test_data)

    mlflow.log_metrics(metrics)
    mlflow.spark.log_model(model, "model")

    # Log artifacts
    mlflow.log_artifact("feature_importance.png")
```

---

## 🚀 Model Deployment

### Batch Scoring

```python
# Scheduled batch job
def score_batch(date):
    # Load data
    data = spark.read.parquet(f"s3a://data/{date}/")

    # Load model
    model = mlflow.spark.load_model("models:/propensity-model/production")

    # Predict
    predictions = model.transform(data)

    # Save results
    predictions.write \
        .mode("overwrite") \
        .parquet(f"s3a://predictions/{date}/")
```

### Real-time Inference

```python
from pyspark.sql.functions import struct, col

# Structured Streaming
stream = spark.readStream \
    .format("kafka") \
    .option("kafka.bootstrap.servers", "kafka:9092") \
    .option("subscribe", "events") \
    .load()

# Apply model
model = mlflow.spark.load_model("models:/fraud-detection/staging")

predictions = model.transform(stream)

# Write to output
query = predictions.writeStream \
    .format("kafka") \
    .option("kafka.bootstrap.servers", "kafka:9092") \
    .option("topic", "predictions") \
    .option("checkpointLocation", "/tmp/checkpoint") \
    .start()

query.awaitTermination()
```

---

## 🐛 Troubleshooting

### Common Issues

**OOM Errors:**
```python
# Increase executor memory
spark.conf.set("spark.executor.memory", "16g")
spark.conf.set("spark.executor.memoryOverhead", "2g")
```

**Slow Jobs:**
```python
# Increase parallelism
spark.conf.set("spark.sql.shuffle.partitions", "200")

# Cache frequently used data
df.cache()
df.count()  # Action to materialize cache
```

**Connection Issues:**
```bash
# Check Spark Connect status
kubectl get svc spark-connect

# Port-forward if needed
kubectl port-forward svc/spark-connect 15002:15002
```

---

## 🆘 Help & Support

### Stuck?

1. [Data Engineer Guide](data-engineer.md) — For deployment issues
2. [Troubleshooting](../operations/troubleshooting.md) — Decision trees
3. [Ask in Telegram](https://t.me/spark_k8s) — Community chat

### Learn More

- [ML Workflow Tutorial](../tutorials/ml-workflow.md) — End-to-end ML example
- [GPU Support](../recipes/integration/gpu-support.md) — Deep learning on Spark
- [MLflow Integration](../recipes/integration/mlflow.md) — Experiment tracking
- [Recipes](../recipes/) — How-to guides

---

## 📈 Next Steps

After completing the Data Scientist path:

1. **Advanced ML**: Distributed training, hyperparameter tuning
2. **Streaming**: Real-time model serving with Structured Streaming
3. **GPU**: Deep learning workloads with GPU acceleration
4. **Production**: MLOps practices, CI/CD for models

---

**Persona:** Data Scientist
**Experience Level:** Beginner → Intermediate
**Estimated Time to Productivity:** 1 day (local) → 1 week (ML workflows)
**Last Updated:** 2026-02-04
