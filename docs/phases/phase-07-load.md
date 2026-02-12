# Phase 7: Load Tests

> **Status:** Completed
> **Priority:** P2 - Производительность
> **Feature:** F13
> **Estimated Workstreams:** 5
> **Estimated LOC:** ~3000

## Goal

Создать 20 load сценариев для проверки производительности и стабильности при sustained load (30 min). Валидировать production-ready deployment при продолжительной нагрузке с реальными данными.

## Current State

**Реализовано** — 20 load сценариев в scripts/tests/load/ (baseline, gpu, iceberg, comparison, security).

## Updated Workstreams

| WS | Task | Scenarios | Scope | Dependencies | Status |
|----|------|-----------|-------|-------------|--------|
| WS-013-01 | Baseline load (4) | 4 | MEDIUM (~600 LOC) | Phase 0, Phase 6 | completed |
| WS-013-02 | GPU load (4) | 4 | MEDIUM (~600 LOC) | Phase 0, Phase 6 (GPU E2E) | completed |
| WS-013-03 | Iceberg load (4) | 4 | MEDIUM (~600 LOC) | Phase 0, Phase 6 (Iceberg E2E) | completed |
| WS-013-04 | Comparison load (4) | 4 | MEDIUM (~600 LOC) | Phase 0, Phase 6 | completed |
| WS-013-05 | Security stability (4) | 4 | MEDIUM (~600 LOC) | Phase 0, Phase 1 | completed |

**Total Scenarios:** 20 (4 × 5)

## Design Decisions (Approved)

### 1. Load Profile

**Sustained load: constant query rate for 30 minutes**
- Baseline: 1 query/second
- GPU: 0.5-1 query/second (heavier queries)
- Iceberg: 10 inserts/second, 5 merges/second

### 2. Duration Control

- Fixed duration: 30 minutes per test
- pytest.mark.timeout(2400) — 40 minutes timeout
- Graceful degradation on errors

### 3. Metrics Collection

- **throughput_total**: total queries executed
- **throughput_avg**: average queries/second
- **latency_p50/p95/p99**: percentile latencies
- **error_rate**: percentage of failed queries
- **GPU-specific**: memory, utilization, speedup
- **Iceberg-specific**: scan time, snapshot size, file pruning

### 4. Resource Limits

- Fixed executor/memory for reproducibility
- Dynamic allocation disabled
- Isolated namespaces for load tests

### 5. Test Matrix

**Baseline load (4 scenarios):**
- Spark 3.5.8, 4.1.1 × Airflow × connect-k8s
- Sustained SELECT + aggregations

**GPU load (4 scenarios):**
- Spark 4.1.0, 4.1.1 × Airflow × connect-k8s × GPU
- RAPIDS acceleration under load

**Iceberg load (4 scenarios):**
- Spark 3.5.8, 4.1.1 × Airflow × connect-k8s × Iceberg
- INSERT + MERGE operations

**Comparison load (4 scenarios):**
- 3.5.8 vs 4.1.1 comparison
- Same queries, different versions

**Security stability (4 scenarios):**
- PSS restricted mode under load
- SCC/OpenShift presets under load

## Dependencies

- **Phase 0 (F06):** Helm charts deployed
- **Phase 1 (F07):** Security templates applied
- **Phase 6 (F12):** E2E tests passing

## Success Criteria

1. ✅ 20 load сценариев созданы
2. ⏳ Duration: 30 min sustained для каждого теста
3. ⏳ Метрики производительности собираются
4. ⏳ Стабильность подтверждена (error rate < 1%)
5. ⏳ GPU acceleration проверена при нагрузке
6. ⏳ Iceberg operations стабильны при нагрузке
7. ⏳ Security settings стабильны при нагрузке

## File Structure

```
tests/load/
├── conftest.py              # Load test fixtures
├── pytest.ini                # Pytest configuration (timeout 2400)
├── queries/
│   ├── baseline_select.sql
│   ├── baseline_aggregation.sql
│   ├── gpu_ml.sql
│   └── iceberg_merge.sql
├── metrics/
│   ├── collector.py          # Metrics collection
│   └── reporter.py           # Report generation
├── baseline/
│   ├── test_baseline_load_358.py
│   ├── test_baseline_load_411.py
│   └── ...
├── gpu/
│   ├── test_gpu_load_410.py
│   └── test_gpu_load_411.py
├── iceberg/
│   ├── test_iceberg_load_358.py
│   └── test_iceberg_load_411.py
├── comparison/
│   └── test_version_comparison.py
└── security/
    ├── test_pss_stability.py
    └── test_scc_stability.py
```

## Integration with Other Phases

- **Phase 0 (F06):** Charts provide deployment base
- **Phase 1 (F07):** Security ensures stability under load
- **Phase 6 (F12):** E2E tests provide baseline scenarios

## Beads Integration

```bash
# Feature
spark_k8s-xxx - F13: Phase 7 - Load Tests (P2)

# Workstreams
spark_k8s-xxx - WS-013-01: Baseline load (P2)
spark_k8s-xxx - WS-013-02: GPU load (P2)
spark_k8s-xxx - WS-013-03: Iceberg load (P2)
spark_k8s-xxx - WS-013-04: Comparison load (P2)
spark_k8s-xxx - WS-013-05: Security stability (P2)

# Dependencies
All WS depend on F06, F07, F12
```

## References

- [PRODUCT_VISION.md](../../PRODUCT_VISION.md)
- [workstreams/INDEX.md](../workstreams/INDEX.md)
- [phase-06-e2e.md](./phase-06-e2e.md)
- [phase-01-security.md](./phase-01-security.md)
