## ADR-0004: Modular Chart Architecture for Multi-Version Spark

### Status

Accepted

### Context

The repository already supports Spark 3.5.7 and needs to add Spark 4.1.0.
Key requirements:

- Deploy both versions simultaneously without conflicts
- Share infrastructure (RBAC, MinIO, PostgreSQL) where possible
- Keep version-specific components isolated (Metastore, History Server)
- Allow future versions (4.2, 5.0) without major refactors

### Decision

Adopt a **modular chart architecture**:

```
charts/
├── spark-base/       # Shared infrastructure
├── spark-3.5/        # Spark 3.5.7 LTS
├── spark-4.1/        # Spark 4.1.0
├── celeborn/         # Optional shuffle service
└── spark-operator/   # Optional CRD-based job management
```

Principles:

1. `spark-base` provides shared components (optional dependency).
2. Versioned charts (`spark-3.5`, `spark-4.1`) depend on `spark-base`.
3. Optional components (Celeborn, Operator) remain standalone charts.
4. Version-specific services (Metastore, History Server) are isolated.

### Consequences

**Pros**

- Clear separation of concerns
- No duplication for RBAC/MinIO/PostgreSQL
- Easy to add new Spark versions
- Users can deploy only required components

**Cons**

- More chart dependencies (`helm dependency update`)
- Higher initial learning curve for operators
- Refactoring existing charts required

### Alternatives Considered

**Monolithic chart with version flag**

- Rejected: cannot deploy both versions simultaneously.

**Separate repositories per version**

- Rejected: duplicates shared infrastructure and increases maintenance.
