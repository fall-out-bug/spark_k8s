## WS-BUG-006: Spark 4.1 History Log Prefix Missing

### 🎯 Goal

**Bug:** History Server crashes when `s3a://spark-logs/4.1/events` does not exist.  
**Expected:** MinIO init creates required prefix so History Server starts.  
**Actual:** CrashLoopBackOff with FileNotFoundException.

**Acceptance Criteria:**
- [ ] MinIO init creates `spark-logs/4.1/events/.keep`
- [ ] Helm template output includes the new prefix creation
- [ ] No regression in MinIO init job
- [ ] PSS `restricted` compatibility preserved

---

### Context

**Reported by:** Runtime validation  
**Affected:** Spark 4.1 History Server  
**Severity:** P1

**Reproduction steps:**
1. Deploy `charts/spark-4.1` with default history server log directory.
2. History Server exits with FileNotFoundException.

### Root Cause Analysis

MinIO init only creates `spark-logs/events/.keep`, not the versioned prefix
`spark-logs/4.1/events/.keep`.

### Dependency

Independent (spark-base MinIO init).

### Input Files

- `charts/spark-base/templates/minio.yaml`

### Steps

1. Write failing check (helm template + grep for `/4.1/events`)
2. Add versioned prefix creation for `spark-logs/4.1/events`
3. Verify rendered output contains the new command
4. Run template sanity checks

### Expected Result

- MinIO init job creates `spark-logs/4.1/events/.keep`

### Completion Criteria

```bash
# Render output must include versioned prefix creation
helm template spark-base charts/spark-base \
  --set minio.enabled=true \
  --set "minio.buckets[0]=spark-logs" | rg "spark-logs/4.1/events"

# Render sanity
helm template spark-base charts/spark-base \
  --set minio.enabled=true \
  --set "minio.buckets[0]=spark-logs" >/dev/null
```

---

### Execution Report

**Executed by:** Auto (agent)  
**Date:** 2026-01-19

#### 🎯 Goal Status

- [x] AC1: MinIO init creates `spark-logs/4.1/events/.keep` — ✅
- [x] AC2: Template output includes new prefix creation — ✅
- [x] AC3: No regression in MinIO init job — ✅
- [x] AC4: PSS `restricted` compatibility preserved — ✅

**Goal Achieved:** ✅ YES

#### Modified Files

| File | Action | LOC |
|------|--------|-----|
| `charts/spark-base/templates/minio.yaml` | modified | 1 |
| `docs/workstreams/backlog/WS-BUG-006-history-log-prefix.md` | modified | 40 |

#### Completed Steps

- [x] Step 1: Wrote failing template check for versioned prefix
- [x] Step 2: Added `spark-logs/4.1/events/.keep` creation
- [x] Step 3: Verified rendered output contains new command
- [x] Step 4: Render sanity check

#### Self-Check Results

```bash
$ python3 - <<'PY'
import subprocess, sys
out = subprocess.check_output([
    'helm','template','spark-base','charts/spark-base',
    '--set','minio.enabled=true',
    '--set','minio.buckets[0]=spark-logs'
], text=True)
print('spark-logs/4.1/events' in out)
PY
True

$ helm template spark-base charts/spark-base \
  --set minio.enabled=true \
  --set "minio.buckets[0]=spark-logs" >/dev/null
```

#### Issues

- None

### Review Result

**Status:** APPROVED
