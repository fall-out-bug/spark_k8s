# Bead spark_k8s-1xt.6: Demo P1-02 Loki Datasource

**Date:** 2026-03-03
**Category:** Demo (chart/script)

## Problem

deploy-grafana-with-sidecar.sh configured only Prometheus. Logs Explorer dashboard
needs Loki. deploy-observability.sh adds both.

## Fix

Added Loki datasource to deploy-grafana-with-sidecar.sh:
url: http://loki.observability.svc.cluster.local:3100

## Classification

**Problem type:** Chart/script (Grafana datasource config)
