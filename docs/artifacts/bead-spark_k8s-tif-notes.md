# Bead spark_k8s-tif: WS-034-01 Image Pyramid

**Date:** 2026-03-03
**Category:** Build (run-matrix)

## Problem

get_runtime_image ignored gpu and iceberg; always returned baseline. GPU/Iceberg scenarios got wrong image.

## Fix

Updated get_runtime_image in tests/run-matrix.sh:
- variant: baseline | iceberg | gpu | gpu-iceberg from gpu/iceberg params
- spark-custom: tag with -variant suffix (baseline = no suffix)
- spark-k8s-runtime: 3.5-X-baseline, 4.1-X-baseline format

## Classification

**Problem type:** Build/script (image selection)
