# ISSUE-020: Spark 4.1 Connect needs spark-submit for config loading

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
- Spark Connect CrashLoopBackOff
- K8s backend load tests cannot run

---

## Root Cause

Launching via `spark-class` does not load `spark-defaults.conf` from
`SPARK_CONF_DIR`, so `spark.master` is missing.

---

## Reproduction

1. Deploy `charts/spark-4.1` with Connect enabled.
2. Pod logs show “A master URL must be set”.

---

## Resolution

Use `spark-submit` with `--properties-file` and the Spark Connect jar:

```
/opt/spark/bin/spark-submit \
  --class org.apache.spark.sql.connect.service.SparkConnectServer \
  --properties-file /tmp/spark-conf/spark-defaults.conf \
  local:///opt/spark/jars/spark-connect_2.13-4.1.0.jar
```

---

## Affected Files

- `charts/spark-4.1/templates/spark-connect.yaml`

---

## Related

- `scripts/test-spark-connect-k8s-load.sh`
