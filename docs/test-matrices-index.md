# Test Matrices Index

Индекс всех тестовых матриц для Spark K8s deployment.

**Last updated:** 2026-02-01 15:00

---

## Обзор

Проект использует четыре типа тестирования с различными матрицами сценариев:

| Тип | Назначение | Сценариев | Создано | Progress |
|-----|------------|-----------|---------|----------|
| **Smoke** | Быстрая проверка базовой функциональности | 152 | 13 | 9% |
| **E2E** | Полная проверка на полных данных | 80 | 0 | 0% |
| **Load** | Нагрузочные тесты производительности | 20 | 0 | 0% |
| **Security** | Проверка соответствия security требованиям | 54 | 0 | 0% |
| **Docker** | Тесты Docker образов и слоёв | 68 | 2 | 3% |
| **ИТОГО** | | **374** | **15** | **4%** |

---

## Smoke Test Matrix

**Файл:** [smoke-test-matrix.md](smoke-test-matrix.md)

**Назначение:** Быстрая проверка базовой функциональности всех комбинаций компонентов, версий Spark, режимов запуска и фич.

**Размерность:**
- Компоненты: 3 (Jupyter, Airflow, Spark-submit)
- Версии Spark: 4 (3.5.7, 3.5.8, 4.1.0, 4.1.1)
- Режимы запуска: 3 (k8s, standalone, connect)
- Фичи: 4 (baseline, GPU, Iceberg, GPU+Iceberg)
- **Security:** 8 сценариев (PSS, SCC, Network Policies)

**Всего:** 144 + 8 = **152 сценария**

**Progress:** 13/152 (9%)

**Созданные сценарии:**
- ✅ `jupyter-k8s-358.sh`
- ✅ `jupyter-connect-k8s-410.sh`
- ✅ `jupyter-connect-standalone-410.sh`
- ✅ `jupyter-connect-k8s-411.sh`
- ✅ `jupyter-connect-standalone-411.sh`
- ✅ `airflow-connect-k8s-410.sh`
- ✅ `airflow-connect-standalone-410.sh`
- ✅ `airflow-gpu-connect-k8s-410.sh`
- ✅ `airflow-iceberg-connect-k8s-410.sh`
- ✅ `airflow-connect-k8s-411.sh`
- ✅ `airflow-connect-standalone-411.sh`
- ✅ `airflow-gpu-connect-k8s-411.sh`
- ✅ `airflow-iceberg-connect-k8s-411.sh`

**Обязательные требования:**
- S3 для Event Log
- History Server
- MinIO

---

## E2E Test Matrix

**Файл:** [e2e-test-matrix.md](e2e-test-matrix.md)

**Назначение:** Полная проверка функциональности на реальных/больших данных (11GB NYC Taxi dataset).

**Размерность (оптимизированная):**
- Компоненты: 3 (Jupyter, Airflow, Spark-submit)
- Версии Spark: 4 (3.5.7, 3.5.8, 4.1.0, 4.1.1)
- Версии Python: 2 (3.10 для 3.5.x, 3.11 для 4.1.x)
- Версии JDK: 2 (17 для 3.5.x, 21 для 4.1.x)
- Версии Airflow: 2 (2.8.x, 2.9.x - branch 2)
- Режимы запуска: 3 (k8s, standalone, connect)
- Фичи: 4 (baseline, GPU, Iceberg, GPU+Iceberg)

**Всего (оптимизированная матрица):** **80 сценариев**

**Progress:** 0/80 (0%)

**Категории:**
1. Core функциональность: 24 сценариев
2. GPU: 16 сценариев 📦
3. Iceberg: 16 сценариев 📦
4. GPU+Iceberg: 8 сценариев 📦
5. Standalone: 8 сценариев
6. Library compatibility: 8 сценариев

**Dataset:** NYC Taxi full (11GB, 744M records)

**Обязательные требования:**
- S3 для Event Log
- History Server
- MinIO
- Полный датасет (11GB)

---

## Load Test Matrix

**Файл:** [load-test-matrix.md](load-test-matrix.md)

**Назначение:** Нагрузочные тесты для проверки производительности, масштабирования и стабильности при длительной работе.

**Размерность:**
- Компоненты: 3 (Jupyter, Airflow, Spark-submit)
- Версии Spark: 4 (3.5.7, 3.5.8, 4.1.0, 4.1.1)
- Категории: 5 (Baseline, GPU, Iceberg, Connect vs K8s, Standalone scalability)
- **Security:** 4 сценария (PSS/SCC load tests)

**Всего:** 16 + 4 = **20 сценариев**

**Progress:** 0/20 (0%)

**Категории:**
1. Baseline: 4 сценария
2. GPU: 4 сценария 📦
3. Iceberg: 4 сценария 📦
4. Connect vs K8s: 2 сценария
5. Standalone scalability: 2 сценария
6. Security stability: 4 сценария

**Dataset:** NYC Taxi full (11GB, 744M records)

**Duration:** 30 min sustained load

**Обязательные требования:**
- S3 для Event Log
- History Server
- MinIO
- Подробные метрики в JSON

---

## Security Test Matrix

**Файл:** [security-test-matrix.md](security-test-matrix.md)

**Назначение:** Проверка соответствия OpenShift security требованиям, Pod Security Standards и SCC.

**Размерность:**
- PSS Tests: 8 сценариев
- SCC Tests: 12 сценариев
- Network Policies: 6 сценариев
- RBAC Tests: 6 сценариев
- Secret Management: 8 сценариев
- Container Security: 8 сценариев
- S3 Security: 6 сценариев

**Всего:** **54 сценария**

**Progress:** 0/54 (0%)

**Проверки:**
- Pod Security Standards (restricted, baseline, privileged)
- OpenShift SCC (restricted, anyuid, nonroot, hostmount, hostnetwork)
- Network Policies (default deny, Spark communication, external S3)
- RBAC (read-only, full, custom)
- Secret Management (K8s native, External Secrets, Sealed Secrets, Vault)
- Container Security (readonly, capabilities, seccomp, vulnerability scan)
- S3 Security (encryption, IAM, presigned URLs)

---

## Docker Test Matrix

**Файл:** [docker-test-matrix.md](docker-test-matrix.md)

**Назначение:** Тесты Docker образов, слоёв и сборки.

**Размерность:**
- Base layers: 3 Dockerfiles + 3 unit tests
- Intermediate layers: 7 Dockerfiles + 4 unit tests
- Final images: 20 Dockerfiles + 14 integration tests
- Build scripts: 3

**Всего:** **68 файлов**

**Progress:** 2/68 (3%)

**Структура:**
```
docker/
├── base/              # Base layers (3 Dockerfiles)
│   ├── jdk17/
│   ├── python310/
│   └── cuda121/
├── layers/            # Intermediate layers (7 Dockerfiles)
│   ├── spark-core/
│   ├── python-deps/
│   ├── jdbc-drivers/
│   └── jars/ (rapids, iceberg)
├── images/            # Final images (20 Dockerfiles)
│   ├── spark-3.5/
│   ├── spark-4.1/
│   ├── spark-*-gpu/
│   └── jupyter-spark/
└── tests/
    ├── unit/          # Unit тесты слоёв (10)
    └── integration/   # Integration тесты образов (28)
```

---

## Поддерживаемые версии библиотек

### Python

| Spark версия | Мин. | Рекомендуемая | Макс. | E2E использует |
|-------------|------|---------------|-------|----------------|
| 3.5.7 | 3.8 | 3.10 | 3.11 | 3.10 |
| 3.5.8 | 3.8 | 3.10 | 3.11 | 3.10 |
| 4.1.0 | 3.8 | 3.11 | 3.12 | 3.11 |
| 4.1.1 | 3.8 | 3.11 | 3.12 | 3.11 |

### JDK

| Spark версия | Мин. | Рекомендуемая | Макс. | E2E использует |
|-------------|------|---------------|-------|----------------|
| 3.5.7 | 8 | 17 | 21 | 17 |
| 3.5.8 | 8 | 17 | 21 | 17 |
| 4.1.0 | 17 | 21 | 23 | 21 |
| 4.1.1 | 17 | 21 | 23 | 21 |

### Airflow

| Ветка | Версии в E2E | Провайдер |
|-------|--------------|-----------|
| 2.x | 2.8.x, 2.9.x | apache-airflow-providers-cncf-kubernetes |

### CUDA + RAPIDS

| CUDA | RAPIDS | Spark версии |
|------|--------|--------------|
| 12.1 | 24.x | 3.5.x, 4.1.x |

### Iceberg

| Iceberg | Spark версии |
|---------|--------------|
| 1.4.x | 3.5.x |
| 1.5.x | 4.1.x |

---

## Обязательные требования для всех тестов

Все типы тестов **ДОЛЖНЫ** включать:

1. **S3 для Event Log** - все логи выполнения Spark jobs сохраняются в S3
2. **History Server** - развёрнут для чтения логов из S3
3. **MinIO** - S3-совместимое хранилище (для локального тестирования)

```yaml
# Обязательные значения для всех тестов
global:
  s3:
    enabled: true
    endpoint: "http://minio:9000"
    accessKey: "minioadmin"
    secretKey: "minioadmin"
    pathStyleAccess: true
    sslEnabled: false

connect:  # или jupyter, spark-submit
  eventLog:
    enabled: true
    dir: "s3a://spark-logs/{version}/{type}/{scenario}/events"

historyServer:
  enabled: true
  provider: "s3"
  s3:
    endpoint: "http://minio:9000"
```

---

## Датасеты

### Small (для smoke tests)

- **Размер:** ~100MB
- **Записей:** ~7M
- **Формат:** Parquet
- **Source:** NYC Taxi sample

### Medium (для отладки)

- **Размер:** ~1GB
- **Записей:** ~70M
- **Формат:** Parquet
- **Source:** NYC Taxi subset

### Large (для E2E и load tests)

- **Размер:** ~11GB
- **Записей:** ~744M
- **Формат:** 119 Parquet files
- **Source:** NYC Taxi full (2015-2024)
- **Location:** `s3a://nyc-taxi/full/yellow_tripdata_*.parquet`

### Synthetic (для stress тестирования)

- **Генерируется:** На лету
- **Размер:** Настраиваемый
- **Формат:** Генерируемые данные
- **Purpose:** Пиковая нагрузка

---

## Required Docker Images

### Baseline (уже существуют)

| Образ | Spark | Python | JDK | Статус |
|-------|-------|--------|-----|--------|
| `spark-custom:3.5.7` | 3.5.7 | 3.10 | 17 | ✅ |
| `spark-custom:3.5.8` | 3.5.8 | 3.10 | 17 | ✅ |
| `spark-custom:4.1.0` | 4.1.0 | 3.11 | 21 | ✅ |
| `spark-custom:4.1.1` | 4.1.1 | 3.11 | 21 | ✅ |
| `jupyter-spark:3.5.7` | 3.5.7 | 3.10 | 17 | ✅ |
| `jupyter-spark:3.5.8` | 3.5.8 | 3.10 | 17 | ✅ |
| `jupyter-spark:4.1.0` | 4.1.0 | 3.11 | 21 | ✅ |
| `jupyter-spark:4.1.1` | 4.1.1 | 3.11 | 21 | ✅ |

### GPU (требуют сборки) 📦

| Образ | Spark | Python | JDK | CUDA | RAPIDS | Статус |
|-------|-------|--------|-----|------|--------|--------|
| `spark-custom-gpu:3.5.7` | 3.5.7 | 3.10 | 17 | 12.1 | 24.x | ❌ |
| `spark-custom-gpu:3.5.8` | 3.5.8 | 3.10 | 17 | 12.1 | 24.x | ❌ |
| `spark-custom-gpu:4.1.0` | 4.1.0 | 3.11 | 21 | 12.1 | 24.x | ❌ |
| `spark-custom-gpu:4.1.1` | 4.1.1 | 3.11 | 21 | 12.1 | 24.x | ❌ |
| `jupyter-spark-gpu:*` | all | all | all | 12.1 | 24.x | ❌ |

### Iceberg (требуют сборки) 📦

| Образ | Spark | Python | JDK | Iceberg | Статус |
|-------|-------|--------|-----|---------|--------|
| `spark-custom-iceberg:3.5.7` | 3.5.7 | 3.10 | 17 | 1.4.x | ❌ |
| `spark-custom-iceberg:3.5.8` | 3.5.8 | 3.10 | 17 | 1.5.x | ❌ |
| `spark-custom-iceberg:4.1.0` | 4.1.0 | 3.11 | 21 | 1.5.x | ❌ |
| `spark-custom-iceberg:4.1.1` | 4.1.1 | 3.11 | 21 | 1.5.x | ❌ |
| `jupyter-spark-iceberg:*` | all | all | all | 1.4.x/1.5.x | ❌ |

### Airflow (branch 2.x)

| Образ | Airflow | Python | Spark | Статус |
|-------|---------|--------|-------|--------|
| `airflow-spark:2.9.0-*` | 2.9.0 | 3.10/3.11 | all | ❌ |
| `airflow-spark-gpu:2.9.0-*` | 2.9.0 | 3.11 | 4.1.x | ❌ |
| `airflow-spark-iceberg:2.9.0-*` | 2.9.0 | 3.11 | 4.1.x | ❌ |

---

## OpenShift Security

**Анализ безопасности:** [openshift-security-analysis.md](openshift-security-analysis.md)

**Статус:** ⚠️ Требует внимания

### Критические проблемы

1. **Отсутствует namespace.yaml** с PSS labels
2. **podSecurityStandards: false** по умолчанию
3. **Нет OpenShift preset values**

### Action Items

#### Phase 1: Critical (День 1)

- [ ] Создать `templates/namespace.yaml` в spark-3.5 и spark-4.1
- [ ] Включить `podSecurityStandards: true` по умолчанию
- [ ] Создать security validation test

#### Phase 2: Documentation (День 1-2)

- [ ] Создать `presets/openshift-values.yaml` для обеих версий
- [ ] Документировать OpenShift UID ranges
- [ ] Обновить README.md с OpenShift instructions

---

## План работ

### Phase 1: Complete Smoke Tests (День 1-3)

**Priority:** P0 - Базовая функциональность

- [ ] Создать 139 оставшихся smoke сценариев
- [ ] Baseline для всех (25)
- [ ] Connect для 3.5 (18) 📦
- [ ] GPU (36) 📦
- [ ] Iceberg (36) 📦
- [ ] GPU+Iceberg (24) 📦
- [ ] Security tests (8)

### Phase 2: Critical Security + Chart Updates (День 1-2)

**Priority:** P0 - OpenShift compatibility

- [ ] Создать namespace.yaml templates
- [ ] Включить podSecurityStandards по умолчанию
- [ ] Создать OpenShift presets
- [ ] Создать PSS/SCC smoke tests

### Phase 3: Docker Images (День 3-7)

**Priority:** P1 - Инфраструктура для GPU/Iceberg

- [ ] Base layers (3)
- [ ] Intermediate layers (7)
- [ ] Final images (20)
- [ ] Unit tests (10)
- [ ] Integration tests (28)

### Phase 4: E2E Tests (День 4-7)

**Priority:** P1 - Полная проверка

- [ ] Core E2E (24)
- [ ] Library compatibility (8)
- [ ] GPU E2E (16) 📦
- [ ] Iceberg E2E (16) 📦
- [ ] GPU+Iceberg E2E (8) 📦
- [ ] Standalone (8)

### Phase 5: Load Tests (День 6-8)

**Priority:** P2 - Производительность

- [ ] Baseline (4)
- [ ] GPU (4) 📦
- [ ] Iceberg (4) 📦
- [ ] Comparison (4)
- [ ] Security stability (4)

### Phase 6: Advanced Security (День 7+)

**Priority:** P1 - Security hardening

- [ ] PSS tests (8)
- [ ] SCC tests (12)
- [ ] Network policies (6)
- [ ] RBAC tests (6)
- [ ] Secret management (8)
- [ ] Container security (8)
- [ ] S3 security (6)

---

## Progress Summary

| Матрица | Всего | Создано | % | Next |
|---------|-------|---------|---|------|
| Smoke | 152 | 13 | 9% | Phase 1 |
| E2E | 80 | 0 | 0% | Phase 4 |
| Load | 20 | 0 | 0% | Phase 5 |
| Security | 54 | 0 | 0% | Phase 6 |
| Docker | 68 | 2 | 3% | Phase 3 |
| **ИТОГО** | **374** | **15** | **4%** | Phase 1+2 |

---

## Last updated

2026-02-01 15:00 - Initial index creation
- Progress: 15/374 (4%)
- Next: Phase 1 - Complete Smoke Tests + Phase 2 - Critical Security
