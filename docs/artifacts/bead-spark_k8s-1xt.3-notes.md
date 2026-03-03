# Bead spark_k8s-1xt.3: Demo P0-03 spark-35-full-stack-demo Wrong Services

**Date:** 2026-03-03
**Category:** Demo (docs)

## Problem

Doc used spark-operations for Grafana/Prometheus; deploy-demo-minikube uses observability.
Mixed scenario1/scenario2 with single-release path caused wrong commands.

## Fix

- Added "Deployment Paths" table: deploy-demo-minikube vs run-minikube-scenarios vs legacy
- Updated port-forward: observability first, spark-operations as fallback
- Added deploy-demo alternatives for Jupyter/Master (spark-infra)
- Pushgateway: observability (note: may not be deployed in minimal observability stack)

## Classification

**Problem type:** Documentation (wrong namespace references)
