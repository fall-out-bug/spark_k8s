# Airflow with Spark Kubernetes Operator support
FROM apache/airflow:2.11.0-python3.11

USER root

# Install Java for spark-submit (optional, for local testing)
RUN apt-get update && apt-get install -y --no-install-recommends \
    openjdk-17-jre-headless \
    && rm -rf /var/lib/apt/lists/*

USER airflow

# Install Airflow providers for Spark, Kubernetes, OpenLineage
# OpenTelemetry SDK pinned for Airflow 2.11 native traces compatibility
# Quoted version specifiers to satisfy hadolint SC2261
RUN pip install --no-cache-dir --no-deps \
    "apache-airflow-providers-apache-spark>=4.7.0" \
    "apache-airflow-providers-cncf-kubernetes>=8.0.0" \
    "apache-airflow-providers-amazon>=8.19.0" \
    "apache-airflow-providers-openlineage>=1.7.0"

# OpenTelemetry pinned versions, installed separately to avoid slow resolver
RUN pip install --no-cache-dir \
    "opentelemetry-sdk==1.20.0" \
    "opentelemetry-api==1.20.0" \
    "opentelemetry-exporter-otlp-proto-http==1.20.0" \
    "opentelemetry-proto==1.20.0"

RUN pip install --no-cache-dir \
    "pyspark>=3.5.0" \
    "boto3>=1.34.0"

# Copy DAGs
COPY --chown=airflow:root dags/ /opt/airflow/dags/
