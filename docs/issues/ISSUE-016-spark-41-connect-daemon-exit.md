# ISSUE-016: Spark 4.1 Spark Connect container exits immediately

**Created:** 2026-01-20  
**Status:** Open  
**Severity:** 🔴 CRITICAL (Connect CrashLoopBackOff)  
**Feature:** F06 - Spark Connect Standalone Parity

---

## Problem Statement

Spark Connect 4.1 pod repeatedly restarts with exit code 0 (Completed). The
container starts, logs a startup line, then exits immediately.

**Observed behavior:**
- Pod in CrashLoopBackOff
- Last termination reason: `Completed` (exit code 0)

**Impact:**
- Spark Connect not available
- K8s backend load tests cannot run

---

## Root Cause

The chart uses `start-connect-server.sh`, which daemonizes and exits.
In a container this causes the main process to finish, so Kubernetes restarts it.

---

## Reproduction

1. Deploy `charts/spark-4.1` with Connect enabled.
2. Pod logs show "starting SparkConnectServer" then exit.
3. Pod restarts repeatedly.

---

## Resolution

Run Spark Connect in the foreground using `spark-class`:

```
/opt/spark/bin/spark-class org.apache.spark.sql.connect.service.SparkConnectServer \
  --properties-file /tmp/spark-conf/spark-properties.conf
```

---

## Affected Files

- `charts/spark-4.1/templates/spark-connect.yaml`

---

## Related

- `scripts/test-spark-connect-k8s-load.sh`
