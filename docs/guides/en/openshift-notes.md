# OpenShift Compatibility Notes

**Tested on:** Minikube  
**Prepared for:** OpenShift-like constraints (PSS `restricted` / SCC `restricted`)

## Overview

The charts in this repository are **prepared** for OpenShift-like security constraints (Pod Security Standards `restricted` / SecurityContextConstraints `restricted`), but have been **tested only on Minikube**.

## Security Hardening

### Pod Security Standards (PSS) `restricted`

When `security.podSecurityStandards: true` in values, the charts enforce PSS `restricted`-compatible settings:

- **`runAsNonRoot: true`** — Pods run as non-root user
- **`seccompProfile.type: RuntimeDefault`** — Default seccomp profile
- **`allowPrivilegeEscalation: false`** — No privilege escalation
- **`capabilities.drop: ALL`** — All capabilities dropped
- **`readOnlyRootFilesystem: true`** — Root filesystem is read-only (writable paths mounted via `emptyDir`/PVC)

### What Is Configurable

#### PostgreSQL Relaxation

Embedded PostgreSQL (for Hive Metastore, Airflow, MLflow) can run in "relaxed" mode for local testing:

```yaml
security:
  podSecurityStandards: true
  postgresql:
    relaxed: true  # Allows postgres to run with relaxed PSS (for local/test only)
```

**Note:** In production, use an external PostgreSQL database. The embedded PostgreSQL is intended for local/test environments only.

#### User/Group IDs

You can configure UID/GID for pods:

```yaml
security:
  podSecurityStandards: true
  runAsUser: 1000
  runAsGroup: 1000
  fsGroup: 1000
```

Adjust these values to match your OpenShift cluster's requirements.

## What Was Tested

### Tested on Minikube

- Spark Standalone cluster (master + workers) with PSS hardening enabled
- Airflow with KubernetesExecutor (PSS-hardened pods)
- SparkPi job execution
- Airflow DAG runs (`example_bash_operator`, `spark_etl_synthetic`)
- MinIO bucket initialization
- Spark Master HA with PVC-backed recovery

### Not Validated on OpenShift

The following have **not** been validated on a real OpenShift cluster:

- SCC `restricted` enforcement (only PSS emulation tested)
- OpenShift-specific network policies
- OpenShift route configuration (Ingress is generic)
- OpenShift image streams (charts use standard Docker images)
- OpenShift service mesh integration (if enabled)

## Known Limitations

### PostgreSQL Image Compatibility

The official `postgres:16-alpine` image is not fully compatible with strict PSS `restricted` in many setups. The chart provides a "relaxed" mode for embedded PostgreSQL:

```yaml
security:
  postgresql:
    relaxed: true  # Recommended for local/test
```

**Production recommendation:** Use an external PostgreSQL database managed by your platform team.

### Storage Classes

The charts use default StorageClass for PVCs. In OpenShift, you may need to:

1. Specify a StorageClass explicitly:
```yaml
sparkMaster:
  ha:
    persistence:
      storageClass: "gp3"  # Example: AWS EBS
```

2. Ensure the StorageClass exists and is accessible in your namespace.

### ServiceAccount Permissions

The charts create a ServiceAccount with RBAC permissions for:
- Creating/deleting pods (for Spark executors, Airflow workers)
- Reading ConfigMaps/Secrets

In OpenShift, ensure your namespace has sufficient permissions or adjust RBAC as needed.

## Deployment Checklist for OpenShift

Before deploying to OpenShift:

- [ ] Review and adjust `security.runAsUser`/`runAsGroup`/`fsGroup` to match your cluster
- [ ] Set `security.postgresql.relaxed: false` if using embedded PostgreSQL (or use external DB)
- [ ] Configure StorageClass for PVCs (Spark Master HA, MinIO, PostgreSQL)
- [ ] Verify ServiceAccount has required permissions
- [ ] Test in a non-production namespace first
- [ ] Review network policies (if enabled in your cluster)

## Troubleshooting

### Pods Stuck in `Pending`

**Check:**
```bash
kubectl describe pod <pod-name> -n <namespace>
```

**Common causes:**
- StorageClass not available
- Insufficient resources (CPU/memory)
- SecurityContext violations (check SCC/PSS)

### Permission Denied Errors

**Symptoms:** `Operation not permitted`, `Permission denied`

**Check:**
```bash
# Verify security context
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.spec.securityContext}'

# Check SCC (OpenShift)
oc describe scc restricted
```

**Fix:** Adjust `security.runAsUser`/`runAsGroup` or use `security.postgresql.relaxed: true` for embedded PostgreSQL.

## Reference

- **Validation guide:** [`docs/guides/en/validation.md`](validation.md)
- **Chart guides:** [`docs/guides/en/charts/`](charts/)
- **Repository map:** [`docs/PROJECT_MAP.md`](../../PROJECT_MAP.md)
