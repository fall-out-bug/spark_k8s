# Bead spark_k8s-1xt.10: Demo P1-06 Promtail Path

**Date:** 2026-03-03
**Category:** Demo (docs/infra)

## Problem

Promtail uses /var/log/pods/ (containerd). On Docker runtime path differs; logs may not be collected.

## Fix

Added runbook note: Promtail validated for containerd; Docker runtime may need workaround.

## Classification

**Problem type:** Infrastructure/docs (runtime-specific log path)
