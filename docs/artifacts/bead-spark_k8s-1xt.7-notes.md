# Bead spark_k8s-1xt.7: Demo P1-03 NodePorts

**Date:** 2026-03-03
**Category:** Demo (chart)

## Problem

Runbook section 6 assumes NodePorts 30080/30088/30081 for Airflow/Jupyter/History.
demo-full-spark-infra used ClusterIP.

## Fix

Added to demo-full-spark-infra.yaml:
- historyServer.service: NodePort 30081
- jupyter.service: NodePort 30088
- standalone.airflow.webserver.service: NodePort 30080

## Classification

**Problem type:** Chart (preset values)
