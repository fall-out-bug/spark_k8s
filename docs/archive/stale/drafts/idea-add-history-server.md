# Idea: Add Spark History Server to Standalone Chart

**Created:** 2026-01-16
**Status:** Designed
**Author:** user + GPT-5.2 (agent)
**Feature:** F03
**Workstreams:** WS-012-01, WS-012-02

---

## 1. Problem Statement

### Current State
The `spark-standalone` chart configures Spark applications to write event logs to S3 (`spark.eventLog.enabled=true`), but there is no component deployed to read and visualize these logs.

### Problem
When a Spark application finishes (success or failure), it disappears from the Spark Master UI. Developers cannot debug failed jobs or analyze performance of past jobs because there is no History Server UI.

### Impact
- Hard to debug production failures.
- "Blind spots" in cluster usage history.

---

## 2. Proposed Solution

### Description
Add an optional **Spark History Server** component to the `charts/spark-standalone` Helm chart. It will run as a Deployment, connect to the configured S3 bucket, and serve the standard Spark History UI.

### Key Capabilities
1. **Deployment**: Optional `history-server` deployment controlled by `historyServer.enabled`.
2. **S3 Integration**: Reuses existing S3 configuration and secrets to read event logs.
3. **UI Access**: Service (port 18080) and Ingress integration for web access.

---

## 3. User Stories

### Primary User: Spark Developer

- As a Spark Developer, I want to view the details (stages, tasks, DAGs) of my completed application so that I can optimize performance or debug errors.
- As a Spark Developer, I want the History Server to automatically find logs on S3 without manual configuration.

---

## 4. Scope

### In Scope
- Add `templates/history-server.yaml` (Deployment + Service).
- Update `values.yaml` with History Server configuration (image, resources, ports).
- Update `templates/ingress.yaml` to include History Server rule.
- Ensure History Server pod has necessary environment variables/secrets for S3 access.

### Out of Scope
- Custom authentication/authorization (Basic Auth via Ingress is sufficient if needed).
- Complex log retention policies (will stick to Spark defaults).

### Future Considerations
- PVC-backed caching for History Server (if S3 listing becomes slow).

---

## 5. Success Criteria

### Acceptance Criteria
- [ ] `historyServer.enabled: true` deploys a History Server pod.
- [ ] History Server pod starts without errors and connects to S3.
- [ ] UI is accessible on port 18080.
- [ ] Completed Spark applications (e.g. from `test-spark-standalone.sh`) appear in the UI.

### Metrics (if applicable)
- N/A

---

## 6. Dependencies & Risks

### Dependencies
| Dependency | Type | Status |
|------------|------|--------|
| S3/MinIO | Hard | Ready (configured in chart) |
| Spark Event Logs | Hard | Ready (`spark.eventLog.enabled=true` in configmap) |

### Risks
| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| S3 connection issues | Low | High | Reuse tested S3 config logic from Master/Worker |

---

## 7. Open Questions

- [x] ~~Need to verify if `spark-custom` image has `history-server` entrypoint or requires custom command.~~
  **RESOLVED:** `docker/spark/entrypoint.sh` supports `SPARK_MODE=history` (lines 112-128). Uses `SPARK_HISTORY_LOG_DIR` env var to override log directory.

---

## 8. Notes

- Requires `spark.history.fs.logDirectory` to match `spark.eventLog.dir`.
- Should share the same `Secret` for S3 keys as the rest of the cluster.

---

## Next Steps

1. **Review draft** — review and refine
2. **Run `/design idea-add-history-server`** — create workstreams
