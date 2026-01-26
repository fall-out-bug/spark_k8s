# ISSUE-022: Spark 4.1 Connect fails when event log prefix is missing

**Created:** 2026-01-20  
**Status:** Open  
**Severity:** 🔴 CRITICAL (Connect CrashLoopBackOff)  
**Feature:** F06 - Spark Connect Standalone Parity

---

## Problem Statement

Spark Connect 4.1 fails with:
```
java.io.FileNotFoundException: No such file or directory: s3a://spark-logs/4.1/events
```

**Impact:**
- Spark Connect CrashLoopBackOff
- K8s backend load tests cannot run

---

## Root Cause

`spark-logs/4.1/events` prefix does not exist in MinIO or S3. Spark 4.1 requires
the event log directory to exist before starting.

---

## Reproduction

1. Deploy `charts/spark-4.1` with default history log directory.
2. Spark Connect fails on startup due to missing S3 prefix.

---

## Resolution

Create the prefix (directory marker) during bucket initialization:
```
echo "" | mc pipe myminio/spark-logs/4.1/events/.keep
```

---

## Affected Files

- `charts/spark-base/templates/minio.yaml` (or any MinIO init)
- `charts/spark-4.1/values.yaml`

---

## Related

- `scripts/test-spark-connect-k8s-load.sh`
