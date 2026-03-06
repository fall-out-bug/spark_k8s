# Demo Guide — Полное руководство по демо spark_k8s

Руководство по развёртыванию, использованию и наблюдению за демо-стендом: Spark Standalone, Airflow, Observability (Prometheus, Grafana, Loki, Jaeger).

---

## 1. Что такое демо

**Демо** — полный стек для разработки и мониторинга Spark на Kubernetes:

| Слой | Компоненты |
|------|------------|
| **Инфраструктура** | MinIO (S3), PostgreSQL, Hive Metastore |
| **Spark** | Standalone Master + Workers, History Server |
| **Оркестрация** | Airflow (DAG'и запускают spark-submit) |
| **Интерактивность** | Jupyter Lab |
| **Observability** | Prometheus, Grafana, Loki, Jaeger, demo-metrics-exporter |

**Namespaces:** `spark-infra` (Spark, Airflow, MinIO), `observability` (Prometheus, Grafana, Loki, Jaeger).

---

## 2. Пререквизиты

- **Minikube** запущен: `minikube status`
- **Helm 3**, **kubectl** установлены
- Рекомендуемый бюджет: 6 CPU / 48Gi RAM

---

## 3. Быстрый старт

```bash
# 1. Образы (ОБЯЗАТЕЛЬНО ПЕРВЫМ)
./scripts/build-and-load-matrix-images.sh --quick

# 2. Развёртывание
./scripts/deploy-demo-minikube.sh

# 3. Port-forwards для UI
./tests/observability/start-ui-portforwards.sh
```

После этого откройте http://localhost:18080 (Airflow), http://localhost:13000 (Grafana).

---

## 4. Развёртывание по шагам

### 4.1. Проверка состояния

```bash
./scripts/check-demo-health.sh
```

- **Exit 0** — демо здорово
- **Exit 1** — выполните `./scripts/restore-demo.sh`

### 4.2. Восстановление (если демо сломано)

```bash
./scripts/restore-demo.sh
```

### 4.3. Полный деплой с нуля

```bash
./scripts/deploy-demo-minikube.sh
```

Скрипт: создаёт namespace, деплоит spark-infra (preset demo-full-spark-infra), observability, загружает spark-jobs и NYC Taxi sample в MinIO.

### 4.4. Дополнительная загрузка данных

| Скрипт | Назначение |
|--------|------------|
| `./scripts/upload-spark-jobs-to-minio.sh spark-infra` | Spark job-скрипты (уже входит в deploy) |
| `./scripts/upload-nyc-taxi-sample.sh spark-infra` | NYC Taxi parquet (для nyc_taxi_ml_full_pipeline) |
| `./scripts/upload-citibike-sample.sh spark-infra` | Citibike sample (для citibike DAG и Jupyter) |

### 4.5. Port-forwards

```bash
./tests/observability/start-ui-portforwards.sh
```

---

## 5. Куда смотреть — URL и порты

| Сервис | URL | Логин |
|--------|-----|-------|
| **Airflow** | http://localhost:18080 | admin/admin |
| **Jupyter** | http://localhost:18888/lab | token в логах |
| **Grafana** | http://localhost:13000/login | admin/admin |
| **History Server** | http://localhost:18081 | — |
| **Spark Master** | http://localhost:18082 | — |
| **Prometheus** | http://localhost:19090 | — |
| **Jaeger** | http://localhost:16686 | — |
| **MinIO Console** | http://localhost:19001 | minioadmin/minioadmin |

**WSL2:** если localhost не работает из Windows, используйте `http://<wsl-ip>:<port>` — скрипт выводит эти URL.

**NodePort (без port-forward):** Grafana — `http://<minikube-ip>:30030`, Jupyter — `http://<minikube-ip>:30088/lab`.

---

## 6. Метрики — что пишется и откуда

### 6.1. demo-metrics-exporter (порт 9108)

Скрапит Spark Master JSON, History API, Airflow PostgreSQL. Интервал: 15 сек.

**Источники:** `SPARK_MASTER_JSON`, `SPARK_HISTORY_API`, Airflow PostgreSQL.

#### Spark (кластер)

| Метрика | Описание | Labels |
|---------|----------|--------|
| `spark_workers_alive` | Живые workers | — |
| `spark_workers_total` | Всего workers | — |
| `spark_apps_running` | Запущенные приложения | — |
| `spark_apps_waiting` | В очереди | — |
| `spark_apps_completed` | Завершённые | — |
| `spark_cores_total` / `spark_cores_used` | Ядра | — |
| `spark_memory_total_mb` / `spark_memory_used_mb` | Память | — |
| `spark_worker_cores_free` | Свободные ядра по worker | worker_id, host |
| `spark_worker_memory_free_mb` | Свободная память по worker | worker_id, host |

#### Spark (job anatomy — по DAG/task)

| Метрика | Описание | Labels |
|---------|----------|--------|
| `spark_job_input_bytes` | Байты чтения (storage) | dag_id, task_id |
| `spark_job_output_bytes` | Байты записи | dag_id, task_id |
| `spark_job_shuffle_read_bytes` | Shuffle read | dag_id, task_id |
| `spark_job_shuffle_write_bytes` | Shuffle write | dag_id, task_id |
| `spark_job_memory_spill_bytes` | Memory spill | dag_id, task_id |
| `spark_job_disk_spill_bytes` | Disk spill | dag_id, task_id |
| `spark_job_fetch_wait_ms` | Ожидание shuffle-блоков (мс) | dag_id, task_id |
| `spark_job_shuffle_write_time_ms` | Блокировка на записи shuffle (мс) | dag_id, task_id |
| `spark_job_duration_ms` | Длительность job | dag_id, task_id |

#### Spark (per-run — точки по запускам)

| Метрика | Описание | Labels |
|---------|----------|--------|
| `spark_job_run_*` | Те же метрики, но по каждому запуску | dag_id, task_id, run_id |

Окно сбора: 7 дней (`DEMO_EXPORTER_RUN_MAX_AGE_SEC`).

#### Executor

| Метрика | Описание | Labels |
|---------|----------|--------|
| `spark_executor_active` | Executor активен | app_id, executor_id, dag_id, task_id |
| `spark_executor_total_tasks` | Всего задач | — |
| `spark_executor_input_bytes` | Input bytes | — |
| `spark_executor_memory_used_bytes` | Cache memory | — |
| `spark_executor_shuffle_read_bytes` | Shuffle read | — |
| `spark_executor_shuffle_write_bytes` | Shuffle write | — |

#### Airflow

| Метрика | Описание | Labels |
|---------|----------|--------|
| `airflow_dag_runs_state` | DAG runs по состоянию | dag_id, state |
| `airflow_task_instances_state` | Task instances по состоянию | dag_id, state |
| `airflow_latest_dag_run_age_seconds` | Возраст последнего run | dag_id |

#### Служебные

| Метрика | Описание |
|---------|----------|
| `demo_metrics_exporter_up` | Exporter работает |
| `demo_metrics_exporter_spark_up` | Spark scrape OK |
| `demo_metrics_exporter_airflow_up` | Airflow scrape OK |

### 6.2. PrometheusServlet (driver pods во время job)

DAG'и включают PrometheusServlet + S3A metrics. Prometheus скрейпит driver pods (label `spark-driver-metrics=true`) **во время выполнения job**.

| Источник | Метрики | Когда доступны |
|----------|---------|----------------|
| Driver/Executor | `filesystem_s3a_*`, `jvm_memory_*` | Только во время job |
| Prometheus | Сохраняет scraped данные | Retention 15 дней |

---

## 7. Дашборды Grafana

**Папка Spark:**

| Дашборд | Назначение |
|---------|------------|
| **Spark Overview** | Workers, apps, cores, memory |
| **Performance Analysis** | Shuffle, spill, duration по DAG/task |
| **Demo Spark Overview** | Exporter up, базовые метрики |
| **Spark Job Anatomy** | Input/output, shuffle, spill, fetch_wait, shuffle_write_time, per-run точки |

**Папка Operations:**

| Дашборд | Назначение |
|---------|------------|
| performance-analysis | Детальный анализ |
| slo-forecast | SLO прогноз |
| incident-metrics | Инциденты |
| cost-by-team, cost-by-job | Стоимость |
| chaos-metrics | Chaos-тесты |
| budget-status, backup-status | Бюджет, бэкапы |
| rto-rpo | RTO/RPO |

**Explore:**
- **Prometheus:** `spark_workers_alive`, `spark_apps_running`, `airflow_dag_runs_state`, `spark_job_run_input_bytes`
- **Loki:** `{namespace="spark-infra"}`, `{app=~"spark|airflow"}`

---

## 8. Логи (Loki)

**Запросы в Grafana → Explore → Loki:**

| Запрос | Описание |
|--------|----------|
| `{namespace="spark-infra"}` | Все логи spark-infra |
| `{app=~"spark|airflow"}` | Spark и Airflow |
| `{pod=~".*driver.*"}` | Driver pods |
| `|= "ERROR"` | Строки с ERROR |

---

## 9. Сценарий использования

### 9.1. Запуск DAG'ов

1. Airflow: http://localhost:18080, admin/admin
2. Включить DAG'и (toggle слева)
3. Запустить:
   - `spark_standalone_load_demo` — простой ETL
   - `nyc_taxi_ml_full_pipeline` — ML pipeline (нужен NYC Taxi data)
   - `citibike_analytics_pipeline` — аналитика Citibike
   - `movielens_recommendation_pipeline` — рекомендации

### 9.2. Наблюдение во время выполнения

- **Spark Master** (18082) — появление приложений
- **History Server** (18081) — завершённые приложения, event logs
- **Grafana → Spark Job Anatomy** — метрики по DAG/task в реальном времени

### 9.3. Jupyter

1. Token: `kubectl logs -n spark-infra -l app.kubernetes.io/component=jupyter --tail=50` — искать `?token=...`
2. http://localhost:18888/lab
3. Demo-ноутбуки: `nyc_taxi_pipeline_demo.ipynb`, `spark_shared_infra_quickstart.ipynb`, `citibike_eda.ipynb` и др.

### 9.4. Jaeger

http://localhost:16686 — трассировка (если Spark отправляет traces в OTLP).

---

## 10. Канонические скрипты

| Скрипт | Назначение |
|--------|------------|
| `./scripts/deploy-demo-minikube.sh` | Полный деплой |
| `./scripts/restore-demo.sh` | Восстановление |
| `./scripts/check-demo-health.sh` | Проверка здоровья |
| `./scripts/tests/minikube/deploy-observability.sh` | Observability stack |
| `./tests/observability/start-ui-portforwards.sh` | Port-forwards |
| `./scripts/deploy-grafana-dashboards.sh observability` | Обновление дашбордов |

---

## 11. Troubleshooting

| Проблема | Действие |
|----------|----------|
| Health check fails | `./scripts/restore-demo.sh` |
| Port-forwards не работают | `pkill -f "kubectl port-forward"` → `./tests/observability/start-ui-portforwards.sh` |
| Grafana без datasources | `./scripts/tests/minikube/deploy-observability.sh` |
| ImagePullBackOff | `./scripts/build-and-load-matrix-images.sh --quick` |
| DAG падает (нет скрипта) | `./scripts/upload-spark-jobs-to-minio.sh spark-infra` |
| nyc_taxi падает (нет данных) | `./scripts/upload-nyc-taxi-sample.sh spark-infra` |
| Jupyter без ноутбуков | `kubectl rollout restart deployment -n spark-infra spark-infra-spark-35-jupyter` |
| Prometheus без endpoints | Патч service selector в `deploy-observability.sh` (app.kubernetes.io/name=prometheus) |

**Подробнее:** [docs/operations/demo-protection.md](../../operations/demo-protection.md)

---

## 12. Ресурсный бюджет (minikube 6 CPU / 48Gi)

| Компонент | CPU req | Memory req |
|-----------|---------|------------|
| System | ~850m | ~300Mi |
| Observability | ~850m | ~1.7Gi |
| spark-infra infra | ~1550m | ~4.5Gi |
| 3 workers | 2400m | 39Gi |
| **Итого** | ~5.6 CPU (93%) | ~45Gi (94%) |
