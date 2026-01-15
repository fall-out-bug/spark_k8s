# Airflow with Spark Kubernetes Operator support
FROM apache/airflow:2.11.0-python3.11

USER root

# Install Java for spark-submit (optional, for local testing)
RUN apt-get update && apt-get install -y --no-install-recommends \
    openjdk-17-jre-headless \
    && rm -rf /var/lib/apt/lists/*

USER airflow

# Install Airflow providers for Spark and Kubernetes
RUN pip install --no-cache-dir \
    apache-airflow-providers-apache-spark>=4.7.0 \
    apache-airflow-providers-cncf-kubernetes>=8.0.0 \
    apache-airflow-providers-amazon>=8.19.0 \
    pyspark>=3.5.0 \
    boto3>=1.34.0

# Copy DAGs
COPY --chown=airflow:root dags/ /opt/airflow/dags/
