#!/bin/bash
# Setup Kind cluster for local Spark development
# Part of WS-050-01: Getting Started Guides

set -e

echo "🚀 Setting up Kind cluster for Spark K8s development..."

# Check if kind is installed
if ! command -v kind &> /dev/null; then
    echo "❌ Kind not found. Install from: https://kind.sigs.k8s.io/"
    exit 1
fi

# Check Docker
if ! docker ps &> /dev/null; then
    echo "❌ Docker not running. Start Docker Desktop and try again."
    exit 1
fi

# Create Kind cluster
echo "📦 Creating Kind cluster..."
kind create cluster \
    --name spark-dev \
    --image=kindest/node:v1.28.0

# Verify cluster
echo "✅ Verifying cluster..."
kubectl get nodes

echo ""
echo "✅ Kind cluster is ready!"
echo ""
echo "Next steps:"
echo "  1. Deploy Spark: helm install spark spark-k8s/spark-connect"
echo "  2. Port-forward: kubectl port-forward svc/jupyter 8888:8888"
echo "  3. Open: http://localhost:8888"
echo ""
echo "For more info: https://github.com/fall-out-bug/spark_k8s/docs/getting-started/"
