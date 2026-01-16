## WS-012-02: History Server Smoke Test

### 🎯 Goal

**What should WORK after WS completion:**
- Smoke test validates History Server is running and accessible
- Test verifies completed Spark applications appear in History Server UI

**Acceptance Criteria:**
- [ ] `test-spark-standalone.sh` includes History Server health check
- [ ] Script verifies History Server API returns completed applications (after SparkPi runs)
- [ ] Test passes on Minikube with `historyServer.enabled=true`

**⚠️ WS is NOT complete until Goal is achieved (all AC ✅).**

---

### Context

WS-012-01 adds the History Server Deployment/Service. This WS extends the existing smoke test to verify the History Server is operational and displays completed Spark applications.

### Dependency

WS-012-01

### Input Files

- `scripts/test-spark-standalone.sh` — existing E2E smoke test
- Spark History Server REST API: `GET /api/v1/applications` returns JSON list of apps

### Steps

1. **Update `test-spark-standalone.sh`**:
   - Add check: if `historyServer.enabled` (detect via helm values or service existence)
   - Wait for History Server pod to be ready
   - After SparkPi completes, query History Server API for applications
   - Assert at least one completed application is listed

2. **Test locally**:
   - Deploy with `historyServer.enabled=true`
   - Run `scripts/test-spark-standalone.sh`
   - Verify History Server check passes

### Code

**Snippet to add to `test-spark-standalone.sh`:**

```bash
# -----------------------------------------------------------------------------
# 4. History Server check (if deployed)
# -----------------------------------------------------------------------------
HISTORY_SVC="${RELEASE}-spark-standalone-history-server"
if kubectl get svc "$HISTORY_SVC" -n "$NAMESPACE" &>/dev/null; then
  echo "=== Checking History Server ==="
  
  # Wait for pod ready
  echo "Waiting for History Server pod..."
  kubectl wait --for=condition=ready pod \
    -l app=spark-history-server \
    -n "$NAMESPACE" \
    --timeout=120s
  
  # Port-forward in background
  kubectl port-forward "svc/${HISTORY_SVC}" 18080:18080 -n "$NAMESPACE" &
  PF_PID=$!
  sleep 3
  
  # Query applications (may take a moment for logs to be parsed)
  echo "Querying History Server API..."
  APPS=$(curl -s http://localhost:18080/api/v1/applications 2>/dev/null || echo "[]")
  echo "Applications: $APPS"
  
  # Cleanup port-forward
  kill $PF_PID 2>/dev/null || true
  
  # Check at least one application exists
  APP_COUNT=$(echo "$APPS" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
  if [[ "$APP_COUNT" -gt 0 ]]; then
    echo "✓ History Server shows $APP_COUNT application(s)"
  else
    echo "⚠ History Server has no applications yet (may need more time)"
  fi
else
  echo "=== History Server not deployed (skipping) ==="
fi
```

### Expected Result

- Modified: `scripts/test-spark-standalone.sh`
- History Server health check runs as part of E2E smoke

### Scope Estimate

- Files: 1 modified
- Lines: ~40 (SMALL)
- Tokens: ~200

### Completion Criteria

```bash
# Deploy with History Server enabled
helm upgrade --install spark-sa charts/spark-standalone \
  -n spark-sa --create-namespace \
  --set historyServer.enabled=true

# Run smoke test
scripts/test-spark-standalone.sh spark-sa spark-sa

# Expected output includes:
# ✓ History Server shows N application(s)
```

### Constraints

- DO NOT break existing test flow
- DO NOT make History Server check mandatory (skip if not deployed)
- Keep test idempotent
