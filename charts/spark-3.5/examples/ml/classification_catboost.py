"""
Binary Classification with CatBoost and Spark MLlib
===================================================

This example demonstrates:
1. CatBoostClassifier for gradient boosting (CPU only)
2. Spark MLlib RandomForestClassifier for comparison
3. Feature engineering with Spark ML Pipelines
4. Model evaluation and comparison
5. MLflow experiment tracking (optional)

NOTE: CatBoost for Apache Spark does NOT support GPU.
For GPU-accelerated DataFrame operations, use Spark RAPIDS.

Requirements:
    pip install catboost pandas numpy

Run:
    spark-submit --master spark://master:7077 \
        --jars /path/to/spark-metrics_2.12-3.5.7.jar \
        classification_catboost.py
"""

from pyspark.sql import SparkSession
from pyspark.sql.functions import col, when, rand, split
from pyspark.ml.feature import StringIndexer, VectorAssembler, StandardScaler
from pyspark.ml.classification import RandomForestClassifier, LogisticRegression
from pyspark.ml.evaluation import BinaryClassificationEvaluator, MulticlassClassificationEvaluator
from pyspark.ml import Pipeline
from pyspark.ml.tuning import CrossValidator, ParamGridBuilder
import time


def create_spark_session():
    """Create SparkSession with ML configuration."""
    return (
        SparkSession.builder.appName("ClassificationCatBoost")
        .master("spark://airflow-sc-standalone-master:7077")
        .config("spark.sql.shuffle.partitions", "20")
        .config("spark.memory.fraction", "0.6")
        .config("spark.memory.storageFraction", "0.5")
        .config("spark.sql.execution.arrow.pyspark.enabled", "true")
        .config("spark.sql.execution.arrow.maxRecordsPerBatch", "10000")
        .getOrCreate()
    )


def generate_sample_data(spark, n_samples=100000):
    """Generate synthetic classification dataset."""
    from pyspark.sql.functions import lit

    df = spark.range(n_samples).select(
        col("id").alias("customer_id"),
        (rand() * 100).alias("age"),
        (rand() * 100000).alias("income"),
        (rand() * 50).alias("years_employed"),
        (rand() * 10).alias("num_accounts"),
        (rand() * 5).alias("num_loans"),
        (rand() * 0.1).alias("default_rate"),
        when(rand() > 0.5, "M").otherwise("F").alias("gender"),
        when(rand() > 0.7, "Urban").when(rand() > 0.4, "Suburban").otherwise("Rural").alias("region"),
        when(rand() > 0.5, "Premium").when(rand() > 0.3, "Standard").otherwise("Basic").alias("account_type"),
        when((col("income") > 50000) & (col("years_employed") > 5) & (col("default_rate") < 0.05), 1)
        .otherwise(0)
        .alias("label"),
    )
    return df


def build_spark_ml_pipeline():
    """Build Spark ML Pipeline for classification."""
    gender_indexer = StringIndexer(inputCol="gender", outputCol="gender_idx", handleInvalid="keep")

    region_indexer = StringIndexer(inputCol="region", outputCol="region_idx", handleInvalid="keep")

    account_indexer = StringIndexer(inputCol="account_type", outputCol="account_type_idx", handleInvalid="keep")

    assembler = VectorAssembler(
        inputCols=[
            "age",
            "income",
            "years_employed",
            "num_accounts",
            "num_loans",
            "default_rate",
            "gender_idx",
            "region_idx",
            "account_type_idx",
        ],
        outputCol="features_raw",
        handleInvalid="keep",
    )

    scaler = StandardScaler(inputCol="features_raw", outputCol="features", withStd=True, withMean=True)

    rf = RandomForestClassifier(featuresCol="features", labelCol="label", numTrees=100, maxDepth=10, seed=42)

    pipeline = Pipeline(stages=[gender_indexer, region_indexer, account_indexer, assembler, scaler, rf])

    return pipeline


def train_catboost_model(train_pdf, test_pdf):
    """Train CatBoost model on pandas DataFrame."""
    from catboost import CatBoostClassifier, Pool
    from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score, roc_auc_score

    feature_cols = [
        "age",
        "income",
        "years_employed",
        "num_accounts",
        "num_loans",
        "default_rate",
        "gender_idx",
        "region_idx",
        "account_type_idx",
    ]
    cat_cols = ["gender_idx", "region_idx", "account_type_idx"]

    X_train = train_pdf[feature_cols]
    y_train = train_pdf["label"]
    X_test = test_pdf[feature_cols]
    y_test = test_pdf["label"]

    model = CatBoostClassifier(
        iterations=500,
        learning_rate=0.1,
        depth=6,
        loss_function="Logloss",
        eval_metric="AUC",
        cat_features=cat_cols,
        random_seed=42,
        verbose=100,
        task_type="CPU",
    )

    start_time = time.time()
    model.fit(X_train, y_train, eval_set=(X_test, y_test), early_stopping_rounds=50, verbose=False)
    train_time = time.time() - start_time

    predictions = model.predict(X_test)
    probabilities = model.predict_proba(X_test)[:, 1]

    metrics = {
        "accuracy": accuracy_score(y_test, predictions),
        "precision": precision_score(y_test, predictions),
        "recall": recall_score(y_test, predictions),
        "f1": f1_score(y_test, predictions),
        "auc_roc": roc_auc_score(y_test, probabilities),
        "train_time_seconds": train_time,
        "best_iteration": model.best_iteration_,
    }

    return model, metrics


def evaluate_spark_model(predictions):
    """Evaluate Spark ML model predictions."""
    binary_evaluator = BinaryClassificationEvaluator(
        rawPredictionCol="rawPrediction", labelCol="label", metricName="areaUnderROC"
    )

    multi_evaluator = MulticlassClassificationEvaluator(predictionCol="prediction", labelCol="label")

    auc = binary_evaluator.evaluate(predictions)
    accuracy = multi_evaluator.setMetricName("accuracy").evaluate(predictions)
    precision = multi_evaluator.setMetricName("weightedPrecision").evaluate(predictions)
    recall = multi_evaluator.setMetricName("weightedRecall").evaluate(predictions)
    f1 = multi_evaluator.setMetricName("f1").evaluate(predictions)

    return {"auc_roc": auc, "accuracy": accuracy, "precision": precision, "recall": recall, "f1": f1}


def main():
    """Run classification comparison: CatBoost vs Spark MLlib."""
    print("\n" + "=" * 60)
    print("BINARY CLASSIFICATION: CatBoost vs Spark MLlib")
    print("=" * 60)

    spark = create_spark_session()
    spark.sparkContext.setLogLevel("WARN")

    print(f"Spark version: {spark.version}")
    print("\nGenerating sample data...")

    df = generate_sample_data(spark, n_samples=100000)

    print(f"Total samples: {df.count()}")
    print(f"Class distribution:")
    df.groupBy("label").count().show()

    train_df, test_df = df.randomSplit([0.8, 0.2], seed=42)
    print(f"Train: {train_df.count()}, Test: {test_df.count()}")

    print("\n" + "=" * 60)
    print("1. SPARK MLlib RANDOM FOREST")
    print("=" * 60)

    pipeline = build_spark_ml_pipeline()

    start_time = time.time()
    spark_model = pipeline.fit(train_df)
    spark_train_time = time.time() - start_time

    spark_predictions = spark_model.transform(test_df)
    spark_metrics = evaluate_spark_model(spark_predictions)
    spark_metrics["train_time_seconds"] = spark_train_time

    print("\nSpark MLlib Random Forest Results:")
    for metric, value in spark_metrics.items():
        print(f"  {metric}: {value:.4f}")

    print("\n" + "=" * 60)
    print("2. CATBOOST CLASSIFIER (CPU)")
    print("=" * 60)

    try:
        from pyspark.sql.functions import col as spark_col

        indexers = Pipeline(
            stages=[
                StringIndexer(inputCol="gender", outputCol="gender_idx"),
                StringIndexer(inputCol="region", outputCol="region_idx"),
                StringIndexer(inputCol="account_type", outputCol="account_type_idx"),
            ]
        )

        indexed_train = indexers.fit(train_df).transform(train_df)
        indexed_test = indexers.fit(train_df).transform(test_df)

        train_pdf = indexed_train.toPandas()
        test_pdf = indexed_test.toPandas()

        print(f"Converting to pandas: train={len(train_pdf)}, test={len(test_pdf)}")

        catboost_model, catboost_metrics = train_catboost_model(train_pdf, test_pdf)

        print("\nCatBoost Results:")
        for metric, value in catboost_metrics.items():
            print(f"  {metric}: {value:.4f}")

    except ImportError:
        print("CatBoost not installed. Skipping.")
        catboost_metrics = None
    except Exception as e:
        print(f"CatBoost error: {e}")
        catboost_metrics = None

    print("\n" + "=" * 60)
    print("MODEL COMPARISON")
    print("=" * 60)

    print(f"\n{'Metric':<20} {'Spark MLlib':<15} {'CatBoost':<15}")
    print("-" * 50)

    if catboost_metrics:
        for metric in ["accuracy", "precision", "recall", "f1", "auc_roc", "train_time_seconds"]:
            spark_val = spark_metrics.get(metric, 0)
            cat_val = catboost_metrics.get(metric, 0)
            print(f"{metric:<20} {spark_val:<15.4f} {cat_val:<15.4f}")
    else:
        for metric, value in spark_metrics.items():
            print(f"{metric:<20} {value:<15.4f} {'N/A':<15}")

    spark.stop()
    print("\nClassification comparison complete.")


if __name__ == "__main__":
    main()
