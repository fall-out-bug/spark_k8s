# ISSUE-017: Spark 4.1 Spark Connect ignores properties file

**Created:** 2026-01-20  
**Status:** Resolved  
**Severity:** 🔴 CRITICAL (Connect CrashLoopBackOff)  
**Feature:** F06 - Spark Connect Standalone Parity

---

## Problem Statement

Spark Connect 4.1 starts but fails with:
```
org.apache.spark.SparkException: A master URL must be set in your configuration
```

**Impact:**
- Spark Connect pod CrashLoopBackOff
- K8s backend load tests cannot run

---

## Root Cause

The chart runs:
```
spark-class org.apache.spark.sql.connect.service.SparkConnectServer --properties-file /tmp/spark-conf/spark-properties.conf
```
`--properties-file` is passed *after* the class name, so it is treated as an
argument to the class and **ignored** by `spark-class`.

---

## Reproduction

1. Deploy `charts/spark-4.1` with `connect.backendMode=k8s`.
2. Pod logs show `A master URL must be set in your configuration`.

---

## Resolution

Pass `--properties-file` before the class name:
```
/opt/spark/bin/spark-class --properties-file /tmp/spark-conf/spark-properties.conf \
  org.apache.spark.sql.connect.service.SparkConnectServer
```

---

## Affected Files

- `charts/spark-4.1/templates/spark-connect.yaml`

---

## Related

- `scripts/test-spark-connect-k8s-load.sh`
