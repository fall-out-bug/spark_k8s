# UAT: F06 Core Components + Feature Presets

**Feature:** F06 - Phase 0 Core Components + Feature Presets  
**Review Date:** 2026-02-10

---

## Overview

F06 provides unified Helm chart structure for Spark 3.5 and 4.1 with Core Components (MinIO, PostgreSQL, Hive Metastore, History Server) and feature presets (GPU, Iceberg). All preset combinations validate with `helm template`.

---

## Prerequisites

- `helm` 3.x
- `kubectl` (optional, for deployment validation)

---

## Quick Verification (2 minutes)

### Smoke Test

```bash
# Validate spark-4.1 core-baseline (quick)
helm template test charts/spark-4.1 -f charts/spark-4.1/presets/core-baseline.yaml >/dev/null && echo "OK" || echo "FAIL"

# Validate all 8 spark-4.1 presets
for f in charts/spark-4.1/presets/core-*.yaml charts/spark-4.1/presets/scenarios/*.yaml; do
  helm template test charts/spark-4.1 -f "$f" >/dev/null || echo "FAIL: $f"
done
# Expected: no FAIL output
```

### Quick Check

```bash
helm template test charts/spark-4.1 -f charts/spark-4.1/presets/core-baseline.yaml | head -20
# Expected: valid YAML output (ServiceAccount, Namespace, etc.)
```

---

## Detailed Scenarios

### Scenario 1: Core Baseline

```bash
helm template test charts/spark-4.1 -f charts/spark-4.1/presets/core-baseline.yaml
# Verify: minio, postgresql, hive-metastore, history-server resources present
```

### Scenario 2: GPU Preset

```bash
helm template test charts/spark-4.1 -f charts/spark-4.1/presets/core-gpu.yaml
# Verify: GPU resources, nvidia.com/gpu in executor template
```

### Scenario 3: Iceberg Preset

```bash
helm template test charts/spark-4.1 -f charts/spark-4.1/presets/core-iceberg.yaml
# Verify: Iceberg catalog config, iceberg-*.jar references
```

### Scenario 4: Jupyter Connect K8s

```bash
helm template test charts/spark-4.1 -f charts/spark-4.1/presets/scenarios/jupyter-connect-k8s.yaml
# Verify: Jupyter deployment, Spark Connect config
```

---

## Red Flags

| # | Red Flag | Where to Check | Severity |
|---|----------|----------------|----------|
| 1 | helm template fails | stderr | HIGH |
| 2 | Nil pointer in template | vpa/keda/hpa sections | HIGH |
| 3 | Missing core components | output YAML | MEDIUM |
| 4 | TODO/FIXME in charts | grep | MEDIUM |

---

## Code Sanity Checks

```bash
# No TODO/FIXME
grep -rn "TODO\|FIXME" charts/spark-3.5/ charts/spark-4.1/ --include="*.yaml" --include="*.tpl"
# Expected: empty

# Presets exist
ls charts/spark-3.5/presets/core-*.yaml charts/spark-4.1/presets/core-*.yaml
# Expected: 8 files (4 per chart)

# All presets validate
helm template test charts/spark-3.5 -f charts/spark-3.5/presets/core-baseline.yaml >/dev/null
helm template test charts/spark-4.1 -f charts/spark-4.1/presets/core-baseline.yaml >/dev/null
# Expected: exit 0
```

---

## Sign-off Checklist

- [ ] All 16 presets pass helm template
- [ ] Red flags absent
- [ ] Code sanity checks passed
- [ ] README documents quick start

---

## Related Documents

- Feature spec: `docs/intent/f06-core-components-presets.json`
- Workstreams: `docs/workstreams/completed/WS-006-*.md`
- Review report: `docs/reports/review-F06-2026-02-10.md`
