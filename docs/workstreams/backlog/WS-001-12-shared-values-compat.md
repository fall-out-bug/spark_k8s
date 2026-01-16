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

