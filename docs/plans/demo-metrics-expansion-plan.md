# Demo Metrics Expansion Plan

**Цель:** Максимальный объём метрик и дашбордов в демо, полное разнообразие пайплайнов (включая SparkML), проброс портов на хост из WSL.

---

## 1. Текущее состояние (по beads и коду)

### Beads задачи
- **F23 (spark_k8s-f0t):** Quick Start Experience — sample notebook creation
- **WS-016-01 (spark_k8s-0su):** Metrics collection (Prometheus)
- **WS-016-04 (spark_k8s-e7p):** Dashboards (Grafana) — 5+ дашбордов

### Текущие DAGs
| DAG | Статус | Spark jobs |
|-----|--------|------------|
| `nyc_taxi_ml_full_pipeline` | ✅ | taxi_feature_engineering, taxi_catboost_training, taxi_predict |
| `spark_standalone_load_demo` | ✅ | inline |
| `citibike_analytics_pipeline` | ✅ | citibike_feature_engineering, citibike_statistics |
| `movielens_recommendation_pipeline` | ⚠️ | movielens_feature_engineering ✅, **movielens_als_training ❌**, **movielens_generate_recs ❌** |
| `spark_etl_example` | ❌ Удалён из chart (остался в docker/optional) | — |
| `spark_streaming_example` | ❌ Удалён из chart (остался в docker/optional) | — |

### Текущие notebooks
- `nyc_taxi_pipeline_demo.ipynb` — базовый ETL
- `spark_shared_infra_quickstart.ipynb` — quickstart
- `nyc_taxi_ml_training_pipeline.ipynb` — ML pipeline

### Метрики (demo-metrics-exporter)
- Spark: workers, apps, cores, memory, executors, stages (input/output/shuffle/spill)
- Airflow: **только TARGET_DAG=spark_standalone_load_demo** — остальные DAGs не скрейпятся

### Проброс портов
- `start-ui-portforwards.sh`: Airflow 18080, Jupyter 18888, Grafana 13000, History 18081, Prometheus 19090, MinIO 19000/19001
- NodePorts в runbook: Airflow 30080, Jupyter 30088, History 30081, Grafana 30030, Prometheus 30090
- **Проблема:** values-demo не задаёт NodePorts для Airflow/Jupyter/Master — доступ только через port-forward

### Values files (без дублирования)
| Файл | Назначение |
|------|------------|
| `charts/spark-3.5/values-demo-full-pipeline.yaml` | Полный demo: standalone+airflow+connect+jupyter+history |
| `tests/demo-values.yaml` | Минимальный demo: standalone+minio+metastore+history |
| `tests/shared-infra-values.yaml` | Shared infra только: minio+metastore+history |
| **Правило:** один preset для demo (values-demo-full-pipeline), tests/* — для e2e/runbook |

---

## 2. Требования (из запроса)

| Требование | Текущее | Нужно |
|------------|---------|-------|
| Jupyter EDA | Частично | Полноценный EDA notebook |
| Feature engineering on Spark | ✅ citibike, movielens, taxi | Добавить pandas UDF примеры |
| ML model learning with Spark pandas UDF | ❌ | Новый pipeline/notebook |
| Артефакты на S3 | ✅ | Модели, метрики в ml-models, nyc-taxi |
| Airflow — несколько пайплайнов параллельно | max_active_runs=1 | Разрешить параллельность |
| Метрики джобов | ✅ History API | + memory, resource wait, S3 I/O |
| Метрики кластера | ✅ | — |
| Метрики Airflow | 1 DAG | Все DAGs |
| Анализ тюнинга | ❌ | Дашборд shuffle/spill/partitions |
| Логи в History Server | ✅ eventLog.dir | Проверить все DAGs |
| MinIO, Metastore, History Server | ✅ | — |
| Проброс портов на хост WSL | port-forward 0.0.0.0 | + NodePort в values |

---

## 3. План работ

### 3.1 Критичные (блокеры)
1. **Создать movielens_als_training.py, movielens_generate_recs.py** — иначе movielens DAG падает
2. **Скопировать taxi_feature_engineering.py, taxi_predict.py** в `charts/.../dags/spark_jobs/` — DAGs качают из S3 spark-jobs
3. **Убрать spark_etl_example, spark_streaming_example** из dags или восстановить
4. **Добавить citibike, movielens в dags** в values spark-standalone

### 3.2 demo-metrics-exporter
5. **Скрейпить все DAGs** — убрать TARGET_DAG, итерировать по dag_run/task_instance для всех DAGs
6. **Добавить метрики:** `spark_executor_memory_used`, `spark_stage_s3_read_time_ms`, `spark_stage_s3_write_time_ms` (если есть в History API)

### 3.3 Дашборды Grafana
7. **Дашборд тюнинга:** shuffle read/write, memory/disk spill, partitions, duration
8. **Дашборд S3 I/O:** input/output bytes по приложениям
9. **Дашборд Airflow multi-DAG:** все DAGs, task states

### 3.4 Notebooks
10. **Jupyter EDA** — explorative analysis (citibike/nyc-taxi), визуализации
11. **Feature engineering + pandas UDF** — пример mapInPandas / applyInPandas
12. **ML pipeline с pandas UDF** — обучение по borough с pandas UDF

### 3.5 Пайплайны
13. **Новый DAG:** e.g. `s3_io_benchmark` — чисто для метрик S3 read/write
14. **Параллельность Airflow:** max_active_runs=2–3 для разных DAGs

### 3.6 Порты
15. **values-demo NodePorts:** Airflow 30080, Jupyter 30088, History 30081, Spark Master 30082
16. **start-ui-portforwards:** добавить Spark Master 18082:8080
17. **Документация WSL:** как пробросить minikube в WSL на Windows host

---

## 4. Порядок выполнения

```
Phase 1 (блокеры):
  - movielens_als_training.py, movielens_generate_recs.py
  - taxi_feature_engineering.py, taxi_predict.py в spark_jobs
  - dags: убрать etl/streaming, добавить citibike, movielens

Phase 2 (метрики):
  - demo-metrics-exporter: все DAGs
  - Дашборды: tuning, S3 I/O, Airflow multi

Phase 3 (контент):
  - Notebooks: EDA, pandas UDF, ML
  - Новый DAG s3_io_benchmark
  - Параллельность Airflow

Phase 4 (порты):
  - NodePorts в values-demo
  - Port-forward Spark Master
  - WSL runbook
```

---

## 5. Файлы для изменения

| Файл | Действие |
|------|----------|
| `charts/.../dags/spark_jobs/movielens_als_training.py` | Создать |
| `charts/.../dags/spark_jobs/movielens_generate_recs.py` | Создать |
| `charts/.../dags/spark_jobs/taxi_feature_engineering.py` | Скопировать из dags/ |
| `charts/.../dags/spark_jobs/taxi_predict.py` | Скопировать из dags/ |
| `charts/.../values.yaml` dags | citibike, movielens, убрать etl/streaming |
| `tests/observability/demo-metrics-exporter.yaml` | Все DAGs |
| `tests/observability/grafana-dashboards-*.yaml` | Новые дашборды |
| `charts/.../notebooks/` | EDA, pandas UDF, ML |
| `tests/demo-values.yaml` или preset | NodePorts |
| `tests/observability/start-ui-portforwards.sh` | Spark Master |
