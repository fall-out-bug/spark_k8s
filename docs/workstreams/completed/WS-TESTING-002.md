---
ws_id: TESTING-002
feature: TESTING
status: completed
size: SMALL
project_id: 00
github_issue: issue-001
assignee: claude-code
depends_on: ["TESTING-001"]
---

## WS-TESTING-002: Storage Provisioner Fix Implementation

### 🎯 Goal

**What must WORK after completing this WS:**
- Helper scripts for manual PV provisioning created
- PV templates for Core Components (Minio, PostgreSQL)
- Setup script automated for testing environment
- E2E test passes with manual PVs

**Acceptance Criteria:**
- [ ] AC1: `scripts/testing/setup-manual-pvs.sh` created
- [ ] AC2: PV templates for Minio and PostgreSQL created
- [ ] AC3: Setup script tested successfully
- [ ] AC4: Documentation updated with manual PV instructions
- [ ] AC5: WS-TESTING-003 ready for E2E test

**⚠️ WS is NOT complete until Goal is achieved (all AC ✅).**

---

### Context

WS-TESTING-001 identified that dynamic provisioning doesn't work in minikube (WSL2 + docker driver).
Manual PV provisioning (Option 3) was verified working. This WS implements helper scripts
and templates to streamline manual PV setup for testing.

### Dependencies

WS-TESTING-001 (Diagnostics completed)

### Input Files

- `docs/testing/minikube-storage-diagnostics.md`
- `docs/testing/test-pv.yaml` (reference)
- `docs/issues/issue-001-minikube-pvc-provisioning.md`

### Steps

1. **Create PV templates for Core Components**
   - `templates/testing/pv-minio.yaml` - 10Gi PVC for Minio
   - `templates/testing/pv-postgresql.yaml` - 5Gi PVC for PostgreSQL

2. **Create setup script**
   ```bash
   #!/bin/bash
   # scripts/testing/setup-manual-pvs.sh
   # Create PVs for testing environment
   ```

3. **Create cleanup script**
   ```bash
   #!/bin/bash
   # scripts/testing/cleanup-manual-pvs.sh
   # Remove PVs and reclaim storage
   ```

4. **Update testing documentation**
   - Add manual PV setup instructions
   - Document PV sizing for each component
   - Add troubleshooting section

### Code

```bash
#!/bin/bash
# scripts/testing/setup-manual-pvs.sh

set -e

NAMESPACE=${1:-default}
STORAGE_BASE=${2:-/tmp/spark-testing}

echo "Setting up manual PVs for Spark testing..."
echo "Namespace: $NAMESPACE"
echo "Storage base: $STORAGE_BASE"

# Create directories in minikube
minikube ssh "mkdir -p $STORAGE_BASE/minio $STORAGE_BASE/postgresql"

# Apply PV manifests
kubectl apply -f templates/testing/pv-minio.yaml
kubectl apply -f templates/testing/pv-postgresql.yaml

echo "PVs created successfully!"
kubectl get pv
```

```yaml
# templates/testing/pv-minio.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: minio-pv
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: standard
  hostPath:
    path: /tmp/spark-testing/minio
```

```yaml
# templates/testing/pv-postgresql.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: postgresql-pv
spec:
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: standard
  hostPath:
    path: /tmp/spark-testing/postgresql
```

### Expected Outcome

- Automated PV setup for testing
- Documented manual PV workflow
- Ready for E2E testing (WS-TESTING-003)

### Scope Estimate

- Files: ~4 (2 templates, 2 scripts, docs)
- Lines: ~200 (SMALL)
- Tokens: ~3000

### Completion Criteria

```bash
# Verify scripts exist and executable
ls -la scripts/testing/setup-manual-pvs.sh
ls -la scripts/testing/cleanup-manual-pvs.sh
test -x scripts/testing/setup-manual-pvs.sh

# Verify PV templates
ls -la templates/testing/pv-*.yaml

# Run setup script
./scripts/testing/setup-manual-pvs.sh test-namespace
kubectl get pv | grep -E "minio|postgresql"

# Verify documentation
grep -r "manual PV" docs/testing/
```

### Constraints

- DO NOT modify chart templates (this is testing infrastructure only)
- DO NOT commit to production fixes (testing only)
- MUST document that this is testing-only workaround

---

## Execution Report

**Executed by:** Claude Code
**Date:** 2026-02-02
**Duration:** 20 minutes

### Goal Status
- [x] AC1: `scripts/testing/setup-manual-pvs.sh` created (executable, tested)
- [x] AC2: PV templates for Minio and PostgreSQL created
- [x] AC3: Setup script tested successfully (PVs created and verified)
- [x] AC4: Documentation updated with manual PV instructions
- [x] AC5: WS-TESTING-003 ready for E2E test

**Goal Achieved:** YES

### Files Changed
| File | Action | LOC |
|------|--------|-----|
| templates/testing/pv-minio.yaml | Created | 28 |
| templates/testing/pv-postgresql.yaml | Created | 27 |
| scripts/testing/setup-manual-pvs.sh | Created | 115 |
| scripts/testing/cleanup-manual-pvs.sh | Created | 75 |
| docs/testing/minikube-testing-guide.md | Created | 180 |
| docs/workstreams/backlog/WS-TESTING-003.md | Created | 200 |

### Statistics
- **Files Changed:** 6
- **Lines Added:** ~625
- **Scripts Tested:** setup-manual-pvs.sh ✅

### Test Results

**Setup Script Test:**
```bash
$ ./scripts/testing/setup-manual-pvs.sh spark-test

=== Spark Testing: Manual PV Setup ===
Namespace: spark-test
Storage base: /tmp/spark-testing

Step 1: Creating storage directories in minikube...
✓ Directories created

Step 2: Checking existing PVs...
persistentvolume/minio-pv created
✓ minio-pv created
persistentvolume/postgresql-pv created
✓ postgresql-pv created

Step 3: Verifying PVs...
NAME            CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM   STORAGECLASS   AGE
minio-pv        10Gi       RWO            Retain           Available           standard       0s
postgresql-pv   5Gi        RWO            Retain           Available           standard       0s

=== Setup Complete ===
PVs created and available for binding.
```

**PVs Created:**
- minio-pv: 10Gi, Available, standard StorageClass
- postgresql-pv: 5Gi, Available, standard StorageClass

### Deviations from Plan
None - followed specification exactly.

### Next Steps
WS-TESTING-003: E2E test with manual PVs (ready to execute)

### Commit
Pending (files staged, ready to commit)
