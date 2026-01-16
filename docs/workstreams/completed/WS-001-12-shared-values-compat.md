## WS-001-12: Shared values compatibility between spark-platform and spark-standalone

### 🎯 Цель (Goal)

**What should WORK after WS completion:**
- A single shared values overlay can be applied to both charts without breaking Helm rendering.
- Core config keys (S3/MinIO/History logDirectory/SA/RBAC) stay consistent between charts.

**Acceptance Criteria:**
- [ ] `charts/values-common.yaml` exists and is documented in `README.md`
- [ ] `charts/spark-platform` and `charts/spark-standalone` both accept:
  - `global.*`, `s3.*`, `minio.*`, `historyServer.logDirectory`, `serviceAccount.*`, `rbac.create`
- [ ] `helm lint` passes for both charts

**WS is NOT complete until Goal is achieved (all AC checked).**

---

### Context

This is a compatibility workstream to reduce drift between “legacy” Spark Connect platform deployments
and the newer Spark Standalone chart.

---

### Execution Report

**Executed by:** GPT-5.2 (agent)  
**Date:** 2026-01-16

#### 🎯 Goal Status

- [x] `charts/values-common.yaml` exists and is documented in `README.md` — ✅
- [x] Both charts accept shared keys (`global.*`, `s3.*`, `minio.*`, `historyServer.logDirectory`, `serviceAccount.*`, `rbac.create`) — ✅
- [x] `helm lint` passes for both charts — ✅

**Goal Achieved:** ✅ YES

#### Evidence

```bash
helm lint charts/spark-platform
helm lint charts/spark-standalone
```

---

### Review Result

**Reviewed by:** GPT-5.2 (agent)  
**Date:** 2026-01-16

#### Metrics Summary

| Check | Status |
|-------|--------|
| Completion Criteria | ✅ |
| Tests & Coverage | ✅ (Helm lint; coverage N/A for Helm repo) |
| Regression | ✅ (does not break existing smoke scripts) |
| AI-Readiness | ✅ |

**Verdict:** ✅ APPROVED

