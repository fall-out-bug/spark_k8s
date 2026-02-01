# Phase 7: Load Tests

> **Status:** Draft
> **Priority:** P2 - Производительность
> **Estimated Workstreams:** 5
> **Estimated LOC:** ~3000

## Goal

Создать 20 load сценариев для проверки производительности и стабильности при sustained load (30 min).

## Critical Design Questions

1. **Load Profile:**
   - Какой load pattern? (sustained, burst, scaling, concurrent)
   - Как измерять "sustained load"?

2. **Duration Control:**
   - Как обеспечить 30 min sustained load?
   - Как обрабатывать fallback/timeout?

3. **Metrics Collection:**
   - Какие метрики собирать? (execution time, throughput, resources, stability)
   - Как сохранять результаты? (JSON + charts)

4. **Resource Limits:**
   - Как ограничить ресурсы для load тестов?
   - Как избежать влияния на другие тесты?

## Proposed Workstreams

| WS | Task | Scope | Dependencies |
|----|------|-------|-------------|
| WS-007-01 | Baseline load (4) | MEDIUM (~600 LOC) | Phase 0, Phase 6 |
| WS-007-02 | GPU load (4) | MEDIUM (~600 LOC) | Phase 0, Phase 6 (GPU E2E) |
| WS-007-03 | Iceberg load (4) | MEDIUM (~600 LOC) | Phase 0, Phase 6 (Iceberg E2E) |
| WS-007-04 | Comparison load (4) | MEDIUM (~600 LOC) | Phase 0, Phase 6 |
| WS-007-05 | Security stability (4) | MEDIUM (~600 LOC) | Phase 0, Phase 1 |

## Dependencies

- Phase 0 (Helm charts)
- Phase 6 (E2E tests)

## Success Criteria

1. ✅ 20 load сценариев созданы
2. ✅ Duration: 30 min sustained
3. ✅ Метрики производительности собираются
4. ✅ Стабильность подтверждена
