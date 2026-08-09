# Idea: Test Matrix TDD Design

**Status:** Draft
**Created:** 2026-03-03
**Feature:** Test Matrix TDD

---

## 1. Problem Statement

Матрица тестов (320 сценариев × 3 уровня = 960 прогонов) в плачевном состоянии:
- 48/96 smoke проходят, 48 падают (4.1.x deploy, event log, образы)
- Нет чёткой связи тест ↔ требование
- Падение теста интерпретируется как «тест неправильный», а не «требование не выполнено»
- Дрифт требований: run-matrix игнорирует gpu/iceberg при выборе образа; MinIO init не создаёт spark-logs/4.1/events; stash@{1} удалял тесты вместо split

**Цель:** Зелёная матрица через TDD — каждый тест доказывает конкретное требование. Red → Green → Refactor.

---

## 2. Requirements

### 2.1 Критический путь теста

Каждый сценарий матрицы проходит **все уровни** + метрики:

| Уровень | Требование | Доказательство |
|---------|------------|----------------|
| **Deploy** | Helm install успешен | release deployed, pods Ready |
| **Smoke** | 1K rows, count + filter | SMOKE_SUCCESS |
| **E2E** | 10K rows, aggregations, joins | E2E_SUCCESS |
| **Load** | S3 parquet, 3 agg iterations | LOAD_SUCCESS + row count |
| **Metrics** | Event logs → History Server | Application visible in History Server |

### 2.2 Конфигурация

- **Конфиги:** через `--set` (параметры helm), без статических values-файлов на сценарий
- **Фильтр:** `--filter "key=value"` по dimensions (spark_version, gpu, platform, etc.)

### 2.3 Пирамида образов

Образы выстроены от базового к специализированному:

```
Level 0: Base (docker-base)
  ├── jdk-17, python-3.10, cuda-12.1

Level 1: Custom Spark (docker/spark-custom)
  ├── spark-custom:3.5.7
  ├── spark-custom:3.5.8
  ├── spark-custom:4.1.0
  └── spark-custom:4.1.1

Level 2: Runtime (docker/runtime/spark) — extends Level 1
  ├── spark-k8s-runtime:3.5-3.5.7-baseline
  ├── spark-k8s-runtime:3.5-3.5.7-iceberg
  ├── spark-k8s-runtime:3.5-3.5.7-gpu
  ├── spark-k8s-runtime:3.5-3.5.7-gpu-iceberg
  ├── spark-k8s-runtime:4.1-4.1.0-baseline
  ├── spark-k8s-runtime:4.1-4.1.1-baseline
  └── (аналогично для 4.1.x: iceberg, gpu, gpu-iceberg)

Level 3: Jupyter (docker/runtime/jupyter) — extends Level 2
  └── spark-k8s-jupyter:3.5-3.5.7-baseline, etc.
```

**Требование:** `get_runtime_image(spark_version, gpu, iceberg)` возвращает образ из пирамиды по dimensions сценария.

### 2.4 Инфраструктура

- **spark-infra:** MinIO, History Server, Hive Metastore — shared
- **MinIO init:** создаёт `spark-logs/events/.keep` и `spark-logs/4.1/events/.keep`
- **S3:** nyc-taxi data в `s3a://nyc-taxi/raw/` (per-file read для INT32/INT64 mix)

---

## 3. Red-Green-Refactor Plan

### 3.1 Цикл на тест

| Фаза | Действие | Критерий |
|------|----------|----------|
| **Red** | Тест падает при невыполненном требовании | Ожидаемое падение документировано |
| **Green** | Минимальный фикс (конфиг, образ, chart) | Тест проходит |
| **Refactor** | Упрощение без изменения поведения | Тест по-прежнему проходит |

### 3.2 Beads на тест

Один bead на сценарий (или на группу по spark_version для экономии):
- **Title:** `[SCENARIO-XXXX] Red-Green-Refactor: {name}`
- **Body:** Требование, Red (ожидаемое падение), Green (фикс), Refactor (опционально)
- **Labels:** test-matrix, tdd, scenario

### 3.3 Приоритет

1. **P0:** Image pyramid (gpu, iceberg) — get_runtime_image. GPU не исключается: кластер перезапускается с поддержкой GPU.
2. **P1:** 96 k8s/no-gpu как первый milestone (smoke → e2e → load)
3. **P2:** Metrics (History Server validation)
4. **P3:** Полная матрица 320 (включая gpu=true сценарии)

---

## 4. Drift Analysis (Roadmap vs Reality)

### 4.1 Где произошёл дрифт

| Область | Roadmap/Требование | Реальность | Причина |
|---------|-------------------|------------|---------|
| **F04 Spark 4.1** | 24 WS, backlog | Charts есть, standalone — через spark-3.5 | spark-4.1 не имеет standalone component |
| **get_runtime_image** | gpu, iceberg dimensions | Игнорирует gpu/iceberg | Упрощение для быстрого smoke |
| **Event logs** | Всегда включены | SPARK_EVENTLOG_ENABLED=false (откат) | 4.1.1 image default s3a без credentials |
| **MinIO init** | spark-logs bucket | spark-logs/4.1/events/ отсутствовал | Только events/, не 4.1/events/ |
| **Load test** | S3 parquet | Fallback in-memory (откат) | INT32/INT64 schema mix |
| **TESTING** | 3 WS (storage, fix, e2e) | run-matrix 320 сценариев | Разные scope: minikube vs matrix |
| **stash@{1}** | Split >200 LOC | Delete 14 test files | Агент интерпретировал «удалить» |
| **test_scenarios_exist** | 320 сценариев | Проверяет 8 values-файлов | Планировочный разрыв |
| **GPU** | В scope (F08, F12 GPU E2E) | Не исключается | Кластер перезапускается с GPU |

### 4.2 Корневые причины

1. **Отсутствие TDD:** тесты писались под «работающий» код, а не под требования
2. **Упрощение вместо фикса:** отключение event log вместо настройки S3
3. **Игнорирование dimensions:** gpu/iceberg не влияют на образ
4. **Разрозненная документация:** INDEX, ROADMAP, beads — разные источники правды

---

## 5. Success Criteria

- [ ] Зелёная матрица (320 full, включая gpu=true)
- [ ] Каждый тест имеет bead с Red-Green-Refactor планом
- [ ] get_runtime_image учитывает gpu, iceberg
- [ ] Event logs включены, MinIO init создаёт 4.1/events
- [ ] Load test — только S3, без fallback
- [ ] AGENTS.md содержит project memory (структура, принципы)

---

## 6. Stakeholders

- **Разработчики:** run-matrix, charts, pipeline
- **CI/CD:** GitHub Actions matrix
- **SRE:** observability, History Server

---

## 7. Out of Scope

- Уменьшение количества сценариев (320 — целевое)
- Замена helm на другой инструмент
- Переход на другой runner (pytest вместо bash)
