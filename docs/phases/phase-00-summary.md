# Phase 0: Helm Charts Update - Implementation Plan

**Status:** Design Complete
**Date:** 2026-02-01
**Total Workstreams:** 10
**Estimated LOC:** ~4400

---

## Overview

Phase 0 updates Helm charts (spark-3.5 and spark-4.1) to support GPU, Iceberg, and Spark Connect features through template improvements and preset configurations.

## Critical Design Decisions

### 1. Template Structure: Single Chart with Conditional Logic

**Decision:** Use a single chart with conditional blocks rather than separate sub-charts for each feature.

**Rationale:**
- Reduces chart duplication
- Easier to maintain parity between 3.5 and 4.1
- Simpler for users to enable/disable features
- Template helpers keep complexity manageable

**Implementation:**
- Feature flags in values.yaml (e.g., `connect.features.gpu.enabled`)
- Helper templates for conditional logic
- Minimal code duplication

### 2. Preset Organization: Independent Presets

**Decision:** Create independent presets for each feature combination rather than base + override files.

**Rationale:**
- Clearer intent (baseline, gpu, iceberg, gpu-iceberg)
- Easier to understand what's enabled
- Simpler validation and testing
- No hidden overrides

**Presets:**
```
charts/spark-{version}/presets/
├── baseline.yaml       # Default, no features
├── gpu.yaml            # GPU + RAPIDS only
├── iceberg.yaml        # Iceberg only
└── gpu-iceberg.yaml    # Combined GPU + Iceberg
```

### 3. Documentation Format: README per Chart

**Decision:** Create comprehensive README.md files in each chart directory.

**Rationale:**
- Standard Helm convention
- Easy to find (same location as Chart.yaml)
- Can include code examples
- GitHub renders markdown natively

**Structure:**
- Quick start
- Architecture overview
- Configuration reference
- Feature guides (GPU, Iceberg)
- Troubleshooting
- Migration guide (4.1 only)

### 4. Version Compatibility: Shared Structure, Version-Specific Values

**Decision:** Keep chart structure identical between 3.5 and 4.1, use version-specific values and image tags.

**Rationale:**
- Easier to maintain consistency
- Users can switch versions with minimal changes
- Documentation can be largely shared
- Templates remain similar

## File Structure

### Templates Directory

```
charts/spark-{version}/templates/
├── _helpers.tpl                    # Chart helpers
├── common/
│   └── _labels.tpl                 # Label helpers
├── features/
│   ├── _gpu-resources.tpl          # GPU resource helpers
│   └── _iceberg-config.tpl         # Iceberg config helpers
├── spark-connect.yaml              # Connect deployment + service
├── spark-connect-configmap.yaml    # Connect configuration
├── executor-pod-template-configmap.yaml
├── jupyter.yaml
├── jupyter-pvc.yaml
├── history-server.yaml
├── hive-metastore.yaml
├── hive-metastore-configmap.yaml
├── rbac.yaml
└── ingress.yaml
```

### Presets Directory

```
charts/spark-{version}/presets/
├── baseline.yaml       # Default configuration
├── gpu.yaml            # GPU with RAPIDS
├── iceberg.yaml        # Apache Iceberg
└── gpu-iceberg.yaml    # Combined
```

### Values Structure

```yaml
connect:
  enabled: true
  replicas: 1
  backendMode: k8s  # or standalone
  
  # Feature flags
  features:
    gpu:
      enabled: false
    iceberg:
      enabled: false
  
  # GPU configuration (when enabled)
  executor:
    gpu:
      enabled: false
      count: "1"
      vendor: "nvidia.com/gpu"
      nodeSelector: {}
      tolerations: []
  
  # Iceberg configuration (when enabled)
  features:
    iceberg:
      catalogType: "hadoop"  # hadoop, hive, rest
      warehouse: "s3a://warehouse/iceberg"
      ioImpl: "org.apache.iceberg.hadoop.HadoopFileIO"
  
  # Spark configurations
  sparkConf: {}
```

## Workstream Summary

| ID | Task | LOC | Dependency |
|----|------|-----|------------|
| WS-000-01 | Template structure design | 300 | Independent |
| WS-000-02 | GPU templates | 600 | WS-000-01 |
| WS-000-03 | Iceberg templates | 600 | WS-000-01 |
| WS-000-04 | Connect 3.5 templates | 500 | WS-000-01, WS-000-02, WS-000-03 |
| WS-000-05 | Baseline presets | 400 | WS-000-01 |
| WS-000-06 | GPU presets | 450 | WS-000-01, WS-000-02 |
| WS-000-07 | Iceberg presets | 450 | WS-000-01, WS-000-03 |
| WS-000-08 | GPU+Iceberg presets | 450 | WS-000-01, WS-000-02, WS-000-03, WS-000-06, WS-000-07 |
| WS-000-09 | Spark 3.5 docs | 600 | WS-000-05, WS-000-06, WS-000-07, WS-000-08 |
| WS-000-10 | Spark 4.1 docs | 650 | WS-000-05, WS-000-06, WS-000-07, WS-000-08, WS-000-09 |

## Dependency Graph

```
Phase 1 (Foundation):
    WS-000-01 (Template Structure Design)
        │
        ├─────────────────┐
        │                 │
        ▼                 ▼
Phase 2 (Templates): Phase 3 (Presets):
    WS-000-02 (GPU)      WS-000-05 (Baseline)
    WS-000-03 (Iceberg)  WS-000-06 (GPU)
        │                 WS-000-07 (Iceberg)
        │                     │
        ▼                     ▼
    WS-000-04 (Connect 3.5)  WS-000-08 (Combo)
                                │
                                ▼
                        Phase 4 (Documentation):
                            WS-000-09 (3.5 Docs)
                                │
                                ▼
                            WS-000-10 (4.1 Docs)
```

## Execution Plan

### Week 1: Foundation
1. **WS-000-01** - Design template structure
   - Create ADR document
   - Define file structure
   - Document design decisions

### Week 2: Templates (Parallel)
2. **WS-000-02** - GPU templates
   - Create `_gpu-resources.tpl` helper
   - Update spark-connect.yaml with GPU conditions
3. **WS-000-03** - Iceberg templates
   - Create `_iceberg-config.tpl` helper
   - Update spark-connect-configmap.yaml

### Week 3: Connect 3.5 + Presets Start
4. **WS-000-04** - Connect 3.5 templates
   - Update for feature parity with 4.1
   - Add GPU/Iceberg conditional logic
5. **WS-000-05** - Baseline presets
6. **WS-000-06** - GPU presets
7. **WS-000-07** - Iceberg presets

### Week 4: Combo + Docs
8. **WS-000-08** - GPU+Iceberg combo presets
9. **WS-000-09** - Spark 3.5 documentation
10. **WS-000-10** - Spark 4.1 documentation

## Key Implementation Details

### GPU Template Helper

```yaml
{{- define "spark.gpu.resources" -}}
{{- if and .Values.connect.executor.gpu .Values.connect.executor.gpu.enabled }}
resources:
  limits:
    {{ .Values.connect.executor.gpu.vendor }}: {{ .Values.connect.executor.gpu.count | quote }}
{{- end }}
{{- end }}
```

### Iceberg Template Helper

```yaml
{{- define "spark.iceberg.sparkConf" -}}
{{- if .Values.connect.features.iceberg.enabled }}
spark.sql.extensions: org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions
spark.sql.catalog.iceberg: org.apache.iceberg.spark.SparkCatalog
{{- end }}
{{- end }}
```

### Values for Features

```yaml
connect:
  features:
    gpu:
      enabled: false
    iceberg:
      enabled: false
  
  executor:
    gpu:
      enabled: false
      count: "1"
      vendor: "nvidia.com/gpu"
```

## Success Criteria

Phase 0 is complete when:

1. Templates support GPU, Iceberg, Connect for both 3.5 and 4.1
2. Presets cover all combinations (baseline, gpu, iceberg, gpu-iceberg)
3. Documentation created for both charts
4. `helm template` validates all configurations
5. Backward compatibility maintained (existing values.yaml files work)

## Next Steps After Phase 0

1. **Phase 1:** Smoke test matrix implementation
2. **Phase 2:** E2E test matrix implementation
3. **Phase 3:** Docker test matrix implementation
4. **Phase 4:** Security test implementation

## Related Documentation

- Phase specification: `docs/phases/phase-00-helm-charts.md`
- Test matrices: `docs/smoke-test-matrix.md`, `docs/e2e-test-matrix.md`
- Architecture: `docs/architecture/spark-k8s-charts.md`
- Workstreams: `docs/workstreams/INDEX.md`
