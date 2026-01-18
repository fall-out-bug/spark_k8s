## WS-020-01: Create `spark-base` Chart (Shared Infrastructure)

### 🎯 Goal

**What should WORK after WS completion:**
- Helm chart `charts/spark-base/` exists with reusable templates for RBAC, MinIO, PostgreSQL, and shared helpers
- Templates are parameterized and can be included by `spark-3.5` and `spark-4.1` charts
- `helm lint charts/spark-base` passes without errors

**Acceptance Criteria:**
- [ ] `charts/spark-base/Chart.yaml` defines chart metadata (version 0.1.0, appVersion N/A)
- [ ] `charts/spark-base/values.yaml` contains default configurations for RBAC, MinIO, PostgreSQL
- [ ] `charts/spark-base/templates/rbac.yaml` defines ServiceAccount, Role, RoleBinding
- [ ] `charts/spark-base/templates/minio.yaml` defines optional MinIO Deployment + Service + init job
- [ ] `charts/spark-base/templates/postgresql.yaml` defines optional PostgreSQL StatefulSet + Service
- [ ] `charts/spark-base/templates/_helpers.tpl` defines shared helper functions (labels, selectors, security contexts)
- [ ] `helm lint charts/spark-base` passes

**⚠️ WS is NOT complete until Goal is achieved (all AC ✅).**

---

### Context

Feature F04 introduces a modular architecture for multi-version Spark support. The `spark-base` chart acts as a shared foundation, providing common infrastructure components (storage, metadata DB, RBAC) that can be reused by version-specific charts (`spark-3.5`, `spark-4.1`).

This workstream extracts reusable patterns from existing `spark-standalone` and `spark-platform` charts.

### Dependency

Independent (first WS in F04)

### Input Files

**Reference for extraction:**
- `charts/spark-standalone/templates/rbac.yaml` — RBAC patterns
- `charts/spark-standalone/templates/minio.yaml` — MinIO deployment + init job
- `charts/spark-standalone/templates/postgresql-metastore.yaml` — PostgreSQL template
- `charts/spark-standalone/templates/_helpers.tpl` — Helper functions (PSS security contexts, labels)
- `charts/spark-standalone/values.yaml` — Configuration structure

### Steps

1. Create `charts/spark-base/` directory structure:
   ```
   charts/spark-base/
   ├── Chart.yaml
   ├── values.yaml
   └── templates/
       ├── _helpers.tpl
       ├── rbac.yaml
       ├── minio.yaml
       └── postgresql.yaml
   ```

2. **Chart.yaml**: Define metadata
   - name: `spark-base`
   - version: `0.1.0`
   - appVersion: `N/A` (infrastructure chart)
   - description: "Shared infrastructure for Spark deployments"

3. **values.yaml**: Extract common configs
   ```yaml
   global:
     imagePullSecrets: []
   
   rbac:
     create: true
     serviceAccountName: "spark"
   
   minio:
     enabled: false
     image:
       repository: minio/minio
       tag: "RELEASE.2024-01-01T16-36-33Z"
     service:
       port: 9000
     buckets:
       - spark-logs
       - spark-data
   
   postgresql:
     enabled: false
     image:
       repository: postgres
       tag: "15"
     persistence:
       enabled: true
       size: "8Gi"
     databases: []  # List of DB names to create
   
   security:
     podSecurityStandards: false
   ```

4. **templates/_helpers.tpl**: Copy and adapt helpers from `spark-standalone`:
   - `spark-base.fullname`
   - `spark-base.labels`
   - `spark-base.selectorLabels`
   - `spark-base.podSecurityContext`
   - `spark-base.containerSecurityContext`
   - `spark-base.serviceAccountName`

5. **templates/rbac.yaml**: Extract RBAC (parameterized)
   - ServiceAccount with `{{ .Values.rbac.serviceAccountName }}`
   - Role with permissions: `pods`, `services`, `configmaps` (list, get, create, delete)
   - RoleBinding

6. **templates/minio.yaml**: Extract MinIO template
   - Conditional on `{{ if .Values.minio.enabled }}`
   - Deployment with configurable replicas, resources
   - Service (ClusterIP, port 9000)
   - Init job (Helm hook `post-install,post-upgrade`) to create buckets
   - Use `.Values.minio.buckets` loop to create buckets dynamically

7. **templates/postgresql.yaml**: Extract PostgreSQL template
   - Conditional on `{{ if .Values.postgresql.enabled }}`
   - StatefulSet with PVC template
   - Service (ClusterIP, port 5432)
   - ConfigMap for init scripts (create databases from `.Values.postgresql.databases` list)
   - Secret for credentials (`POSTGRES_PASSWORD`)

8. Validate with `helm lint`:
   ```bash
   helm lint charts/spark-base
   ```

### Expected Result

```
charts/spark-base/
├── Chart.yaml                  # ~15 LOC
├── values.yaml                 # ~80 LOC
└── templates/
    ├── _helpers.tpl            # ~120 LOC
    ├── rbac.yaml               # ~60 LOC
    ├── minio.yaml              # ~150 LOC
    └── postgresql.yaml         # ~120 LOC
```

### Scope Estimate

- Files: 6 created
- Lines: ~545 LOC (MEDIUM)
- Tokens: ~2200

### Completion Criteria

```bash
# Lint check
helm lint charts/spark-base

# Template render (dry-run)
helm template spark-base charts/spark-base --debug

# Check all templates render correctly
helm template spark-base charts/spark-base \
  --set minio.enabled=true \
  --set postgresql.enabled=true \
  --set security.podSecurityStandards=true
```

### Constraints

- DO NOT include application-specific logic (Spark Master, Workers, etc.)
- DO NOT hardcode credentials (use parameterized secrets)
- DO NOT create NOTES.txt (reserved for version-specific charts)
- Templates MUST support PSS `restricted` when `security.podSecurityStandards=true`

---

### Execution Report

**Executed by:** gpt-5.2-codex-high  
**Date:** 2026-01-18

#### 🎯 Goal Status

- [x] AC1: `charts/spark-base/Chart.yaml` defines chart metadata — ✅
- [x] AC2: `charts/spark-base/values.yaml` contains RBAC/MinIO/PostgreSQL defaults — ✅
- [x] AC3: `templates/rbac.yaml` defines ServiceAccount, Role, RoleBinding — ✅
- [x] AC4: `templates/minio.yaml` defines MinIO Deployment + Service + init job — ✅
- [x] AC5: `templates/postgresql.yaml` defines PostgreSQL StatefulSet + Service — ✅
- [x] AC6: `templates/_helpers.tpl` defines shared helper functions — ✅
- [x] AC7: `helm lint charts/spark-base` passes — ✅

**Goal Achieved:** ✅ YES

#### Modified Files

| File | Action | LOC |
|------|--------|-----|
| `charts/spark-base/Chart.yaml` | created | 6 |
| `charts/spark-base/values.yaml` | created | 68 |
| `charts/spark-base/templates/_helpers.tpl` | created | 91 |
| `charts/spark-base/templates/rbac.yaml` | created | 47 |
| `charts/spark-base/templates/minio.yaml` | created | 190 |
| `charts/spark-base/templates/postgresql.yaml` | created | 126 |

#### Completed Steps

- [x] Created `spark-base` chart structure and metadata
- [x] Implemented shared helpers (labels, selectors, security contexts)
- [x] Added RBAC resources (ServiceAccount, Role, RoleBinding)
- [x] Added MinIO deployment/service/init job
- [x] Added PostgreSQL StatefulSet/service/init scripts
- [x] Ran helm lint and render checks

#### Self-Check Results

```bash
$ helm lint charts/spark-base
1 chart(s) linted, 0 chart(s) failed

$ helm template spark-base charts/spark-base --debug
# Render succeeded

$ helm template spark-base charts/spark-base \
  --set minio.enabled=true \
  --set postgresql.enabled=true \
  --set security.podSecurityStandards=true
# Render succeeded

$ hooks/post-build.sh WS-020-01
Skipping tests/coverage/linters for this repo layout
```

#### Issues

None.
