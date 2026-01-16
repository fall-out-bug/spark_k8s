## ADR-0001: Spark Standalone Master HA uses PVC-backed filesystem (not S3)

### Status

Accepted

### Context

We want an optional “backup-plan” HA mode for Spark Standalone Master in Kubernetes.
Spark Standalone HA for the master uses:

- `spark.deploy.recoveryMode=FILESYSTEM`
- `spark.deploy.recoveryDirectory=<path>`

In practice, Master recovery state is read/written via Spark’s filesystem persistence engine and expects a **POSIX-like filesystem path**.

During runtime validation, using an S3A URI (e.g. `s3a://...`) as recovery directory led to master-side errors and unstable behavior for app submissions.

### Decision

- Master HA is supported as **optional**.
- When enabled, it uses a **PVC-backed directory** mounted into the master pod (default mount: `/opt/spark/recovery`).
- S3 remains the **primary storage** for:
  - Spark SQL warehouse (`spark.sql.warehouse.dir`)
  - Spark event logs (`spark.eventLog.dir`)
  - MLflow artifacts (when enabled)

### Consequences

- **Pros**
  - Reliable master recovery semantics in Kubernetes.
  - Compatible with Pod Security Standards (no hostPath required).
  - Keeps “primary data” on S3 while master state stays on a small PVC.
- **Cons**
  - Requires a StorageClass/PVC in the cluster.
  - Not multi-master; still a single master pod with recovery state.

### Notes / Follow-ups

If we later need stronger HA guarantees (multi-master), consider ZooKeeper-based recovery for Standalone or migrate workloads to Spark on Kubernetes scheduler mode.

