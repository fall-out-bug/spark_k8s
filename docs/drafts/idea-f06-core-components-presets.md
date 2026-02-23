# Feature F06: Phase 0 — Core Components + Feature Presets

> **Feature ID:** F06
> **Status:** Draft
> **Created:** 2026-02-02

## Problem

**Current State:** Spark K8s Constructor has completed features F01-F05, but Phase 0 foundation work is needed. Updated PRODUCT_VISION.md emphasizes Core Components (Hive Metastore, Minio, History Server) as mandatory for any build and testing.

**Gap:** No unified approach to Core Components across Spark 3.5 and 4.1 charts. DevOps Engineers (primary users) need production-ready configurations with Core Components as foundation, not optional add-ons.

## Users

**Primary:** DevOps Engineers — Need production-ready infrastructure with mandatory Core Components
- Must understand how to deploy and configure Hive Metastore, Minio, History Server
- Need clear documentation on component interaction
- Require validated Helm templates

**Secondary:** Data Engineers/Leads — Need preset configurations for different scenarios
- k8s backend mode for power users
- standalone backend mode for conservative approaches
- operator mode for advanced scheduling

**Tertiary:** Data Scientists/Analysts — Need Spark Connect + Jupyter with working backends
- pandas-like experience without K8s complexity
- Pre-configured storage and metadata

## Success Criteria

### Primary
- [ ] **Helm Template Validation**: All preset combinations pass `helm template --validate`
  - Core Components only (baseline)
  - Core + GPU
  - Core + Iceberg
  - Core + GPU + Iceberg

### Secondary
- [ ] **Time to First Spark**: `< 5 minutes` from `git clone` to working Spark Connect with Core Components
- [ ] **Documentation Coverage**: 100% of Core Components scenarios documented with examples
- [ ] **Backward Compatibility**: Existing values.yaml files continue to work

## Goals

### Primary Goals
1. **Core Components as Foundation** — Hive Metastore, Minio, History Server mandatory in all presets
2. **GPU/Iceberg as Optional Features** — Add via feature flags, not separate charts
3. **Hybrid Presets** — Core base + feature/scenario combinations
4. **Template Validation** — All combinations validated with `helm template --validate`

### Secondary Goals
1. **Documentation** — README for each chart with Core Components first
2. **Backward Compatibility** — Existing deployments continue to work
3. **OpenShift Ready** — PSS `restricted` / SCC `restricted` compatible

## Non-Goals

- **Spark Education** — Not teaching how to write Spark jobs or tune queries
- **Managed Service** — Operations (patching, updates) are user responsibility
- **All Integrations** — Only typical scenarios: Jupyter, Airflow, MLflow
- **Custom Presets** — Users create custom values based on documented patterns

## Technical Approach

### Architecture Decision: Single Chart with Conditional Logic

**Rationale:**
- Reduces chart duplication between 3.5 and 4.1
- Core Components always enabled, features optional via flags
- Simpler for DevOps to understand (one chart, clear separation)

**Implementation:**
```yaml
# Core Components (always present)
core:
  components:
    hiveMetastore:
      enabled: true  # Can be disabled but default true
    minio:
      enabled: true  # Can be disabled but default true
    historyServer:
      enabled: true  # Can be disabled but default true

# Optional Features
features:
  gpu:
    enabled: false
  iceberg:
    enabled: false
```

### Preset Structure

**Hybrid Approach:** Core base + feature combinations

```
charts/spark-{version}/presets/
├── core-baseline.yaml           # Core Components only
├── core-gpu.yaml                # Core + GPU
├── core-iceberg.yaml            # Core + Iceberg
├── core-gpu-iceberg.yaml        # Core + GPU + Iceberg
└── scenarios/
    ├── jupyter-connect-k8s.yaml     # Core + Jupyter + Connect (k8s)
    ├── airflow-connect-k8s.yaml     # Core + Airflow + Connect (k8s)
    └── airflow-connect-standalone.yaml  # Core + Airflow + Connect (standalone)
```

### Template Helpers

**Core Components:**
- `templates/core/_hive-metastore.tpl` — Hive Metastore deployment + service
- `templates/core/_minio.tpl` — Minio deployment + service + buckets
- `templates/core/_history-server.tpl` — History Server deployment + service

**Features (optional):**
- `templates/features/_gpu-resources.tpl` — GPU resource helpers
- `templates/features/_iceberg-config.tpl` — Iceberg config helpers

### Values Structure

```yaml
# Core Components (default: enabled)
core:
  hiveMetastore:
    enabled: true
    # ... configuration
  minio:
    enabled: true
    # ... configuration
  historyServer:
    enabled: true
    # ... configuration

# Optional Features
features:
  gpu:
    enabled: false
    executor:
      count: "1"
      vendor: "nvidia.com/gpu"
  iceberg:
    enabled: false
    catalogType: "hadoop"
    warehouse: "s3a://warehouse/iceberg"

# Spark Connect (optional)
connect:
  enabled: false
  backendMode: k8s  # k8s | standalone | operator

# Optional Components
jupyter:
  enabled: false
airflow:
  enabled: false
```

## Dependencies

**None** — Independent feature, foundation for subsequent phases

## Related Documentation

- [PRODUCT_VISION.md](../../PRODUCT_VISION.md) — Updated project vision
- [phase-00-summary.md](../phases/phase-00-summary.md) — Original Phase 0 plan (to be updated)
- [architecture/spark-k8s-charts.md](../architecture/spark-k8s-charts.md) — Chart architecture
