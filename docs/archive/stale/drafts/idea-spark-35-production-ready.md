# F25: Spark 3.5 Charts Production-Ready

> **Feature ID:** F25
> **Status:** Draft
> **Created:** 2026-02-10
> **Bead:** spark_k8s-ju2
> **Priority:** P0

## Problem

Helm charts для Spark 3.5.7/3.5.8 находятся в нерабочем состоянии:

1. **Chart.yaml** указывает appVersion "3.5.3", а образы используют 3.5.7
2. **values.yaml** содержит ссылки на Spark 4.1 (postgresql host `postgresql-metastore-41`, hive tag `4.0.0-pg`, database `metastore_spark41`)
3. **Scenario values files** (8 шт.) все используют `backendMode: local` вместо заявленных k8s/standalone режимов
4. **Executor pod template** содержит `spark-version: "4.1.0"` вместо 3.5.x
5. **Spark Standalone template отсутствует** — values.yaml описывает master/workers, но шаблон для деплоя не создан
6. **Monitoring templates отсутствуют** — values.yaml определяет ServiceMonitor/PodMonitor/Grafana, но шаблонов нет
7. **OpenShift Route template отсутствует** — только Ingress, Routes для OpenShift не поддерживаются
8. **spark-connect-configmap.yaml** содержит опечатку `spark.shuffle.sort bypassMergeThreshold`, нет Hive Metastore URI

## Users

1. **Data Engineers** — Airflow + Spark Connect для ETL пайплайнов
2. **Data Scientists** — Jupyter + Spark Connect для интерактивного анализа
3. **Platform Engineers** — деплой на K8s/OpenShift с мониторингом Grafana
4. **DevOps** — smoke-тестирование всех сценариев матрицы

## Success Criteria

- [ ] `helm template` проходит без ошибок для всех 8 scenario values
- [ ] Spark Connect работает в режимах: local, k8s, standalone
- [ ] Spark Standalone master + workers деплоятся корректно
- [ ] Connect + Standalone backend работают вместе
- [ ] Prometheus метрики экспортируются (ServiceMonitor/PodMonitor)
- [ ] 3 Grafana дашборда деплоятся как ConfigMap
- [ ] OpenShift Routes создаются для History Server, Jupyter, Spark UI
- [ ] OpenShift presets включают Routes + Monitoring
- [ ] Все ссылки на Spark 4.1 удалены из values.yaml
- [ ] Smoke тесты проходят для 3.5.7 (приоритет) и 3.5.8

## Goals

### P1 — Критический путь
- Spark Connect: k8s + standalone + local backend modes
- Spark Standalone: master + workers deployment в chart
- Jupyter + Spark Connect интеграция
- Airflow + Spark Connect интеграция
- Metrics + profiling (Prometheus exporter + Grafana dashboards)
- OpenShift compatibility (Routes)

### P0 — База (уже частично реализована)
- MinIO S3-compatible storage
- Hive Metastore 3.1.3
- History Server
- RBAC (ServiceAccount, Role, ClusterRole)

## Non-Goals

- Iceberg integration (P2, второй приоритет)
- GPU/RAPIDS support (P2)
- Celeborn shuffle (P2)
- Spark Operator integration (P2)
- MLflow integration (P2)
- Load testing (отдельная фича F13)
- CI/CD pipeline (отдельная фича F15)

## Technical Approach

### Архитектура изменений

```
charts/spark-3.5/
├── Chart.yaml                          # FIX: appVersion 3.5.7
├── values.yaml                         # FIX: remove 4.1 refs, add missing fields
├── templates/
│   ├── spark-connect.yaml              # FIX: add metrics port
│   ├── spark-connect-configmap.yaml    # FIX: typo, add Hive URI, metrics config
│   ├── spark-standalone.yaml           # NEW: master + workers deployment
│   ├── executor-pod-template-cm.yaml   # FIX: spark-version label
│   ├── route.yaml                      # NEW: OpenShift Routes
│   └── monitoring/
│       ├── servicemonitor.yaml         # NEW: Prometheus ServiceMonitor
│       ├── podmonitor.yaml             # NEW: Executor PodMonitor
│       ├── grafana-dashboard-overview.yaml     # NEW
│       ├── grafana-dashboard-executors.yaml    # NEW
│       └── grafana-dashboard-jobs.yaml         # NEW
├── airflow-connect-k8s-3.5.7.yaml     # FIX: backendMode k8s
├── airflow-connect-k8s-3.5.8.yaml     # FIX: backendMode k8s
├── airflow-connect-standalone-3.5.7.yaml  # FIX: backendMode standalone
├── airflow-connect-standalone-3.5.8.yaml  # FIX: backendMode standalone
├── jupyter-connect-k8s-3.5.7.yaml     # FIX: enable connect + k8s mode
├── jupyter-connect-k8s-3.5.8.yaml     # FIX: same
├── jupyter-connect-standalone-3.5.7.yaml  # FIX: backendMode standalone
├── jupyter-connect-standalone-3.5.8.yaml  # FIX: same
└── presets/openshift/
    ├── restricted.yaml                 # UPDATE: add routes + monitoring
    └── anyuid.yaml                     # UPDATE: add routes + monitoring
```

### Метрики

Spark 3.5 поддерживает Prometheus через `PrometheusServlet` (порт 4040) + JMX Exporter.
Добавим:
- `spark.metrics.conf` конфигурацию в ConfigMap
- Порт метрик в Service (порт 4040 или настраиваемый)
- ServiceMonitor для driver, PodMonitor для executors

### Spark Standalone

Template для master (Deployment + Service) и workers (Deployment).
Connect может подключаться к standalone master через `backendMode: standalone`.

### OpenShift Routes

Отдельный template `route.yaml` с condition `routes.enabled`.
Поддержка TLS termination (edge/passthrough/reencrypt).
