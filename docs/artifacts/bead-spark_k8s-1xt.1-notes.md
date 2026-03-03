# Bead spark_k8s-1xt.1: Demo P0-01 Service Name Mismatch

**Date:** 2026-03-03
**Category:** Demo (chart/infra)

## Problem

Runbook, demo-metrics-exporter, DAGs, notebooks referenced `spark-shared-spark-35-*`.
Actual deploy uses release `spark-infra` → `spark-infra-spark-35-*`.

## Fix

Replaced `spark-shared` with `spark-infra` in:
- tests/demo-runbook-shared-infra.md
- tests/observability/demo-metrics-exporter.yaml
- tests/shared-infra-values.yaml (postgres host)
- charts/spark-3.5/charts/spark-standalone/dags/spark_standalone_load_demo.py
- charts/spark-3.5/notebooks/*.ipynb (3 files)
- scripts/tests/minikube/verify-observability-recipes.sh
- tests/observability/start-ui-portforwards.sh
- scripts/scale-down-spark-infra.sh
- docs/observability/recipes/ds-5min.md

## Classification

**Problem type:** Chart/infrastructure naming (deploy uses spark-infra release)
