"""
Regression with Spark MLlib
===========================

This example demonstrates:
1. Linear Regression
2. Gradient Boosted Trees (GBT) Regressor
3. Feature engineering pipeline
4. Cross-validation and hyperparameter tuning
5. Model evaluation metrics

Run:
    spark-submit --master spark://master:7077 regression_spark_ml.py
"""

from pyspark.sql import SparkSession
from pyspark.sql.functions import col, rand, when, log, exp
from pyspark.ml.feature import VectorAssembler, StandardScaler, PolynomialExpansion
from pyspark.ml.regression import LinearRegression, GBTRegressor, RandomForestRegressor
from pyspark.ml.evaluation import RegressionEvaluator
from pyspark.ml.tuning import CrossValidator, ParamGridBuilder
from pyspark.ml import Pipeline
import time


def create_spark_session():
    """Create SparkSession for ML workloads."""
    return (
        SparkSession.builder.appName("RegressionSparkML")
        .master("spark://airflow-sc-standalone-master:7077")
        .config("spark.sql.shuffle.partitions", "20")
        .config("spark.memory.fraction", "0.6")
        .config("spark.sql.adaptive.enabled", "true")
        .getOrCreate()
    )


def generate_regression_data(spark, n_samples=100000):
    """Generate synthetic regression dataset with known relationships."""
    df = spark.range(n_samples).select(
        col("id").alias("sample_id"),
        (rand() * 100).alias("feature_1"),
        (rand() * 50).alias("feature_2"),
        (rand() * 200).alias("feature_3"),
        (rand() * 10).alias("feature_4"),
        (rand() * 5).alias("feature_5"),
        when(rand() > 0.5, 1).otherwise(0).alias("categorical_1"),
        when(rand() > 0.7, 1).otherwise(0).alias("categorical_2"),
    )

    df = df.withColumn(
        "target",
        col("feature_1") * 2.5
        + col("feature_2") * 1.8
        + col("feature_3") * 0.5
        + col("feature_4") * 3.0
        + col("categorical_1") * 10
        + col("categorical_2") * (-5)
        + (rand() - 0.5) * 20,
    )

    return df


def build_linear_regression_pipeline():
    """Build linear regression pipeline with feature preprocessing."""
    assembler = VectorAssembler(
        inputCols=["feature_1", "feature_2", "feature_3", "feature_4", "feature_5", "categorical_1", "categorical_2"],
        outputCol="features_raw",
    )

    scaler = StandardScaler(inputCol="features_raw", outputCol="features", withStd=True, withMean=True)

    lr = LinearRegression(
        featuresCol="features",
        labelCol="target",
        predictionCol="prediction",
        maxIter=100,
        regParam=0.1,
        elasticNetParam=0.5,
    )

    return Pipeline(stages=[assembler, scaler, lr])


def build_gbt_pipeline():
    """Build Gradient Boosted Trees regression pipeline."""
    assembler = VectorAssembler(
        inputCols=["feature_1", "feature_2", "feature_3", "feature_4", "feature_5", "categorical_1", "categorical_2"],
        outputCol="features",
    )

    gbt = GBTRegressor(
        featuresCol="features",
        labelCol="target",
        predictionCol="prediction",
        maxIter=100,
        maxDepth=5,
        stepSize=0.1,
        seed=42,
    )

    return Pipeline(stages=[assembler, gbt])


def evaluate_regression(predictions, label_col="target", prediction_col="prediction"):
    """Calculate regression metrics."""
    evaluator_rmse = RegressionEvaluator(predictionCol=prediction_col, labelCol=label_col, metricName="rmse")

    evaluator_mae = RegressionEvaluator(predictionCol=prediction_col, labelCol=label_col, metricName="mae")

    evaluator_r2 = RegressionEvaluator(predictionCol=prediction_col, labelCol=label_col, metricName="r2")

    return {
        "rmse": evaluator_rmse.evaluate(predictions),
        "mae": evaluator_mae.evaluate(predictions),
        "r2": evaluator_r2.evaluate(predictions),
    }


def cross_validate_model(pipeline, train_df):
    """Perform cross-validation with hyperparameter tuning."""
    param_grid = (
        ParamGridBuilder()
        .addGrid(pipeline.getStages()[-1].regParam, [0.01, 0.1, 0.5])
        .addGrid(pipeline.getStages()[-1].elasticNetParam, [0.0, 0.5, 1.0])
        .build()
    )

    evaluator = RegressionEvaluator(predictionCol="prediction", labelCol="target", metricName="rmse")

    crossval = CrossValidator(
        estimator=pipeline, estimatorParamMaps=param_grid, evaluator=evaluator, numFolds=3, parallelism=2, seed=42
    )

    return crossval.fit(train_df)


def main():
    """Run regression model comparison."""
    print("\n" + "=" * 60)
    print("REGRESSION WITH SPARK MLlib")
    print("=" * 60)

    spark = create_spark_session()
    spark.sparkContext.setLogLevel("WARN")

    print(f"Spark version: {spark.version}")
    print("\nGenerating regression data...")

    df = generate_regression_data(spark, n_samples=100000)

    print(f"Total samples: {df.count()}")
    print("\nData summary:")
    df.describe(["feature_1", "feature_2", "target"]).show()

    train_df, test_df = df.randomSplit([0.8, 0.2], seed=42)
    print(f"\nTrain: {train_df.count()}, Test: {test_df.count()}")

    print("\n" + "=" * 60)
    print("1. LINEAR REGRESSION")
    print("=" * 60)

    lr_pipeline = build_linear_regression_pipeline()

    start_time = time.time()
    lr_model = lr_pipeline.fit(train_df)
    lr_train_time = time.time() - start_time

    lr_predictions = lr_model.transform(test_df)
    lr_metrics = evaluate_regression(lr_predictions)
    lr_metrics["train_time_seconds"] = lr_train_time

    print("\nLinear Regression Results:")
    for metric, value in lr_metrics.items():
        print(f"  {metric}: {value:.4f}")

    lr_model_stage = lr_model.stages[-1]
    print(f"\nCoefficients: {lr_model_stage.coefficients}")
    print(f"Intercept: {lr_model_stage.intercept}")

    print("\n" + "=" * 60)
    print("2. GRADIENT BOOSTED TREES")
    print("=" * 60)

    gbt_pipeline = build_gbt_pipeline()

    start_time = time.time()
    gbt_model = gbt_pipeline.fit(train_df)
    gbt_train_time = time.time() - start_time

    gbt_predictions = gbt_model.transform(test_df)
    gbt_metrics = evaluate_regression(gbt_predictions)
    gbt_metrics["train_time_seconds"] = gbt_train_time

    print("\nGBT Regressor Results:")
    for metric, value in gbt_metrics.items():
        print(f"  {metric}: {value:.4f}")

    gbt_model_stage = gbt_model.stages[-1]
    print(f"\nFeature Importances:")
    feature_names = ["feature_1", "feature_2", "feature_3", "feature_4", "feature_5", "categorical_1", "categorical_2"]
    for name, importance in zip(feature_names, gbt_model_stage.featureImportances):
        print(f"  {name}: {importance:.4f}")

    print("\n" + "=" * 60)
    print("3. RANDOM FOREST REGRESSOR")
    print("=" * 60)

    assembler = VectorAssembler(
        inputCols=["feature_1", "feature_2", "feature_3", "feature_4", "feature_5", "categorical_1", "categorical_2"],
        outputCol="features",
    )

    rf = RandomForestRegressor(
        featuresCol="features", labelCol="target", predictionCol="prediction", numTrees=100, maxDepth=10, seed=42
    )

    rf_pipeline = Pipeline(stages=[assembler, rf])

    start_time = time.time()
    rf_model = rf_pipeline.fit(train_df)
    rf_train_time = time.time() - start_time

    rf_predictions = rf_model.transform(test_df)
    rf_metrics = evaluate_regression(rf_predictions)
    rf_metrics["train_time_seconds"] = rf_train_time

    print("\nRandom Forest Results:")
    for metric, value in rf_metrics.items():
        print(f"  {metric}: {value:.4f}")

    print("\n" + "=" * 60)
    print("MODEL COMPARISON")
    print("=" * 60)

    print(f"\n{'Metric':<20} {'Linear':<12} {'GBT':<12} {'RandomForest':<12}")
    print("-" * 56)

    for metric in ["rmse", "mae", "r2", "train_time_seconds"]:
        lr_val = lr_metrics.get(metric, 0)
        gbt_val = gbt_metrics.get(metric, 0)
        rf_val = rf_metrics.get(metric, 0)
        print(f"{metric:<20} {lr_val:<12.4f} {gbt_val:<12.4f} {rf_val:<12.4f}")

    spark.stop()
    print("\nRegression comparison complete.")


if __name__ == "__main__":
    main()
