# ISSUE-015: Spark 4.1 executor pod template path mismatch

**Created:** 2026-01-20  
**Status:** Open  
**Severity:** 🔴 CRITICAL (Connect crashloop)  
**Feature:** F06 - Spark Connect Standalone Parity

---

## Problem Statement

Spark Connect 4.1 renders `executor-pod-template.yaml` into `/tmp/spark-conf`,
but `spark.kubernetes.executor.podTemplateFile` points to
`/opt/spark/conf-k8s/executor-pod-template.yaml`, which does not exist.

**Impact:**
- Spark Connect fails to start in K8s executors mode
- Pod CrashLoopBackOff

---

## Root Cause

Template rendering path and Spark configuration path are inconsistent.

---

## Reproduction

1. Deploy `charts/spark-4.1` with `connect.backendMode=k8s`.
2. Spark Connect pod CrashLoopBackOff.
3. Logs indicate missing executor pod template file.

---

## Resolution

Update `spark.kubernetes.executor.podTemplateFile` to point to the rendered path:
```
/tmp/spark-conf/executor-pod-template.yaml
```

---

## Affected Files

- `charts/spark-4.1/templates/spark-connect-configmap.yaml`

---

## Related

- `scripts/test-spark-connect-k8s-load.sh`
