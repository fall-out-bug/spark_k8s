# Monitoring Setup Guide

> **Audience:** Operators
> **Dependencies:** F16 (Observability stack)

## Overview

Step-by-step guide to set up monitoring for Spark on Kubernetes.

## Prerequisites

- Kubernetes cluster with Spark workloads
- Helm 3.x
- Prometheus, Grafana, Loki (optional)

## Step 1: Deploy Observability Stack

```bash
helm repo add observability https://charts.example.com/observability
helm install observability observability/observability \
  --namespace observability \
  --create-namespace
```

## Step 2: Enable Spark Metrics Export

Ensure Spark applications export metrics to Prometheus:

```yaml
# In SparkApplication or Helm values
sparkConf:
  spark.metrics.conf.*.sink.prometheusServlet.class: org.apache.spark.metrics.sink.PrometheusServlet
  spark.ui.prometheus.enabled: "true"
```

## Step 3: Configure ServiceMonitor

Create ServiceMonitor for Spark driver/executor metrics:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: spark-metrics
spec:
  selector:
    matchLabels:
      app: spark
  endpoints:
  - port: metrics
    interval: 15s
```

## Step 4: Import Dashboards

Import Grafana dashboards from `charts/observability/grafana/dashboards/`:

- `performance-analysis.json` — Job performance
- `cost-by-job.json` — Cost attribution

## Step 5: Configure Alerts

See [Alert Configuration](./alert-configuration.md) for Prometheus rules and AlertManager examples.

## Verification

```bash
# Check Prometheus targets
kubectl port-forward -n observability svc/prometheus 9090:9090
# Open http://localhost:9090/targets

# Check Grafana
kubectl port-forward -n observability svc/grafana 3000:3000
# Open http://localhost:3000
```
