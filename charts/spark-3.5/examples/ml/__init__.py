"""
ML Examples Catalog
===================

Machine learning examples for Apache Spark on Kubernetes.

Available Examples:
1. classification_catboost.py - Binary classification with CatBoost
2. regression_spark_ml.py - Regression with Spark MLlib
3. clustering_kmeans.py - K-Means clustering
4. feature_engineering.py - Feature engineering pipelines
5. model_serving.py - Model serving patterns

All examples support:
- Spark RAPIDS for GPU-accelerated DataFrame operations
- CatBoost CPU for gradient boosting (GPU not supported in Spark integration)
- MLflow for experiment tracking
- Distributed training on Kubernetes

Usage:
    spark-submit --master spark://master:7077 classification_catboost.py
"""

__all__ = [
    "classification_catboost",
    "regression_spark_ml",
    "clustering_kmeans",
    "feature_engineering",
    "model_serving",
]
