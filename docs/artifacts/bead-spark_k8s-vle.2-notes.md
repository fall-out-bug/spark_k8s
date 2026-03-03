# Bead spark_k8s-vle.2: F01/F03 Chart Path Docs

**Date:** 2026-03-03
**Category:** Drift (docs)

## Problem

Original WS expected `charts/spark-standalone` at repo root. Actual layout:
`charts/spark-3.5/charts/spark-standalone`. History Server in parent chart.

## Fix

- Updated `docs/guides/en/charts/spark-standalone.md`: added "Current layout" note
- Symlink `charts/spark-standalone` → `spark-3.5/charts/spark-standalone` already exists

## Classification

**Problem type:** Documentation drift (not test, chart, build, or infra)
