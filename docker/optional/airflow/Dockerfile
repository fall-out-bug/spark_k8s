# Airflow with Spark Kubernetes Operator support
FROM apache/airflow:3.2.2-python3.11

USER root

# Install Java for spark-submit (optional, for local testing)
RUN apt-get update && apt-get install -y --no-install-recommends \
    openjdk-17-jre-headless \
    && rm -rf /var/lib/apt/lists/*

USER airflow

# Install Airflow providers for Spark, Kubernetes, OpenLineage.
# Provider majors bumped for Airflow 3.x compatibility:
#   - openlineage 2.x (was 1.7) — Airflow-3-compatible line
#   - cncf-kubernetes 10.x (was 8.0) — tracks Airflow 3
#   - apache-spark 9.x, amazon 9.x — 3.x-compatible floors
# Quoted version specifiers to satisfy hadolint SC2261
RUN pip install --no-cache-dir --no-deps \
    "apache-airflow-providers-apache-spark>=9.0.0" \
    "apache-airflow-providers-cncf-kubernetes>=10.0.0" \
    "apache-airflow-providers-amazon>=9.0.0" \
    "apache-airflow-providers-openlineage>=2.18.0"

# OpenTelemetry SDK for Airflow 3.x native tracing (OTLP export to Jaeger/Collector).
# IMPORTANT: pin >=1.35.0 — versions <1.35 have a MeterProvider memory leak
# (apache/airflow#53763) that crashes schedulers/triggerers. The previous 1.20.0
# pin was an Airflow-2.11-specific workaround (T029) that is both unnecessary and
# actively harmful on 3.x. 3.x uses a different OTel code path that works with 1.35+.
RUN pip install --no-cache-dir \
    "opentelemetry-sdk>=1.35.0" \
    "opentelemetry-api>=1.35.0" \
    "opentelemetry-exporter-otlp-proto-http>=1.35.0" \
    "opentelemetry-proto>=1.35.0"

RUN pip install --no-cache-dir \
    "pyspark>=3.5.0" \
    "boto3>=1.34.0"

# Copy DAGs
COPY --chown=airflow:root dags/ /opt/airflow/dags/
