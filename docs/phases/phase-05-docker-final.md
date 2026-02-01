# Phase 5: Docker Final Images

> **Status:** Draft
> **Priority:** P1 - Инфраструктура для GPU/Iceberg
> **Estimated Workstreams:** 3
> **Estimated LOC:** ~3900

## Goal

Создать финальные Docker образы (Spark 3.5/4.1 × baseline/GPU/Iceberg/GPU+Iceberg + Jupyter) с integration тестами.

## Critical Design Questions

1. **Image Variants:**
   - Как организовать 4 варианта? (Dockerfile args, separate files, scripts?)
   - Как минимизировать дубликацию между вариантами?

2. **Build Script:**
   - Как организовать параллельную сборку?
   - Как прервать сборку при ошибке?

3. **Integration Testing:**
   - Какие тесты для каждого образа? (spark-shell, spark-submit, python)
   - Как тестировать GPU образ без GPU node?

4. **Image Size:**
   - Как достичь уменьшения на 60-80%?
   - Multi-stage builds для оптимизации?

## Proposed Workstreams

| WS | Task | Scope | Dependencies |
|----|------|-------|-------------|
| WS-005-01 | Spark 3.5 images (8) + tests | LARGE (~1200 LOC) | Phase 4 |
| WS-005-02 | Spark 4.1 images (8) + tests | LARGE (~1200 LOC) | Phase 4 |
| WS-005-03 | Jupyter images (12) + tests | LARGE (~1500 LOC) | Phase 4 |

## Dependencies

- Phase 4 (Intermediate layers)

## Success Criteria

1. ✅ 18 final Dockerfiles создан
2. ✅ 28 integration тестов проходят
3. ✅ Размер образов уменьшен на 60-80%
4. ✅ GPU, Iceberg, GPU+Iceberg работают
