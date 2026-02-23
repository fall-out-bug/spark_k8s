# Docker Images Test Matrix

Матрица Docker образов для сборки, тестирования и валидации.

## Размерность

### Базовые образы (3-5 образов)
- JDK base layers (JDK 17, Python 3.10, CUDA 12.1)

### Intermediate слои (5-7 слоёв)
- Spark core (3.5.7, 3.5.8, 4.1.0, 4.1.1)
- Python dependencies
- JDBC drivers
- JARs (RAPIDS, Iceberg)

### Финальные образы (16-20 образов)
- Spark: 4 версии × 4 варианта (baseline, GPU, Iceberg, GPU+Iceberg)
- Jupyter: 4 версии × 4 варианта
- Airflow: baseline
- JupyterHub: baseline

### Тесты (30-40 тестов)
- Unit тесты для каждого слоя
- Integration тесты для каждого финального образа

**Итого:** ~30-40 Docker файлов + тесты

## Легенда

- ✅ = Создано
- ❌ = Не создано
- 🔄 = В работе
- 🔧 = Требует dependencies (JARs, библиотеки)
- 📦 = Базируется на других слоях

---

## Базовые образы (Base Images)

### JDK 17 Base

**Путь:** `docker/base/jdk17/Dockerfile`

| Статус | Описание |
|--------|-----------|
| ❌ | Базовый образ с JDK 17, bash, curl |

**Проверка:**
- [ ] `java -version` показывает 17
- [ ] `bash`, `curl` доступны
- [ ] Минимальный размер образа

**Размер ожидается:** < 200MB

---

### Python 3.10 Base

**Путь:** `docker/base/python310/Dockerfile`

| Статус | Описание |
|--------|-----------|
| ❌ | Базовый образ с Python 3.10, pip |

**Проверка:**
- [ ] `python --version` показывает 3.10
- [ ] `pip` доступен
- [ ] Минимальный размер образа

**Размер ожидается:** < 100MB

---

### CUDA 12.1 Base

**Путь:** `docker/base/cuda121/Dockerfile`

| Статус | Описание |
|--------|-----------|
| ❌ | Базовый образ с CUDA 12.1, cuDNN 8 |

**Проверка:**
- [ ] `nvidia-smi` работает
- [ ] CUDA 12.1 доступен
- [ ] cuDNN библиотеки доступны

**Размер ожидается:** ~4-5GB

---

## Intermediate слои (Intermediate Layers)

### Spark Core 3.5.7

**Путь:** `docker/layers/spark-3.5.7/Dockerfile`

| Статус | Описание | Базируется на |
|--------|-----------|----------------|
| ❌ | Spark 3.5.7 binary | base-jdk17 |
| 🔧 | Hadoop 3.4.1 + AWS SDK v2 | base-jdk17 |
| 🔧 | JDBC драйверы (Vertica, Oracle, PostgreSQL) | spark-core-3.5.7 |
| 🔧 | Python пакеты | spark-core-3.5.7 |

**Размер ожидается:** ~800MB-1GB

---

### Spark Core 3.5.8

| Статус | Описание | Базируется на |
|--------|-----------|----------------|
| ❌ | Spark 3.5.8 binary | base-jdk17 |
| 🔧 | Hadoop 3.4.1 + AWS SDK v2 | base-jdk17 |
| 🔧 | JDBC драйверы | spark-core-3.5.8 |
| 🔧 | Python пакеты | spark-core-3.5.8 |

**Размер ожидается:** ~800MB-1GB

---

### Spark Core 4.1.0

| Статус | Описание | Базируется на |
|--------|-----------|----------------|
| ❌ | Spark 4.1.0 binary (сборка из исходников) | base-jdk17, python310 |
| 🔧 | Hadoop 3.4.1 + AWS SDK v2 | spark-core-4.1.0 |
| 🔧 | JDBC драйверы | spark-core-4.1.0 |
| 🔧 | Python пакеты | spark-core-4.1.0 |

**Размер ожидается:** ~800MB-1.2GB (больше из-за сборки из исходников)

---

### Spark Core 4.1.1

| Статус | Описание | Базируется на |
|--------|-----------|----------------|
| ❌ | Spark 4.1.1 binary (сборка из исходников) | base-jdk17, python310 |
| 🔧 | Hadoop 3.4.1 + AWS SDK v2 | spark-core-4.1.1 |
| 🔧 | JDBC драйверы | spark-core-4.1.1 |
| 🔧 | Python пакеты | spark-core-4.1.1 |

**Размер ожидается:** ~800MB-1.2GB

---

### Python Dependencies Layer

| Статус | Описание | Базируется на |
|--------|-----------|----------------|
| ❌ | Общие Python пакеты для Spark | base-python310 |
| 🔧 | requirements-base.txt | python-deps |
| 🔧 | requirements-gpu.txt (RAPIDS) | python-deps |
| 🔧 | requirements-iceberg.txt (Iceberg) | python-deps |

**Размер ожидается:** ~500MB-1GB

---

### JDBC Drivers Layer

| Статус | Описание | Базируется на |
|--------|-----------|----------------|
| ❌ | Vertica, Oracle, PostgreSQL JDBC | base-jdk17 |

**Размер ожидается:** ~200MB

---

### JARs Layer - RAPIDS

| Статус | Описание | Загрузка |
|--------|-----------|----------|
| ❌ | RAPIDS plugin JARs | Скачиваются из NVIDIA |
| 🔧 | rapids-4-spark_3.x.jar | GPU image |
| 🔧 | rapids-4-spark_2.x.jar | Legacy |

**Размер ожидается:** ~500MB

---

### JARs Layer - Iceberg

| Статус | Описание | Загрузка |
|--------|-----------|----------|
| ❌ | Iceberg JARs | Скачиваются из Apache |
| 🔧 | iceberg-spark-3.x.jar | |
| 🔧 | iceberg-spark-4.x.jar | |

**Размер ожидается:** ~200MB

---

## Финальные образы (Final Images)

### Spark 3.5.7

| Образ | Статус | Базируется на | Размер |
|-------|--------|--------------|-------|
| `spark-custom:3.5.7` | ❌ | spark-core-3.5.7 + python-deps | ~1-1.5GB |
| `spark-custom-gpu:3.5.7` | ❌ | spark-core-3.5.7 + python-deps-gpu + jars-rapids 📦 | ~2-2.5GB |
| `spark-custom-iceberg:3.5.7` | ❌ | spark-core-3.5.7 + python-deps-iceberg + jars-iceberg 📦 | ~1.5-2GB |
| `spark-custom-gpu-iceberg:3.5.7` | ❌ | spark-core-3.5.7 + python-deps-gpu + jars-rapids + jars-iceberg 📦 | ~2.5-3GB |

---

### Spark 3.5.8

| Образ | Статус | Базируется на | Размер |
|-------|--------|--------------|-------|
| `spark-custom:3.5.8` | ❌ | spark-core-3.5.8 + python-deps | ~1-1.5GB |
| `spark-custom-gpu:3.5.8` | ❌ | spark-core-3.5.8 + python-deps-gpu + jars-rapids 📦 | ~2-2.5GB |
| `spark-custom-iceberg:3.5.8` | ❌ | spark-core-3.5.8 + python-deps-iceberg + jars-iceberg 📦 | ~1.5-2GB |
| `spark-custom-gpu-iceberg:3.5.8` | ❌ | spark-core-3.5.8 + python-deps-gpu + jars-rapids + jars-iceberg 📦 | ~2.5-3GB |

---

### Spark 4.1.0

| Образ | Статус | Базируется на | Размер |
|-------|--------|--------------|-------|
| `spark-custom:4.1.0` | ✅ (существует) | spark-core-4.1.0 + python-deps | ~1-1.5GB |
| `spark-custom-gpu:4.1.0` | ❌ | spark-core-4.1.0 + python-deps-gpu + jars-rapids 📦 | ~2-2.5GB |
| `spark-custom-iceberg:4.1.0` | ❌ | spark-core-4.1.0 + python-deps-iceberg + jars-iceberg 📦 | ~1.5-2GB |
| `spark-custom-gpu-iceberg:4.1.0` | ❌ | spark-core-4.1.0 + python-deps-gpu + jars-rapids + jars-iceberg 📦 | ~2.5-3GB |

---

### Spark 4.1.1

| Образ | Статус | Базируется на | Размер |
|-------|--------|--------------|-------|
| `spark-custom:4.1.1` | ✅ (существует) | spark-core-4.1.1 + python-deps | ~1-1.5GB |
| `spark-custom-gpu:4.1.1` | ✅ (существует как 4.1.0-gpu) | spark-core-4.1.1 + python-deps-gpu + jars-rapids 📦 | ~2.5GB |
| `spark-custom-iceberg:4.1.1` | ✅ (существует как 4.1.0-iceberg) | spark-core-4.1.1 + python-deps-iceberg + jars-iceberg 📦 | ~1.5-2GB |
| `spark-custom-gpu-iceberg:4.1.1` | ❌ | spark-core-4.1.1 + python-deps-gpu + jars-rapids + jars-iceberg 📦 | ~2.5-3GB |

---

### Jupyter Images

| Образ | Статус | Базируется на | Размер |
|-------|--------|--------------|-------|
| `jupyter-spark:3.5.7` | ❌ | spark-custom:3.5.7 | ~2-3GB |
| `jupyter-spark:3.5.8` | ✅ (существует) | spark-custom:3.5.8 | ~2-3GB |
| `jupyter-spark-gpu:3.5.7` | ❌ | spark-custom-gpu:3.5.7 | ~3-4GB |
| `jupyter-spark-gpu:3.5.8` | ❌ | spark-custom-gpu:3.5.8 | ~3-4GB |
| `jupyter-spark-iceberg:3.5.7` | ❌ | spark-custom-iceberg:3.5.7 | ~3-4GB |
| `jupyter-spark-iceberg:3.5.8` | ❌ | spark-custom-iceberg:3.5.8 | ~3-4GB |
| `jupyter-spark:4.1.0` | ✅ (существует) | spark-custom:4.1.0 | ~2-3GB |
| `jupyter-spark:4.1.1` | ❌ | spark-custom:4.1.1 | ~2-3GB |
| `jupyter-spark-gpu:4.1.0` | ❌ | spark-custom-gpu:4.1.0 | ~3-4GB |
| `jupyter-spark-gpu:4.1.1` | ❌ | spark-custom-gpu:4.1.1 | ~3-4GB |
| `jupyter-spark-iceberg:4.1.0` | ❌ | spark-custom-iceberg:4.1.0 | ~3-4GB |
| `jupyter-spark-iceberg:4.1.1` | ❌ | spark-custom-iceberg:4.1.1 | ~3-4GB |

---

### Airflow Images

| Образ | Статус | Описание |
|-------|--------|-----------|
| `airflow-spark:latest` | ❌ | Airflow с интеграцией Spark |
| `airflow-spark-gpu:latest` | ❌ | Airflow + GPU образ |

---

## Unit тесты слоёв

### Base слои (3 теста)

| Тест | Статус | Проверяет |
|------|--------|----------|
| `test-base-jdk17.sh` | ❌ | JDK 17 base образ |
| `test-base-python310.sh` | ❌ | Python 3.10 base образ |
| `test-base-cuda121.sh` | ❌ | CUDA 12.1 base образ |

---

### Intermediate слои (7 тестов)

| Тест | Статус | Проверяет |
|------|--------|----------|
| `test-spark-core-357.sh` | ❌ | Spark 3.5.7 core слой |
| `test-spark-core-358.sh` | ❌ | Spark 3.5.8 core слой |
| `test-spark-core-410.sh` | ❌ | Spark 4.1.0 core слой |
| `test-spark-core-411.sh` | ❌ | Spark 4.1.1 core слой |
| `test-python-deps.sh` | ❌ | Python dependencies слой |
| `test-jdbc-drivers.sh` | ❌ | JDBC драйверы слой |
| `test-jars-rapids.sh` | ❌ | RAPIDS JARs слой |
| `test-jars-iceberg.sh` | ❌ | Iceberg JARs слой |

---

## Integration тесты образов

### Spark образы (16 тестов)

| Тест | Статус | Проверяет |
|------|--------|----------|
| `test-spark-357.sh` | ❌ | spark-custom:3.5.7 |
| `test-spark-358.sh` | ❌ | spark-custom:3.5.8 |
| `test-spark-410.sh` | ❌ | spark-custom:4.1.0 |
| `test-spark-411.sh` | ❌ | spark-custom:4.1.1 |
| `test-spark-gpu-357.sh` | ❌ | spark-custom-gpu:3.5.7 |
| `test-spark-gpu-358.sh` | ❌ | spark-custom-gpu:3.5.8 |
| `test-spark-gpu-410.sh` | ❌ | spark-custom-gpu:4.1.0 |
| `test-spark-gpu-411.sh` | ❌ | spark-custom-gpu:4.1.1 |
| `test-spark-iceberg-357.sh` | ❌ | spark-custom-iceberg:3.5.7 |
| `test-spark-iceberg-358.sh` | ❌ | spark-custom-iceberg:3.5.8 |
| `test-spark-iceberg-410.sh` | ❌ | spark-custom-iceberg:4.1.0 |
| `test-spark-iceberg-411.sh` | ❌ | spark-custom-iceberg:4.1.1 |
| `test-spark-gpu-iceberg-357.sh` | ❌ | spark-custom-gpu-iceberg:3.5.7 |
| `test-spark-gpu-iceberg-358.sh` | ❌ | spark-custom-gpu-iceberg:3.5.8 |
| `test-spark-gpu-iceberg-410.sh` | ❌ | spark-custom-gpu-iceberg:4.1.0 |
| `test-spark-gpu-iceberg-411.sh` | ❌ | spark-custom-gpu-iceberg:4.1.1 |

### Jupyter образы (12 тестов)

| Тест | Статус | Проверяет |
|------|--------|----------|
| `test-jupyter-357.sh` | ❌ | jupyter-spark:3.5.7 |
| `test-jupyter-358.sh` | ❌ | jupyter-spark:3.5.8 |
| `test-jupyter-410.sh` | ❌ | jupyter-spark:4.1.0 |
| `test-jupyter-411.sh` | ❌ | jupyter-spark:4.1.1 |
| `test-jupyter-gpu-357.sh` | ❌ | jupyter-spark-gpu:3.5.7 |
| `test-jupyter-gpu-358.sh` | ❌ | jupyter-spark-gpu:3.5.8 |
| `test-jupyter-gpu-410.sh` | ❌ | jupyter-spark-gpu:4.1.0 |
| `test-jupyter-gpu-411.sh` | ❌ | jupyter-spark-gpu:4.1.1 |
| `test-jupyter-iceberg-357.sh` | ❌ | jupyter-spark-iceberg:3.5.7 |
| `test-jupyter-iceberg-358.sh` | ❌ | jupyter-spark-iceberg:3.5.8 |
| `test-jupyter-iceberg-410.sh` | ❌ | jupyter-spark-iceberg:4.1.0 |
| `test-jupyter-iceberg-411.sh` | ❌ | jupyter-spark-iceberg:4.1.1 |

---

## Сводная таблица

### Docker файлы

| Категория | Всего | Создано | Осталось |
|-----------|-------|---------|----------|
| Base layers | 3 | 0 | 3 |
| Intermediate layers | 7 | 0 | 7 |
| Final images | 20 | 2 | 18 |
| Unit tests | 10 | 0 | 10 |
| Integration tests | 28 | 0 | 28 |
| **ИТОГО** | **68** | **2** | **66** |

### Прогресс по версиям Spark

| Версия | Базовый | GPU | Iceberg | GPU+Iceberg | Итого |
|--------|--------|-----|---------|--------------|-------|
| 3.5.7 | 0 | 0 | 0 | 0 | 0/4 |
| 3.5.8 | 0 | 0 | 0 | 0 | 0/4 |
| 4.1.0 | 1 | 1 | 1 | 0 | 3/4 |
| 4.1.1 | 1 | 1 | 1 | 0 | 3/4 |
| **ИТОГО** | **2/8** | **2/8** | **2/8** | **0/8** | **6/16** |

---

## Структура тестов Docker

### Unit тест слоя

```bash
#!/bin/bash
# @meta
name: "test-base-jdk17"
type: "unit"
description: "Unit test for JDK 17 base Docker layer"
layer: "base-jdk17"
dockerfile: "docker/base/jdk17/Dockerfile"
# @endmeta

# Запуск контейнера
container=$(docker run -d base-jdk17:latest sleep 30)

# Проверки
docker exec $container java -version 2>&1 | grep -q "17"
docker exec $container which curl
docker exec $container which bash

# Cleanup
docker stop $container
```

### Integration тест образа

```bash
#!/bin/bash
# @meta
name: "test-spark-410"
type: "integration"
description: "Integration test for spark-custom:4.1.0"
image: "spark-custom:4.1.0"
# @endmeta

# Запуск Spark job
docker run --rm spark-custom:4.1.0 \
    /opt/spark/bin/spark-submit \
    --master local[*] \
    --conf spark.driver.memory=512m \
    /opt/spark/examples/src/main/python/pi.py 10
```

---

## Build скрипты

### Сборка базовых слоёв

```bash
scripts/build-base-layers.sh
```

Собирает в порядке:
1. base-jdk17
2. base-python310
3. base-cuda121

Параллельно, так как слои независимы.

---

### Сборка intermediate слоёв

```bash
scripts/build-intermediate-layers.sh
```

Собирает в порядке:
1. spark-core-3.5.7 (после base слоёв)
2. spark-core-3.5.8
3. spark-core-4.1.0
4. spark-core-4.1.1
5. python-deps
6. jdbc-drivers

Можно параллелить spark-core для разных версий.

---

### Сборка финальных образов

```bash
scripts/build-final-images.sh
```

Собирает все финальные образы:
- spark-custom для всех версий и вариантов
- jupyter-spark для всех версий и вариантов

Параллелит всё что возможно.

---

## Зависимости для сборки

### RAPIDS (GPU)

- CUDA 12.1
- cuDF, cuSpark, Rapids Plugin
- Версии должны совпадать с версией CUDA

**JARs для скачивания:**
- rapids-4-spark_3.x.jar
- cudf.jar
- Rapids SQL plugin

### Iceberg

- Apache Iceberg JARs
- Hive Metastore (для catalog)
- S3A connector

**JARs для скачивания:**
- iceberg-spark-3.x.jar или iceberg-spark-4.x.jar
- iceberg-hive-runtime.jar

---

## План работ

### Phase 1: Базовые слои (3 Dockerfiles + 3 теста)
- `docker/base/jdk17/Dockerfile`
- `docker/base/python310/Dockerfile`
- `docker/base/cuda121/Dockerfile`
- `docker/tests/unit/test-base-*.sh` (3 файла)

### Phase 2: Intermediate слои - Spark Core (4 Dockerfiles + 4 теста)
- `docker/layers/spark-3.5.7/Dockerfile`
- `docker/layers/spark-3.5.8/Dockerfile`
- `docker/layers/spark-4.1.0/Dockerfile`
- `docker/layers/spark-4.1.1/Dockerfile`
- Unit тесты для каждого

### Phase 3: Intermediate слои - Dependencies (3 Dockerfiles + 3 теста)
- `docker/layers/python-deps/Dockerfile`
- `docker/layers/jdbc-drivers/Dockerfile`
- `docker/layers/jars/rapids/download.sh` + Dockerfile
- `docker/layers/jars/iceberg/download.sh` + Dockerfile
- Unit тесты для каждого

### Phase 4: Финальные образы - Spark 3.5 (8 Dockerfiles + 8 тестов)
- spark-custom:3.5.7 (baseline)
- spark-custom-gpu:3.5.7
- spark-custom-iceberg:3.5.7
- spark-custom-gpu-iceberg:3.5.7
- spark-custom:3.5.8 (baseline)
- spark-custom-gpu:3.5.8
- spark-custom-iceberg:3.5.8
- spark-custom-gpu-iceberg:3.5.8
- Integration тесты для всех

### Phase 5: Финальные образы - Spark 4.1 (8 Dockerfiles + 8 тестов)
- spark-custom:4.1.0 (baseline) ✅
- spark-custom-gpu:4.1.0
- spark-custom-iceberg:4.1.0
- spark-custom-gpu-iceberg:4.1.0
- spark-custom:4.1.1 (baseline) ✅
- spark-custom-gpu:4.1.1
- spark-custom-iceberg:4.1.1
- spark-custom-gpu-iceberg:4.1.1
- Integration тесты для всех

### Phase 6: Финальные образы - Jupyter (12 Dockerfiles + 12 тестов)
- jupyter-spark:3.5.7
- jupyter-spark:3.5.8 ✅
- jupyter-spark-gpu:3.5.7
- jupyter-spark-gpu:3.5.8
- jupyter-spark-iceberg:3.5.7
- jupyter-spark-iceberg:3.5.8
- jupyter-spark:4.1.0 ✅
- jupyter-spark:4.1.1
- jupyter-spark-gpu:4.1.0
- jupyter-spark-gpu:4.1.1
- jupyter-spark-iceberg:4.1.0
- jupyter-spark-iceberg:4.1.1
- Integration тесты для всех

### Phase 7: Скрипты сборки
- `scripts/build-base-layers.sh`
- `scripts/build-intermediate-layers.sh`
- `scripts/build-final-images.sh`
- `scripts/build-all.sh` (оркестратор)

---

## Last updated

2026-02-01 12:00 - Initial matrix creation
- Progress: 2/68 файлов (3%)
- Next: Phase 1 - Base layers + tests
- Создано: spark-custom:4.1.0, spark-custom:4.1.1 (legacy)
