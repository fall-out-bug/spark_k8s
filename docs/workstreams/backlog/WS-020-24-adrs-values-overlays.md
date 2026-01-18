## WS-020-24: ADRs + Values Overlays

### 🎯 Goal

**What should WORK after WS completion:**
- 4 ADRs created documenting key architectural decisions for F04
- Values overlays for minimal and production scenarios
- All ADRs follow standard format (Context, Decision, Consequences)
- ADRs linked from README.md

**Acceptance Criteria:**
- [ ] `docs/adr/ADR-0004-spark-410-modular-architecture.md` exists
- [ ] `docs/adr/ADR-0005-celeborn-disaggregated-shuffle.md` exists
- [ ] `docs/adr/ADR-0006-spark-operator-optional.md` exists
- [ ] `docs/adr/ADR-0007-version-specific-metastores.md` exists
- [ ] `docs/examples/values-spark-41-minimal.yaml` exists (already in WS-020-13, ensure complete)
- [ ] `docs/examples/values-spark-41-production.yaml` exists (already in WS-020-20, validate)
- [ ] README.md links to all ADRs

**⚠️ WS is NOT complete until Goal is achieved (all AC ✅).**

---

### Context

Feature F04 makes significant architectural decisions (modular charts, Celeborn, Operator, version-specific Metastores). ADRs document rationale for future maintainers.

### Dependency

Independent (documents decisions already made in draft)

### Input Files

**Reference:**
- `docs/adr/ADR-0001-spark-standalone-master-ha-pvc.md` — Existing ADR format
- `docs/adr/ADR-0003-shared-values-contract.md` — Another ADR example
- `docs/drafts/idea-spark-410-charts.md` — Source of architectural decisions

### Steps

1. **Create `docs/adr/ADR-0004-spark-410-modular-architecture.md`:**
   ```markdown
   # ADR-0004: Modular Chart Architecture for Multi-Version Spark
   
   **Status:** Accepted  
   **Date:** 2026-01-15  
   **Author:** AI Agent (SDP WS-020-24)
   
   ## Context
   
   The repository supports Spark 3.5.7 (LTS) and requires addition of Spark 4.1.0 (latest). Key challenges:
   
   - Simultaneous deployment of both versions without conflicts
   - Shared infrastructure (RBAC, MinIO, PostgreSQL) to avoid duplication
   - Version-specific components (Hive Metastore, History Server)
   - Future scalability (adding Spark 4.2, 5.0)
   
   ## Decision
   
   Adopt a **modular chart architecture**:
   
   ```
   charts/
   ├── spark-base/       # Shared infrastructure (RBAC, MinIO, PostgreSQL)
   ├── spark-3.5/        # Spark 3.5.7 LTS (umbrella: standalone + connect)
   ├── spark-4.1/        # Spark 4.1.0 (umbrella: connect + k8s native)
   ├── celeborn/         # Optional shuffle service
   └── spark-operator/   # Optional CRD-based job management
   ```
   
   **Key principles:**
   
   1. **spark-base** provides shared components (optional dependency)
   2. Version-specific charts (`spark-3.5`, `spark-4.1`) depend on `spark-base`
   3. Optional components (Celeborn, Operator) are standalone charts
   4. Version-specific components (Metastore, History Server) are isolated
   
   ## Consequences
   
   ### Positive
   
   - ✅ Clear separation of concerns
   - ✅ No code duplication for RBAC, MinIO, PostgreSQL
   - ✅ Easy to add Spark 4.2+ in future (create `spark-4.2/` chart)
   - ✅ Users can deploy only what they need
   
   ### Negative
   
   - ❌ More complex chart dependencies (requires `helm dependency update`)
   - ❌ Longer initial learning curve for operators
   - ❌ Refactoring existing `spark-standalone` and `spark-platform` charts
   
   ### Mitigation
   
   - Provide comprehensive documentation (quickstart, production guides)
   - Create values overlays for common scenarios
   - Maintain backward compatibility (existing charts still work)
   
   ## Alternatives Considered
   
   ### Alternative 1: Monolithic Chart
   
   Single `spark` chart with `version` parameter (`3.5.7` or `4.1.0`).
   
   **Rejected:** Cannot deploy both versions simultaneously.
   
   ### Alternative 2: Separate Repositories
   
   One repo per Spark version (`spark-3.5-k8s`, `spark-4.1-k8s`).
   
   **Rejected:** Duplication of infrastructure code (RBAC, MinIO, etc.).
   
   ## References
   
   - Feature F04 Draft: `docs/drafts/idea-spark-410-charts.md`
   - Helm Chart Best Practices: https://helm.sh/docs/chart_best_practices/
   ```

2. **Create `docs/adr/ADR-0005-celeborn-disaggregated-shuffle.md`:**
   ```markdown
   # ADR-0005: Apache Celeborn for Disaggregated Shuffle
   
   **Status:** Accepted  
   **Date:** 2026-01-15  
   **Author:** AI Agent (SDP WS-020-24)
   
   ## Context
   
   Spark 4.1.0 jobs with large shuffle operations (>100GB) experience:
   
   - OOM failures when executors die (shuffle data lost)
   - Shuffle fetch failures in dynamic allocation scenarios
   - Poor performance with spot instances (executor churn)
   
   Apache Celeborn (formerly RSS) provides disaggregated shuffle:
   
   - Shuffle data stored outside executors (in Celeborn workers)
   - Executors can fail/restart without losing shuffle data
   - Optimizations for skewed partitions
   
   ## Decision
   
   **Include Celeborn as optional component** for Spark 4.1.0:
   
   - Separate `celeborn` Helm chart (standalone deployment)
   - `spark-4.1` chart integrates via `celeborn.enabled=true` flag
   - Celeborn is NOT deployed by default (opt-in)
   
   **When to use:**
   
   - ✅ Production jobs with >100GB shuffle
   - ✅ Spot instances or dynamic allocation
   - ✅ Jobs with frequent shuffle failures
   
   **When to skip:**
   
   - ❌ Dev/testing environments
   - ❌ Small datasets (<10GB)
   - ❌ Spark Standalone mode (use External Shuffle Service instead)
   
   ## Consequences
   
   ### Positive
   
   - ✅ Improved stability for large-scale jobs
   - ✅ Better support for spot instances
   - ✅ Performance gains (optimized shuffle writes)
   - ✅ Production-ready feature for cost optimization
   
   ### Negative
   
   - ❌ Additional infrastructure to manage (Celeborn masters + workers)
   - ❌ Increased storage requirements (PVCs for shuffle data)
   - ❌ Operational complexity (monitoring, troubleshooting)
   
   ### Mitigation
   
   - Provide comprehensive guide: `docs/guides/CELEBORN-GUIDE.md`
   - Make Celeborn optional (not required for basic deployment)
   - Include integration tests: `scripts/test-spark-41-integrations.sh`
   
   ## Alternatives Considered
   
   ### Alternative 1: Use Spark's Built-in Shuffle
   
   Rely on standard Spark shuffle (no Celeborn).
   
   **Rejected:** Does not solve OOM/fetch failures for large shuffles.
   
   ### Alternative 2: External Shuffle Service (ESS)
   
   Use Spark's External Shuffle Service (DaemonSet on every node).
   
   **Rejected:** ESS is deprecated in Spark 4.x; Celeborn is recommended replacement.
   
   ## References
   
   - Apache Celeborn: https://celeborn.apache.org/
   - Inspiration: [aagumin/spark-connect-kubernetes](https://github.com/aagumin/spark-connect-kubernetes)
   ```

3. **Create `docs/adr/ADR-0006-spark-operator-optional.md`:**
   ```markdown
   # ADR-0006: Spark Operator as Optional Component
   
   **Status:** Accepted  
   **Date:** 2026-01-15  
   **Author:** AI Agent (SDP WS-020-24)
   
   ## Context
   
   Spark jobs can be submitted via multiple methods:
   
   1. **spark-submit** (CLI, manual)
   2. **Spark Connect** (client/server, interactive)
   3. **Kubernetes Operator** (CRD-based, declarative)
   
   Target users for Spark 4.1.0:
   
   - Data Scientists: Use Jupyter + Spark Connect (interactive)
   - DataOps/Engineers: Need declarative job management (GitOps-friendly)
   
   ## Decision
   
   **Include Spark Operator as optional component**:
   
   - Separate `spark-operator` Helm chart
   - Manages `SparkApplication` CRDs
   - Optional dependency (not required for basic Spark Connect usage)
   
   **Target users:**
   
   - DataOps teams using GitOps (ArgoCD, Flux)
   - Production batch jobs (scheduled or triggered)
   - Teams wanting automatic job lifecycle management
   
   ## Consequences
   
   ### Positive
   
   - ✅ Declarative job management (YAML manifests)
   - ✅ GitOps-friendly (version control for Spark jobs)
   - ✅ Automatic lifecycle (submission, monitoring, cleanup)
   - ✅ Webhook validation (catch config errors before submission)
   
   ### Negative
   
   - ❌ Additional complexity (CRDs, operator, webhook)
   - ❌ Learning curve for teams unfamiliar with operators
   - ❌ Requires ClusterRole (cluster-admin permissions for CRD management)
   
   ### Mitigation
   
   - Make Operator optional (default: disabled)
   - Provide comprehensive guide: `docs/guides/SPARK-OPERATOR-GUIDE.md`
   - Include example SparkApplication manifests
   - Support Spark Connect without Operator (keep simple path)
   
   ## Alternatives Considered
   
   ### Alternative 1: Operator as Core Component
   
   Make Operator required for all Spark 4.1.0 deployments.
   
   **Rejected:** Too opinionated; Data Scientists don't need Operator for Jupyter.
   
   ### Alternative 2: No Operator Support
   
   Only support spark-submit and Spark Connect (no CRDs).
   
   **Rejected:** Missing GitOps use case for DataOps teams.
   
   ## References
   
   - Spark Operator: https://googlecloudplatform.github.io/spark-on-k8s-operator/
   ```

4. **Create `docs/adr/ADR-0007-version-specific-metastores.md`:**
   ```markdown
   # ADR-0007: Version-Specific Hive Metastores (No Migration)
   
   **Status:** Accepted  
   **Date:** 2026-01-15  
   **Author:** AI Agent (SDP WS-020-24)
   
   ## Context
   
   Hive Metastore stores table metadata for Spark SQL. Key considerations:
   
   - Hive 3.1.3 (used with Spark 3.5.7) and Hive 4.0.0 (for Spark 4.1.0) have schema differences
   - In-place schema migration is complex and risky
   - Users want to run Spark 3.5.7 and 4.1.0 simultaneously (gradual migration)
   
   ## Decision
   
   **Use separate Hive Metastores for each Spark version:**
   
   - Spark 3.5.7 → Hive Metastore 3.1.3 → PostgreSQL database `metastore_spark35`
   - Spark 4.1.0 → Hive Metastore 4.0.0 → PostgreSQL database `metastore_spark41`
   
   **No automatic migration:**
   
   - Tables must be recreated in 4.1.0 (or migrated manually)
   - Recommend data stays in S3 (only metadata is recreated)
   
   ## Consequences
   
   ### Positive
   
   - ✅ Safe coexistence (no schema conflicts)
   - ✅ No risk of corrupting existing metadata
   - ✅ Easy rollback (3.5.7 Metastore unchanged)
   - ✅ Simple architecture (no migration tools)
   
   ### Negative
   
   - ❌ Table definitions not automatically available in 4.1.0
   - ❌ Manual effort to recreate tables (or migration scripts)
   - ❌ Duplicate metadata during migration period
   
   ### Mitigation
   
   - Document manual migration process:
     1. Export table DDL from 3.5.7: `SHOW CREATE TABLE`
     2. Re-run DDL in 4.1.0: `spark.sql("CREATE TABLE ...")`
     3. Data remains in S3 (no data copy needed)
   - Provide migration guide: `docs/guides/MULTI-VERSION-DEPLOYMENT.md`
   - Recommend gradual migration (3-6 months)
   
   ## Alternatives Considered
   
   ### Alternative 1: Shared Metastore (In-Place Upgrade)
   
   Upgrade Hive Metastore 3.1.3 → 4.0.0 in place (schema migration).
   
   **Rejected:**
   - Breaks Spark 3.5.7 (cannot read Hive 4.0 schema)
   - Risky (no rollback path)
   - Requires downtime
   
   ### Alternative 2: Automatic Migration Tool
   
   Build custom tool to replicate tables from 3.1.3 to 4.0.0.
   
   **Rejected:** Out of scope for F04; users can build this if needed.
   
   ## References
   
   - Hive Metastore Schema Tool: https://cwiki.apache.org/confluence/display/Hive/Hive+Schema+Tool
   ```

5. **Validate all ADRs exist and update README.md:**
   ```bash
   ls docs/adr/ADR-000{4,5,6,7}-*.md
   ```

6. **Ensure values overlays exist:**
   - `docs/examples/values-spark-41-minimal.yaml` (created in WS-020-13)
   - `docs/examples/values-spark-41-production.yaml` (created in WS-020-20)

7. **Update README.md ADR section:**
   ```markdown
   ## Architectural Decision Records (ADRs)
   
   - [ADR-0001: Spark Standalone Master HA (PVC)](docs/adr/ADR-0001-spark-standalone-master-ha-pvc.md)
   - [ADR-0002: Airflow KubernetesExecutor Pod Template](docs/adr/ADR-0002-airflow-kubernetesexecutor-pod-template-and-fernet.md)
   - [ADR-0003: Shared Values Contract](docs/adr/ADR-0003-shared-values-contract.md)
   - [ADR-0004: Spark 4.1.0 Modular Architecture](docs/adr/ADR-0004-spark-410-modular-architecture.md)
   - [ADR-0005: Celeborn Disaggregated Shuffle](docs/adr/ADR-0005-celeborn-disaggregated-shuffle.md)
   - [ADR-0006: Spark Operator as Optional Component](docs/adr/ADR-0006-spark-operator-optional.md)
   - [ADR-0007: Version-Specific Hive Metastores](docs/adr/ADR-0007-version-specific-metastores.md)
   ```

### Expected Result

```
docs/adr/
├── ADR-0004-spark-410-modular-architecture.md      # ~100 LOC
├── ADR-0005-celeborn-disaggregated-shuffle.md      # ~120 LOC
├── ADR-0006-spark-operator-optional.md             # ~100 LOC
└── ADR-0007-version-specific-metastores.md         # ~110 LOC
```

### Scope Estimate

- Files: 4 created, 1 modified (README.md)
- Lines: ~430 LOC (MEDIUM)
- Tokens: ~2000

### Completion Criteria

```bash
# Check all ADRs exist
ls docs/adr/ADR-000{4,5,6,7}-*.md

# Validate markdown format
markdownlint docs/adr/ADR-*.md || echo "Linter not installed, skip"

# Check README links
grep "ADR-000[4-7]" README.md
```

### Constraints

- DO NOT create ADRs for trivial decisions (follow existing pattern)
- DO NOT include implementation details (focus on rationale)
- ENSURE all ADRs follow standard format (Context, Decision, Consequences, Alternatives)
- USE consistent tone (objective, not promotional)

---

### Execution Report

**Executed by:** Auto (agent)  
**Date:** 2026-01-18

#### 🎯 Goal Status

- [x] AC1: `docs/adr/ADR-0004-spark-410-modular-architecture.md` exists — ✅
- [x] AC2: `docs/adr/ADR-0005-celeborn-disaggregated-shuffle.md` exists — ✅
- [x] AC3: `docs/adr/ADR-0006-spark-operator-optional.md` exists — ✅
- [x] AC4: `docs/adr/ADR-0007-version-specific-metastores.md` exists — ✅
- [x] AC5: `docs/examples/values-spark-41-minimal.yaml` exists — ✅
- [x] AC6: `docs/examples/values-spark-41-production.yaml` exists — ✅
- [x] AC7: README links to all ADRs — ✅

**Goal Achieved:** ✅ YES

#### Modified Files

| File | Action | LOC |
|------|--------|-----|
| `docs/adr/ADR-0004-spark-410-modular-architecture.md` | added | 60 |
| `docs/adr/ADR-0005-celeborn-disaggregated-shuffle.md` | added | 63 |
| `docs/adr/ADR-0006-spark-operator-optional.md` | added | 57 |
| `docs/adr/ADR-0007-version-specific-metastores.md` | added | 44 |
| `docs/examples/values-spark-41-minimal.yaml` | added | 22 |
| `README.md` | modified | 83 |

#### Completed Steps

- [x] Step 1: Added ADR-0004 (modular architecture)
- [x] Step 2: Added ADR-0005 (Celeborn shuffle)
- [x] Step 3: Added ADR-0006 (Operator optional)
- [x] Step 4: Added ADR-0007 (versioned metastores)
- [x] Step 5: Validated ADR files and README links
- [x] Step 6: Ensured values overlays exist (minimal + production)

#### Self-Check Results

```bash
$ ls docs/adr/ADR-000{4,5,6,7}-*.md
docs/adr/ADR-0004-spark-410-modular-architecture.md
docs/adr/ADR-0005-celeborn-disaggregated-shuffle.md
docs/adr/ADR-0006-spark-operator-optional.md
docs/adr/ADR-0007-version-specific-metastores.md

$ ls docs/examples/values-spark-41-minimal.yaml docs/examples/values-spark-41-production.yaml
docs/examples/values-spark-41-minimal.yaml
docs/examples/values-spark-41-production.yaml

$ markdownlint docs/adr/ADR-*.md || echo "Linter not installed, skip"
markdownlint not installed, skip

$ grep "ADR-000[4-7]" README.md
- [ADR-0004: Spark 4.1.0 Modular Architecture](docs/adr/ADR-0004-spark-410-modular-architecture.md)
- [ADR-0005: Celeborn Disaggregated Shuffle](docs/adr/ADR-0005-celeborn-disaggregated-shuffle.md)
- [ADR-0006: Spark Operator as Optional Component](docs/adr/ADR-0006-spark-operator-optional.md)
- [ADR-0007: Version-Specific Hive Metastores](docs/adr/ADR-0007-version-specific-metastores.md)
```

#### Issues

- None
