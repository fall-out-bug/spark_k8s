#!/bin/bash
# Setup Minikube for local Spark development
# Part of WS-050-01: Getting Started Guides

set -e

echo "🚀 Setting up Minikube for Spark K8s development..."

# Check if Minikube is installed
if ! command -v minikube &> /dev/null; then
    echo "❌ Minikube not found. Install from: https://minikube.sigs.k8s.io/"
    exit 1
fi

# Check Docker
if ! docker ps &> /dev/null; then
    echo "❌ Docker not running. Start Docker Desktop and try again."
    exit 1
fi

# Start Minikube
echo "📦 Starting Minikube..."
minikube start \
    --cpus=4 \
    --memory=8192 \
    --driver=docker \
    --container-runtime=docker \
    --dns-proxy=false

# Enable ingress (optional, for some use cases)
echo "🌐 Enabling ingress..."
minikube addons enable ingress || true

# Verify cluster
echo "✅ Verifying cluster..."
kubectl get nodes

echo ""
echo "✅ Minikube is ready!"
echo ""
echo "Next steps:"
echo "  1. Deploy Spark: helm install spark spark-k8s/spark-connect"
echo "  2. Port-forward: kubectl port-forward svc/jupyter 8888:8888"
echo "  3. Open: http://localhost:8888"
echo ""
echo "For more info: https://github.com/fall-out-bug/spark_k8s/docs/getting-started/"
