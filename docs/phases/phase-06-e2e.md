# Phase 6: E2E Tests

> **Status:** Completed
> **Priority:** P1 - Полная проверка
> **Feature:** F12
> **Estimated Workstreams:** 6
> **Estimated LOC:** ~4900

## Goal

Создать 80 E2E сценариев с полным датасетом (NYC Taxi 11GB) для всех комбинаций версий Spark, компонентов, режимов и фич. Валидировать production-ready deployment с реальными данными.

## Current State

**Реализовано** — 80 E2E сценариев в scripts/tests/e2e/ (Core, GPU, Iceberg, GPU+Iceberg, Standalone, Compatibility).

## Updated Workstreams

| WS | Task | Scenarios | Scope | Dependencies | Status |
|----|------|-----------|-------|-------------|--------|
| WS-012-01 | Core E2E | 24 | LARGE (~1500 LOC) | Phase 0, Phase 1, Phase 5 | completed |
| WS-012-02 | GPU E2E | 16 | MEDIUM (~900 LOC) | Phase 0, Phase 5 (GPU images) | completed |
| WS-012-03 | Iceberg E2E | 16 | MEDIUM (~900 LOC) | Phase 0, Phase 5 (Iceberg images) | completed |
| WS-012-04 | GPU+Iceberg E2E | 8 | MEDIUM (~500 LOC) | Phase 0, Phase 5 (GPU+Iceberg) | completed |
| WS-012-05 | Standalone E2E | 8 | MEDIUM (~500 LOC) | Phase 0, Phase 1 | completed |
| WS-012-06 | Library compatibility | 8 | MEDIUM (~600 LOC) | Phase 0, Phase 1 | completed |

**Total Scenarios:** 80 (24 + 16 + 16 + 8 + 8 + 8)

## Design Decisions (Approved)

### 1. Dataset Management

**NYC Taxi full dataset (11GB):**
- Хранение в S3/MinIO
- Фикстуры для загрузки в conftest.py
- Препроцессинг для тестов

**Sample dataset (1GB):**
- Для быстрых smoke tests
- Тот же формат что полный датасет
- Хранение в MinIO

### 2. Query Set

**4 стандартных SQL запроса для всех сценариев:**
- Q1: SELECT COUNT(*) — validate row count
- Q2: GROUP BY aggregation — validate aggregation
- Q3: JOIN with filter — validate join performance
- Q4: Window function — validate complex queries

### 3. Duration Control

- Timeout для каждого теста: 600-1200 секунд
- pytest.mark.timeout decorator
- Timeout fixtures в conftest.py

### 4. Metrics Collection

- **execution_time**: время выполнения query
- **throughput**: rows/second
- **memory_used**: peak memory (GPU, executor)
- **gpu_utilization**: GPU usage percentage
- **additional_metrics**: для специфических сценариев

### 5. Test Matrix

**Core E2E (24 scenarios):**
- Spark 3.5.7, 3.5.8 × Jupyter, Airflow × k8s-submit, connect-k8s
- Baseline scenarios с полным датасетом

**GPU E2E (16 scenarios):**
- Spark 4.1.0, 4.1.1 × Jupyter, Airflow × connect-k8s × GPU
- RAPIDS acceleration validation

**Iceberg E2E (16 scenarios):**
- Spark 3.5.7, 3.5.8, 4.1.0, 4.1.1 × Airflow × connect-k8s × Iceberg
- Table operations validation

**GPU+Iceberg E2E (8 scenarios):**
- Spark 4.1.0, 4.1.1 × Airflow × connect-k8s × GPU+Iceberg
- Combined feature validation

**Standalone E2E (8 scenarios):**
- Spark 3.5.7, 3.5.8 × Jupyter, Airflow × standalone-submit
- Standalone cluster validation

**Library Compatibility (8 scenarios):**
- Разные версии библиотек (pandas, numpy, pyarrow)
- Version matrix validation

## Dependencies

- **Phase 0 (F06):** Helm charts deployed
- **Phase 1 (F07):** Security templates applied
- **Phase 5 (F11):** Final runtime images available

## Success Criteria

1. ✅ 80 E2E сценариев созданы
2. ⏳ NYC Taxi full dataset (11GB) используется
3. ⏳ Все сценарии проходят (timeout < 1200s)
4. ⏳ Метрики собираются корректно
5. ⏳ GPU acceleration проверен (RAPIDS vs CPU)
6. ⏳ Iceberg table operations проверены
7. ⏳ Standalone cluster проверен
8. ⏳ Library compatibility matrix создана

## File Structure

```
tests/e2e/
├── conftest.py              # Pytest fixtures, dataset loading
├── conftest_lakefs.py        # MinIO/S3 fixtures
├── pytest.ini                # Pytest configuration
├── queries/
│   ├── q1_count.sql
│   ├── q2_aggregation.sql
│   ├── q3_join.sql
│   └── q4_window.sql
├── data/
│   └── nyc-taxi/
│       ├── fixtures.py      # Dataset download/prep
│       └── schema.py         # Schema definition
├── core/
│   ├── test_jupyter_k8s.py
│   ├── test_airflow_connect_k8s.py
│   └── ...
├── gpu/
│   ├── test_jupyter_gpu.py
│   └── test_airflow_gpu.py
├── iceberg/
│   └── test_airflow_iceberg.py
├── standalone/
│   ├── test_jupyter_standalone.py
│   └── test_airflow_standalone.py
└── compatibility/
    └── test_library_versions.py
```

## Integration with Other Phases

- **Phase 0 (F06):** Charts provide deployment base
- **Phase 1 (F07):** Security ensures PSS compliance
- **Phase 2 (F08):** Smoke tests validate basic functionality
- **Phase 3 (F09):** Base images provide runtime
- **Phase 4 (F10):** Intermediate layers provide components
- **Phase 5 (F11):** Final images used in E2E tests

## Beads Integration

```bash
# Feature
spark_k8s-xxx - F12: Phase 6 - E2E Tests (P1)

# Workstreams
spark_k8s-xxx - WS-012-01: Core E2E (P1)
spark_k8s-xxx - WS-012-02: GPU E2E (P1)
spark_k8s-xxx - WS-012-03: Iceberg E2E (P1)
spark_k8s-xxx - WS-012-04: GPU+Iceberg E2E (P1)
spark_k8s-xxx - WS-012-05: Standalone E2E (P1)
spark_k8s-xxx - WS-012-06: Library compatibility (P1)

# Dependencies
All WS depend on F06, F07, F11
```

## References

- [PRODUCT_VISION.md](../../PRODUCT_VISION.md)
- [workstreams/INDEX.md](../workstreams/INDEX.md)
- [phase-02-smoke.md](./phase-02-smoke.md)
- [phase-05-docker-final.md](./phase-05-docker-final.md)
