# OpenLineage Integration Setup

This guide explains how to set up OpenLineage with Spark K8s for data lineage tracking.

## Overview

OpenLineage is an open standard for data lineage that tracks:
- Job executions and their inputs/outputs
- Dataset schemas and versions
- Run states and dependencies

## Components

| Component | Purpose |
|-----------|---------|
| **Marquez** | OpenLineage backend (web UI + API) |
| **openlineage-spark** | Spark listener for emitting lineage events |
| **openlineage-python** | Python client for programmatic lineage |

## Quick Start

### 1. Deploy Marquez

```bash
# Using Helm
helm repo add marquez https://openlineage.io/charts
helm install marquez marquez/marquez \
  --namespace lineage \
  --create-namespace \
  --set service.type=LoadBalancer

# Or using Docker Compose
curl -L https://raw.githubusercontent.com/OpenLineage/openlineage/main/docker/docker-compose.yml | docker-compose -f - up -d
```

### 2. Enable OpenLineage in Spark K8s

```bash
helm install spark charts/spark-4.1 \
  -f charts/spark-4.1/presets/openlineage-values.yaml \
  --set features.openLineage.endpoint=http://marquez:5000 \
  --set features.openLineage.namespace=my-team
```

### 3. Verify Integration

```bash
# Port-forward Marquez UI
kubectl port-forward svc/marquez 5000:5000 -n lineage

# Open http://localhost:5000 in browser
# Run a Spark job and check lineage in UI
```

## Configuration Reference

### values.yaml Configuration

```yaml
features:
  openLineage:
    enabled: true
    # Backend endpoint
    endpoint: "http://marquez:5000"
    # Namespace for organizing jobs (team, environment, etc.)
    namespace: "spark-k8s"
    # Job name prefix
    jobPrefix: "spark-"
    # Facet configuration
    facets:
      enabled: true
      sparkVersion: true
      sourceCode: false
    # Transport type
    transport:
      type: "http"  # http, kafka, file
```

### Spark Properties Generated

When `features.openLineage.enabled: true`, the following Spark properties are set:

| Property | Description |
|----------|-------------|
| `spark.extraListeners` | `io.openlineage.spark.OpenLineageSparkListener` |
| `spark.openlineage.host` | Backend endpoint |
| `spark.openlineage.namespace` | Lineage namespace |
| `spark.openlineage.jobPrefix` | Job name prefix |

## Transport Options

### HTTP (Default)

```yaml
features:
  openLineage:
    transport:
      type: "http"
```

Events sent directly to Marquez API.

### Kafka

```yaml
features:
  openLineage:
    transport:
      type: "kafka"
      kafka:
        topic: "openlineage.events"
        brokers: "kafka:9092"
```

Events published to Kafka topic for async processing.

### File

```yaml
features:
  openLineage:
    transport:
      type: "file"
      file:
        path: "/tmp/openlineage/events.json"
```

Events written to local file (useful for debugging).

## Marquez UI

Access the Marquez UI to view:
- **DAG View**: Visual representation of job dependencies
- **Run History**: Execution times, durations, statuses
- **Dataset Schema**: Column names, types, versions

### Example Lineage

```
[nyc_taxi_raw] --> [spark-etl-job] --> [nyc_taxi_clean]
                                              |
                                              v
                                    [spark-aggregate-job] --> [nyc_taxi_metrics]
```

## Integration with Airflow

OpenLineage integrates with Airflow for end-to-end lineage:

```python
from airflow import DAG
from airflow.providers.apache.spark.operators.spark_submit import SparkSubmitOperator

with DAG("spark_etl", ...) as dag:
    etl = SparkSubmitOperator(
        task_id="etl_job",
        application="/path/to/etl.py",
        conf={
            "spark.extraListeners": "io.openlineage.spark.OpenLineageSparkListener",
            "spark.openlineage.host": "http://marquez:5000",
            "spark.openlineage.namespace": "production",
        },
    )
```

## Troubleshooting

### No Lineage Events Appearing

1. Check Spark logs for OpenLineage errors:
   ```bash
   kubectl logs <spark-pod> | grep -i openlineage
   ```

2. Verify Marquez is accessible:
   ```bash
   curl http://marquez:5000/api/v1/namespaces
   ```

3. Check network connectivity between Spark and Marquez

### Missing JAR Error

If you see `ClassNotFoundException: io.openlineage.spark.OpenLineageSparkListener`:

1. Ensure `openlineage-spark` JAR is in Spark classpath
2. Rebuild Docker image with pom.xml dependency
3. Or download JAR manually:
   ```bash
   wget -O /opt/spark/jars/openlineage-spark.jar \
     https://repo1.maven.org/maven2/io/openlineage/openlineage-spark_2.13/1.24.0/openlineage-spark_2.13-1.24.0.jar
   ```

## Resources

- [OpenLineage Documentation](https://openlineage.io/docs)
- [Marquez GitHub](https://github.com/OpenLineage/marquez)
- [openlineage-spark](https://github.com/OpenLineage/openlineage-spark)
- [Marquez Helm Chart](https://github.com/OpenLineage/helm-charts)
