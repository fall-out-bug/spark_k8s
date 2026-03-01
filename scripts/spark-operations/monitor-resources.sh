#!/bin/bash
# ===================================================================
# Spark Resource Monitor
# ===================================================================
# Monitor Spark cluster resources in Kubernetes
#
# Usage:
#   ./monitor-resources.sh [namespace]
#
# Shows:
#   - Master/Worker pod status
#   - Memory and CPU usage
#   - Executor status
# ===================================================================

set -e

NAMESPACE="${1:-spark-airflow}"

echo "=============================================="
echo "Spark Cluster Resource Monitor"
echo "=============================================="
echo "Namespace: $NAMESPACE"
echo "Time: $(date)"
echo ""

echo "--- Master Pod ---"
MASTER_POD=$(kubectl get pods -n $NAMESPACE -l app=spark-standalone-master -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [[ -n "$MASTER_POD" ]]; then
    kubectl get pod -n $NAMESPACE $MASTER_POD -o custom-columns=\
NAME:.metadata.name,\
STATUS:.status.phase,\
CPU:.spec.containers[0].resources.requests.cpu,\
MEMORY:.spec.containers[0].resources.requests.memory,\
RESTARTS:.status.containerStatuses[0].restartCount
else
    echo "Master pod not found"
fi

echo ""
echo "--- Worker Pods ---"
kubectl get pods -n $NAMESPACE -l app=spark-standalone-worker -o custom-columns=\
NAME:.metadata.name,\
STATUS:.status.phase,\
CPU:.spec.containers[0].resources.requests.cpu,\
MEMORY:.spec.containers[0].resources.requests.memory,\
RESTARTS:.status.containerStatuses[0].restartCount 2>/dev/null || echo "No worker pods found"

echo ""
echo "--- Resource Quota ---"
kubectl get resourcequota -n $NAMESPACE 2>/dev/null || echo "No resource quota defined"

echo ""
echo "--- Recent Events ---"
kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' 2>/dev/null | tail -10 || echo "No events"

echo ""
echo "--- Spark UI ---"
echo "Port-forward: kubectl port-forward -n $NAMESPACE svc/airflow-sc-standalone-master 8080:8080"
echo "UI URL:       http://localhost:8080"
