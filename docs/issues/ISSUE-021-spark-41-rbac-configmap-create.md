# ISSUE-021: Spark 4.1 Connect lacks RBAC for configmap creation

**Created:** 2026-01-20  
**Status:** Open  
**Severity:** 🔴 CRITICAL (Connect CrashLoopBackOff)  
**Feature:** F06 - Spark Connect Standalone Parity

---

## Problem Statement

Spark Connect 4.1 crashes with:
```
configmaps is forbidden: User "system:serviceaccount:<ns>:spark-41" cannot create resource "configmaps"
```

**Impact:**
- Spark Connect CrashLoopBackOff
- K8s executors mode cannot run

---

## Root Cause

`charts/spark-4.1/templates/rbac.yaml` grants only `get/list` on configmaps.
Spark Connect requires create/update/delete for driver/executor configmaps.

---

## Reproduction

1. Deploy `charts/spark-4.1` with `connect.backendMode=k8s`.
2. Spark Connect pod crashes with RBAC 403 for configmaps.

---

## Resolution

Extend RBAC permissions for configmaps:

```
verbs: ["create", "get", "list", "watch", "delete", "patch", "update"]
```

---

## Affected Files

- `charts/spark-4.1/templates/rbac.yaml`

---

## Related

- `scripts/test-spark-connect-k8s-load.sh`
