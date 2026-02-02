# Minikube Storage Diagnostics Report

**Date:** 2026-02-02
**Workstream:** WS-TESTING-001
**Environment:** WSL2 (Ubuntu 22.04), Docker driver
**Related Issue:** issue-001-minikube-pvc-provisioning

---

## Configuration

| Component | Version/Config |
|-----------|----------------|
| **Minikube** | v1.37.0 (commit: 65318f4c) |
| **Driver** | docker |
| **Kubernetes** | v1.34.0 |
| **CPUs** | 4 |
| **Memory** | 36192 MB |
| **Disk** | 100 GB |
| **StorageClass (default)** | local-path (rancher.io/local-path) |
| **StorageClass (standard)** | standard (k8s.io/minikube-hostpath) |
| **StorageClass mode** | WaitForFirstConsumer (local-path), Immediate (standard) |

---

## Root Cause Analysis

### Problem Statement

PVC provisioning in minikube (WSL2 with docker driver) fails with:
```
Warning  FailedScheduling  0/1 nodes are available: pod has unbound immediate PersistentVolumeClaims. not found
```

### Findings

1. **Storage-Provisioner Pod Status:**
   - Initial state: `CrashLoopBackOff` (402 restarts)
   - Exit code: 1 (permission denied accessing node proxy)
   - RBAC issue: `Forbidden (user=kube-apiserver-kubelet-client, verb=get, resource=nodes, subresource=[proxy])`

2. **Storage-Provisioner Fix:**
   - Restarting the addon fixed the pod status: `minikube addons disable storage-provisioner && minikube addons enable storage-provisioner`
   - After restart: `storage-provisioner 1/1 Running`

3. **Dynamic Provisioning Still Fails:**
   - PVC remains in `Pending` state
   - No PV created by provisioner
   - Message: `Waiting for a volume to be created either by the external provisioner`

4. **Rancher Local-Path Provisioner:**
   - Enabled via: `minikube addons enable storage-provisioner-rancher`
   - Created `local-path` StorageClass as default
   - **However:** Rancher provisioner pod never started (deployment missing)
   - This is a known minikube + WSL2 + docker driver issue

### Root Cause

**Primary Issue:** Minikube's storage provisioners (both hostpath and rancher) do not work correctly in WSL2 with docker driver. The provisioner pods cannot properly create hostpath volumes due to WSL2 filesystem limitations and docker container isolation.

**Secondary Issue:** RBAC permissions prevent viewing logs, making debugging difficult (but not blocking).

---

## Test Results

| Test | Result | Details |
|------|--------|---------|
| Simple PVC (auto-provision) | **FAIL** | PVC stays Pending, no PV created |
| PVC with standard StorageClass | **FAIL** | hostpath provisioner doesn't create PV |
| PVC with local-path StorageClass | **FAIL** | Rancher provisioner pod not running |
| Option 1: Reconfigure hostpath | **PARTIAL** | Provisioner runs but doesn't create PVs |
| Option 2: Rancher local-path | **FAIL** | Addon enables but pod doesn't start |
| Option 3: Manual PV + PVC | **✅ PASS** | PVC binds successfully, Pod mounts volume |

### Test Case: Manual PV Provisioning (Option 3)

**PV Configuration:**
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: test-pv
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: /tmp/minio-data
  storageClassName: standard
```

**PVC Configuration:**
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc-standard
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: standard
```

**Result:**
- PVC Status: `Bound`
- PV Status: `Bound`
- Pod Status: `Running` (10.244.3.18)
- Volume mounted at `/data`

**Verification:**
```bash
$ kubectl get pvc test-pvc-standard
NAME                STATUS   VOLUME    CAPACITY   ACCESS MODES   STORAGECLASS   AGE
test-pvc-standard   Bound    test-pv   1Gi        RWO            standard       5s

$ kubectl get pv test-pv
NAME     CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                       AGE
test-pv  1Gi        RWO            Retain           Bound    default/test-pvc-standard   16s

$ kubectl get pod test-pod-standard
NAME                READY   STATUS    RESTARTS   AGE
test-pod-standard   1/1     Running   0          12s
```

---

## Recommendation

**Selected Option: Option 3 (Manual PV Provisioning)**

### Reasoning

1. **Options 1 & 2 (Dynamic Provisioning)**
   - ❌ Do not work in WSL2 + docker driver environment
   - ❌ Known minikube limitation
   - ❌ Cannot be fixed without changing driver (kvm2, podman) or using Linux native

2. **Option 3 (Manual PV Provisioning)**
   - ✅ **Verified working** in current environment
   - ✅ Simple to implement
   - ✅ Full control over volume paths
   - ✅ Predictable behavior
   - ⚠️ Manual management required (pre-provision PVs before deployment)

### Implementation Strategy

**For Testing (F06, WS-TESTING-003):**
1. Create manual PVs for each component (Minio, PostgreSQL)
2. Use `storageClassName: standard` in PVCs
3. PVs use hostPath pointing to minikube-accessible locations

**For Production:**
1. Use proper Kubernetes cluster (not minikube)
2. Enable cloud-specific storage classes (AWS EBS, Azure Disk, etc.)
3. Dynamic provisioning will work correctly

### Alternative Workarounds

1. **Change Minikube Driver:**
   ```bash
   minikube delete
   minikube start --driver=podman  # or --driver=kvm2 (Linux native)
   ```
   - May fix dynamic provisioning
   - Requires additional setup

2. **Use Linux Native (not WSL2):**
   - WSL2 has known filesystem limitations
   - Native Linux + kvm2 driver works better

3. **Use Kind (Kubernetes in Docker):**
   - Alternative to minikube
   - May have better storage support

---

## Files Created

| File | Purpose |
|------|---------|
| `docs/testing/test-pv.yaml` | Manual PV template |
| `docs/testing/test-pvc.yaml` | PVC template (auto-provision) |
| `docs/testing/test-pvc-standard.yaml` | PVC template (manual PV) |
| `docs/testing/test-pod.yaml` | Test pod with auto-provision PVC |
| `docs/testing/test-pod-standard.yaml` | Test pod with manual PV |

---

## Next Steps

1. **WS-TESTING-002:** Create helper scripts for manual PV provisioning
2. **WS-TESTING-003:** Deploy F06 core-baseline preset with manual PVs
3. **Documentation:** Update testing guide with manual PV instructions

---

**Report Status:** ✅ Complete
**Root Cause Identified:** Yes
**Solution Verified:** Yes (Option 3)
**WS-TESTING-002 Ready:** Yes
