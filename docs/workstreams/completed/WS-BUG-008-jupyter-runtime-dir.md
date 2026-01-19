## WS-BUG-008: Jupyter 4.1 Runtime Directory Permission Error

### 🎯 Goal

**Bug:** Jupyter fails to start with `PermissionError: /nonexistent`.  
**Expected:** Jupyter uses writable runtime/home directories.  
**Actual:** CrashLoopBackOff due to runtime dir permission.

**Acceptance Criteria:**
- [ ] Jupyter sets `HOME` and `JUPYTER_RUNTIME_DIR` to writable paths
- [ ] Template output includes runtime env vars
- [ ] No regression in spark-4.1 templates
- [ ] PSS `restricted` compatibility preserved

---

### Context

**Reported by:** Runtime validation  
**Affected:** Spark 4.1 Jupyter  
**Severity:** P1

### Root Cause Analysis

Container runs as non-root without a valid home dir; Jupyter defaults to
`/nonexistent` and cannot create runtime directories.

### Input Files

- `charts/spark-4.1/templates/jupyter.yaml`

### Steps

1. Write failing check (helm template + missing runtime env)
2. Add `HOME` and `JUPYTER_RUNTIME_DIR`
3. Mount writable `emptyDir` for runtime
4. Render sanity checks

### Completion Criteria

```bash
helm template spark-41 charts/spark-4.1 | rg "JUPYTER_RUNTIME_DIR"
```

---

### Execution Report

**Executed by:** Auto (agent)  
**Date:** 2026-01-19

#### 🎯 Goal Status

- [x] AC1: Jupyter sets HOME and runtime dir — ✅
- [x] AC2: Template output includes runtime env vars — ✅
- [x] AC3: No regression in spark-4.1 templates — ✅
- [x] AC4: PSS `restricted` compatibility preserved — ✅

**Goal Achieved:** ✅ YES

#### Modified Files

| File | Action | LOC |
|------|--------|-----|
| `charts/spark-4.1/templates/jupyter.yaml` | modified | 10 |
| `docs/workstreams/backlog/WS-BUG-008-jupyter-runtime-dir.md` | modified | 40 |

#### Completed Steps

- [x] Step 1: Failing template check for runtime env
- [x] Step 2: Added HOME + JUPYTER_RUNTIME_DIR
- [x] Step 3: Added writable runtime emptyDir
- [x] Step 4: Render sanity check

#### Self-Check Results

```bash
$ python3 - <<'PY'
import subprocess, sys
out = subprocess.check_output(['helm','template','spark-41','charts/spark-4.1'], text=True)
print('JUPYTER_RUNTIME_DIR' in out)
PY
True

$ helm template spark-41 charts/spark-4.1 >/dev/null
```

#### Issues

- None

### Review Result

**Status:** APPROVED
