## WS-020-02: Refactor Existing Charts → `spark-3.5/` Structure

### 🎯 Goal

**What should WORK after WS completion:**
- Existing `spark-standalone` and `spark-platform` charts are reorganized under `charts/spark-3.5/` umbrella chart
- Charts use `spark-base` as a dependency for shared infrastructure
- All existing smoke tests (`scripts/test-spark-standalone.sh`) pass without modification
- `helm lint charts/spark-3.5` passes

**Acceptance Criteria:**
- [ ] Directory `charts/spark-3.5/` created with Chart.yaml defining dependencies
- [ ] `charts/spark-3.5/charts/spark-standalone/` and `charts/spark-3.5/charts/spark-connect/` exist as subcharts
- [ ] `charts/spark-3.5/values.yaml` includes default overrides for `spark-base`
- [ ] Templates reference `spark-base` helpers (e.g., `{{ include "spark-base.labels" . }}`)
- [ ] `helm lint charts/spark-3.5` passes
- [ ] `scripts/test-spark-standalone.sh` runs successfully with new chart path

**⚠️ WS is NOT complete until Goal is achieved (all AC ✅).**

---

### Context

Feature F04 introduces modular architecture. Existing Spark 3.5.7 charts (`spark-standalone`, `spark-platform`) must be refactored to:
1. Live under `charts/spark-3.5/` as subcharts
2. Leverage `spark-base` for shared infrastructure (RBAC, MinIO, PostgreSQL)

This is a **non-breaking refactor** — all functionality must remain intact.

### Dependency

WS-020-01 (spark-base chart must exist)

### Input Files

**Source (to be moved/refactored):**
- `charts/spark-standalone/` — entire directory
- `charts/spark-platform/` — entire directory (Spark Connect 3.5.7)
- `scripts/test-spark-standalone.sh` — test script to validate

### Steps

1. **Create umbrella chart structure:**
   ```bash
   mkdir -p charts/spark-3.5/charts
   mkdir -p charts/spark-3.5/templates
   ```

2. **Move existing charts:**
   ```bash
   mv charts/spark-standalone charts/spark-3.5/charts/
   mv charts/spark-platform charts/spark-3.5/charts/spark-connect
   ```

3. **Create `charts/spark-3.5/Chart.yaml`:**
   ```yaml
   apiVersion: v2
   name: spark-3.5
   version: 0.1.0
   appVersion: "3.5.7"
   description: Apache Spark 3.5.7 LTS (Standalone + Connect modes)
   
   dependencies:
     - name: spark-base
       version: 0.1.0
       repository: "file://../spark-base"
       condition: spark-base.enabled
   ```

4. **Create `charts/spark-3.5/values.yaml`:**
   ```yaml
   # Shared infrastructure (from spark-base)
   spark-base:
     enabled: true
     rbac:
       create: true
     minio:
       enabled: false
     postgresql:
       enabled: false
     security:
       podSecurityStandards: false
   
   # Spark Standalone subchart
   spark-standalone:
     enabled: true
     # (existing values remain)
   
   # Spark Connect subchart
   spark-connect:
     enabled: false
     # (existing values remain)
   ```

5. **Update subcharts to use `spark-base` helpers:**
   
   In `charts/spark-3.5/charts/spark-standalone/templates/*.yaml`:
   - Replace `{{ include "spark-standalone.labels" . }}` with `{{ include "spark-base.labels" . }}`
   - Replace `{{ include "spark-standalone.podSecurityContext" . }}` with `{{ include "spark-base.podSecurityContext" . }}`
   - Keep subchart-specific helpers (e.g., `spark-standalone.fullname`)

6. **Update MinIO/PostgreSQL references:**
   
   Remove `minio.yaml` and `postgresql-*.yaml` from subcharts (now provided by `spark-base`). Update values to reference parent:
   ```yaml
   # In spark-standalone/values.yaml
   global:
     s3:
       endpoint: "{{ .Release.Name }}-minio:9000"  # Reference spark-base MinIO
   ```

7. **Update test script paths:**
   
   Modify `scripts/test-spark-standalone.sh`:
   ```bash
   # OLD: helm install ... charts/spark-standalone
   # NEW: helm install ... charts/spark-3.5 --set spark-standalone.enabled=true
   ```

8. **Run `helm dependency update`:**
   ```bash
   helm dependency update charts/spark-3.5
   ```

9. **Validate with lint:**
   ```bash
   helm lint charts/spark-3.5
   ```

10. **Run smoke test:**
    ```bash
    ./scripts/test-spark-standalone.sh test-ns test-release
    ```

### Expected Result

**New structure:**
```
charts/spark-3.5/
├── Chart.yaml                                # ~20 LOC
├── values.yaml                               # ~150 LOC
├── charts/
│   ├── spark-base -> ../../spark-base       # symlink or dependency
│   ├── spark-standalone/                     # existing (refactored)
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── templates/ (updated references)
│   └── spark-connect/                        # renamed from spark-platform
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
└── templates/
    └── NOTES.txt                             # ~30 LOC
```

**Removed duplicates:**
- `charts/spark-3.5/charts/spark-standalone/templates/minio.yaml` (now in spark-base)
- `charts/spark-3.5/charts/spark-standalone/templates/postgresql-*.yaml` (now in spark-base)
- `charts/spark-3.5/charts/spark-standalone/templates/_helpers.tpl` (partially, shared helpers moved to spark-base)

### Scope Estimate

- Files: ~5 created, ~20 modified (template references)
- Lines: ~200 LOC new + ~300 LOC refactored = ~500 LOC (MEDIUM)
- Tokens: ~2000

### Completion Criteria

```bash
# Lint umbrella chart
helm lint charts/spark-3.5

# Lint subcharts
helm lint charts/spark-3.5/charts/spark-standalone

# Template render
helm template spark-35 charts/spark-3.5 \
  --set spark-standalone.enabled=true \
  --set spark-base.minio.enabled=true

# Runtime smoke test
./scripts/test-spark-standalone.sh test-ns test-release

# Verify no regression
# (All existing features from F01-F03 must work)
```

### Constraints

- DO NOT change existing functionality (non-breaking refactor)
- DO NOT modify Docker images (`docker/spark/`, `docker/jupyter/`)
- DO NOT change existing values schema (backward compatible)
- Existing deployments using old chart paths should still work (symlinks or docs update)
