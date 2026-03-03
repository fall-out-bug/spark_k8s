# Bead spark_k8s-1xt.4: Demo P0-04 Missing Grafana Dashboards

**Date:** 2026-03-03
**Category:** Demo (docs)

## Problem

Runbook section 0 applied grafana-dashboards.yaml and grafana-dashboards-spark.yaml
but not tech-lead and logs-explorer. Manual path missed Tech Lead Morning and Logs Explorer.

## Fix

Added to runbook section 0:
- kubectl apply -f tests/observability/grafana-dashboard-tech-lead.yaml
- kubectl apply -f tests/observability/grafana-dashboard-logs-explorer.yaml

## Classification

**Problem type:** Documentation (incomplete apply list)
