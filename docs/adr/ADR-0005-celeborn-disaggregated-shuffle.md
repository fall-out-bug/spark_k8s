## ADR-0005: Apache Celeborn for Disaggregated Shuffle

### Status

Accepted

### Context

Large Spark 4.1.0 workloads with heavy shuffle (>100GB) can suffer:

- OOM failures when executors die (shuffle data lost)
- Shuffle fetch failures under dynamic allocation
- Poor resilience with spot/preemptible executors

Apache Celeborn provides disaggregated shuffle:

- Shuffle data stored outside executors (Celeborn workers)
- Executors can fail without losing shuffle data
- Optimizations for skewed partitions

### Decision

Include **Celeborn as an optional component**:

- Deploy via standalone `celeborn` Helm chart
- Integrate with `spark-4.1` when `celeborn.enabled=true`
- Do not enable by default (opt-in)

Use cases:

- ✅ Production jobs with large shuffle
- ✅ Spot instances or dynamic allocation
- ✅ Frequent shuffle failures

Skip for:

- ❌ Dev/testing
- ❌ Small datasets (<10GB)
- ❌ Spark Standalone (use External Shuffle Service)

### Consequences

**Pros**

- Improved stability for large shuffles
- Better support for spot instances
- Potential performance gains

**Cons**

- Additional infrastructure (masters + workers)
- More storage requirements (PVCs)
- Operational complexity (monitoring, tuning)

### Alternatives Considered

**Standard Spark shuffle**

- Rejected: does not address OOM/fetch failures for large shuffles.

**External Shuffle Service (ESS)**

- Rejected: deprecated in Spark 4.x; Celeborn is preferred.
