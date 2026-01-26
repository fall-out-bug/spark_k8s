## WS-022-02: Spark Connect 4.1 backend mode support

### 🎯 Goal

**What should WORK after WS completion:**
- Spark Connect 4.1 can run in **K8s executors mode** or **Standalone backend mode** via values.
- Standalone backend mode sets `spark.master=spark://<standalone-master>:7077` consistently.

**Acceptance Criteria:**
- [ ] Values expose `backendMode: k8s|standalone` for Spark Connect 4.1
- [ ] Standalone mode renders `spark.master` to Standalone master service/port
- [ ] K8s mode preserves current behavior (k8s executors)
- [ ] `helm template` covers both modes without errors

**⚠️ WS is NOT complete until Goal is achieved (all AC ✅).**

---

### Context

Spark Connect 4.1 currently assumes K8s executors. This WS adds a configurable backend
mode to support running Connect **next to** a Standalone cluster.

### Dependency

WS-022-01

### Input Files

- `charts/spark-4.1/values.yaml` — add backend mode values
- `charts/spark-4.1/templates/spark-connect.yaml` — render `spark.master`
- `charts/spark-4.1/templates/spark-connect-configmap.yaml` — update config map if needed

### Steps

1. Add `spark-connect.backendMode` and Standalone master service/port values.
2. Update Spark Connect config rendering to set `spark.master` per mode.
3. Render both modes via `helm template` for verification.

### Code

```yaml
# values.yaml (example)
connect:
  backendMode: "standalone"
  standalone:
    masterService: "spark-sa-spark-standalone-master"
    masterPort: 7077
```

### Expected Result

- Spark Connect 4.1 chart supports both backend modes with clean templating.

### Scope Estimate

- Files: ~0 created, ~2 modified
- Lines: ~120-200 (SMALL)
- Tokens: ~600-1000

### Completion Criteria

```bash
# Standalone backend mode
helm template sc41 charts/spark-4.1 \
  --set connect.enabled=true \
  --set connect.backendMode=standalone \
  --set connect.standalone.masterService=spark-sa-spark-standalone-master \
  --set connect.standalone.masterPort=7077 | grep "spark.master spark://"

# K8s executors mode
helm template sc41 charts/spark-4.1 \
  --set connect.enabled=true \
  --set connect.backendMode=k8s | grep "spark.master k8s://"
```

### Constraints

- DO NOT change Spark Standalone chart in this WS
- DO NOT relax PSS/OpenShift hardening

---

### Execution Report

**Executed by:** Auto (agent)  
**Date:** 2026-01-19

#### 🎯 Goal Status

- [x] AC1: Values expose `backendMode: k8s|standalone` for Spark Connect 4.1 — ✅
- [x] AC2: Standalone mode renders `spark.master` to Standalone master service/port — ✅
- [x] AC3: K8s mode preserves current behavior (k8s executors) — ✅
- [x] AC4: `helm template` covers both modes without errors — ✅

**Goal Achieved:** ✅ YES

#### Modified Files

| File | Action | LOC |
|------|--------|-----|
| `charts/spark-4.1/values.yaml` | modified | +6 |
| `charts/spark-4.1/templates/spark-connect-configmap.yaml` | modified | +12 |

**Total:** 2 files modified, ~18 LOC added

#### Completed Steps

- [x] Step 1: Added `backendMode` and `standalone` config to values.yaml under `connect`
- [x] Step 2: Updated configmap template to conditionally render `spark.master` per backend mode
- [x] Step 3: Verified `helm template` for both modes

#### Self-Check Results

```bash
$ helm template sc41-test charts/spark-4.1 \
  --set connect.enabled=true \
  --set connect.backendMode=standalone \
  --set connect.standalone.masterService=test-master \
  --set connect.standalone.masterPort=7077 | grep "spark.master spark://"
    spark.master spark://test-master:7077

$ helm template sc41-test charts/spark-4.1 \
  --set connect.enabled=true \
  --set connect.backendMode=k8s | grep "spark.master k8s://"
    spark.master k8s://https://kubernetes.default.svc.cluster.local:443

$ helm lint charts/spark-4.1
==> Linting charts/spark-4.1
[INFO] Chart.yaml: icon is recommended
1 chart(s) linted, 0 chart(s) failed
```

#### Issues

None

### Review Result

**Status:** READY
