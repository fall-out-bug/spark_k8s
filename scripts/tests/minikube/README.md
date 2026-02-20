# Minikube scenarios (Spark 3.5.7, Airflow 2.11)

Запуск сценариев в minikube: инфра, Jupyter+Spark Connect (standalone)+Spark SA, Airflow+Spark SA.

## Требования

- minikube (`minikube start --cpus=4 --memory=8g`)
- kubectl, helm 3
- Docker (для сборки образов)

## Образы

Сценарии используют образы, которых нет в публичном registry:

- **Hive Metastore:** `spark-k8s/hive:3.1.3-pg` — нужна сборка из `docker/hive` (HIVE_VERSION=3.1.3).
- **History Server / Connect / Standalone:** `spark-custom:3.5.7-new` — сборка из `docker/spark-custom`.
- **Jupyter:** `spark-k8s-jupyter:3.5-3.5.7` — сборка из `docker/runtime/jupyter` или аналог.
- **Airflow:** `spark-k8s-airflow:3.5-3.5.7` — сборка из `docker/optional/airflow` или аналог.

Перед запуском сценариев соберите и загрузите образы в minikube:

```bash
./scripts/tests/minikube/build-and-load-images.sh
```

Либо задайте свои образы через `--set historyServer.image.repository=...` и т.д.

## Сценарии

| # | Описание | Команда |
|---|----------|---------|
| 0 | Инфра: MinIO + Hive Metastore + History Server | `./run-minikube-scenarios.sh 0` |
| 1 | Jupyter + Spark Connect (standalone) + Spark Standalone K8s | `./run-minikube-scenarios.sh 1` |
| 2 | Airflow K8s + Spark Standalone K8s | `./run-minikube-scenarios.sh 2` |
| all | Последовательно 0 → observability → 1 → 2 | `./run-minikube-scenarios.sh all` |

Сценарии 1 и 2 ожидают, что в кластере уже развёрнута инфра (сценарий 0) в namespace `spark-infra` (MinIO, Postgres, Hive, History Server). При запуске `all` после сценария 0 автоматически вызывается `deploy-observability.sh` (OTEL Collector + Grafana в namespace `observability`). Release-имена: сценарий 1 — `scenario1`, сценарий 2 — `scenario2`.

## Observability (телеметрия + Grafana)

Телеметрия нужна и в Airflow, и в джобах Spark (Connect/драйверы). Дашборд — в Grafana.

1. После сценария 0 разверните стек: `./scripts/tests/minikube/deploy-observability.sh`  
   Создаётся namespace `observability`, OTEL Collector (`otel-collector.observability.svc.cluster.local:4317`) и Grafana.
2. В пресете `spark-infra`: `monitoring.enabled: true`, `monitoring.grafanaDashboards.enabled: true`.  
   Чтобы дашборды подхватились Grafana: `monitoring.grafanaDashboards.namespace: observability`.
3. В пресетах сценариев 1/2 (Jupyter, Airflow): `connect.openTelemetry.enabled: true`, `endpoint: "http://otel-collector.observability.svc.cluster.local:4317"`, `connect.eventLog.enabled: true` (event log в S3 для History Server).
4. Grafana: `kubectl port-forward svc/grafana 3000:80 -n observability` → http://localhost:3000 (admin/admin). Дашборды Spark из чарта подгружаются sidecar'ом (ConfigMaps с меткой `grafana_dashboard=1`).

## Smoke / E2E / Load (тесты используют инфраструктуру)

Тесты имеют смысл только с инфрой: S3 (MinIO) для event log, History Server для проверки джобов.

- **Smoke (Connect доступен):** `kubectl run nc --rm -i --restart=Never -n spark-35-jupyter-sa --image=busybox:1.36 -- nc -zv scenario1-spark-35-connect 15002`.
- **Load-тест:** выполняется **в кластере** (под с образом spark-custom). По умолчанию пишет event log в S3 (`LOAD_EVENT_LOG_DIR=s3a://spark-logs/events`) и **обязательно** проверяет, что History Server показывает приложение после теста (иначе тест падает). Endpoint MinIO по умолчанию: `http://minio.spark-infra.svc.cluster.local:9000`.  
  `./scripts/test-spark-connect-standalone-load.sh spark-35-jupyter-sa scenario1 scenario1-spark-35-standalone-master:7077`  
  (release `scenario1`, Standalone master: `scenario1-spark-35-standalone-master:7077`)
- **Проверка History Server:** `./scripts/tests/minikube/verify-history-server.sh`
- **E2E:** `./scripts/tests/integration/test-spark-35-minikube.sh` (при наличии образов и namespace).
- **Load:** скрипты из `scripts/tests/load/` (читают/пишут S3) и `scripts/test-spark-connect-standalone-load.sh`.

Проверка артефактов:

- **History Server:** `kubectl port-forward svc/spark-infra-spark-35-history 18080:18080 -n spark-infra` → http://localhost:18080 (должен возвращать 200 и список приложений).
- **Телеметрия:** при включённом `connect.openTelemetry` джобы Spark шлют трассы в OTEL Collector; дашборд — в Grafana (см. Observability выше).

## Hive + Postgres 15

Postgres 15 по умолчанию использует SCRAM-SHA-256 (auth type 10). Старый JDBC в образе Hive его не поддерживает.

- **Рекомендуется:** образ Hive с JDBC 42.7+ (сборка из `docker/hive`): `./scripts/tests/minikube/build-and-load-images.sh` (собирает `spark-k8s/hive:3.1.3-pg`), затем `kubectl rollout restart deployment/spark-infra-spark-35-metastore -n spark-infra`. Убедитесь, что образ собирается в minikube (`eval $(minikube docker-env)`).
- **Либо:** при первом деплое spark-infra с пресетом задаётся `spark-base.postgresql.authMethod: md5` — тогда при первой инициализации Postgres создаёт пользователей с md5. Если Postgres уже был развёрнут без md5, пересоздайте PVC и StatefulSet (потеря данных) или используйте образ Hive с JDBC 42.7.

## Исправления в пресетах (уже внесены)

- В `presets/spark-infra.yaml`: `global.postgresql`, `spark-base.postgresql.databases`, `spark-base.postgresql.authMethod: md5` (для Hive JDBC), `rbac.create: true`, образы Hive/History, endpoint MinIO.
- S3 endpoint для сценариев 1/2: `http://minio.spark-infra.svc.cluster.local:9000` (сервис MinIO в spark-base называется `minio`).
- Load-тест: если Connect развёрнут без `connect.eventLog.enabled=true`, проверка History Server может не пройти; задайте `LOAD_REQUIRE_HISTORY_SERVER=false` или переустановите сценарий с event log.
