# Load Testing Architecture

Part of WS-013-11: CI/CD Integration & Documentation

## System Overview

The load testing framework provides a comprehensive, automated testing infrastructure for Spark on Kubernetes. It supports 1,280 test combinations across 6 dimensions with automated regression detection.

```
┌─────────────────────────────────────────────────────────────────┐
│                        CI/CD Layer                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │   GitHub     │  │   GitHub     │  │   GitHub     │          │
│  │   Actions    │  │   Actions    │  │   Actions    │          │
│  │  (Smoke)     │  │  (Nightly)   │  │  (Weekly)    │          │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘          │
│         │                  │                  │                  │
│         └──────────────────┴──────────────────┘                  │
│                            │                                     │
└────────────────────────────┼─────────────────────────────────────┘
                             │
┌────────────────────────────┼─────────────────────────────────────┐
│                    Orchestration Layer                            │
│  ┌──────────────────────────┴──────────────────────────┐        │
│  │              Argo Workflows Controller              │        │
│  │  - Matrix generation                                │        │
│  │  - Parallel execution                                │        │
│  │  - Resource synchronization                           │        │
│  └──────────────────────────┬──────────────────────────┘        │
│                             │                                     │
│  ┌──────────────────────────┴──────────────────────────┐        │
│  │              Workflow Templates                      │        │
│  │  - Setup environment                                 │        │
│  │  - Execute workload                                  │        │
│  │  - Collect metrics                                   │        │
│  │  - Generate report                                   │        │
│  └──────────────────────────┬──────────────────────────┘        │
└────────────────────────────┼─────────────────────────────────────┘
                             │
┌────────────────────────────┼─────────────────────────────────────┐
│                      Execution Layer                              │
│  ┌──────────────────────────┴──────────────────────────┐        │
│  │              Test Namespace (per test)               │        │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐ │        │
│  │  │ Spark       │  │ Spark       │  │ Executor    │ │        │
│  │  │ Driver      │  │ Executors   │  │ Pods        │ │        │
│  │  └─────────────┘  └─────────────┘  └─────────────┘ │        │
│  └──────────────────────────┬──────────────────────────┘        │
└────────────────────────────┼─────────────────────────────────────┘
                             │
┌────────────────────────────┼─────────────────────────────────────┐
│                      Infrastructure Layer                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │    Minio     │  │   Postgres   │  │     Hive     │          │
│  │  (S3 Store)  │  │ (Database)   │  │  (Metastore) │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
│  ┌──────────────┐  ┌──────────────┐                          │
│  │ History      │  │ Argo         │                          │
│  │ Server       │  │ Workflows    │                          │
│  └──────────────┘  └──────────────┘                          │
└─────────────────────────────────────────────────────────────────┘
```

## Component Responsibilities

### CI/CD Layer

**GitHub Actions Workflows:**
- `load-test-smoke.yml`: P0 smoke tests on PR (64 combinations, 30min)
- `load-test-nightly.yml`: P1 core tests nightly (384 combinations, 4hr)
- `load-test-weekly.yml`: P2 full matrix weekly (1280 combinations, 48hr)

### Orchestration Layer

**Argo Workflows:**
- Matrix generator: Creates test combinations
- Workflow controller: Manages execution
- Resource synchronization: Prevents cluster overload
- Artifact collection: Gathers logs and metrics

### Execution Layer

**Test Namespaces:**
- Isolated per test run
- Automatic cleanup on completion
- Resource quotas enforced

**Workload Scripts:**
- `read.py`: S3 read operations
- `aggregate.py`: Aggregation workloads
- `join.py`: Self-join operations
- `window.py`: Window function workloads
- `write.py`: Postgres write operations

### Infrastructure Layer

**Storage:**
- Minio: S3-compatible object storage (logs, data)
- Postgres: Test database (write workloads)

**Metadata:**
- Hive Metastore: Table metadata (Iceberg)

**Observability:**
- History Server: Spark event log analysis

## Data Flow

```
1. Matrix Generation
   priority-matrix.yaml → generate-matrix.py → test combinations

2. Workflow Submission
   test combinations → submit-workflow.sh → Argo

3. Environment Setup
   setup-minikube-load-tests.sh → Kubernetes resources

4. Test Execution
   workload script → Spark cluster → data processing

5. Metrics Collection
   Spark events + K8s metrics → collector.py → metrics.jsonl

6. Regression Detection
   current metrics + baseline → regression_detector.py → regression report

7. Report Generation
   metrics → report_generator.py → multi-layer reports
```

## Test Matrix Dimensions

### Dimension 1: Spark Version (2)
- 3.5.0
- 4.1.0

### Dimension 2: Orchestrator (2)
- connect (Spark Connect client mode)
- operator (Spark Operator)

### Dimension 3: Deployment Mode (2)
- kubernetes (classic cluster mode)
- standalone (standalone on K8s)

### Dimension 4: Extensions (4)
- none (core Spark)
- iceberg (Apache Iceberg)
- rapids (NVIDIA RAPIDS GPU)
- iceberg+rapids (both)

### Dimension 5: Operation (5)
- read (S3 read)
- aggregate (aggregation)
- join (self-join)
- window (window functions)
- write (Postgres write)

### Dimension 6: Data Size (2)
- 1gb (NYC taxi 1GB)
- 11gb (NYC taxi 11GB)

**Total Combinations**: 2 × 2 × 2 × 4 × 5 × 2 = 320 × 4 = **1,280**

## Priority Tiers

### P0 Smoke (64 combinations)
- **Purpose**: PR gate, quick validation
- **Timeout**: 30 minutes
- **Dimensions**: Latest versions, core config only

### P1 Core (384 combinations)
- **Purpose**: Nightly regression testing
- **Timeout**: 4 hours
- **Dimensions**: All modes, common extensions

### P2 Full (1,280 combinations)
- **Purpose**: Weekly comprehensive testing
- **Timeout**: 48 hours
- **Dimensions**: All combinations

## Extension Points

### Custom Workloads
Add new workload types to `scripts/tests/load/workloads/`:

```python
# custom_workload.py
def run_custom_workload(spark, data_path, metadata):
    # Implementation
    pass
```

### Custom Metrics
Extend metrics collection in `scripts/tests/load/metrics/collector.py`:

```python
def collect_custom_metrics(self):
    # Custom metric collection
    pass
```

### Custom Reports
Add new report layers in `scripts/tests/load/metrics/report_generator.py`:

```python
def generate_custom_report(self, results):
    # Custom report generation
    pass
```

## Performance Considerations

### Resource Optimization
- **Parallel execution**: Configurable per tier
- **Resource synchronization**: Mutex prevents cluster overload
- **Namespace isolation**: Prevents test interference

### Data Optimization
- **Partitioning**: Data partitioned by year/month
- **Z-ordering**: Optimized for location-based queries
- **Compression**: Snappy compression for Parquet files

### Execution Optimization
- **Dynamic allocation**: Enabled for cluster mode
- **Adaptive query execution**: Enabled by default
- **Broadcast joins**: Configured threshold (10MB)

## Security Considerations

### Credentials
- Minio: `minioadmin/minioadmin` (local only)
- Postgres: `postgres/sparktest` (local only)

### Network Policies
- Test namespaces isolated
- Services cluster-local only

### RBAC
- Dedicated service account for workflows
- Minimal required permissions
