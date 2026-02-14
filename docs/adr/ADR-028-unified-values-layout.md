# ADR-028: Unified Values Layout for Core Components

## Status

Accepted

## Context

Spark 3.5 and Spark 4.1 charts both include PostgreSQL and Hive Metastore as core infrastructure. Previously:

- **spark-4.1**: Uses `core.postgresql` and `core.hiveMetastore` (unified layout)
- **spark-3.5**: Uses `core.postgresql` and `core.hiveMetastore` for templates in `templates/core/`, plus legacy `hiveMetastore` at root
- **spark-base**: Uses flat `postgresql` (different path), no Hive Metastore

This caused duplication of postgresql-deployment and hive-metastore templates across charts.

## Decision

1. **Standardize on `core.*` layout** — Both spark-3.5 and spark-4.1 already use `core.postgresql` and `core.hiveMetastore` for core templates. spark-base adopts this layout.

2. **Extract shared templates to spark-base** — `postgresql-deployment.yaml` and `hive-metastore-deployment.yaml` (plus configmap, service) move to `charts/spark-base/templates/core/`.

3. **Values flow** — Parent charts (spark-3.5, spark-4.1) pass `core` to spark-base via the dependency override:
   ```yaml
   spark-base:
     core:
       postgresql: ...   # from parent's core.postgresql
       hiveMetastore: ... # from parent's core.hiveMetastore
     rbac:
       serviceAccountName: "spark-41"  # or "spark-35"
   ```
   Use YAML anchors in parent values to avoid duplication.

4. **Database name** — Default database name differs per chart (`metastore_spark41` vs `metastore_spark35`). Parent sets `core.hiveMetastore.database.name` in values; template uses `{{ .Values.core.hiveMetastore.database.name | default "metastore" }}`.

5. **ServiceAccount** — spark-base templates use `.Values.rbac.serviceAccountName` (passed from parent via `spark-base.rbac.serviceAccountName`).

## Consequences

**Pros**

- Single source of truth for PostgreSQL and Hive Metastore templates
- Consistent values structure across spark-3.5 and spark-4.1
- Easier maintenance and fewer drift issues

**Cons**

- **Breaking change** for spark-base standalone users who relied on `postgresql.*` path — document migration in release notes
- Legacy `hiveMetastore` root key in spark-3.5 remains for backward compat; phase out in future WS

## Migration (spark-base standalone)

If using spark-base with `postgresql.enabled: true`:

- Migrate to `core.postgresql` layout, or
- Continue using `postgresql.*` for spark-base's own postgresql.yaml (unchanged); new core templates use `core.*` only when parent passes them

## Notes

- `charts/spark-base/templates/postgresql.yaml` (flat `postgresql`) remains for backward compat with spark-base standalone.
- New `charts/spark-base/templates/core/` contains shared templates consumed when parent passes `core` via `spark-base.core`.
