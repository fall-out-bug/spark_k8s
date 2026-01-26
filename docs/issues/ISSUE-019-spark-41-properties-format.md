# ISSUE-019: Spark 4.1 Spark Connect config uses non‑properties format

**Created:** 2026-01-20  
**Status:** Open  
**Severity:** 🔴 CRITICAL (master not set)  
**Feature:** F06 - Spark Connect Standalone Parity

---

## Problem Statement

Spark Connect 4.1 fails with:
```
org.apache.spark.SparkException: A master URL must be set in your configuration
```

**Impact:**
- Spark Connect pod CrashLoopBackOff
- K8s backend load tests cannot run

---

## Root Cause

`spark-defaults.conf` is rendered with space‑separated `key value` entries.
When loaded by Spark via `SPARK_CONF_DIR`, the master URL is not recognized.

---

## Reproduction

1. Deploy `charts/spark-4.1` with Connect enabled.
2. Pod logs show "A master URL must be set".

---

## Resolution

Render configuration in standard properties format `key=value`:

```
spark.master=k8s://...
spark.kubernetes.namespace=...
```

---

## Affected Files

- `charts/spark-4.1/templates/spark-connect-configmap.yaml`

---

## Related

- `scripts/test-spark-connect-k8s-load.sh`
