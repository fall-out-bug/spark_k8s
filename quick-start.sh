#!/bin/bash
# Quick Start - Deploy Spark + Jupyter in <2 min
# Usage: ./quick-start.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Spark K8s Quick Start ==="

# Ensure minikube/kubectl
if ! command -v kubectl &>/dev/null; then
    echo "Error: kubectl required. Install: https://kubernetes.io/docs/tasks/tools/"
    exit 1
fi

# Start minikube if needed
if command -v minikube &>/dev/null && ! kubectl cluster-info &>/dev/null 2>&1; then
    echo "Starting Minikube..."
    minikube start --driver=docker 2>/dev/null || minikube start
fi

# Deploy (use spark-3.5 or spark-4.1)
CHART="${SPARK_CHART:-charts/spark-3.5}"
echo "Deploying Spark from $CHART..."
helm upgrade --install spark "$CHART" \
  -n spark --create-namespace --wait --timeout 5m

echo ""
echo "=========================================="
echo "  Success! Spark K8s is deployed."
echo "=========================================="
echo ""
echo "  Port-forward: kubectl port-forward -n spark svc/spark-spark-*-jupyter 8888:8888"
echo "  Jupyter:      http://localhost:8888"
echo ""
echo "  See docs/quick-start.md for details."
echo ""
