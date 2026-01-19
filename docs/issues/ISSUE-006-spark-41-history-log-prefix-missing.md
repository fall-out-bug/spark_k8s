# ISSUE-006: Spark 4.1 History Server crashes if log prefix missing

**Created:** 2026-01-19  
**Status:** Open  
**Severity:** 🔴 CRITICAL (blocks runtime tests)  
**Feature:** F04 - Spark 4.1.0 Charts

---

## Problem Statement

Spark 4.1 History Server fails to start when the configured event log
directory `s3a://spark-logs/4.1/events` does not exist.

**Observed error:**
```
java.io.FileNotFoundException: Log directory specified does not exist: s3a://spark-logs/4.1/events
```

**Impact:**
- History Server crashes (CrashLoopBackOff)
- Smoke, compatibility, and benchmark tests fail

---

## Root Cause

MinIO init job only creates `spark-logs/events/.keep`. It does not create
the versioned prefix `spark-logs/4.1/events/`, so S3A fails to resolve
the directory.

---

## Reproduction

1. Deploy `charts/spark-4.1` with default history server log directory.
2. History Server exits with FileNotFoundException.

---

## Proposed Fix

Create the versioned prefix during bucket initialization, for example:

```
echo "" | mc pipe myminio/spark-logs/4.1/events/.keep
```

Alternatively, set default log directory to `s3a://spark-logs/events`
and keep versioning outside of the path.

---

## Affected Files

- `charts/spark-base/templates/minio.yaml`
- `charts/spark-4.1/values.yaml`
- `charts/spark-4.1/templates/history-server.yaml`

---

## Related

- `scripts/test-spark-41-smoke.sh`
- `scripts/test-history-server-compat.sh`
- `scripts/benchmark-spark-versions.sh`
