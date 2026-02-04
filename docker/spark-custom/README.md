# Spark Custom Images - Build Guide

## Quick Start

Build images with default UID 185:

```bash
cd docker/spark-custom
docker build -f Dockerfile.3.5.7 -t spark-k8s:3.5.7-hadoop3.4.2 .
docker build -f Dockerfile.4.1.0 -t spark-k8s:4.1.0-hadoop3.4.2 .
```

## OpenShift Builds

For OpenShift with restricted SCC, use UID 1000000000:

```bash
# Spark 3.5.7 for OpenShift
docker build -f Dockerfile.3.5.7 \
  --build-arg SPARK_UID=1000000000 \
  --build-arg SPARK_GID=1000000000 \
  -t spark-k8s:3.5.7-hadoop3.4.2-openshift .

# Spark 4.1.0 for OpenShift
docker build -f Dockerfile.4.1.0 \
  --build-arg SPARK_UID=1000000000 \
  --build-arg SPARK_GID=1000000000 \
  -t spark-k8s:4.1.0-hadoop3.4.2-openshift .
```

Then update your Helm values:

```yaml
# For OpenShift, use the openshift preset
helm install spark -f presets/openshift/restricted.yaml ...
```

## Image Contents

Both images include:
- Spark from source with Hadoop 3.4.2 (AWS SDK v2 support)
- Kafka support (spark-sql-kafka-0-10)
- JDBC drivers: PostgreSQL, Oracle, Vertica
- PySpark with Python 3.11
- Kubernetes python client

## Versions

| Image | Spark | Hadoop | Scala | Size |
|-------|-------|--------|-------|------|
| spark-k8s:3.5.7-hadoop3.4.2 | 3.5.7 | 3.4.2 | 2.12 | ~10.5GB |
| spark-k8s:4.1.0-hadoop3.4.2 | 4.1.0 | 3.4.2 | 2.13 | ~11.7GB |
