# ISSUE-003: History Server MinIO Events Directory Creation

**Created:** 2026-01-16  
**Status:** Resolved  
**Severity:** 🔴 CRITICAL (blocking feature)  
**Feature:** F03 - Spark History Server for Standalone Chart

---

## Problem Statement

During runtime validation (UAT testing) of Feature F03, the Spark History Server pod was in CrashLoopBackOff state with the following error:

```
Exception in thread "main" java.io.FileNotFoundException: Log directory specified does not exist: s3a://spark-logs/events
	at org.apache.spark.deploy.history.FsHistoryProvider.startPolling(FsHistoryProvider.scala:270)
Caused by: java.io.FileNotFoundException: No such file or directory: s3a://spark-logs/events
	at org.apache.hadoop.fs.s3a.S3AFileSystem.s3GetFileStatus(S3AFileSystem.java:4156)
```

**Impact:**
- History Server could not start
- No way to view completed Spark application details
- Feature F03 completely blocked

---

## Root Cause

The MinIO bucket initialization job (`charts/spark-standalone/templates/minio.yaml`) was using an incorrect command to create S3 subdirectories:

```bash
# INCORRECT (from WS-012-01):
mc mb --ignore-existing myminio/spark-logs/events
mc mb --ignore-existing myminio/spark-standalone-logs/events
```

**Problem:** `mc mb` is for creating buckets, not subdirectories. The command `mc mb myminio/spark-logs/events` attempts to create a bucket named `spark-logs/events`, which is invalid (bucket names cannot contain `/`). Even if it succeeded, it would create a bucket, not a prefix/directory within an existing bucket.

S3A FileSystem expects a "directory marker" (an empty object with key ending in `/`) to recognize directories. Without this marker, `S3AFileSystem.getFileStatus()` throws `FileNotFoundException`.

---

## Solution

Replace `mc mb` with `mc pipe` to create empty objects as directory markers:

```bash
# CORRECT:
echo "" | mc pipe myminio/spark-logs/events/.keep
echo "" | mc pipe myminio/spark-standalone-logs/events/.keep
```

This creates:
- Object: `spark-logs/events/.keep` (0 bytes)
- Object: `spark-standalone-logs/events/.keep` (0 bytes)

These `.keep` files act as directory markers that S3AFileSystem can recognize.

---

## Testing

### Before Fix
```bash
$ kubectl logs -n spark-sa -l app=spark-history-server
Exception in thread "main" java.io.FileNotFoundException: Log directory specified does not exist: s3a://spark-logs/events

$ kubectl get pods -n spark-sa | grep history
spark-sa-spark-standalone-history-server-57bf54c97f-wwmqx   0/1     Error       2 (31s ago)   56s
```

### After Fix
```bash
$ kubectl logs -n spark-sa -l app=spark-history-server
Starting Spark History Server...
# (no errors)

$ kubectl get pods -n spark-sa | grep history
spark-sa-spark-standalone-history-server-57bf54c97f-zpmph   1/1     Running     0   103s

$ curl -s http://localhost:18080/api/v1/applications | python3 -m json.tool
[
    {
        "id": "app-20260116125042-0000",
        "name": "Spark Pi",
        "attempts": [
            {
                "completed": true,
                ...
            }
        ]
    }
]
```

### Smoke Test Result
```bash
$ scripts/test-spark-standalone.sh spark-sa spark-sa
...
6) Checking History Server (if deployed)...
   ✓ History Server shows 2 application(s)
   OK
=== Done ===
```

---

## Files Modified

- `charts/spark-standalone/templates/minio.yaml` (lines 169-170)

---

## Prevention

**For future WS:**
- Always test MinIO bucket/directory creation in runtime validation (not just `helm lint`)
- Document S3A directory marker requirements in comments
- Add explicit test case: "History Server starts without FileNotFoundException"

---

## Related

- **Feature:** F03 - Spark History Server for Standalone Chart
- **Workstream:** WS-012-01, WS-012-02
- **Commit:** `a00a959` - fix(history-server): correct MinIO events directory creation

---

## Status

**Resolved:** 2026-01-16

Fix committed and validated:
- History Server pod runs successfully (1/1 Running)
- Event logs written to S3 and parsed by History Server
- API returns completed applications
- Smoke test passes with all checks OK
