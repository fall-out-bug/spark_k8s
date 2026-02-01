# Phase 7: Load Tests

> **Status:** Ready
> **Priority:** P2 - Производительность
> **Estimated Workstreams:** 5
> **Estimated LOC:** ~3000

## Goal

Создать 20 load сценариев для проверки производительности и стабильности при sustained load (30 min).

## Design Decisions (Approved)

1. **Load Profile:**
   - Sustained load: constant query rate for 30 minutes
   - Baseline: 1 query/second
   - GPU: 0.5-1 query/second (heavier queries)
   - Iceberg: 10 inserts/second, 5 merges/second

2. **Duration Control:**
   - Fixed duration: 30 minutes per test
   - pytest.mark.timeout(2400) — 40 minutes timeout
   - Graceful degradation on errors

3. **Metrics Collection:**
   - throughput_total: total queries executed
   - throughput_avg: average queries/second
   - latency_p50/p95/p99: percentile latencies
   - error_rate: percentage of failed queries
   - GPU-specific: memory, utilization, speedup
   - Iceberg-specific: scan time, snapshot size, file pruning

4. **Resource Limits:**
   - Fixed executor/memory for reproducibility
   - Dynamic allocation disabled
   - Isolated namespaces for load tests

## Workstreams

| WS | Task | Scenarios | Scope | Dependencies |
|----|------|-----------|-------|-------------|
| WS-007-01 | Baseline load (4) | 4 | MEDIUM (~600 LOC) | Phase 0, Phase 6 |
| WS-007-02 | GPU load (4) | 4 | MEDIUM (~600 LOC) | Phase 0, Phase 6 (GPU E2E) |
| WS-007-03 | Iceberg load (4) | 4 | MEDIUM (~600 LOC) | Phase 0, Phase 6 (Iceberg E2E) |
| WS-007-04 | Comparison load (4) | 4 | MEDIUM (~600 LOC) | Phase 0, Phase 6 |
| WS-007-05 | Security stability (4) | 4 | MEDIUM (~600 LOC) | Phase 0, Phase 1 |

**Total Scenarios:** 20 (4 × 5)

## Dependencies

- Phase 0 (Helm charts)
- Phase 6 (E2E tests)

## Success Criteria

1. 20 load сценариев созданы
2. Duration: 30 min sustained для каждого теста
3. Метрики производительности собираются
4. Стабильность подтверждена
5. GPU acceleration проверена при нагрузке
6. Iceberg operations стабильны при нагрузке
7. Security settings стабильны при нагрузке
