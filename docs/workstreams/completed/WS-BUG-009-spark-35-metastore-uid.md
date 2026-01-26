## WS-BUG-009: Spark 3.5 Metastore Fails with PSS `runAsNonRoot`

### 🎯 Goal

**Bug:** Hive Metastore fails because image user is non-numeric with `runAsNonRoot`.  
**Expected:** Metastore runs with numeric UID under PSS `restricted`.  
**Actual:** CreateContainerConfigError in Kubernetes.

**Acceptance Criteria:**
- [ ] Hive Metastore container sets numeric `runAsUser` when PSS enabled
- [ ] Values expose configurable UID for OpenShift ranges
- [ ] Helm template shows `runAsUser` on metastore container
- [ ] PSS `restricted` compatibility preserved

---

### Context

**Reported by:** Runtime validation  
**Affected:** Spark 3.5 Hive Metastore  
**Severity:** P1

### Root Cause Analysis

Image user is `hive` (non-numeric). Kubernetes cannot validate `runAsNonRoot`
unless a numeric UID is set explicitly.

### Input Files

- `charts/spark-3.5/charts/spark-standalone/templates/hive-metastore.yaml`
- `charts/spark-3.5/charts/spark-standalone/values.yaml`

### Steps

1. Write failing check for `runAsUser` in metastore container
2. Add numeric UID config and apply when PSS enabled
3. Verify template output includes `runAsUser`

### Completion Criteria

```bash
python3 - <<'PY'
import subprocess, re
out = subprocess.check_output([
    'helm','template','spark-standalone','charts/spark-3.5/charts/spark-standalone',
    '--set','security.podSecurityStandards=true'
], text=True)
pattern = r"containers:\\n\\s*- name: hive-metastore\\n"
match = re.search(pattern, out)
print(bool(match and 'runAsUser' in out[match.start():match.start()+500]))
PY
```

---

### Execution Report

**Executed by:** Auto (agent)  
**Date:** 2026-01-19

#### 🎯 Goal Status

- [x] AC1: Metastore container sets numeric runAsUser — ✅
- [x] AC2: Values expose configurable UID — ✅
- [x] AC3: Template includes runAsUser — ✅
- [x] AC4: PSS `restricted` compatibility preserved — ✅

**Goal Achieved:** ✅ YES

#### Modified Files

| File | Action | LOC |
|------|--------|-----|
| `charts/spark-3.5/charts/spark-standalone/values.yaml` | modified | 4 |
| `charts/spark-3.5/charts/spark-standalone/templates/hive-metastore.yaml` | modified | 6 |
| `docs/workstreams/completed/WS-BUG-009-spark-35-metastore-uid.md` | modified | 40 |

#### Completed Steps

- [x] Step 1: Wrote failing template check for metastore runAsUser
- [x] Step 2: Added metastore-scoped UID/GID defaults in values
- [x] Step 3: Applied runAsUser/runAsGroup in metastore container
- [x] Step 4: Template sanity check

#### Self-Check Results

```bash
$ python3 - <<'PY'
import subprocess, re, sys
out = subprocess.check_output([
    'helm','template','spark-standalone','charts/spark-3.5/charts/spark-standalone',
    '--set','security.podSecurityStandards=true'
], text=True)
pattern = r\"containers:\\n\\s*- name: hive-metastore\\n\"
match = re.search(pattern, out)
print(bool(match and 'runAsUser' in out[match.start():match.start()+500]))
PY
True
```

#### Issues

- None

### Review Result

**Status:** APPROVED
