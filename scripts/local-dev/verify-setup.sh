#!/bin/bash
# Verify local Spark K8s setup
# Part of WS-050-01: Getting Started Guides

set -e

echo "🔍 Verifying Spark K8s setup..."

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Install from: https://kubernetes.io/docs/tasks/tools/"
    exit 1
fi

# Check helm
if ! command -v helm &> /dev/null; then
    echo "❌ helm not found. Install from: https://helm.sh/"
    exit 1
fi

# Check cluster access
if ! kubectl get nodes &> /dev/null; then
    echo "❌ Cannot access cluster. Check kubectl configuration."
    exit 1
fi

# Check for Spark pods
echo "📊 Checking Spark components..."

SPARK_PODS=$(kubectl get pods -l app.kubernetes.io/part-of=spark-k8s -o name 2>/dev/null || true)

if [ -z "$SPARK_PODS" ]; then
    echo "⚠️  No Spark pods found. Deploy Spark first:"
    echo "  helm repo add spark-k8s https://fall-out-bug.github.io/spark_k8s"
    echo "  helm install spark spark-k8s/spark-connect"
    echo ""
    echo "After deployment, run this script again."
else
    echo "✅ Spark pods found:"
    echo "$SPARK_PODS"
fi

echo ""
echo "✅ Setup verification complete!"
echo ""
echo "Ready to deploy Spark jobs. See: docs/getting-started/first-spark-job.md"
