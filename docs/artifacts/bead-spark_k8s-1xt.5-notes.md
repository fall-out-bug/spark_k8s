# Bead spark_k8s-1xt.5: Demo P1-01 MinIO spark-logs/4.1/events

**Date:** 2026-03-03
**Category:** Demo (infrastructure)

## Problem

Manual MinIO bootstrap created spark-logs/events/.keep only. Spark 4.1 History Server
expects spark-logs/4.1/events/. Helm-based init creates both.

## Fix

Added to runbook section 2: `echo '' | mc pipe local/spark-logs/4.1/events/.keep`

## Classification

**Problem type:** Infrastructure (MinIO path for Spark 4.1)
