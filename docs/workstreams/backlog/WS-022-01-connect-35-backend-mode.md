## WS-022-01: Spark Connect 3.5 backend mode support

### 🎯 Goal

**What should WORK after WS completion:**
- Spark Connect 3.5 can run in **K8s executors mode** or **Standalone backend mode** via values.
- Standalone backend mode sets `spark.master=spark://<standalone-master>:7077` consistently.

**Acceptance Criteria:**
- [ ] Values expose `backendMode: k8s|standalone` for Spark Connect 3.5
- [ ] Standalone mode renders `spark.master` to Standalone master service/port
- [ ] K8s mode preserves current behavior (k8s executors)
- [ ] `helm template` covers both modes without errors

**⚠️ WS is NOT complete until Goal is achieved (all AC ✅).**

---

### Context

Spark Connect 3.5 currently assumes K8s executors. This WS adds a configurable backend
mode to support running Connect **next to** a Standalone cluster.

### Dependency

Independent

### Input Files

- `charts/spark-3.5/charts/spark-connect/values.yaml` — add backend mode values
- `charts/spark-3.5/charts/spark-connect/templates/spark-connect.yaml` — render `spark.master`
- `charts/spark-3.5/charts/spark-connect/templates/configmap.yaml` — update config map if needed

### Steps

1. Add `spark-connect.backendMode` and Standalone master service/port values.
2. Update Spark Connect config rendering to set `spark.master` per mode.
3. Render both modes via `helm template` for verification.

### Code

```yaml
# values.yaml (example)
spark-connect:
  backendMode: "standalone"
  standalone:
    masterService: "spark-sa-spark-standalone-master"
    masterPort: 7077
```

### Expected Result

- Spark Connect 3.5 chart supports both backend modes with clean templating.

### Scope Estimate

- Files: ~0 created, ~2 modified
- Lines: ~120-200 (SMALL)
- Tokens: ~600-1000

### Completion Criteria

```bash
# Standalone backend mode
helm template sc35 charts/spark-3.5 \
  --set spark-connect.enabled=true \
  --set spark-connect.sparkConnect.backendMode=standalone \
  --set spark-connect.sparkConnect.standalone.masterService=spark-sa-spark-standalone-master \
  --set spark-connect.sparkConnect.standalone.masterPort=7077 | grep "spark.master=spark://"

# K8s executors mode
helm template sc35 charts/spark-3.5 \
  --set spark-connect.enabled=true \
  --set spark-connect.sparkConnect.backendMode=k8s | grep "spark.master=k8s://"
```

### Constraints

- DO NOT change Spark Standalone chart in this WS
- DO NOT relax PSS/OpenShift hardening

---

### Execution Report

**Executed by:** Auto (agent)  
**Date:** 2026-01-19

#### 🎯 Goal Status

- [x] AC1: Values expose `backendMode: k8s|standalone` for Spark Connect 3.5 — ✅
- [x] AC2: Standalone mode renders `spark.master` to Standalone master service/port — ✅
- [x] AC3: K8s mode preserves current behavior (k8s executors) — ✅
- [x] AC4: `helm template` covers both modes without errors — ✅

**Goal Achieved:** ✅ YES

#### Modified Files

| File | Action | LOC |
|------|--------|-----|
| `charts/spark-3.5/charts/spark-connect/values.yaml` | modified | +8 |
| `charts/spark-3.5/charts/spark-connect/templates/configmap.yaml` | modified | +10 |
| `charts/spark-3.5/charts/spark-connect/templates/spark-connect.yaml` | modified | +2 |

**Total:** 3 files modified, ~20 LOC added

#### Completed Steps

- [x] Step 1: Added `backendMode` and `standalone` config to values.yaml
- [x] Step 2: Updated configmap template to render `spark.master` per backend mode
- [x] Step 3: Updated deployment/service templates to handle both modes
- [x] Step 4: Verified `helm template` for both modes

#### Self-Check Results

```bash
$ helm template sc35-test charts/spark-3.5 \
  --set spark-connect.enabled=true \
  --set spark-connect.sparkConnect.backendMode=standalone \
  --set spark-connect.sparkConnect.standalone.masterService=test-master \
  --set spark-connect.sparkConnect.standalone.masterPort=7077 | grep "spark.master=spark://"
    spark.master=spark://test-master:7077

$ helm template sc35-test charts/spark-3.5 \
  --set spark-connect.enabled=true \
  --set spark-connect.sparkConnect.backendMode=k8s | grep "spark.master=k8s://"
    spark.master=k8s://https://kubernetes.default.svc:443

$ helm lint charts/spark-3.5
==> Linting charts/spark-3.5
[INFO] Chart.yaml: icon is recommended
1 chart(s) linted, 0 chart(s) failed
```

#### Issues

None

### Review Result

**Status:** READY
