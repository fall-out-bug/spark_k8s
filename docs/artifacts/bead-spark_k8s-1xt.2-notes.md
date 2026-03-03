# Bead spark_k8s-1xt.2: Demo P0-02 Missing nyc-taxi Bucket

**Date:** 2026-03-03
**Category:** Demo (infrastructure + docs)

## Problem

nyc_taxi_ml_full_pipeline requires `s3a://nyc-taxi/raw/` (≥4 files). MinIO bootstrap
created warehouse, spark-logs, spark-jobs but not nyc-taxi. No ingestion step documented.

## Fix

- Added `mc mb --ignore-existing local/nyc-taxi` to runbook section 2
- Documented data ingestion: download_nyc_tlc.py with port-forward or from pod

## Classification

**Problem type:** Infrastructure (bucket) + documentation (ingestion step)
