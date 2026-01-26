# ISSUE-013: Spark Connect MinIO init job does not create events prefix

**Created:** 2026-01-20  
**Status:** Open  
**Severity:** 🔴 CRITICAL (Connect init stuck, load tests blocked)  
**Feature:** F06 - Spark Connect Standalone Parity

---

## Problem Statement

Spark Connect pods wait for `s3://spark-logs/events` to exist, but the MinIO
init job in `charts/spark-3.5/charts/spark-connect` uses `mc mb` to create
`spark-logs/events` which is invalid for subdirectories. As a result, the
init container waits and retries until timeout.

**Observed error (init container):**
```
Timeout waiting for MinIO buckets
```

**Impact:**
- Spark Connect pods stuck in `Init:0/1`
- Load tests cannot start

---

## Root Cause

`mc mb` is for buckets, not prefixes. The job attempts:
```
mc mb --ignore-existing myminio/spark-logs/events
```
which does not create the `spark-logs/events/` prefix required by S3A.

---

## Reproduction

1. Deploy `charts/spark-3.5/charts/spark-connect` with `minio.enabled=true`.
2. Spark Connect init container waits for `spark-logs/events` indefinitely.

---

## Resolution

Create a directory marker via `mc pipe`:
```
echo "" | mc pipe myminio/spark-logs/events/.keep
```

---

## Affected Files

- `charts/spark-3.5/charts/spark-connect/templates/minio.yaml`

---

## Related

- `scripts/test-spark-connect-k8s-load.sh`
- `scripts/test-spark-connect-standalone-load.sh`
