## WS-BUG-004: Spark 4.1 Connect Config Write Fails on Read-only ConfigMap

### 🎯 Goal

**Bug:** Spark Connect cannot write rendered configs to `/opt/spark/conf-k8s` (ConfigMap mount).  
**Expected:** Spark Connect renders configs to a writable path and starts.  
**Actual:** CrashLoopBackOff with permission denied.

**Acceptance Criteria:**
- [ ] Spark Connect uses a writable config directory
- [ ] Helm template output shows writable config path and volume
- [ ] No regression in other spark-4.1 templates
- [ ] PSS `restricted` compatibility preserved

---

### Context

**Reported by:** Runtime validation  
**Affected:** Spark 4.1 Connect server  
**Severity:** P1

**Reproduction steps:**
1. Deploy `charts/spark-4.1` with Spark Connect enabled.
2. Pod enters CrashLoopBackOff.
3. Logs show permission error on `/opt/spark/conf-k8s`.

### Root Cause Analysis

Rendered config files are written into a ConfigMap mount, which is read-only.

### Dependency

Independent (F04 chart templates only).

### Input Files

- `charts/spark-4.1/templates/spark-connect.yaml`
- `charts/spark-4.1/templates/spark-connect-configmap.yaml`
- `charts/spark-4.1/templates/executor-pod-template-configmap.yaml`

### Steps

1. Write failing check (helm template + grep for writable path)
2. Update Spark Connect template to render into writable `emptyDir`
3. Verify rendered output includes new path/volume
4. Run template sanity checks

### Expected Result

- Spark Connect uses `/tmp/spark-conf` (or equivalent writable path)
- Config templates remain sourced from ConfigMaps

### Scope Estimate

- Files: ~1-2
- Lines: ~40 (SMALL)

### Completion Criteria

```bash
# Render output must include writable config path
helm template spark-41 charts/spark-4.1 | rg "/tmp/spark-conf"

# Render sanity
helm template spark-41 charts/spark-4.1 >/dev/null
```

---

### Execution Report

**Executed by:** Auto (agent)  
**Date:** 2026-01-19

#### 🎯 Goal Status

- [x] AC1: Spark Connect uses writable config directory — ✅
- [x] AC2: Template output includes writable path and volume — ✅
- [x] AC3: No regression in spark-4.1 templates — ✅
- [x] AC4: PSS `restricted` compatibility preserved — ✅

**Goal Achieved:** ✅ YES

#### Modified Files

| File | Action | LOC |
|------|--------|-----|
| `charts/spark-4.1/templates/spark-connect.yaml` | modified | 12 |
| `docs/workstreams/backlog/WS-BUG-004-spark-41-connect-readonly-config.md` | modified | 40 |

#### Completed Steps

- [x] Step 1: Wrote failing template check for writable path
- [x] Step 2: Updated Spark Connect to render into `emptyDir`
- [x] Step 3: Verified rendered output contains `/tmp/spark-conf`
- [x] Step 4: Render sanity check

#### Self-Check Results

```bash
$ python3 - <<'PY'
import subprocess, sys
out = subprocess.check_output(['helm','template','spark-41','charts/spark-4.1'], text=True)
print('/tmp/spark-conf' in out)
PY
True

$ helm template spark-41 charts/spark-4.1 >/dev/null
```

#### Issues

- None

### Review Result

**Status:** APPROVED
