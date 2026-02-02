# Issue-001: Minikube PVC Provisioning Failure

**Status:** In Progress (Root Cause Identified)
**Priority:** P1 (Blocks E2E testing)
**Created:** 2026-02-02
**Feature:** F06 (testing infrastructure)
**Resolution:** Option 3 - Manual PV Provisioning (verified working)

---

## Problem Description

When deploying Spark charts with Core Components to minikube, PVC provisioning fails with:

```
Warning  FailedScheduling  0/1 nodes are available: pod has unbound immediate PersistentVolumeClaims. not found
```

**Observed Behavior:**
- PVCs remain in `Pending` state indefinitely
- Pods dependent on PVCs fail to schedule (minio, postgresql)
- StorageClass `standard` exists and is default
- Helm template validation passes successfully

**Affected Components:**
- Minio (`minio-spark-41-pvc`)
- PostgreSQL (`data-postgresql-metastore-41-0`)

---

## Root Cause Analysis

**Identified:** WSL2 + Docker Driver limitation

### Environment
- **Platform:** WSL2 (Ubuntu 22.04)
- **Minikube:** v1.37.0
- **Driver:** docker
- **Kubernetes:** v1.34.0
- **StorageClass:** standard (k8s.io/minikube-hostpath), local-path (rancher.io/local-path)

### Confirmed Root Cause

**Primary Issue:** Minikube's storage provisioners (both hostpath and rancher) do not work correctly in WSL2 with docker driver. The provisioner pods cannot properly create hostpath volumes due to WSL2 filesystem limitations and docker container isolation.

**Evidence:**
1. Storage-provisioner pod was in `CrashLoopBackOff` (402 restarts)
2. After restart, pod runs but doesn't create PVs
3. Rancher local-path addon enables but provisioner pod never starts
4. Manual PV + PVC works perfectly

**Diagnostics Report:** `docs/testing/minikube-storage-diagnostics.md`

---

## Acceptance Criteria

- [x] AC1: Root cause identified and documented
- [x] AC2: Solution verified (Option 3 - Manual PV)
- [ ] AC3: WS-TESTING-002 created for implementation
- [ ] AC4: E2E test passes with manual PVs
- [ ] AC5: Storage provisioning documented in testing guide

**Test Results:**
- ✅ Manual PV + PVC: **PASS** (Pod running, volume mounted)
- ❌ Auto-provision (hostpath): **FAIL**
- ❌ Auto-provision (rancher): **FAIL**

---

---

## Proposed Solutions

### Option 1: Fix Hostpath Provisioner (Recommended)

Configure minikube to properly provision hostpath volumes:

```bash
# Stop minikube
minikube stop

# Start with explicit storage configuration
minikube start \
  --driver=docker \
  --container-runtime=docker \
  --extra-config=storageclass.default.k8s.io/standard=true \
  --disk-size=20g

# Verify provisioner
kubectl get pods -n kube-system | grep storage
```

### Option 2: Use Local Path Provisioner

Install alternative local-path provisioner:

```bash
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.26/deploy/local-path-storage.yaml

# Patch default storageclass
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

### Option 3: Pre-provision Volumes

Create manual PVs for testing:

```yaml
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
  hostPath:
    path: /tmp/minio-data
```

---

## Implementation Plan

### Phase 1: Diagnostics (WS-TESTING-001)
- Verify minikube storage provisioner status
- Check kube-system logs for storage errors
- Test PVC creation with simple manifest
- Document current minikube configuration

### Phase 2: Fix Implementation (WS-TESTING-002)
- Implement chosen solution (Option 1 or 2)
- Update minikube setup documentation
- Add storage validation script

### Phase 3: E2E Testing (WS-TESTING-003)
- Deploy core-baseline preset successfully
- Verify PVC binding and pod mounting
- Run sample Spark job
- Document results

---

## Workstream References

This issue blocks:
- **WS-TESTING-001:** Minikube storage diagnostics
- **WS-TESTING-002:** Storage provisioner fix
- **WS-TESTING-003:** Complete E2E test with Core Components

Related to:
- **F06:** Core Components + Feature Presets (testing incomplete)
- **All future features:** Blocked on E2E testing infrastructure

---

## Technical Details

### Current StorageClass

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: k8s.io/minikube-hostpath
reclaimPolicy: Delete
volumeBindingMode: Immediate
allowVolumeExpansion: false
```

### PVC Template (from charts)

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: minio-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: standard  # Uses default
```

### Error Timeline

1. `helm install` executed
2. PVCs created in `Pending` state
3. Pods attempted to schedule
4. Scheduler failed: "pod has unbound immediate PersistentVolumeClaims. not found"
5. Helm post-install hook timed out (10m)
6. Installation marked as failed

---

## Testing Commands

```bash
# Test PVC creation manually
cat <<EOF | kubectl apply -f -
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
EOF

# Watch PVC status
kubectl get pvc test-pvc -w

# Check provisioner logs
kubectl logs -n kube-system -l app=storage-provisioner

# Describe PVC if stuck
kubectl describe pvc test-pvc
```

---

## References

- [Minikube Storage Documentation](https://minikube.sigs.k8s.io/docs/handbook/persistent_volumes/)
- [Kubernetes Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)
- [Local Path Provisioner](https://github.com/rancher/local-path-provisioner)

---

## Next Steps

1. Create workstream WS-TESTING-001 for diagnostics
2. Run diagnostic commands to confirm root cause
3. Implement fix based on findings
4. Re-test F06 deployment with fix in place
5. Update testing documentation

---

**Last Updated:** 2026-02-02
**Assignee:** TBD
**Target:** Complete before F07 development starts
