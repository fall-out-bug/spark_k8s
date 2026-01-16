## WS-011-02: Operator guides (EN) for all charts + values overlays
### 🎯 Цель (Goal)
**What should WORK after WS completion:**
- An English operator guide exists for:
  - `charts/spark-platform`
  - `charts/spark-standalone`
- Copy-pasteable values overlays exist for:
  - “any Kubernetes” baseline
  - “SA prod-like” (based on tested Minikube profile)
**Acceptance Criteria:**
- [ ] `docs/guides/en/charts/spark-platform.md` exists
- [ ] `docs/guides/en/charts/spark-standalone.md` exists
- [ ] `docs/guides/en/overlays/` contains copy-pasteable YAML overlays (at least 2)
- [ ] Guides include “quickstart” commands and reference existing `values*.yaml` files
- [ ] Guides explicitly state: tested on Minikube; prepared for OpenShift-like constraints
**WS is NOT complete until Goal is achieved (all AC checked).**
---
### Context
Docs must be minimal and actionable: which chart to choose, how to install it, and which values to start from.
### Dependency
WS-011-01
### Input Files
- `charts/spark-platform/values.yaml`
- `charts/spark-standalone/values.yaml`
- `charts/spark-standalone/values-prod-like.yaml`
- `charts/values-common.yaml`
- `scripts/test-*.sh`
### Steps
1. Add EN chart guides for both charts:
   - what it deploys
   - key values knobs (first 10)
   - install/upgrade examples
2. Add overlays under `docs/guides/en/overlays/`:
   - `values-anyk8s.yaml` (generic defaults + placeholders)
   - `values-sa-prodlike.yaml` (references tested `values-prod-like.yaml` and key toggles)
3. Reference smoke scripts and expected “green” outcomes.
### Expected Result
- New guides in `docs/guides/en/...`
- Overlays usable via `helm -f ...`
### Scope Estimate
- Files: ~4 created
- Lines: ~400-600 (MEDIUM)
- Tokens: ~1500-2500
### Completion Criteria
```bash
# Lint stays green
helm lint charts/spark-platform
helm lint charts/spark-standalone
```

---

### Execution Report

**Executed by:** GPT-5.2 (agent)  
**Date:** 2026-01-16

#### 🎯 Goal Status

- [x] `docs/guides/en/charts/spark-platform.md` exists — ✅
- [x] `docs/guides/en/charts/spark-standalone.md` exists — ✅
- [x] `docs/guides/en/overlays/` contains copy-pasteable YAML overlays (at least 2) — ✅
- [x] Guides include "quickstart" commands and reference existing `values*.yaml` files — ✅
- [x] Guides explicitly state: tested on Minikube; prepared for OpenShift-like constraints — ✅

**Goal Achieved:** ✅ YES

#### Modified Files

| File | Action | LOC |
|------|--------|-----|
| `docs/guides/en/charts/spark-platform.md` | created | 138 |
| `docs/guides/en/charts/spark-standalone.md` | created | 187 |
| `docs/guides/en/overlays/values-anyk8s.yaml` | created | 48 |
| `docs/guides/en/overlays/values-sa-prodlike.yaml` | created | 50 |

**Total:** 423 LOC (within MEDIUM scope estimate: 400-600)

#### Completed Steps

- [x] Step 1: Add EN chart guides for both charts (what it deploys, key values, install examples)
- [x] Step 2: Add overlays under `docs/guides/en/overlays/` (values-anyk8s.yaml, values-sa-prodlike.yaml)
- [x] Step 3: Reference smoke scripts and expected "green" outcomes

#### Self-Check Results

```bash
$ helm lint charts/spark-platform
==> Linting charts/spark-platform
[INFO] Chart.yaml: icon is recommended
1 chart(s) linted, 0 chart(s) failed

$ helm lint charts/spark-standalone
==> Linting charts/spark-standalone
[INFO] Chart.yaml: icon is recommended
1 chart(s) linted, 0 chart(s) failed

$ test -f docs/guides/en/charts/spark-platform.md && \
  test -f docs/guides/en/charts/spark-standalone.md && \
  test -f docs/guides/en/overlays/values-anyk8s.yaml && \
  test -f docs/guides/en/overlays/values-sa-prodlike.yaml && echo "✓ All files exist"
✓ All files exist

$ grep -l "tested on Minikube\|Tested on:" docs/guides/en/charts/*.md
docs/guides/en/charts/spark-platform.md
docs/guides/en/charts/spark-standalone.md

$ hooks/post-build.sh WS-011-02 docs
Post-build checks complete: WS-011-02
```

#### Issues

None.

---

### Review Result

**Reviewed by:** GPT-5.2 (agent)  
**Date:** 2026-01-16

#### Metrics Summary

| Check | Status |
|-------|--------|
| Completion Criteria | ✅ |
| Tests & Coverage | ✅ (Docs verification) |
| Regression | ✅ |
| AI-Readiness | ✅ |
| Security (PSS) | N/A (Docs) |

**Verdict:** ✅ APPROVED
