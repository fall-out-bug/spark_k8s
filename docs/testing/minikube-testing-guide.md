# Minikube Testing Guide

**For:** Spark on Kubernetes testing in minikube (WSL2 environment)
**Related:** issue-001, WS-TESTING-001, WS-TESTING-002

---

## Problem: PVC Provisioning in Minikube (WSL2)

Dynamic PVC provisioning doesn't work in minikube when using WSL2 + docker driver due to filesystem limitations.

**Symptoms:**
- PVCs remain in `Pending` state
- Pods fail to schedule with "unbound immediate PersistentVolumeClaims"
- storage-provisioner pod in CrashLoopBackOff

**Solution:** Manual PV provisioning (verified working)

---

## Quick Start

### 1. Setup Manual PVs

```bash
# Run setup script
./scripts/testing/setup-manual-pvs.sh

# Or with custom namespace/storage
./scripts/testing/setup-manual-pvs.sh spark-test /custom/path
```

**Creates:**
- `minio-pv` (10Gi) - for Minio S3-compatible storage
- `postgresql-pv` (5Gi) - for PostgreSQL database

### 2. Deploy Spark Chart

```bash
# Deploy with core-baseline preset
helm install spark charts/spark-4.1 \
  -f charts/spark-4.1/presets/core-baseline.yaml \
  --namespace spark-test \
  --create-namespace

# PVCs will automatically bind to the manual PVs
```

### 3. Verify Deployment

```bash
# Check PVCs are bound
kubectl get pvc -n spark-test

# Check pods are running
kubectl get pods -n spark-test

# Check PVs are bound
kubectl get pv
```

### 4. Cleanup

```bash
# Uninstall chart
helm uninstall spark -n spark-test

# Delete namespace
kubectl delete namespace spark-test

# Cleanup PVs
./scripts/testing/cleanup-manual-pvs.sh
```

---

## PV Sizing for Components

| Component | PV Name | Size | Purpose |
|-----------|---------|------|---------|
| Minio | minio-pv | 10Gi | Event logs, warehouse, checkpoints |
| PostgreSQL | postgresql-pv | 5Gi | Hive Metastore database |
| Jupyter | - | - | No storage needed (ephemeral) |
| History Server | - | - | Uses Minio via S3 |

---

## Manual PV Details

### Minio PV

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: minio-pv
  labels:
    app.kubernetes.io/component: minio
    app.kubernetes.io/testing: "true"
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: standard
  hostPath:
    path: /tmp/spark-testing/minio
    type: DirectoryOrCreate
```

### PostgreSQL PV

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: postgresql-pv
  labels:
    app.kubernetes.io/component: postgresql
    app.kubernetes.io/testing: "true"
spec:
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: standard
  hostPath:
    path: /tmp/spark-testing/postgresql
    type: DirectoryOrCreate
```

---

## Troubleshooting

### PV Not Binding to PVC

**Check PV status:**
```bash
kubectl get pv minio-pv -o yaml
```

**Common issues:**
1. **PV already bound:** Delete and recreate
   ```bash
   kubectl delete pv minio-pv
   ./scripts/testing/setup-manual-pvs.sh
   ```

2. **StorageClass mismatch:** Ensure PVC uses `storageClassName: standard`

3. **AccessMode mismatch:** PV must be `ReadWriteOnce`

### Pods Not Starting

**Check pod status:**
```bash
kubectl describe pod <pod-name> -n spark-test
```

**Common issues:**
1. **PVC pending:** Verify PVs exist and are Available
2. **Node selector:** Ensure pods can schedule to minikube node
3. **Image pull:** Check images are available (might need pre-load)

### Cleanup Issues

**Force delete PVs:**
```bash
kubectl patch pv minio-pv -p '{"metadata":{"finalizers":null}}'
kubectl delete pv minio-pv
```

**Clean minikube storage:**
```bash
minikube ssh "rm -rf /tmp/spark-testing"
```

---

## Production Deployment

**This manual PV approach is for TESTING ONLY.**

For production, use:
- **AWS EBS:** `storageClassName: gp3`
- **Azure Disk:** `storageClassName: managed-premium`
- **GCE PD:** `storageClassName: standard-rwo`
- **On-prem:** Ceph, NFS, or other CSI drivers

Dynamic provisioning works correctly in production clusters.

---

## Alternative Workarounds

If manual PVs don't work for your environment:

### Option 1: Change Minikube Driver

```bash
minikube delete
minikube start --driver=podman  # or --driver=kvm2 (Linux native)
```

### Option 2: Use Kind (Kubernetes in Docker)

```bash
kind create cluster
# Kind has better storage support
```

### Option 3: Use Minikube with Podman

```bash
minikube start --driver=podman --container-runtime=podman
```

---

## References

- **Diagnostics Report:** `docs/testing/minikube-storage-diagnostics.md`
- **Issue:** issue-001-minikube-pvc-provisioning.md
- **Workstreams:** WS-TESTING-001, WS-TESTING-002

---

**Last Updated:** 2026-02-02
**Tested on:** Minikube v1.37.0, WSL2 (Ubuntu 22.04), Docker driver
