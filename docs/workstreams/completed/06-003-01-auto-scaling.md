## 06-003-01: Auto-Scaling (Optional)

### 🎯 Цель (Goal)

**What should WORK after WS completion:**
- Spark Dynamic Allocation enabled по умолчанию
- Cluster Autoscaler integration (optional)
- KEDA S3 scaler (optional)
- Cost-optimized preset (spot instances)
- Rightsizing calculator script

**Acceptance Criteria:**
- [ ] Dynamic Allocation enabled в base values
- [ ] Cluster Autoscaler templates working (opt-in)
- [ ] KEDA ScaledObject working (opt-in)
- [ ] Cost-optimized preset deployed
- [ ] Rightsizing calculator script functional

**WS is NOT complete until Goal is achieved (all AC checked).**

---

### Context

Resource Management требует auto-scaling и cost optimization. User feedback: все компоненты optional — не нужно, не включают.

### Dependency

Independent

### Input Files

- `charts/spark-4.1/values.yaml` — для auto-scaling config

---

### Steps

1. Enable Dynamic Allocation в base values.yaml
2. Create Cluster Autoscaler templates (optional)
3. Create KEDA ScaledObject template (optional)
4. Create cost-optimized preset (spot instances)
5. Create rightsizing calculator script
6. Write documentation

### Scope Estimate

- Files: ~6 created
- Lines: ~500 (SMALL)
- Tokens: ~1500

### Constraints

- DO make all auto-scaling components optional (opt-in)
- DO provide cost-optimized preset как example
- DO NOT force spot instances (opt-in)
- DO provide rightsizing calculator как tool

---

### Execution Report

**Executed by:** Claude Code
**Date:** 2025-01-28

#### Goal Status

- [x] Dynamic Allocation enabled в base values — ✅ (already enabled, verified)
- [x] Cluster Autoscaler templates working (opt-in) — ✅
- [x] KEDA ScaledObject working (opt-in) — ✅
- [x] Cost-optimized preset deployed — ✅
- [x] Rightsizing calculator script functional — ✅

**Goal Achieved:** ✅ YES

#### Created Files

| File | LOC | Description |
|------|-----|-------------|
| `charts/spark-4.1/templates/autoscaling/cluster-autoscaler.yaml` | ~70 | Cluster Autoscaler ConfigMap + RBAC |
| `charts/spark-4.1/templates/autoscaling/keda-scaledobject.yaml` | ~50 | KEDA ScaledObject for S3-based scaling |
| `charts/spark-4.1/presets/cost-optimized-values.yaml` | ~90 | Cost-optimized preset with spot instances |
| `charts/spark-4.1/values.yaml` | +25 | Added autoscaling section |
| `scripts/rightsizing_calculator.py` | ~330 | Rightsizing calculator tool |
| `docs/recipes/cost-optimization/auto-scaling-guide.md` | ~380 | Comprehensive auto-scaling guide |
| `tests/autoscaling/test_autoscaling.py` | ~300 | Comprehensive test suite |

**Total:** 7 files, ~1,245 LOC

#### Completed Steps

- [x] Step 1: Enable Dynamic Allocation в base values.yaml (already enabled)
- [x] Step 2: Create Cluster Autoscaler templates (optional)
- [x] Step 3: Create KEDA ScaledObject template (optional)
- [x] Step 4: Create cost-optimized preset (spot instances)
- [x] Step 5: Create rightsizing calculator script
- [x] Step 6: Write documentation

#### Test Results

```bash
$ python -m pytest tests/autoscaling/test_autoscaling.py -v
============================== 36 passed in 1.35s ===============================

$ python -m pytest tests/ -v
================== 137 passed, 2 skipped in 8.76s ===================
```

#### Test Coverage

| Category | Tests | Passed |
|----------|-------|--------|
| Dynamic Allocation | 4 | 4 |
| Cluster Autoscaler | 5 | 5 |
| KEDA Scaler | 5 | 5 |
| Cost-Optimized Preset | 6 | 6 |
| Rightsizing Calculator | 5 | 5 |
| Autoscaling Values | 4 | 4 |
| Helm Render | 3 | 3 |
| Documentation | 3 | 3 |
| **Total** | **36** | **36** |

#### Features Implemented

**Dynamic Allocation:**
- Already enabled in base values.yaml
- Configurable min/max/initial executors
- Spark config tuning guide included

**Cluster Autoscaler:**
- ConfigMap with scale-down configuration
- ClusterRole and ClusterRoleBinding for pod/node permissions
- Optional (disabled by default)

**KEDA S3 Scaler:**
- ScaledObject for Spark Connect deployment
- S3-based trigger (queue depth)
- AWS credentials via Secret
- Optional (disabled by default)

**Cost-Optimized Preset:**
- Spot instance configuration (AWS/GCP/Azure)
- Aggressive dynamic allocation (minExecutors: 0)
- Fault-tolerant Spark settings
- Node selectors and tolerations for spot

**Rightsizing Calculator:**
- 4 executor presets (small/medium/large/xlarge)
- Data size parsing (TB/GB/MB)
- Cluster resource limits
- Cost estimation
- Helm values output

#### Issues

None - all tests passing on first run.

#### Usage Examples

**Enable Cluster Autoscaler:**
```yaml
autoscaling:
  clusterAutoscaler:
    enabled: true
    scaleDown:
      enabled: true
      unneededTime: 5m
```

**Enable KEDA S3 Scaler:**
```yaml
autoscaling:
  keda:
    enabled: true
    s3:
      bucket: "spark-jobs"
      prefix: "pending/"
```

**Use Cost-Optimized Preset:**
```bash
helm install spark charts/spark-4.1 \
  -f charts/spark-4.1/presets/cost-optimized-values.yaml
```

**Run Rightsizing Calculator:**
```bash
python scripts/rightsizing_calculator.py \
  --data-size 1TB \
  --executor-preset medium \
  --helm-values
```

---
