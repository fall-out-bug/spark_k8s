## ADR-0003: Shared values contract across `spark-platform` and `spark-standalone`

### Status

Accepted

### Context

We maintain two Helm charts in this repository:

- `charts/spark-platform` (Spark Connect oriented “platform”)
- `charts/spark-standalone` (Standalone master/workers + optional services)

Operators want to keep configuration aligned across both charts, especially:

- S3/MinIO settings
- event log directory for History Server
- ServiceAccount and RBAC defaults

### Decision

- Introduce a shared values overlay at `charts/values-common.yaml`.
- Keep both charts compatible with the following keys:
  - `global.imageRegistry`, `global.imagePullSecrets`
  - `s3.*`
  - `minio.*`
  - `historyServer.logDirectory`
  - `serviceAccount.*`
  - `rbac.create`

### Consequences

- **Pros**
  - Same `-f charts/values-common.yaml` can be reused for both charts.
  - Less drift in S3 and service identity config across deployments.
- **Cons**
  - Some chart-specific settings still require per-chart overlays.

