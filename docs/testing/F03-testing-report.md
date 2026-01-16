# F03 Testing Report

**Feature:** F03 - Spark History Server for Standalone Chart  
**Date:** 2026-01-16  
**Tester:** Auto (agent) + Runtime Validation

---

## Summary

✅ **All tests PASSED** after fixing critical MinIO directory creation issue.

---

## Issues Found & Fixed

### ISSUE-003: MinIO Events Directory Creation (CRITICAL)

**Problem:** History Server crashed with `FileNotFoundException` for `s3a://spark-logs/events`

**Root Cause:** MinIO init job used incorrect `mc mb` command to create subdirectories

**Fix:** Changed to `mc pipe` with `.keep` marker files

**Validation:** ✅ History Server starts successfully, parses event logs, serves API

**Details:** See `docs/issues/ISSUE-003-history-server-minio-dir-creation.md`

---

## Test Results

### 1. Static Validation

```bash
$ helm lint charts/spark-standalone
✅ PASSED - 1 chart(s) linted, 0 chart(s) failed

$ helm template test charts/spark-standalone --set historyServer.enabled=true | grep "spark-history-server"
✅ PASSED - Deployment and Service rendered correctly

$ helm template test charts/spark-standalone --set historyServer.enabled=false | grep "spark-history-server"
✅ PASSED - Not rendered when disabled (0 matches)
```

### 2. Runtime Validation (Minikube)

**Configuration:**
- `historyServer.enabled=true`
- Minimal stack (no Airflow/MLflow/Hive)
- Minikube single-node cluster

**Pod Status:**
```bash
$ kubectl get pods -n spark-sa
NAME                                                        READY   STATUS      RESTARTS   AGE
minio-6c544c6485-f4fch                                      1/1     Running     0          66s
minio-init-buckets-4kx5s                                    0/1     Completed   0          52s
spark-sa-spark-standalone-history-server-57bf54c97f-4bsxc   1/1     Running     0          66s
spark-sa-spark-standalone-master-6ccd9594cc-kvvzk           1/1     Running     0          66s
spark-sa-spark-standalone-shuffle-rbgjv                     1/1     Running     0          66s
spark-sa-spark-standalone-worker-fbb4748dc-8zv7q            1/1     Running     0          66s
spark-sa-spark-standalone-worker-fbb4748dc-gbnhd            1/1     Running     0          66s
```

✅ All pods Running or Completed

**Smoke Test:**
```bash
$ scripts/test-spark-standalone.sh spark-sa spark-sa
=== Testing Spark Standalone Chart (spark-sa in spark-sa) ===
1) Checking pods are ready...               ✅ OK
2) Checking Spark Master UI responds...     ✅ OK
3) Checking at least 1 worker registered... ✅ OK
4) Running SparkPi via spark-submit...      ✅ OK
5) Checking Airflow and MLflow...           ✅ OK (not deployed)
6) Checking History Server...               ✅ OK
   ✓ History Server shows 1 application(s)
=== Done ===
```

### 3. History Server API Validation

**Query:** `GET /api/v1/applications`

**Response:**
```json
[
    {
        "id": "app-20260116130640-0000",
        "name": "Spark Pi",
        "attempts": [
            {
                "startTime": "2026-01-16T13:06:39.574GMT",
                "endTime": "2026-01-16T13:06:45.527GMT",
                "lastUpdated": "2026-01-16T13:06:45.841GMT",
                "duration": 5953,
                "sparkUser": "spark",
                "completed": true,
                "appSparkVersion": "3.5.7",
                ...
            }
        ]
    }
]
```

✅ Application visible in History Server  
✅ Complete job details available (start/end times, duration, user)  
✅ Status: `completed: true`

### 4. S3 Event Logs Validation

**Check:** Verify event logs written to S3

**MinIO init job output:**
```
Bucket created successfully `myminio/spark-logs`.
Bucket created successfully `myminio/spark-logs/events/.keep`.
```

✅ Buckets created  
✅ Directory markers (`.keep`) created  
✅ SparkPi event logs written to `s3a://spark-logs/events`

### 5. PSS Compatibility

**Configuration:** `security.podSecurityStandards=true` (default)

**Pod Security Context:**
```yaml
securityContext:
  runAsNonRoot: true
  seccompProfile:
    type: RuntimeDefault

containerSecurityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
      - ALL
```

✅ History Server pod runs with PSS `restricted` compatible security contexts  
✅ EmptyDir mounts for writable paths (`/tmp`)

---

## Acceptance Criteria Status

### WS-012-01: History Server Template
- ✅ AC1: `helm template` renders history-server Deployment/Service when enabled
- ✅ AC2: History Server pod starts without errors
- ✅ AC3: UI accessible on port 18080 via port-forward
- ✅ AC4: `helm lint` passes

### WS-012-02: History Server Smoke Test
- ✅ AC1: `test-spark-standalone.sh` includes History Server health check
- ✅ AC2: Script verifies History Server API returns completed applications
- ✅ AC3: Test passes on Minikube with `historyServer.enabled=true`

---

## Commit History

```
af53cd0 docs(history-server): add ISSUE-003 for MinIO directory fix
a00a959 fix(history-server): correct MinIO events directory creation
a91cdb4 docs(history-server): F03 review complete - APPROVED
e9fbf05 test(history-server): WS-012-02 - add History Server smoke test
56bcd4f feat(history-server): WS-012-01 - add History Server template
f2afdc8 docs(history-server): create WS specifications for F03
```

---

## Known Limitations

1. **Full stack deployment:** When deploying with Airflow + MLflow + Hive + History Server, minikube single-node may run out of CPU. For full stack testing, use multi-node cluster or reduce resource requests.

2. **Log parsing delay:** History Server may take 10-30 seconds to parse event logs from S3 after application completes. The smoke test shows warning if logs not yet parsed, which is expected behavior.

3. **S3A connectivity:** History Server requires proper S3 endpoint and credentials configuration. Ensure MinIO or external S3 is accessible before enabling History Server.

---

## Recommendations

1. ✅ **Feature F03 is ready for production** with minimal stack (Spark Master/Workers + History Server)

2. **For full stack:** Increase minikube resources or use multi-node cluster:
   ```bash
   minikube start --cpus=8 --memory=16384 --disk-size=50g
   ```

3. **Monitor:** Check History Server logs for S3 connectivity issues:
   ```bash
   kubectl logs -n <namespace> -l app=spark-history-server --tail=50
   ```

---

## Next Steps

- ✅ Feature F03 APPROVED
- ✅ All tests passed
- ✅ Critical issue fixed and documented
- ✅ Ready for merge to main branch

**Merge command:**
```bash
git checkout main
git merge feature/history-server-sa
git push origin main
```
