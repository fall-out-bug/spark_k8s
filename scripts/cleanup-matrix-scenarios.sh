#!/usr/bin/env bash
# Clean up orphaned matrix scenario namespaces (spark-matrix-scenario-*).
# Use after interrupted run-matrix-320.sh or when namespaces are stuck.
#
# Usage:
#   ./scripts/cleanup-matrix-scenarios.sh           # dry-run: list only
#   ./scripts/cleanup-matrix-scenarios.sh --execute # actually delete
#   ./scripts/cleanup-matrix-scenarios.sh --force    # force-terminate stuck namespaces

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
EXECUTE=false
FORCE=false

for arg in "$@"; do
  case "$arg" in
    --execute) EXECUTE=true ;;
    --force)   FORCE=true ;;
    -h|--help)
      echo "Usage: $0 [--execute] [--force]"
      echo "  --execute  Actually uninstall helm and delete namespaces (default: dry-run)"
      echo "  --force    Patch finalizers on stuck Terminating namespaces"
      exit 0
      ;;
  esac
done

cd "$PROJECT_ROOT"

# List spark-matrix-* namespaces
ns_list=$(kubectl get namespaces -o name 2>/dev/null | sed 's|namespace/||' | grep '^spark-matrix-scenario-' || true)

if [[ -z "$ns_list" ]]; then
  echo "No spark-matrix-scenario-* namespaces found."
  exit 0
fi

count=$(echo "$ns_list" | wc -l)
echo "Found $count matrix scenario namespace(s):"
echo "$ns_list" | sed 's/^/  /'

if [[ "$EXECUTE" != "true" ]]; then
  echo ""
  echo "Dry-run. To actually clean up, run: $0 --execute"
  exit 0
fi

echo ""
echo "Cleaning up..."

for ns in $ns_list; do
  # ns: spark-matrix-scenario-0001 -> release: scenario0001
  suffix=$(echo "$ns" | sed 's/spark-matrix-//')
  release=$(echo "$suffix" | tr '[:upper:]' '[:lower:]' | tr -d '-')
  echo "  $ns: helm uninstall $release..."
  helm uninstall "$release" -n "$ns" --wait 2>/dev/null || true
  echo "  $ns: kubectl delete namespace..."
  kubectl delete namespace "$ns" --timeout=120s --ignore-not-found=true 2>/dev/null || true
done

# Check for stuck Terminating namespaces
stuck=$(kubectl get namespaces 2>/dev/null | grep 'spark-matrix-scenario-' | grep Terminating || true)
if [[ -n "$stuck" && "$FORCE" == "true" ]]; then
  echo ""
  echo "Force-terminating stuck namespaces..."
  echo "$stuck" | awk '{print $1}' | while read -r ns; do
    echo "  Patching finalizers on $ns..."
    kubectl patch namespace "$ns" -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
  done
elif [[ -n "$stuck" ]]; then
  echo ""
  echo "Some namespaces stuck in Terminating:"
  echo "$stuck" | sed 's/^/  /'
  echo "Run with --force to patch finalizers (may require cluster-admin)"
fi

echo ""
echo "Done. Remaining spark-matrix-* namespaces:"
kubectl get namespaces 2>/dev/null | grep 'spark-matrix-scenario-' || echo "  (none)"
echo ""
echo "To redeploy shared infra: ./scripts/deploy-shared-infra-minikube.sh"
