# Глубокий анализ демо spark_k8s

**Дата:** 2026-03-06  
**Метод:** проверка документации, кода, запуск скриптов, верификация компонентов

---

## 1. Резюме

| Аспект | Статус | Критичность |
|--------|--------|-------------|
| check-demo-health | ✅ Pass | — |
| spark-infra pods | ✅ Running | — |
| observability pods | ⚠️ 1 Pending (loki-gateway) | Низкая |
| upload-spark-jobs | 🔴 **Критический баг** | Высокая |
| Port-forwards | ✅ Работают | — |
| Airflow | ✅ Доступен (18080) | — |
| Документация vs код | ⚠️ Расхождения | Средняя |

---

## 2. Архитектура демо

### 2.1. Компоненты (preset demo-full-spark-infra)

| Компонент | Namespace | Сервис | Ресурсы |
|-----------|-----------|--------|---------|
| MinIO | spark-infra | minio:9000/9001 | 100m/256Mi |
| PostgreSQL | spark-infra | spark-infra-spark-base-postgresql:5432 | 100m/256Mi |
| Spark Master | spark-infra | spark-infra-standalone-master:7077,8080 | 300m/512Mi |
| Spark Workers | spark-infra | — | 3×800m/13Gi |
| Airflow | spark-infra | spark-infra-airflow-webserver:8080 | 250m/512Mi |
| History Server | spark-infra | spark-infra-spark-35-history:18080 | 100m/256Mi |
| Jupyter | spark-infra | spark-infra-spark-35-jupyter:8888 | 300m/2Gi |
| Hive Metastore | spark-infra | spark-infra-spark-35-metastore:9083 | 100m/256Mi |
| Grafana | observability | observability-demo-grafana:3000 | — |
| Prometheus | observability | observability-demo-prometh-prometheus:9090 | — |
| Loki | observability | observability-demo-loki:3100 | — |
| demo-metrics-exporter | observability | demo-metrics-exporter:9108 | 25m/64Mi |

### 2.2. Порты (port-forwards)

| Сервис | localhost | Целевой сервис |
|--------|-----------|----------------|
| Airflow | 18080 | spark-infra-airflow-webserver:8080 |
| Jupyter | 18888 | spark-infra-spark-35-jupyter:8888 |
| Grafana | 13000 | observability-demo-grafana:3000 |
| History | 18081 | spark-infra-spark-35-history:18080 |
| Prometheus | 19090 | observability-demo-prometh-prometheus:9090 |
| Spark Master | 18082 | spark-infra-standalone-master:8080 |
| MinIO API | 19000 | minio:9000 |
| MinIO Console | 19001 | minio:9001 |

**Проверка:** имена сервисов в `start-ui-portforwards.sh` соответствуют фактическим K8s Service.

---

## 3. Критический баг: upload-spark-jobs-to-minio.sh

### Проблема

Скрипт загружает **неправильные файлы** в MinIO:

- **Текущее поведение:** `SPARK_JOBS_DIR=charts/spark-3.5/dags` → загружаются DAG-файлы:
  - `nyc_taxi_ml_full_pipeline.py`
  - `citibike_analytics_pipeline.py`
  - `movielens_recommendation_pipeline.py`
  - `spark_standalone_load_demo.py`

- **Ожидаемое поведение:** DAG'и скачивают из MinIO `dags/spark_jobs/{script_name}`:
  - nyc_taxi: `taxi_feature_engineering.py`, `taxi_catboost_training.py`, `taxi_predict.py`
  - movielens: `movielens_feature_engineering.py`, `movielens_als_training.py`, `movielens_generate_recs.py`
  - citibike: `citibike_feature_engineering.py`, `citibike_statistics.py`

### Фактическое состояние репо

- `dags/spark_jobs/` содержит только: `taxi_feature_engineering.py`, `taxi_catboost_training.py`, `taxi_predict.py`
- `movielens_*.py` и `citibike_*.py` (кроме DAG) **отсутствуют** в репозитории

### Последствия

1. **spark_standalone_load_demo** — работает (скрипт встроен в DAG, MinIO не нужен)
2. **nyc_taxi_ml_full_pipeline** — падает при выполнении: нет `taxi_feature_engineering.py` в MinIO
3. **movielens_recommendation_pipeline** — падает: нет скриптов и их нет в репо
4. **citibike_analytics_pipeline** — падает: нет скриптов и их нет в репо

### Исправление (применено)

- `SPARK_JOBS_DIR` изменён на `dags/spark_jobs`
- После исправления загружаются: `taxi_feature_engineering.py`, `taxi_catboost_training.py`, `taxi_predict.py`
- **nyc_taxi_ml_full_pipeline** теперь должен работать

### Исправления (2026-03-06)

- Добавлены скрипты: `movielens_feature_engineering.py`, `movielens_als_training.py`, `movielens_generate_recs.py`, `citibike_feature_engineering.py`, `citibike_statistics.py`
- DAG'и movielens и citibike переведены на образ `spark-custom:3.5.7` (вместо spark-custom-ml)

---

## 4. Документация vs код

### 4.1. demo-protection.md

- Указано: "Service names: spark-infra-standalone-* (master, **airflow**)"
- Факт: Airflow сервис — `spark-infra-airflow-webserver`, не standalone
- **Рекомендация:** уточнить в документе: airflow-webserver не входит в standalone-*

### 4.2. demo-screencast-guide.md

- Чеклист требует "Все DAG'и запущены" — при текущем баге upload это недостижимо для nyc_taxi, movielens, citibike
- Путь к Jupyter token корректен: `kubectl logs -n spark-infra -l app.kubernetes.io/component=jupyter --tail=50`

### 4.3. Worker replicas

- Preset: `replicas: 3`
- Факт при проверке: 2 worker pod (возможна нехватка ресурсов или eviction)
- **Рекомендация:** проверить `kubectl describe node` и события eviction

---

## 5. Observability

### 5.1. Prometheus Operator

- Используется образ `quay.io/prometheus-operator/prometheus-operator:v0.68.0` (v0.38.1 недоступен)
- Post-renderer убирает устаревшие флаги: `--logtostderr`, `--config-reloader-image`, `--config-reloader-cpu`, `--config-reloader-memory`
- Статус: оператор Running

### 5.2. Loki

- Режим SingleBinary (исправлено в values: `loki.deploymentMode`)
- Один pod Pending (loki-gateway) — вероятно, старый ReplicaSet; не блокирует работу

### 5.3. demo-metrics-exporter

- Жёстко заданы имена `spark-infra-*` через values (корректно для демо)
- Скрапит: Spark Master JSON, History API, Airflow PostgreSQL
- Метрики: `spark_workers_alive`, `spark_apps_running`, `airflow_dag_runs_state` и др.

---

## 6. Ресурсный бюджет (6 CPU / 48Gi minikube)

| Компонент | CPU req | Memory req |
|-----------|---------|------------|
| System | ~850m | ~300Mi |
| Observability | ~250m | ~544Mi |
| spark-infra infra | ~1550m | ~4.5Gi |
| 3 workers × 800m/13Gi | 2400m | 39Gi |
| **Итого** | ~5050m (84%) | ~44Gi (92%) |

Preset и `test_demo_preset_guard.py` согласованы с этим бюджетом.

---

## 7. Чек-лист работоспособности

| Проверка | Результат |
|----------|-----------|
| `./scripts/check-demo-health.sh` | ✅ Exit 0 |
| `kubectl get pods -n spark-infra` | ✅ Все Running |
| `kubectl get pods -n observability` | ⚠️ 1 Pending (loki-gateway дубликат) |
| `./scripts/upload-spark-jobs-to-minio.sh` | ✅ Исправлено: загружает taxi_*.py из dags/spark_jobs |
| `./tests/observability/start-ui-portforwards.sh` | ✅ Все port-forwards OK |
| Airflow http://localhost:18080/health | ✅ 200 |
| DAG spark_standalone_load_demo | ✅ Должен работать |
| DAG nyc_taxi_ml_full_pipeline | ✅ Должен работать (taxi_*.py загружены) |
| DAG movielens_recommendation_pipeline | 🔴 Падает (нет скриптов) |
| DAG citibike_analytics_pipeline | 🔴 Падает (нет скриптов) |

---

## 8. Рекомендации

1. ~~**Срочно:** исправить `upload-spark-jobs-to-minio.sh`~~ — **исправлено** (SPARK_JOBS_DIR=dags/spark_jobs)
2. **Средний приоритет:** добавить отсутствующие movielens и citibike скрипты или отключить эти DAG'и
3. **Низкий приоритет:** удалить Pending loki-gateway pod, уточнить формулировки в demo-protection.md
4. **Проверка:** после исправления upload — прогнать все 4 DAG'а и убедиться, что они завершаются успешно
