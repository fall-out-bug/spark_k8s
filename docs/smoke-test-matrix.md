# Smoke Test Matrix

Полная матрица smoke тестов для проверки всех комбинаций компонентов, версий Spark, режимов запуска и фич.

## Размерность матрицы

- **Компоненты:** 3 (Jupyter, Airflow, Spark-submit)
- **Версии Spark:** 4 (3.5.7, 3.5.8, 4.1.0, 4.1.1)
- **Режимы запуска:** 3 (k8s, standalone, connect)
- **Фичи:** 4 (baseline, GPU, Iceberg, GPU+Iceberg)

**Итого:** 3 × 4 × 3 × 4 = **144 сценария**

## Обязательные требования для всех сценариев

Все smoke тесты **ДОЛЖНЫ** включать:

1. **S3 для Event Log** - все логи выполнения Spark jobs сохраняются в S3
2. **History Server** - развёрнут для чтения логов из S3
3. **MinIO** - S3-совместимое хранилище (для локального тестирования)

```yaml
# Обязательные значения для всех smoke тестов
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
    dir: "s3a://spark-logs/{version}/events"

historyServer:
  enabled: true
    provider: "s3"
    s3:
      endpoint: "http://minio:9000"
```

**Примечание:** Это требование относится к smoke тестам, так как они должны проверять полную функциональность включая логирование.

## Легенда

- ✅ = Создано
- ❌ = Не создано
- 🔄 = В работе
- 📦 = Требует сборки образа

---

## Spark 3.5.7 (36 сценариев)

### Jupyter (12 сценариев)

| Режим | Baseline | GPU | Iceberg | GPU+Iceberg |
|-------|----------|-----|---------|-------------|
| k8s | ❌ | ❌ | ❌ | ❌ |
| standalone | ❌ | ❌ | ❌ | ❌ |
| connect | ❌ | ❌ | ❌ | ❌ |

**Файлы:**
- `jupyter-k8s-357.sh`
- `jupyter-k8s-gpu-357.sh` 📦
- `jupyter-k8s-iceberg-357.sh` 📦
- `jupyter-k8s-gpu-iceberg-357.sh` 📦
- `jupyter-standalone-357.sh`
- `jupyter-standalone-gpu-357.sh` 📦
- `jupyter-standalone-iceberg-357.sh` 📦
- `jupyter-standalone-gpu-iceberg-357.sh` 📦
- `jupyter-connect-k8s-357.sh` 📦
- `jupyter-connect-gpu-357.sh` 📦
- `jupyter-connect-iceberg-357.sh` 📦
- `jupyter-connect-gpu-iceberg-357.sh` 📦

**Прогресс:** 0/12 (0%)

---

### Airflow (12 сценариев)

| Режим | Baseline | GPU | Iceberg | GPU+Iceberg |
|-------|----------|-----|---------|-------------|
| k8s | ❌ | ❌ | ❌ | ❌ |
| standalone | ❌ | ❌ | ❌ | ❌ |
| connect | ❌ | ❌ | ❌ | ❌ |

**Файлы:**
- `airflow-k8s-357.sh`
- `airflow-k8s-gpu-357.sh` 📦
- `airflow-k8s-iceberg-357.sh` 📦
- `airflow-k8s-gpu-iceberg-357.sh` 📦
- `airflow-standalone-357.sh`
- `airflow-standalone-gpu-357.sh` 📦
- `airflow-standalone-iceberg-357.sh` 📦
- `airflow-standalone-gpu-iceberg-357.sh` 📦
- `airflow-connect-k8s-357.sh` 📦
- `airflow-connect-gpu-357.sh` 📦
- `airflow-connect-iceberg-357.sh` 📦
- `airflow-connect-gpu-iceberg-357.sh` 📦

**Прогресс:** 0/12 (0%)

---

### Spark-submit (12 сценариев)

| Режим | Baseline | GPU | Iceberg | GPU+Iceberg |
|-------|----------|-----|---------|-------------|
| k8s | ❌ | ❌ | ❌ | ❌ |
| standalone | ❌ | ❌ | ❌ | ❌ |
| connect | ❌ | ❌ | ❌ | ❌ |

**Файлы:**
- `spark-submit-k8s-357.sh`
- `spark-submit-k8s-gpu-357.sh` 📦
- `spark-submit-k8s-iceberg-357.sh` 📦
- `spark-submit-k8s-gpu-iceberg-357.sh` 📦
- `spark-submit-standalone-357.sh`
- `spark-submit-standalone-gpu-357.sh` 📦
- `spark-submit-standalone-iceberg-357.sh` 📦
- `spark-submit-standalone-gpu-iceberg-357.sh` 📦
- `spark-submit-connect-k8s-357.sh` 📦
- `spark-submit-connect-gpu-357.sh` 📦
- `spark-submit-connect-iceberg-357.sh` 📦
- `spark-submit-connect-gpu-iceberg-357.sh` 📦

**Прогресс 3.5.7:** 0/36 (0%)

---

## Spark 3.5.8 (36 сценариев)

### Jupyter (12 сценариев)

| Режим | Baseline | GPU | Iceberg | GPU+Iceberg |
|-------|----------|-----|---------|-------------|
| k8s | ✅ | ❌ | ❌ | ❌ |
| standalone | ❌ | ❌ | ❌ | ❌ |
| connect | ❌ | ❌ | ❌ | ❌ |

**Создано:**
- ✅ `jupyter-k8s-358.sh`

**Осталось:**
- `jupyter-k8s-gpu-358.sh` 📦
- `jupyter-k8s-iceberg-358.sh` 📦
- `jupyter-k8s-gpu-iceberg-358.sh` 📦
- `jupyter-standalone-358.sh`
- `jupyter-standalone-gpu-358.sh` 📦
- `jupyter-standalone-iceberg-358.sh` 📦
- `jupyter-standalone-gpu-iceberg-358.sh` 📦
- `jupyter-connect-k8s-358.sh` 📦
- `jupyter-connect-gpu-358.sh` 📦
- `jupyter-connect-iceberg-358.sh` 📦
- `jupyter-connect-gpu-iceberg-358.sh` 📦

**Прогресс:** 1/12 (8%)

---

### Airflow (12 сценариев)

| Режим | Baseline | GPU | Iceberg | GPU+Iceberg |
|-------|----------|-----|---------|-------------|
| k8s | ❌ | ❌ | ❌ | ❌ |
| standalone | ❌ | ❌ | ❌ | ❌ |
| connect | ❌ | ❌ | ❌ | ❌ |

**Файлы:**
- `airflow-k8s-358.sh`
- `airflow-k8s-gpu-358.sh` 📦
- `airflow-k8s-iceberg-358.sh` 📦
- `airflow-k8s-gpu-iceberg-358.sh` 📦
- `airflow-standalone-358.sh`
- `airflow-standalone-gpu-358.sh` 📦
- `airflow-standalone-iceberg-358.sh` 📦
- `airflow-standalone-gpu-iceberg-358.sh` 📦
- `airflow-connect-k8s-358.sh` 📦
- `airflow-connect-gpu-358.sh` 📦
- `airflow-connect-iceberg-358.sh` 📦
- `airflow-connect-gpu-iceberg-358.sh` 📦

**Прогресс:** 0/12 (0%)

---

### Spark-submit (12 сценариев)

| Режим | Baseline | GPU | Iceberg | GPU+Iceberg |
|-------|----------|-----|---------|-------------|
| k8s | ❌ | ❌ | ❌ | ❌ |
| standalone | ❌ | ❌ | ❌ | ❌ |
| connect | ❌ | ❌ | ❌ | ❌ |

**Файлы:**
- `spark-submit-k8s-358.sh`
- `spark-submit-k8s-gpu-358.sh` 📦
- `spark-submit-k8s-iceberg-358.sh` 📦
- `spark-submit-k8s-gpu-iceberg-358.sh` 📦
- `spark-submit-standalone-358.sh`
- `spark-submit-standalone-gpu-358.sh` 📦
- `spark-submit-standalone-iceberg-358.sh` 📦
- `spark-submit-standalone-gpu-iceberg-358.sh` 📦
- `spark-submit-connect-k8s-358.sh` 📦
- `spark-submit-connect-gpu-358.sh` 📦
- `spark-submit-connect-iceberg-358.sh` 📦
- `spark-submit-connect-gpu-iceberg-358.sh` 📦

**Прогресс 3.5.8:** 1/36 (3%)

---

## Spark 4.1.0 (36 сценариев)

### Jupyter (12 сценариев)

| Режим | Baseline | GPU | Iceberg | GPU+Iceberg |
|-------|----------|-----|---------|-------------|
| k8s | ❌ | ❌ | ❌ | ❌ |
| standalone | ❌ | ❌ | ❌ | ❌ |
| connect | ✅ | ❌ | ❌ | ❌ |

**Создано:**
- ✅ `jupyter-connect-k8s-410.sh`
- ✅ `jupyter-connect-standalone-410.sh`

**Осталось:**
- `jupyter-k8s-410.sh`
- `jupyter-k8s-gpu-410.sh` 📦
- `jupyter-k8s-iceberg-410.sh` 📦
- `jupyter-k8s-gpu-iceberg-410.sh` 📦
- `jupyter-standalone-410.sh`
- `jupyter-standalone-gpu-410.sh` 📦
- `jupyter-standalone-iceberg-410.sh` 📦
- `jupyter-standalone-gpu-iceberg-410.sh` 📦
- `jupyter-connect-gpu-410.sh` 📦
- `jupyter-connect-iceberg-410.sh` 📦
- `jupyter-connect-gpu-iceberg-410.sh` 📦

**Прогресс:** 2/12 (17%)

---

### Airflow (12 сценариев)

| Режим | Baseline | GPU | Iceberg | GPU+Iceberg |
|-------|----------|-----|---------|-------------|
| k8s | ✅ | ❌ | ❌ | ❌ |
| standalone | ✅ | ❌ | ❌ | ❌ |
| connect | ✅ | ✅ | ✅ | ❌ |

**Создано:**
- ✅ `airflow-connect-k8s-410.sh`
- ✅ `airflow-connect-standalone-410.sh`
- ✅ `airflow-gpu-connect-k8s-410.sh`
- ✅ `airflow-iceberg-connect-k8s-410.sh`

**Осталось:**
- `airflow-k8s-gpu-410.sh` 📦
- `airflow-k8s-iceberg-410.sh` 📦
- `airflow-k8s-gpu-iceberg-410.sh` 📦
- `airflow-standalone-gpu-410.sh` 📦
- `airflow-standalone-iceberg-410.sh` 📦
- `airflow-standalone-gpu-iceberg-410.sh` 📦
- `airflow-connect-gpu-iceberg-410.sh` 📦

**Прогресс:** 4/12 (33%)

---

### Spark-submit (12 сценариев)

| Режим | Baseline | GPU | Iceberg | GPU+Iceberg |
|-------|----------|-----|---------|-------------|
| k8s | ❌ | ❌ | ❌ | ❌ |
| standalone | ❌ | ❌ | ❌ | ❌ |
| connect | ❌ | ❌ | ❌ | ❌ |

**Файлы:**
- `spark-submit-k8s-410.sh`
- `spark-submit-k8s-gpu-410.sh` 📦
- `spark-submit-k8s-iceberg-410.sh` 📦
- `spark-submit-k8s-gpu-iceberg-410.sh` 📦
- `spark-submit-standalone-410.sh`
- `spark-submit-standalone-gpu-410.sh` 📦
- `spark-submit-standalone-iceberg-410.sh` 📦
- `spark-submit-standalone-gpu-iceberg-410.sh` 📦
- `spark-submit-connect-k8s-410.sh`
- `spark-submit-connect-gpu-410.sh` 📦
- `spark-submit-connect-iceberg-410.sh` 📦
- `spark-submit-connect-gpu-iceberg-410.sh` 📦

**Прогресс 4.1.0:** 6/36 (17%)

---

## Spark 4.1.1 (36 сценариев)

### Jupyter (12 сценариев)

| Режим | Baseline | GPU | Iceberg | GPU+Iceberg |
|-------|----------|-----|---------|-------------|
| k8s | ❌ | ❌ | ❌ | ❌ |
| standalone | ❌ | ❌ | ❌ | ❌ |
| connect | ✅ | ❌ | ❌ | ❌ |

**Создано:**
- ✅ `jupyter-connect-k8s-411.sh`
- ✅ `jupyter-connect-standalone-411.sh`

**Прогресс:** 2/12 (17%)

---

### Airflow (12 сценариев)

| Режим | Baseline | GPU | Iceberg | GPU+Iceberg |
|-------|----------|-----|---------|-------------|
| k8s | ✅ | ❌ | ❌ | ❌ |
| standalone | ✅ | ❌ | ❌ | ❌ |
| connect | ✅ | ✅ | ✅ | ❌ |

**Создано:**
- ✅ `airflow-connect-k8s-411.sh`
- ✅ `airflow-connect-standalone-411.sh`
- ✅ `airflow-gpu-connect-k8s-411.sh`
- ✅ `airflow-iceberg-connect-k8s-411.sh`

**Прогресс:** 4/12 (33%)

---

### Spark-submit (12 сценариев)

| Режим | Baseline | GPU | Iceberg | GPU+Iceberg |
|-------|----------|-----|---------|-------------|
| k8s | ❌ | ❌ | ❌ | ❌ |
| standalone | ❌ | ❌ | ❌ | ❌ |
| connect | ❌ | ❌ | ❌ | ❌ |

**Прогресс 4.1.1:** 6/36 (17%)

---

## Сводная таблица

| Версия | Jupyter | Airflow | Spark-submit | Итого | Создано | % |
|--------|---------|---------|--------------|-------|---------|---|
| 3.5.7 | 0/12 | 0/12 | 0/12 | 0/36 | 0 | 0% |
| 3.5.8 | 1/12 | 0/12 | 0/12 | 1/36 | 1 | 3% |
| 4.1.0 | 2/12 | 4/12 | 0/12 | 6/36 | 6 | 17% |
| 4.1.1 | 2/12 | 4/12 | 0/12 | 6/36 | 6 | 17% |
| **ИТОГО** | **5/48** | **8/48** | **0/48** | **13/144** | **13** | **9%** |

---

## Созданные файлы (13)

### Spark 3.5.8 (1)
- ✅ `jupyter-k8s-358.sh`

### Spark 4.1.0 (6)
- ✅ `jupyter-connect-k8s-410.sh`
- ✅ `jupyter-connect-standalone-410.sh`
- ✅ `airflow-connect-k8s-410.sh`
- ✅ `airflow-connect-standalone-410.sh`
- ✅ `airflow-gpu-connect-k8s-410.sh`
- ✅ `airflow-iceberg-connect-k8s-410.sh`

### Spark 4.1.1 (6)
- ✅ `jupyter-connect-k8s-411.sh`
- ✅ `jupyter-connect-standalone-411.sh`
- ✅ `airflow-connect-k8s-411.sh`
- ✅ `airflow-connect-standalone-411.sh`
- ✅ `airflow-gpu-connect-k8s-411.sh`
- ✅ `airflow-iceberg-connect-k8s-411.sh`

---

## Что нужно создать (131 сценарий)

### 📦 = Требует сборки образа

#### Spark 3.5 Connect scenarios (18 сценариев)
Все сценарии с connect для 3.5 требуют сборки образов с Spark Connect:
- jupyter-connect-*-357.sh, jupyter-connect-*-358.sh (12 файлов)
- airflow-connect-*-357.sh, airflow-connect-*-358.sh (12 файлов)
- spark-submit-connect-*-357.sh, spark-submit-connect-*-358.sh (12 файлов)

#### GPU/Iceberg scenarios (96 сценариев)
Все сценарии с GPU или Iceberg требуют соответствующих образов:
- GPU: 36 сценариев (gpu + gpu-iceberg для каждого)
- Iceberg: 36 сценариев (iceberg + gpu-iceberg для каждого)
- Образы: spark-custom-gpu, spark-custom-iceberg, jupyter-spark-gpu, jupyter-spark-iceberg

---

## План работ

### Phase 1: Baseline для всех (25 сценариев)
- Spark 3.5.7: все 12 baseline
- Spark 3.5.8: ещё 11 baseline
- Spark 4.1.0: ещё 6 baseline (jupyter-k8s, jupyter-standalone, spark-submit все 3 режима)
- Spark 4.1.1: ещё 6 baseline

### Phase 2: Connect для 3.5 (18 сценариев) 📦
- Собрать образы Spark 3.5 + Connect
- Создать все connect сценарии для 3.5.7 и 3.5.8

### Phase 3: GPU образы и сценарии (36 сценариев) 📦
- Собрать spark-custom-gpu, jupyter-spark-gpu образы
- Создать все GPU сценарии

### Phase 4: Iceberg образы и сценарии (36 сценариев) 📦
- Собрать spark-custom-iceberg, jupyter-spark-iceberg образы
- Создать все Iceberg сценарии

### Phase 5: GPU+Iceberg комбо (36 сценариев) 📦
- Проверить комбинацию GPU + Iceberg
- Создать все комбо сценарии

---

## OpenShift Security Testing

### Security test scenarios (8 сценариев)

Отдельные smoke тесты для проверки соответствия OpenShift security требованиям:

| Сценарий | Описание | PSS | SCC |
|----------|-----------|-----|-----|
| ❌ `security-pss-restricted-35.sh` | Spark 3.5 + PSS restricted | ✅ | - |
| ❌ `security-pss-restricted-41.sh` | Spark 4.1 + PSS restricted | ✅ | - |
| ❌ `security-scc-anyuid-35.sh` | Spark 3.5 + SCC anyuid | - | ✅ |
| ❌ `security-scc-anyuid-41.sh` | Spark 4.1 + SCC anyuid | - | ✅ |
| ❌ `security-scc-restricted-35.sh` | Spark 3.5 + SCC restricted | - | ✅ |
| ❌ `security-scc-restricted-41.sh` | Spark 4.1 + SCC restricted | - | ✅ |
| ❌ `security-network-policies-35.sh` | Spark 3.5 + Network Policies | ✅ | - |
| ❌ `security-network-policies-41.sh` | Spark 4.1 + Network Policies | ✅ | - |

**Проверки:**
- ✅ Pod запускается с correct UID/GID
- ✅ Pod соответствует PSS restricted profile
- ✅ Pod соответствует выбранному SCC
- ✅ Network блокируют несанкционированный трафик
- ✅ История Server доступен через S3
- ✅ Job логи пишутся в S3

**Файлы:**
- `scripts/tests/smoke/scenarios/security-pss-restricted-35.sh`
- `scripts/tests/smoke/scenarios/security-pss-restricted-41.sh`
- `scripts/tests/smoke/scenarios/security-scc-anyuid-35.sh`
- `scripts/tests/smoke/scenarios/security-scc-anyuid-41.sh`
- `scripts/tests/smoke/scenarios/security-scc-restricted-35.sh`
- `scripts/tests/smoke/scenarios/security-scc-restricted-41.sh`
- `scripts/tests/smoke/scenarios/security-network-policies-35.sh`
- `scripts/tests/smoke/scenarios/security-network-policies-41.sh`

**Progress:** 0/8 (0%)

**Прогресс с security тестами: 13/152 (9%)**

### OpenShift preset values

Дополнительные preset файлы для OpenShift deployment:

| Preset | Описание | Статус |
|--------|----------|--------|
| ❌ `charts/spark-3.5/presets/openshift-values.yaml` | OpenShift SCC, UID ranges | - |
| ❌ `charts/spark-4.1/presets/openshift-values.yaml` | OpenShift SCC, UID ranges | - |

**Пример preset:**
```yaml
# OpenShift preset for Spark 3.5
# Usage: helm install spark -f charts/spark-3.5/presets/openshift-values.yaml

global:
  s3:
    enabled: true
    endpoint: "http://minio:9000"

rbac:
  create: true

# OpenShift Security Context Constraints
security:
  podSecurityStandards: true
  createNamespace: true
  # OpenShift UID range (adjust for your cluster)
  # Check with: oc describe namespace <project>
  runAsUser: 1000000000
  runAsGroup: 1000000000
  fsGroup: 1000000000
  networkPolicies:
    enabled: true

# Spark Connect server (3.5.x)
connect:
  enabled: true
  eventLog:
    enabled: true
    dir: "s3a://spark-logs/3.5/events"

# History Server
historyServer:
  enabled: true
  provider: "s3"
```

---

## Last updated

2026-02-01 14:30 - Добавлена security testing секция для OpenShift
- Progress: 13/152 (9%) + 8 security scenarios (0%)
- Next: Phase 1 - Baseline для всех + Security tests
