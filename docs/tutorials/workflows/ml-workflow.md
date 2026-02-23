# ML Training Workflow Tutorial

This tutorial demonstrates how to build an ML training pipeline with Spark MLlib on Kubernetes.

## Overview

You will learn:
1. Feature engineering with Spark
2. Distributed model training
3. Hyperparameter tuning
4. Model serving with Spark

## Prerequisites

- Spark with MLlib
- Training data in accessible storage
- Model registry configured

## Tutorial: Customer Churn Prediction

### Step 1: Feature Engineering

```python
# ml_jobs/churn_training.py
from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from pyspark.sql.types import *
from pyspark.ml.feature import *
from pyspark.ml.classification import RandomForestClassifier, GBTClassifier
from pyspark.ml.evaluation import BinaryClassificationEvaluator
from pyspark.ml.tuning import CrossValidator, ParamGridBuilder
import mlflow
import mlflow.spark

def create_spark_session():
    """Create Spark session for ML training."""
    return SparkSession.builder \
        .appName("churn-model-training") \
        .config("spark.sql.adaptive.enabled", "true") \
        .config("spark.sql.adaptive.coalescePartitions.enabled", "true") \
        .getOrCreate()

def load_features(spark, data_path):
    """Load and join feature tables."""
    # User demographics
    demographics = spark.read.parquet(f"{data_path}/demographics")

    # Usage metrics
    usage = spark.read.parquet(f"{data_path}/usage_metrics")

    # Support tickets
    support = spark.read.parquet(f"{data_path}/support_tickets")

    # Join features
    features = demographics \
        .join(usage, "user_id", "left") \
        .join(support, "user_id", "left") \
        .fillna(0) \
        .fillna("unknown")

    return features

def engineer_features(df):
    """Create ML features."""
    # Date features
    df = df.withColumn("account_age_days",
                       datediff(current_date(), to_date(col("created_date"))))

    # Aggregation features
    df = df \
        .withColumn("avg_daily_sessions", col("total_sessions") / col("account_age_days")) \
        .withColumn("avg_daily_duration", col("total_duration") / col("account_age_days"))

    # Ratio features
    df = df \
        .withColumn("support_tickets_per_day",
                    col("support_ticket_count") / col("account_age_days")) \
        .withColumn("failed_payment_rate",
                    col("failed_payments") / col("total_payments"))

    # Encoding categorical variables
    indexers = [
        StringIndexer(inputCol=col, outputCol=col+"_idx")
        for col in ["plan_type", "region", "payment_method"]
    ]

    for indexer in indexers:
        df = indexer.fit(df).transform(df)

    # Assemble feature vector
    numeric_cols = [
        "account_age_days", "avg_daily_sessions", "avg_daily_duration",
        "support_tickets_per_day", "failed_payment_rate", "monthly_spend"
    ]

    categorical_cols = [col+"_idx" for col in ["plan_type", "region", "payment_method"]]

    assembler = VectorAssembler(
        inputCols=numeric_cols + categorical_cols,
        outputCol="features",
        handleInvalid="keep"
    )

    df = assembler.transform(df)

    return df

def train_test_split(df, test_ratio=0.2, seed=42):
    """Split data into train and test sets."""
    train, test = df.randomSplit([1-test_ratio, test_ratio], seed=seed)
    return train, test

def train_model(train_df, model_type="rf"):
    """Train the churn prediction model."""
    mlflow.start_run()

    try:
        if model_type == "rf":
            model = RandomForestClassifier(
                labelCol="churned",
                featuresCol="features",
                numTrees=100,
                maxDepth=10
            )
        elif model_type == "gbt":
            model = GBTClassifier(
                labelCol="churned",
                featuresCol="features",
                maxIter=100
            )

        # Hyperparameter tuning
        param_grid = ParamGridBuilder() \
            .addGrid(model.maxDepth, [5, 10, 15]) \
            .addGrid(model.minInstancesPerNode, [1, 5, 10]) \
            .build()

        evaluator = BinaryClassificationEvaluator(
            labelCol="churned",
            metricName="areaUnderPR"
        )

        cv = CrossValidator(
            estimator=model,
            estimatorParamMaps=param_grid,
            evaluator=evaluator,
            numFolds=5,
            parallelism=4
        )

        cv_model = cv.fit(train_df)

        # Log metrics
        mlflow.log_metric("avg_auc", cv_model.avgMetrics[0] if cv_model.avgMetrics else 0)
        mlflow.log_param("model_type", model_type)

        # Log model
        mlflow.spark.log_model(cv_model.bestModel, "model")

        return cv_model.bestModel

    finally:
        mlflow.end_run()

def evaluate_model(model, test_df):
    """Evaluate model performance."""
    predictions = model.transform(test_df)

    evaluator = BinaryClassificationEvaluator(
        labelCol="churned",
        metricName="areaUnderROC"
    )

    auc = evaluator.evaluate(predictions)
    pr_auc = evaluator.setMetricName("areaUnderPR").evaluate(predictions)

    # Calculate additional metrics
    total = predictions.count()
    churned = predictions.filter(col("churned") == 1).count()
    predicted_churn = predictions.filter(col("prediction") == 1).count()
    correct = predictions.filter(col("churned") == col("prediction")).count()

    accuracy = correct / total

    print(f"Test AUC: {auc:.4f}")
    print(f"Test PR-AUC: {pr_auc:.4f}")
    print(f"Accuracy: {accuracy:.4f}")
    print(f"Total samples: {total}")
    print(f"Churn rate: {churned/total:.2%}")

    return {
        "auc": auc,
        "pr_auc": pr_auc,
        "accuracy": accuracy,
        "total_samples": total
    }

def save_model(model, output_path):
    """Save model to storage."""
    model.write().overwrite().save(output_path)
    print(f"Model saved to: {output_path}")

def main():
    """Main training workflow."""
    import sys

    spark = create_spark_session()

    try:
        data_path = sys.argv[1] if len(sys.argv) > 1 else "s3a://ml-data/churn"
        model_type = sys.argv[2] if len(sys.argv) > 2 else "rf"
        output_path = sys.argv[3] if len(sys.argv) > 3 else "s3a://ml-models/churn/latest"

        print(f"Loading data from: {data_path}")
        raw_df = load_features(spark, data_path)
        print(f"Loaded {raw_df.count()} records")

        print("Engineering features...")
        feature_df = engineer_features(raw_df)

        print("Splitting data...")
        train_df, test_df = train_test_split(feature_df)

        print(f"Training set: {train_df.count()}")
        print(f"Test set: {test_df.count()}")

        print(f"Training {model_type} model...")
        model = train_model(train_df, model_type)

        print("Evaluating model...")
        metrics = evaluate_model(model, test_df)

        print("Saving model...")
        save_model(model, output_path)

        print("Training completed successfully!")

    except Exception as e:
        print(f"Training failed: {str(e)}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
    finally:
        spark.stop()

if __name__ == "__main__":
    main()
```

### Step 2: Deploy Training Job

```yaml
# manifests/ml-training-job.yaml
apiVersion: sparkoperator.k8s.io/v1beta2
kind: SparkApplication
metadata:
  name: churn-model-training
  namespace: spark-ml
spec:
  type: Python
  mode: cluster
  image: your-registry/spark-ml:latest
  mainApplicationFile: local:///app/ml_jobs/churn_training.py
  sparkVersion: "3.5.0"
  restartPolicy: OnFailure

  driver:
    cores: 2
    memory: "4g"
    serviceAccount: spark
    env:
      - name: MLFLOW_TRACKING_URI
        value: "http://mlflow.mlflow.svc.cluster.local:5000"
      - name: MLFLOW_S3_ENDPOINT_URL
        value: "https://s3.amazonaws.com"
      - name: AWS_ACCESS_KEY_ID
        valueFrom:
          secretKeyRef:
            name: mlflow-s3-credentials
            key: access-key-id
      - name: AWS_SECRET_ACCESS_KEY
        valueFrom:
          secretKeyRef:
            name: mlflow-s3-credentials
            key: secret-access-key

  executor:
    cores: 4
    instances: 20
    memory: "8g"

  deps:
    pyPackages:
      - mlflow==2.8.0
      - boto3
```

### Step 3: Model Serving Pipeline

```python
# ml_jobs/churn_serving.py
from pyspark.sql import SparkSession
from pyspark.ml.pipeline import PipelineModel
import json

def load_model(model_path):
    """Load trained model."""
    return PipelineModel.load(model_path)

def predict_batch(spark, model, input_path, output_path):
    """Make predictions on batch data."""
    # Load input data
    input_df = spark.read.parquet(input_path)

    # Load and apply feature engineering
    from ml_jobs.churn_training import engineer_features
    feature_df = engineer_features(input_df)

    # Make predictions
    predictions = model.transform(feature_df)

    # Extract probability and prediction
    result = predictions.select(
        "user_id",
        col("prediction").cast("int").alias("churn_prediction"),
        col("probability").getItem(1).alias("churn_probability")
    )

    # Save predictions
    result.write \
        .mode("overwrite") \
        .format("parquet") \
        .save(output_path)

    return result

def main():
    spark = SparkSession.builder \
        .appName("churn-model-serving") \
        .getOrCreate()

    try:
        model = load_model("s3a://ml-models/churn/latest")

        predictions = predict_batch(
            spark,
            model,
            "s3a://ml-data/churn/inference/latest",
            "s3a://ml-data/churn/predictions/latest"
        )

        print(f"Generated {predictions.count()} predictions")

    finally:
        spark.stop()

if __name__ == "__main__":
    main()
```

### Step 4: Scheduled Retraining

```yaml
apiVersion: batch/v1beta1
kind: CronJob
metadata:
  name: churn-model-retraining
  namespace: spark-ml
spec:
  schedule: "0 3 1 * *"  # First day of month at 3 AM
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: spark
          containers:
          - name: spark-submit
            image: your-registry/spark-ctl:latest
            command:
            - /opt/spark/bin/spark-submit
            - --master
            - k8s://https://kubernetes.default.svc
            - --deploy-mode
            - cluster
            - --name
            - churn-retraining
            - --conf
            - spark.kubernetes.container.image=your-registry/spark-ml:latest
            - --conf
            - spark.kubernetes.namespace=spark-ml
            - --conf
            - spark.kubernetes.authenticate.driver.serviceAccountName=spark
            - --py-files
            - local:///app/ml_jobs/churn_training.py
            - s3a://ml-code/jobs/churn_training.py
```

## Best Practices

### 1. Feature Versioning

Track feature schema changes:

```python
mlflow.log_dict(feature_schema, "feature_schema.json")
```

### 2. Model Registry

Use MLflow model registry:

```python
mlflow.spark.log_model(
    model,
    "model",
    registered_model_name="churn_predictor",
    signature=signature
)
```

### 3. Data Drift Detection

Monitor feature distribution:

```python
def detect_drift(old_features, new_features, threshold=0.1):
    for col in old_features.columns:
        old_mean = old_features.agg(mean(col)).collect()[0][0]
        new_mean = new_features.agg(mean(col)).collect()[0][0]
        drift = abs((new_mean - old_mean) / old_mean)
        if drift > threshold:
            print(f"Drift detected in {col}: {drift:.2%}")
```

## Next Steps

- [ ] Implement online learning for concept drift
- [ ] Add model interpretability (SHAP values)
- [ ] Set up A/B testing for model comparison
- [ ] Create monitoring dashboard

## Related

- [Feature Engineering Guide](../../docs/guides/feature-engineering.md)
- [MLflow Integration](../../docs/guides/mlflow-setup.md)
