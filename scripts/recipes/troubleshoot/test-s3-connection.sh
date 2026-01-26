#!/usr/bin/env bash
# Test S3/MinIO connectivity
# Usage: scripts/recipes/troubleshoot/test-s3-connection.sh <namespace>

set -euo pipefail

NAMESPACE="${1:-spark}"

echo "=== Testing S3/MinIO connectivity ==="

echo -e "\n=== 1. Check MinIO service ==="
kubectl get svc -n "${NAMESPACE}" minio

echo -e "\n=== 2. Port forward to test ==="
PF_PID=""
cleanup() {
  [[ -n "${PF_PID}" ]] && kill "${PF_PID}" 2>/dev/null || true
}
trap cleanup EXIT

kubectl port-forward -n "${NAMESPACE}" svc/minio 9000:9000 >/dev/null 2>&1 &
PF_PID=$!
sleep 3

echo -e "\n=== 3. Test MinIO health ==="
curl -sf http://localhost:9000/minio/health/live && echo "✅ MinIO is healthy" || echo "❌ MinIO health check failed"

echo -e "\n=== 4. Test from Spark Connect pod ==="
POD=$(kubectl get pod -n "${NAMESPACE}" -l app=spark-connect -o jsonpath='{.items[0].metadata.name}')
if [[ -n "${POD}" ]]; then
  echo "Testing from ${POD}..."
  kubectl exec -n "${NAMESPACE}" "${POD}" -- \
    curl -sf http://minio:9000/minio/health/live && echo "✅ Pod can reach MinIO" || echo "❌ Pod cannot reach MinIO"
fi

echo -e "\n=== 5. Check S3 credentials secret ==="
if kubectl get secret -n "${NAMESPACE}" s3-credentials >/dev/null 2>&1; then
  echo "✅ S3 credentials secret exists"
  kubectl get secret -n "${NAMESPACE}" s3-credentials -o yaml | grep -E "access-key|secret-key" | head -4
else
  echo "❌ S3 credentials secret not found"
  echo "Create it with:"
  echo "kubectl create secret generic s3-credentials -n ${NAMESPACE} \\"
  echo "  --from-literal=access-key=minioadmin \\"
  echo "  --from-literal=secret-key=minioadmin"
fi

echo -e "\n=== 6. Check global.s3 configuration ==="
kubectl get cm -n "${NAMESPACE}" spark-connect-configmap -o yaml | grep -A 3 "s3:" || echo "S3 config not in ConfigMap"

echo -e "\n=== Test S3 access with mc (MinIO client) ==="
kubectl run mc-test-$$ --rm -i --restart=Never -n "${NAMESPACE}" --image=quay.io/minio/mc:latest -- \
  /bin/sh -lc "mc alias set test http://minio:9000 minioadmin minioadmin >/dev/null 2>&1 && mc ls test/" && echo "✅ mc can access MinIO" || echo "❌ mc cannot access MinIO"
