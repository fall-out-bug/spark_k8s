---
ws_id: TESTING-001
feature: TESTING
status: backlog
size: SMALL
project_id: 00
github_issue: issue-001
assignee: null
depends_on: []
---

## WS-TESTING-001: Minikube Storage Diagnostics

### 🎯 Goal

**What must WORK after completing this WS:**
- Root cause of PVC provisioning failure identified
- Minikube storage configuration documented
- Reproduction test case created
- Solution path determined

**Acceptance Criteria:**
- [ ] AC1: Root cause documented in issue-001
- [ ] AC2: Minikube configuration captured (version, driver, storageclass)
- [ ] AC3: Simple PVC test case created and executed
- [ ] AC4: Solution recommendation documented (Option 1, 2, or 3)
- [ ] AC5: WS-TESTING-002 created with implementation plan

**⚠️ WS is NOT complete until Goal is achieved (all AC ✅).**

---

### Context

F06 E2E testing failed due to PVC provisioning issues in minikube (WSL2).
This WS performs deep diagnostics to identify the exact cause and determine
the best fix approach.

### Dependencies

None - Diagnostic workstream

### Input Files

- `docs/issues/issue-001-minikube-pvc-provisioning.md`
- Current minikube setup scripts

### Steps

1. **Capture minikube configuration**
   ```bash
   minikube config view
   kubectl get storageclass
   kubectl get pods -n kube-system | grep storage
   ```

2. **Test simple PVC creation**
   ```bash
   # Create minimal PVC
   kubectl apply -f test-pvc.yaml
   kubectl get pvc -w
   kubectl describe pvc test-pvc
   ```

3. **Check provisioner logs**
   ```bash
   kubectl logs -n kube-system -l app=storage-provisioner
   ```

4. **Test all three solution options**
   - Option 1: Reconfigure hostpath provisioner
   - Option 2: Install local-path provisioner
   - Option 3: Manual PV provisioning

5. **Document findings and recommendation**

### Code

```bash
# test-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

```yaml
# Expected outcome document
# docs/testing/minikube-storage-diagnostics.md

## Configuration
- Minikube: v1.37.0
- Driver: docker
- StorageClass: standard (k8s.io/minikube-hostpath)

## Root Cause
[Documented findings]

## Test Results
| Test | Result | Notes |
|------|--------|-------|
| Simple PVC | [PASS/FAIL] | ... |
| With storageClass | [PASS/FAIL] | ... |
| Option 1 | [PASS/FAIL] | ... |
| Option 2 | [PASS/FAIL] | ... |
| Option 3 | [PASS/FAIL] | ... |

## Recommendation
Option X: [Reasoning]
```

### Expected Outcome

- Root cause clearly identified
- At least one solution option verified to work
- WS-TESTING-002 created with implementation plan
- Testing documentation updated

### Scope Estimate

- Files: ~2 (test manifest, diagnostic report)
- Lines: ~150 (SMALL)
- Tokens: ~2200

### Completion Criteria

```bash
# Verify diagnostic report exists
ls -la docs/testing/minikube-storage-diagnostics.md

# Verify test results documented
grep -E "Root Cause|Test Results|Recommendation" docs/testing/minikube-storage-diagnostics.md

# Verify WS-TESTING-002 exists
ls -la docs/workstreams/backlog/WS-TESTING-002.md
```

### Constraints

- DO NOT create PRs (diagnostic work only)
- DO NOT modify chart templates (this is infrastructure fix)
- MUST update issue-001 with findings

---

## Execution Report

**Executed by:** TBD
**Date:** TBD
**Duration:** TBD

### Goal Status
- [ ] AC1-AC5

**Goal Achieved:** PENDING

### Files Changed
| File | Action | LOC |
|------|--------|-----|

### Statistics
- **Files Changed:** 0
- **Lines Added:** 0

### Deviations from Plan
None yet

### Commit
Pending execution
