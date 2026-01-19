## ADR-0007: Version-Specific Hive Metastores (No Migration)

### Status

Accepted

### Context

Hive Metastore schemas differ between Hive 3.1.3 (Spark 3.5.7) and
Hive 4.0.0 (Spark 4.1.0). In-place upgrades are risky, and the project
requires running both Spark versions simultaneously during migration.

### Decision

Use **separate Hive Metastores per Spark version**:

- Spark 3.5.7 → Hive 3.1.3 → DB `metastore_spark35`
- Spark 4.1.0 → Hive 4.0.0 → DB `metastore_spark41`

No automatic metadata migration is provided. Users can recreate tables
manually while keeping data in S3.

### Consequences

**Pros**

- Safe coexistence without schema conflicts
- Easy rollback to Spark 3.5.7
- No risk of corrupting existing metadata

**Cons**

- Table definitions must be recreated for 4.1.0
- Duplicate metadata during migration period

### Alternatives Considered

**Shared metastore with in-place upgrade**

- Rejected: breaks Spark 3.5.7 compatibility and has no rollback.

**Automatic migration tool**

- Rejected: out of scope for F04.
