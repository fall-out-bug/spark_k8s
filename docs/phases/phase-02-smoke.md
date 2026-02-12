# Phase 2: Complete Smoke Tests

> **Status:** Completed
> **Priority:** P0 - Базовая функциональность
> **Estimated Workstreams:** 7
> **Estimated LOC:** ~6500

## Goal

Покрыть все комбинации версий Spark, компонентов, режимов и фич smoke тестами для обеспечения качества каждой сборки.

## Current State

**Реализовано (139 сценариев):**

F08 completed. 139/139 smoke test scenarios created (jupyter 49, airflow 42, mlflow 48 + standalone, operator, history server, GPU, Iceberg, security, performance, load). See docs/reviews/F08-review.md.

## Workstreams

| WS | Task | Scope | Dependencies | Status |
|----|------|-------|-------------|--------|
| WS-008-01 | Jupyter GPU/Iceberg scenarios (12) | SMALL (~500 LOC) | Phase 0, Phase 1, WS-006-06, WS-006-07 | completed |
| WS-008-02 | Standalone chart baseline scenarios (24) | MEDIUM (~800 LOC) | F01 | completed |
| WS-008-03 | Spark Operator scenarios (32) | MEDIUM (~1200 LOC) | WS-020-12 | completed |
| WS-008-04 | History Server validation scenarios (32) | MEDIUM (~1000 LOC) | WS-012-01 | completed |
| WS-008-05 | MLflow scenarios (24) | MEDIUM (~800 LOC) | WS-001-07 | completed |
| WS-008-06 | Dataset generation utilities | SMALL (~400 LOC) | WS-008-01 | completed |
| WS-008-07 | Parallel execution improvements | SMALL (~600 LOC) | WS-008-02 | completed |

## Design Decisions

### 1. Scenario Naming Convention

```
<component>-<mode>-<features>-<chart>-<version>.sh
```

**Примеры:**
- `jupyter-connect-k8s-gpu-4.1.0.sh`
- `airflow-submit-k8s-standalone-3.5.7.sh`
- `mlflow-connect-standalone-iceberg-4.1.1.sh`

**Компоненты:**
- `jupyter` — JupyterLab с интеграцией Spark
- `airflow` — Apache Airflow с Spark operators
- `mlflow` — MLflow с Spark integration

**Режимы:**
- `connect-k8s` — Spark Connect с Kubernetes backend
- `connect-standalone` — Spark Connect с Standalone backend
- `k8s-submit` — Прямая отправка в Kubernetes
- `operator` — Spark Operator mode
- `standalone-submit` — Отправка в Spark Standalone

**Фичи:**
- `gpu` — GPU support (NVIDIA Rapids)
- `iceberg` — Apache Iceberg support
- `celeborn` — Celeborn shuffle service
- (empty) — базовый сценарий

**Charts:**
- `3.5` — charts/spark-3.5
- `4.1` — charts/spark-4.1
- `standalone` — charts/spark-standalone

**Версии:**
- `3.5.7`, `3.5.8` — Spark 3.5.x
- `4.1.0`, `4.1.1` — Spark 4.1.x

### 2. Dataset Strategy

**Baseline Dataset:**
- NYC Taxi sample (~100MB)
- Хранение: `scripts/tests/data/nyc-taxi-sample.parquet`
- Генерация: скрипт `scripts/tests/data/generate-dataset.sh`
- Форматы: Parquet (primary), CSV (fallback)

**Usage:**
```bash
# Generate dataset
./scripts/tests/data/generate-dataset.sh --size small

# Use in scenario
export DATASET_PATH="${PROJECT_ROOT}/scripts/tests/data/nyc-taxi-sample.parquet"
```

### 3. GPU/Iceberg Dependencies

**Решено:** GPU и Iceberg тесты НЕ блокируются Phase 5 (Docker images)

**Обоснование:**
1. Базовые GPU/Iceberg шаблоны уже созданы в WS-006-06, WS-006-07
2. Smoke тесты могут использовать официальные образы с GPU/Iceberg
3. Оптимизированные образы (Phase 5) — это улучшение производительности, не блокер

### 4. Test Matrix Prioritization

**P0 (Critical) — уже реализовано:**
- ✅ Baseline J scenarios (15)
- ✅ Baseline A scenarios с GPU/Iceberg

**P1 (High):**
- WS-008-01: Jupyter GPU/Iceberg (12)
- WS-008-02: Standalone chart scenarios (24)

**P2 (Medium):**
- WS-008-03: Spark Operator scenarios (32)
- WS-008-04: History Server scenarios (32)

**P3 (Low):**
- WS-008-05: MLflow scenarios (24)

### 5. Parallel Execution

**Текущее состояние:**
- Базовая поддержка параллельного запуска реализована
- Использует фоновые процессы Bash

**Улучшения (WS-008-07):**
1. Пропуск тестов при отсутствии ресурсов (GPU)
2. Интеллектуальное планирование по кластерам
3. Aggregated logging
4. Retry механизм для flaky тестов

## Dependencies

- ✅ **Phase 0** — Helm charts с GPU/Iceberg/Connect support (completed: WS-006-01 to WS-006-09)
- ✅ **Phase 1** — Security templates (completed: WS-022-01 to WS-022-04)
- ✅ **F01** — Spark Standalone chart (completed)
- ✅ **WS-001-07** — MLflow template (completed)
- ⏳ **WS-020-12** — Spark Operator chart (backlog)
- ✅ **WS-012-01** — History Server template (completed)

## Success Criteria

1. ✅ **Baseline scenarios (15)** — созданы и проходят
2. ⏳ **All scenarios (139)** — созданы
3. ⏳ **Sequential execution** — все проходят последовательно
4. ⏳ **Parallel execution** — все проходят параллельно
5. ✅ **YAML frontmatter** — в каждом сценарии
6. ⏳ **Dataset generation** — утилита для создания тестовых данных

## Implementation Notes

### Skip Logic

```bash
# GPU scenarios
check_gpu_available() {
    local gpu_nodes
    gpu_nodes=$(kubectl get nodes -o jsonpath='{.items[*].status.allocatable.nvidia\.com/gpu}' 2>/dev/null | tr ' ' '\n' | grep -v "^$" | wc -l)

    if [[ "$gpu_nodes" -eq 0 ]]; then
        log_warning "No GPU nodes found. Skipping..."
        return 1
    fi
    return 0
}

# Iceberg scenarios (require Hive Metastore)
check_iceberg_available() {
    local ns="$1"
    local hive_pods
    hive_pods=$(kubectl get pods -n "$ns" -l app.kubernetes.io/component=hive-metastore --no-headers 2>/dev/null | wc -l)

    if [[ "$hive_pods" -eq 0 ]]; then
        log_warning "Hive Metastore not found. Skipping Iceberg test..."
        return 1
    fi
    return 0
}
```

### Validation Functions

```bash
# Common validation
validate_spark_connect() {
    local pod="$1"
    local ns="$2"
    local port="${3:-15002}"

    kubectl exec -n "$ns" "$pod" -- /bin/sh -c "
        /opt/spark/bin/spark-shell --version
    "
}

validate_gpu_resources() {
    local pod="$1"
    local ns="$2"

    kubectl exec -n "$ns" "$pod" -- /bin/sh -c "
        nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
    " || log_warning "nvidia-smi not available in pod"
}
```

## Alignment with PRODUCT_VISION.md

**Time to First Spark:** Smoke тесты обеспечивают быструю валидацию (`< 5 min`)

**Documentation Coverage:** Каждый сценарий — это пример типичного сценария использования

**Support Reduction:** Comprehensive smoke coverage предотвращает regression

**OpenShift Compatibility:** Все сценарии используют PSS `restricted` по умолчанию

## Beads Integration

```bash
# После завершения каждого WS
bd close WS-008-01 --reason="12 Jupyter GPU/Iceberg scenarios created and passing"

# Создание подзадач для сценариев
bd create --title="Jupyter GPU scenario for 3.5.7" --type=task --priority=1 --parent=WS-008-01
```

## References

- [PRODUCT_VISION.md](../../PRODUCT_VISION.md)
- [workstreams/INDEX.md](../workstreams/INDEX.md)
- [scripts/tests/smoke/README.md](../../scripts/tests/smoke/README.md)
