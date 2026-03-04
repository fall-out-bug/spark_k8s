# Design: Test Matrix — Full Specification

**Source:** `docs/drafts/idea-test-matrix-tdd.md`
**Status:** Design
**Created:** 2026-03-04

---

## 1. Design Principle

**Критическое правило:** Тест считается пройденным только если он **выполнил** проверку, а не проверил наличие файла.

| Запрещено | Требуется |
|-----------|-----------|
| `Path("script.sh").exists()` | `bash script.sh` → exit 0 |
| `"keyword" in file.read_text()` | Реальный вызов `kubectl`, `spark-submit`, Spark Connect API |
| Проверка количества файлов | Реальный deploy + workload + результат |

---

## 2. Architecture

### 2.1 Пирамида уровней

```
                    ┌─────────────────┐
                    │  Load (S3, 3 agg)│  ← throughput, row count
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │  E2E (10K rows) │  ← aggregations, joins
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │ Smoke (1K rows) │  ← count, filter
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │ Deploy (helm)   │  ← pods Ready
                    └─────────────────┘
```

Каждый сценарий проходит все уровни снизу вверх. Провал на любом уровне = сценарий FAIL.

### 2.2 Компоненты

| Компонент | Назначение | Вход | Выход |
|-----------|------------|------|-------|
| **run-matrix** | Оркестратор по сценариям | test-matrix.yaml, --filter | PASS/FAIL per scenario |
| **deploy** | helm install + wait Ready | scenario_id, helm_values | namespace, release_name |
| **smoke** | 1K rows, count+filter | release_name, connect_url | SMOKE_SUCCESS |
| **e2e** | 10K rows, agg+join | release_name, connect_url | E2E_SUCCESS |
| **load** | S3 parquet, 3 agg | release_name, connect_url | LOAD_SUCCESS + metrics |

### 2.3 Поток данных

```
test-matrix.yaml (320 scenarios)
        │
        ▼
run-matrix --filter "gpu=false"
        │
        ├─► Для каждого сценария:
        │   ├─ deploy(scenario)  → helm install, kubectl wait
        │   ├─ smoke(scenario)   → exec workload, assert result
        │   ├─ e2e(scenario)     → exec workload, assert result
        │   ├─ load(scenario)   → exec workload, assert throughput
        │   └─ cleanup(scenario)
        │
        ▼
results/scenario-{id}.json {deploy: PASS, smoke: PASS, e2e: PASS, load: PASS}
```

---

## 3. Workstream Decomposition

### WS-035-01: Matrix Runner Core
**Цель:** Скрипт `scripts/run-matrix.sh` который для сценария **выполняет** deploy → smoke → e2e → load.
- Читает test-matrix.yaml
- Поддерживает --filter по dimensions
- Вызывает helm install (не проверяет наличие)
- Вызывает smoke/e2e/load скрипты (не проверяет наличие)
- Записывает результат в results/

### WS-035-02: Deploy Level
**Цель:** Функция deploy(scenario) — helm install, kubectl wait --for=condition=ready.
- Реальный helm install с values из сценария
- Таймаут, retry
- Cleanup при провале

### WS-035-03: Smoke Level
**Цель:** Smoke скрипт **выполняет** workload (1K rows, count, filter).
- Вызов Spark Connect API или spark-submit
- Assert: результат содержит ожидаемое число строк
- SMOKE_SUCCESS в stdout или exit 0

### WS-035-04: E2E Level
**Цель:** E2E скрипт **выполняет** workload (10K rows, aggregations, joins).
- Реальный SQL/DataFrame workload
- Assert: результат корректен
- E2E_SUCCESS

### WS-035-05: Load Level
**Цель:** Load скрипт **выполняет** S3 parquet read + 3 agg iterations.
- Только S3, без in-memory fallback
- Throughput, row count в результат
- LOAD_SUCCESS

### WS-035-06: Image Pyramid + get_runtime_image
**Цель:** get_runtime_image(spark_version, gpu, iceberg) → образ из пирамиды.
- gpu=true → -gpu suffix
- iceberg=true → -iceberg suffix

### WS-035-07: Metrics Validation
**Цель:** После load — приложение видно в History Server.
- Event logs → S3 → History Server
- curl API, assert application listed

### WS-035-08: Matrix Integration (96 k8s/no-gpu)
**Цель:** 96 сценариев gpu=false, platform=k8s — все зелёные.
- run-matrix all --filter "gpu=false,platform=k8s"
- 96/96 PASS

---

## 4. File Layout

```
scripts/
├── run-matrix.sh              # Orchestrator (WS-035-01)
├── tests/
│   ├── lib/
│   │   ├── deploy.sh          # deploy(scenario) (WS-035-02)
│   │   ├── get_runtime_image.sh # (WS-035-06)
│   │   └── ...
│   ├── smoke/
│   │   ├── run-smoke-tests.sh # Must EXECUTE workload (WS-035-03)
│   │   └── scenarios/*.sh
│   ├── e2e/
│   │   └── ...                # Must EXECUTE workload (WS-035-04)
│   └── load/
│       └── ...                # Must EXECUTE S3 workload (WS-035-05)

tests/
├── test-matrix.yaml           # 320 scenarios (existing)
└── results/
    └── scenario-*.json        # Per-scenario results
```

---

## 5. Success Criteria

- [ ] run-matrix.sh существует и **выполняет** deploy/smoke/e2e/load
- [ ] Ни один тест не использует Path.exists() или "string" in content как доказательство
- [ ] 96 сценариев (gpu=false, k8s) — все PASS
- [ ] Результаты записываются в machine-readable формате (JSON)

---

## 6. Dependency Graph

```
WS-035-01 (Runner Core)
    ├── WS-035-02 (Deploy)
    ├── WS-035-03 (Smoke)
    ├── WS-035-04 (E2E)
    └── WS-035-05 (Load)
            │
            ├── WS-035-06 (Image Pyramid)
            └── WS-035-07 (Metrics)
                    │
                    └── WS-035-08 (96 Green)
```
