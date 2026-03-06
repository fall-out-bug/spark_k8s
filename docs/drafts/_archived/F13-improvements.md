# F13-improvements: Full Load Test Matrix

**Status:** Draft
**Priority:** P1
**Estimated Duration:** 8-12 weeks
**Beads ID:** TBD

## Problem Statement

Current F13 implementation (WS-013-01 through WS-013-05) provides only 20 load test scenarios covering ~1.5% of the required test matrix. The project needs a comprehensive load testing framework that covers:

- 4 Spark versions (3.5.7, 3.5.8, 4.1.0, 4.1.1)
- 2 orchestrators (Airflow, Jupyter)
- 4 Spark modes (Connect, Standalone, k8s workers, k8s operator)
- 4 extension configs (Baseline, Iceberg, Rapids, Iceberg+Rapids)
- 2 data sizes (1GB small, 11GB large NYC taxi parquet)
- 5 operations (Read S3, Aggregate, JOIN, Window, Write Postgres)

**Total matrix: 1,280 test combinations**

## Goals

1. **Automated Minikube Setup**: One-command setup of full test infrastructure (Minio, Postgres, Hive Metastore, History Server, test data)

2. **Matrix-First Test Generation**: YAML-based matrix definition with Jinja2 template generation of all test scenarios

3. **Argo Workflows Orchestration**: Kubernetes-native workflow execution with resource awareness and parallel execution

4. **Comprehensive Metrics Collection**: Three-tier metrics system (Stability, Efficiency, Performance) with automated regression detection

5. **Full Test Coverage**: All 1,280 combinations executable via declarative workflow definitions

## Architecture Decisions

### Decision 1: Test Matrix Dimensions

```
4 versions × 2 orchestrators × 4 modes × 4 extensions × 2 sizes × 5 operations = 1,280 tests
```

**Priority Tiers:**
- P0 (Smoke): 64 tests - baseline + 1GB + read
- P1 (Core): 384 tests - baseline/iceberg + all operations
- P2 (Full): 1,280 tests - all combinations

### Decision 2: Argo Workflows

**Selected over Airflow/GitHub Actions because:**
- Kubernetes-native (CRD-based)
- Declarative YAML workflows (aligns with Helm pattern)
- Built-in resource management (mutex, synchronization)
- Native parallel execution with configurable limits
- Excellent UI for monitoring

### Decision 3: Jinja2 Template Generation

**Approach:**
- Matrix definition in YAML (`priority-matrix.yaml`)
- Jinja2 templates for:
  - Helm values files (`values-scenario-*.yaml`)
  - Load test scenarios (`scenarios/load-*.sh`)
  - Argo workflow definitions (`workflow-*.yaml`)
- Generator script: `generate-matrix.py`

### Decision 4: Data Strategy

**NYC Taxi Datasets:**
- Small: 1GB parquet, date-partitioned + Z-ordered
- Large: 11GB parquet, date-partitioned + Z-ordered
- Stored in Minio (S3-compatible)
- Generated once, versioned by date

### Decision 5: Metrics System

**Three-Tier Hierarchy:**
- Tier 1 (Stability): Pod restarts, OOM, failed tasks → Pass/Fail gate
- Tier 2 (Efficiency): CPU/memory/GPU utilization, shuffle spill → Validity gate
- Tier 3 (Performance): Duration, throughput, latency → Baseline comparison

## Non-Functional Requirements

1. **Maintainability**: All test combinations generated from templates, no manual scenario creation
2. **Scalability**: Support running 100+ tests in parallel with resource awareness
3. **Observability**: All metrics collected and stored for historical analysis
4. **CI/CD Integration**: Triggerable via GitHub Actions with selective tier execution
5. **Resource Efficiency**: Intelligent queue management for Minikube resource constraints

## Out of Scope

- Actual performance optimization (tests detect, not fix)
- Production deployment of Argo Workflows (testing environment only)
- Multi-cluster testing (single Minikube instance)

## Dependencies

- ✅ F06: Helm Charts (completed)
- ✅ F07: Security policies (completed)
- ✅ F09: Docker base images (completed)
- ✅ F10: Docker intermediate layers (completed)
- ✅ F11: Docker runtime images (completed)
- ✅ F12: E2E tests (completed)
- ✅ F13: Initial load tests (completed, this improves it)

## Success Criteria

1. Single command sets up full Minikube infrastructure with test data
2. Matrix YAML defines all 1,280 test combinations declaratively
3. Argo workflow executes any tier (P0/P1/P2) with configurable parallelism
4. All 256 Helm values files generated from templates
5. Load test scenarios cover all 5 operations × 2 data sizes
6. Metrics dashboard shows regression detection across all dimensions
7. Full P2 execution completes in <48 hours with resource-aware queueing

## Open Questions

1. **Storage**: How much Minio storage needed for 1GB + 11GB datasets? (~15GB raw, ~20GB with replication)
2. **Parallelism**: What's the safe max parallel test count for Minikube? (suggested: 5-10)
3. **Retention**: How long to keep test results and logs? (suggested: 30 days)
4. **Baseline**: How many runs to establish initial baseline? (suggested: 5 per combination)
