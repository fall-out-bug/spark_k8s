---
ws_id: TESTING-003
feature: TESTING
status: backlog
size: SMALL
project_id: 00
github_issue: issue-001
assignee: null
depends_on: ["TESTING-002"]
---

## WS-TESTING-003: Complete E2E Test with Manual PVs

### 🎯 Goal

**What must WORK after completing this WS:**
- F06 core-baseline preset deploys successfully with manual PVs
- All Core Components pods start and are healthy
- PVCs bind to manual PVs correctly
- End-to-end smoke test passes (Spark job submission)
- Testing guide validated and documented

**Acceptance Criteria:**
- [ ] AC1: Manual PVs setup with setup-manual-pvs.sh
- [ ] AC2: Helm install core-baseline preset completes successfully
- [ ] AC3: All pods running (minio, postgresql, hive-metastore, history-server)
- [ ] AC4: PVCs bound to PVs and mounted in pods
- [ ] AC5: Smoke test executed (Spark Connect or simple job)
- [ ] AC6: Results documented in testing guide

**⚠️ WS is NOT complete until Goal is achieved (all AC ✅).**

---

### Context

WS-TESTING-001 identified the root cause (WSL2 + docker driver limitation).
WS-TESTING-002 implemented manual PV workaround with helper scripts.
This WS performs the actual E2E test to validate the complete deployment.

### Dependencies

- WS-TESTING-001 (Diagnostics completed)
- WS-TESTING-002 (Manual PV scripts created)

### Input Files

- `scripts/testing/setup-manual-pvs.sh`
- `templates/testing/pv-*.yaml`
- `charts/spark-4.1/presets/core-baseline.yaml`
- `docs/testing/minikube-testing-guide.md`

### Steps

1. **Setup testing environment**
   ```bash
   # Cleanup any existing resources
   ./scripts/testing/cleanup-manual-pvs.sh
   kubectl delete namespace spark-test --ignore-not-found=true

   # Setup manual PVs
   ./scripts/testing/setup-manual-pvs.sh spark-test
   ```

2. **Deploy Spark chart**
   ```bash
   helm install spark-test charts/spark-4.1 \
     -f charts/spark-4.1/presets/core-baseline.yaml \
     --namespace spark-test \
     --create-namespace \
     --timeout 15m
   ```

3. **Verify Core Components**
   ```bash
   # Check PVCs are bound
   kubectl get pvc -n spark-test

   # Check pods are running
   kubectl get pods -n spark-test

   # Check pod logs
   kubectl logs -n spark-test -l app.kubernetes.io/component=minio
   kubectl logs -n spark-test -l app.kubernetes.io/component=postgresql
   kubectl logs -n spark-test -l app.kubernetes.io/component=hive-metastore
   ```

4. **Run smoke test**
   - Connect to Spark Connect (if enabled)
   - OR submit simple Spark job
   - Verify History Server UI accessible

5. **Document results**
   - Update testing guide with actual results
   - Note any issues or workarounds
   - Capture pod logs for reference

### Expected Outcome

- F06 deployment succeeds in minikube
- All Core Components operational
- Testing guide validated with real deployment
- Ready for production deployment (with cloud storage)

### Scope Estimate

- Files: ~1 (testing guide update)
- Lines: ~50 (SMALL)
- Duration: ~30-45 min (mostly waiting for pods)
- Tokens: ~1500

### Completion Criteria

```bash
# Verify PVs created and available
kubectl get pv | grep -E "minio-pv.*Bound|postgresql-pv.*Bound"

# Verify PVCs bound
kubectl get pvc -n spark-test | grep -E "Bound"

# Verify pods running
kubectl get pods -n spark-test | grep -E "1/1.*Running|2/2.*Running"

# Verify services accessible
kubectl get svc -n spark-test
kubectl port-forward -n spark-test svc/spark-test-history-server 18080:18080 &
curl -s http://localhost:18080 | grep -i "history server"

# Verify documentation updated
grep -E "E2E Test Results|Validation Status" docs/testing/minikube-testing-guide.md
```

### Constraints

- DO NOT modify chart templates (testing only)
- Use only manual PVs (no cloud storage)
- Document all issues encountered
- Test in minikube only (not production)

---

## Test Plan

### Test Matrix

| Component | PVC Required | Pod Status | Service | Validation |
|-----------|--------------|------------|---------|------------|
| Minio | ✅ minio-pv | Running | :9000, :9001 | Buckets created |
| PostgreSQL | ✅ postgresql-pv | Running | :5432 | DB accessible |
| Hive Metastore | - | Running | :9083 | Connected to PG |
| History Server | - | Running | :18080 | UI accessible |

### Smoke Test Options

**Option 1: Spark Connect (if available)**
```bash
# Port-forward
kubectl port-forward -n spark-test svc/spark-test-spark-connect 15002:15002 &

# Connect with spark-shell
spark-shell --master spark://localhost:15002
```

**Option 2: Simple Job**
```bash
# Port-forward History Server
kubectl port-forward -n spark-test svc/spark-test-history-server 18080:18080 &

# Check UI
curl http://localhost:18080
```

**Option 3: Log Verification**
```bash
# Check component logs for errors
kubectl logs -n spark-test -l app.kubernetes.io/component=minio --tail=50
kubectl logs -n spark-test -l app.kubernetes.io/component=postgresql --tail=50
kubectl logs -n spark-test -l app.kubernetes.io/component=hive-metastore --tail=50
```

---

## Execution Report

**Executed by:** TBD
**Date:** TBD
**Duration:** TBD

### Goal Status
- [ ] AC1-AC6

**Goal Achieved:** PENDING

### Test Results

| Test | Result | Details |
|------|--------|---------|
| PV Setup | [PASS/FAIL] | ... |
| Helm Install | [PASS/FAIL] | ... |
| PVC Binding | [PASS/FAIL] | ... |
| Pods Running | [PASS/FAIL] | ... |
| Smoke Test | [PASS/FAIL] | ... |

### Files Changed
| File | Action | LOC |
|------|--------|-----|

### Statistics
- **Files Changed:** 0
- **Lines Added:** 0
- **Test Duration:** TBD

### Issues Encountered
(To be filled during execution)

### Deviations from Plan
None yet

### Commit
Pending execution
