#!/usr/bin/env bash
# Restore demo environment from any failure mode in <5 minutes.
# Handles: stuck release, chart swap, scale-to-zero, orphan namespaces.
# Usage: ./scripts/restore-demo.sh [--force]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
NAMESPACE="spark-infra"
RELEASE="spark-infra"
CHART_PATH="$PROJECT_ROOT/charts/spark-3.5"
PRESET="$CHART_PATH/presets/demo-full-spark-infra.yaml"
_FORCE="${1:-}"  # reserved for future --force flag

echo "=== Demo Recovery ==="
echo "Namespace: $NAMESPACE"
echo "Release:   $RELEASE"
echo "Chart:     $CHART_PATH"
echo ""

# Step 1: Clean orphan test namespaces
orphan_ns=$(kubectl get ns -o name 2>/dev/null | grep 'test-scenario-' || true)
if [[ -n "$orphan_ns" ]]; then
  echo "[1/5] Cleaning orphan test namespaces..."
  echo "$orphan_ns" | xargs -r kubectl delete --ignore-not-found --wait=false
else
  echo "[1/5] No orphan test namespaces."
fi

# Step 2: Detect current release state
release_json=$(helm list -n "$NAMESPACE" -f "^${RELEASE}$" -o json 2>/dev/null || echo "[]")
release_status=$(echo "$release_json" | python3 -c "import json,sys; r=json.load(sys.stdin); print(r[0]['status'] if r else 'missing')" 2>/dev/null || echo "missing")
release_chart=$(echo "$release_json" | python3 -c "import json,sys; r=json.load(sys.stdin); print(r[0]['chart'] if r else '')" 2>/dev/null || echo "")

echo "[2/5] Release status: $release_status, chart: ${release_chart:-none}"

# Step 3: Clean conflicting releases
all_releases=$(helm list -n "$NAMESPACE" -o json 2>/dev/null || echo "[]")
extra_releases=$(echo "$all_releases" | python3 -c "
import json, sys
releases = json.load(sys.stdin)
for r in releases:
    if r['name'] != '$RELEASE':
        print(r['name'])
" 2>/dev/null || true)

if [[ -n "$extra_releases" ]]; then
  echo "[3/5] Removing conflicting releases..."
  while IFS= read -r rel; do
    echo "  Uninstalling: $rel"
    helm uninstall "$rel" -n "$NAMESPACE" --wait=false 2>/dev/null || true
  done <<< "$extra_releases"
  sleep 3
else
  echo "[3/5] No conflicting releases."
fi

# Step 4: Fix or reinstall the release
needs_reinstall=false

if [[ "$release_status" == "uninstalling" || "$release_status" == "pending-install" || "$release_status" == "pending-upgrade" ]]; then
  echo "[4/5] Release stuck in '$release_status'. Cleaning helm secrets..."
  kubectl delete secret -n "$NAMESPACE" -l "owner=helm,name=$RELEASE" --ignore-not-found 2>/dev/null || true
  needs_reinstall=true
elif [[ "$release_status" == "failed" ]]; then
  echo "[4/5] Release in 'failed' state. Will reinstall..."
  helm uninstall "$RELEASE" -n "$NAMESPACE" --wait=false 2>/dev/null || true
  kubectl delete secret -n "$NAMESPACE" -l "owner=helm,name=$RELEASE" --ignore-not-found 2>/dev/null || true
  sleep 2
  needs_reinstall=true
elif [[ "$release_status" == "missing" ]]; then
  echo "[4/5] Release missing. Checking for orphan helm secrets..."
  orphan_secrets=$(kubectl get secret -n "$NAMESPACE" -l "owner=helm,name=$RELEASE" --no-headers 2>/dev/null | wc -l || echo "0")
  if [[ "$orphan_secrets" -gt 0 ]]; then
    echo "  Found $orphan_secrets orphan helm secrets. Cleaning..."
    kubectl delete secret -n "$NAMESPACE" -l "owner=helm,name=$RELEASE" --ignore-not-found 2>/dev/null || true
    sleep 2
  fi
  needs_reinstall=true
elif [[ "$release_chart" != spark-3.5-* ]]; then
  echo "[4/5] Wrong chart ($release_chart). Uninstalling and reinstalling with spark-3.5..."
  helm uninstall "$RELEASE" -n "$NAMESPACE" --wait 2>/dev/null || true
  kubectl delete secret -n "$NAMESPACE" -l "owner=helm,name=$RELEASE" --ignore-not-found 2>/dev/null || true
  sleep 3
  needs_reinstall=true
elif [[ "$release_status" == "deployed" ]]; then
  echo "[4/5] Release deployed with correct chart. Checking replicas..."
  scaled_down=false
  for deploy in \
    "${RELEASE}-standalone-master" \
    "${RELEASE}-standalone-worker" \
    "${RELEASE}-airflow-webserver" \
    "${RELEASE}-airflow-scheduler" \
    "${RELEASE}-spark-35-jupyter"; do
    replicas=$(kubectl get deployment "$deploy" -n "$NAMESPACE" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
    if [[ "$replicas" == "0" ]]; then
      echo "  Scaling up $deploy..."
      kubectl scale deployment "$deploy" -n "$NAMESPACE" --replicas=1
      scaled_down=true
    fi
  done
  sts="${RELEASE}-airflow-postgresql"
  if kubectl get statefulset "$sts" -n "$NAMESPACE" &>/dev/null; then
    replicas=$(kubectl get statefulset "$sts" -n "$NAMESPACE" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
    if [[ "$replicas" == "0" ]]; then
      echo "  Scaling up $sts..."
      kubectl scale statefulset "$sts" -n "$NAMESPACE" --replicas=1
      scaled_down=true
    fi
  fi
  # Note: When using shared PostgreSQL, airflow-postgresql StatefulSet is not deployed
  if [[ "$scaled_down" == "false" ]]; then
    echo "  All replicas OK. Running helm upgrade to sync..."
  fi
fi

if [[ "$needs_reinstall" == "true" ]]; then
  echo ""
  echo "Installing $RELEASE from $CHART_PATH..."
  helm dependency build "$CHART_PATH" 2>/dev/null || true
  kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

  # Annotate namespace as protected
  kubectl annotate namespace "$NAMESPACE" \
    spark-k8s/owner-release="$RELEASE" \
    spark-k8s/owner-chart=spark-3.5 \
    spark-k8s/protected=true \
    --overwrite 2>/dev/null || true

  helm upgrade --install "$RELEASE" "$CHART_PATH" \
    -n "$NAMESPACE" \
    -f "$PRESET" \
    --set global.s3.accessKey=minioadmin \
    --set global.s3.secretKey=minioadmin \
    --set spark-base.postgresql.auth.password=postgres \
    --set standalone.airflow.postgresql.auth.password=postgres \
    --timeout 10m \
    --wait
else
  # Ensure correct chart on existing release
  helm upgrade "$RELEASE" "$CHART_PATH" \
    -n "$NAMESPACE" \
    -f "$PRESET" \
    --set global.s3.accessKey=minioadmin \
    --set global.s3.secretKey=minioadmin \
    --set spark-base.postgresql.auth.password=postgres \
    --set standalone.airflow.postgresql.auth.password=postgres \
    --timeout 10m \
    --wait 2>/dev/null || echo "  Helm upgrade skipped or failed (pods may already be starting)"
fi

# Step 5: Ensure PostgreSQL databases exist (spark_db, airflow)
# Required when PVC was initialized before these DBs were in postgresql.databases
pg_pod=$(kubectl get pod -n "$NAMESPACE" -l app=postgresql -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [[ -n "$pg_pod" ]]; then
  echo "[5/6] Ensuring PostgreSQL databases (spark_db, airflow)..."
  kubectl wait --for=condition=ready pod -n "$NAMESPACE" "$pg_pod" --timeout=120s 2>/dev/null || true
  for db in spark_db airflow; do
    kubectl exec -n "$NAMESPACE" "$pg_pod" -- psql -U postgres -c "CREATE DATABASE $db;" 2>/dev/null || true
  done
  # Restart metastore so it picks up spark_db
  kubectl delete pod -n "$NAMESPACE" -l app=hive-metastore --ignore-not-found 2>/dev/null || true
else
  echo "[5/6] No shared PostgreSQL pod (using external or airflow-postgresql)."
fi

# Step 6: Wait and verify
echo ""
echo "[6/6] Waiting for core pods..."
kubectl wait --for=condition=ready pod -l app=minio -n "$NAMESPACE" --timeout=120s 2>/dev/null || true
kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=spark-master -n "$NAMESPACE" --timeout=180s 2>/dev/null || true

echo ""
echo "=== Running health check ==="
"$SCRIPT_DIR/check-demo-health.sh" || echo "WARNING: Some checks still failing. Pods may need more startup time."
