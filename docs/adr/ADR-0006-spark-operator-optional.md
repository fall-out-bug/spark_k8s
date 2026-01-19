## ADR-0006: Spark Operator as Optional Component

### Status

Accepted

### Context

Spark jobs can be submitted in multiple ways:

1. `spark-submit` (CLI/manual)
2. Spark Connect (interactive client/server)
3. Spark Operator (CRD-based, declarative)

Target users:

- Data Scientists: Jupyter + Spark Connect
- DataOps/Engineers: GitOps-friendly job management

### Decision

Include **Spark Operator as an optional component**:

- Deploy via standalone `spark-operator` Helm chart
- Provides `SparkApplication` CRDs
- Not required for Spark Connect usage

Intended for:

- GitOps workflows (ArgoCD, Flux)
- Production batch jobs (scheduled/triggered)
- Teams that want lifecycle management

### Consequences

**Pros**

- Declarative job management
- GitOps-ready job definitions
- Automatic lifecycle (submit/monitor/cleanup)
- Webhook validation

**Cons**

- Additional complexity (CRDs, operator, webhook)
- Learning curve for teams new to operators
- Requires ClusterRole for CRD management

### Alternatives Considered

**Operator required for all deployments**

- Rejected: too heavy for DS workflows.

**No Operator support**

- Rejected: misses GitOps use cases.
