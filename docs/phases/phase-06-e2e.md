# Phase 6: E2E Tests

> **Status:** Ready
> **Priority:** P1 - Полная проверка
> **Estimated Workstreams:** 6
> **Estimated LOC:** ~4900

## Goal

Создать 80 E2E сценариев с полным датасетом (NYC Taxi 11GB) для всех комбинаций версий, компонентов, режимов и фич.

## Design Decisions (Approved)

1. **Dataset Management:**
   - NYC Taxi full dataset (11GB) хранится в S3/MinIO
   - Sample dataset (1GB) для быстрых тестов
   - Датасет загружается через fixtures в conftest.py

2. **Query Set:**
   - 4 стандартных SQL запроса для всех сценариев:
     - Q1: SELECT COUNT(*) — validate row count
     - Q2: GROUP BY aggregation — validate aggregation
     - Q3: JOIN with filter — validate join performance
     - Q4: Window function — validate complex queries

3. **Duration Control:**
   - Timeout для каждого теста: 600-1200 секунд
   - pytest.mark.timeout decorator
   - Timeout fixtures в conftest.py

4. **Metrics Collection:**
   - execution_time: время выполнения query
   - throughput: rows/second
   - memory_used: peak memory (GPU, executor)
   - gpu_utilization: GPU usage percentage
   - additional metrics для специфических сценариев

## Workstreams

| WS | Task | Scenarios | Scope | Dependencies |
|----|------|-----------|-------|-------------|
| WS-006-01 | Core E2E | 24 | LARGE (~1500 LOC) | Phase 0, Phase 1, Phase 5 |
| WS-006-02 | GPU E2E | 16 | MEDIUM (~900 LOC) | Phase 0, Phase 5 (GPU images) |
| WS-006-03 | Iceberg E2E | 16 | MEDIUM (~900 LOC) | Phase 0, Phase 5 (Iceberg images) |
| WS-006-04 | GPU+Iceberg E2E | 8 | MEDIUM (~500 LOC) | Phase 0, Phase 5 (GPU+Iceberg) |
| WS-006-05 | Standalone E2E | 8 | MEDIUM (~500 LOC) | Phase 0, Phase 1 |
| WS-006-06 | Library compatibility | 8 | MEDIUM (~600 LOC) | Phase 0, Phase 1 |

**Total Scenarios:** 80 (24 + 16 + 16 + 8 + 8 + 8)

## Dependencies

- Phase 0 (Helm charts)
- Phase 1 (Security)
- Phase 5 (Final images)

## Success Criteria

1. 80 E2E сценариев созданы
2. NYC Taxi full dataset (11GB) используется
3. Все сценарии проходят
4. Метрики собираются корректно
5. GPU acceleration проверен (RAPIDS)
6. Iceberg table operations проверены
7. Standalone cluster проверен
8. Library compatibility matrix создана
