# ISSUE-018: Spark 4.1 Spark Connect ignores properties file with spark-class

**Created:** 2026-01-20  
**Status:** Open  
**Severity:** 🔴 CRITICAL (Connect CrashLoopBackOff)  
**Feature:** F06 - Spark Connect Standalone Parity

---

## Problem Statement

Spark Connect 4.1 fails to start when using `spark-class --properties-file`.
`spark-class` treats `--properties-file` as the class name and exits:

```
Error: Could not find or load main class .tmp.spark-conf.spark-properties.conf
```

**Impact:**
- Spark Connect pod CrashLoopBackOff
- K8s backend load tests cannot run

---

## Root Cause

`spark-class` does not support `--properties-file`. Only `spark-submit` does.
Passing `--properties-file` before the class name causes the argument parsing
to treat the properties path as the class name.

---

## Reproduction

1. Deploy `charts/spark-4.1` with current `spark-class --properties-file` args.
2. Pod logs show class not found for `/tmp/spark-conf/spark-properties.conf`.

---

## Resolution

Render to `spark-defaults.conf` under `SPARK_CONF_DIR` and run `spark-class`
without `--properties-file`:

```
envsubst > /tmp/spark-conf/spark-defaults.conf
/opt/spark/bin/spark-class org.apache.spark.sql.connect.service.SparkConnectServer
```

---

## Affected Files

- `charts/spark-4.1/templates/spark-connect.yaml`

---

## Related

- `scripts/test-spark-connect-k8s-load.sh`
