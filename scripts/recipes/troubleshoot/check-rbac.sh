#!/usr/bin/env bash
# Check RBAC permissions
# Usage: scripts/recipes/troubleshoot/check-rbac.sh <namespace> [service-account]

set -euo pipefail

NAMESPACE="${1:-spark}"
SA="${2:-spark}"

echo "=== Checking RBAC for ${SA} in ${NAMESPACE} ==="

echo -e "\n=== 1. ServiceAccount ==="
kubectl get sa -n "${NAMESPACE}" "${SA}" || echo "❌ ServiceAccount not found"

echo -e "\n=== 2. ClusterRoleBindings ==="
kubectl get clusterrolebinding -o json | \
  jq -r ".items[] | select(.subjects[]?.name == \"${SA}\" and .subjects[]?.namespace == \"${NAMESPACE}\") | .metadata.name" || echo "No ClusterRoleBindings found"

echo -e "\n=== 3. RoleBindings ==="
kubectl get rolebinding -n "${NAMESPACE}" -o json | \
  jq -r ".items[] | select(.subjects[]?.name == \"${SA}\") | .metadata.name" || echo "No RoleBindings found"

echo -e "\n=== 4. Test permissions with can-i ==="
echo "Checking key permissions..."
kubectl auth can-i get pods -n "${NAMESPACE}" --as=system:serviceaccount:"${NAMESPACE}":"${SA}" && echo "✅ Can list pods" || echo "❌ Cannot list pods"
kubectl auth can-i create pods -n "${NAMESPACE}" --as=system:serviceaccount:"${NAMESPACE}":"${SA}" && echo "✅ Can create pods" || echo "❌ Cannot create pods"
kubectl auth can-i get secrets -n "${NAMESPACE}" --as=system:serviceaccount:"${NAMESPACE}":"${SA}" && echo "✅ Can get secrets" || echo "❌ Cannot get secrets"

echo -e "\n=== 5. Check PSS (Pod Security Standards) ==="
kubectl get namespace "${NAMESPACE}" -o yaml | grep -A 10 "podSecurityContext" || echo "No PSS configured"

echo -e "\n=== Recommendation ==="
if kubectl auth can-i create pods -n "${NAMESPACE}" --as=system:serviceaccount:"${NAMESPACE}":"${SA}" >/dev/null 2>&1; then
  echo "✅ RBAC looks OK"
else
  echo "❌ RBAC insufficient - check docs/recipes/troubleshoot/rbac-permissions.md"
fi
