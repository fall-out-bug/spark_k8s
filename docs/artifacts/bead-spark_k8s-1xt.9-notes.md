# Bead spark_k8s-1xt.9: Demo P1-05 MinIO FQDN

**Date:** 2026-03-03
**Category:** Demo (script/infra)

## Problem

upload-spark-jobs-to-minio.sh used MINIO_ENDPOINT=http://minio:9000. Short name
works when pod runs in same namespace; FQDN improves robustness.

## Fix

Use MINIO_ENDPOINT=http://minio.${NAMESPACE}.svc.cluster.local:9000

## Classification

**Problem type:** Script/infrastructure (DNS resolution)
