# Bead spark_k8s-1xt.8: Demo P1-04 Pushgateway URL

**Date:** 2026-03-03
**Category:** Demo (chart/DAG)

## Problem

nyc_taxi_ml_full_pipeline used Prometheus (9090) for push metrics. Prometheus does not
accept POST to /metrics/job; Pushgateway (9091) does. Observability stack has no Pushgateway.

## Fix

- Set pushgateway_url to "" (disabled by default)
- push_metric() no-op when url empty or port != 9091
- Downgrade failed push to logger.debug (was warning)
- Note: citibike/movielens DAGs have same issue — fix separately

## Classification

**Problem type:** Chart/DAG (wrong service port)
