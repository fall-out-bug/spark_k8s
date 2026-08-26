# Handoff: Spark 3.5 для команды С7 (свежие S3-библиотеки, k8s, мониторинг)

> Дата: 2026-08-26 · Ветка: `dev` · Контакт: fall_out_bug

## Что передаём

Helm-чарты Apache Spark на Kubernetes с фокусом на **Spark 3.5.x** и
собственными образами, в которых заменён древний bundled S3-стек:

| Компонент | Версия | Откуда |
|---|---|---|
| Spark | 3.5.7 / 3.5.8 (исходники apache/spark) | `docker/spark-custom/Dockerfile.3.5.{7,8}` |
| Hadoop client | **3.4.2** (`-Dhadoop.version`) | там же, multi-stage build |
| hadoop-aws | 3.4.2 (в т.ч. свежий s3a) | следует из Hadoop client |
| AWS SDK v2 bundle | **2.54.4** | maven-central, `aws-sdk-java-v2-bundle.jar` |
| JDBC-драйверы | postgres 42.7.x, ojdbc11, vertica | там же |

Чарты: `charts/spark-3.5` (основной), `charts/spark-base` (общий субчарт),
`charts/spark-4.{0,1}` — для справки/будущего.

## Образы: сборка и публикация

Канонический путь один — `docker/spark-custom` (самодостаточные Dockerfile,
компилируют Spark из исходников; `dist/*.tgz` НЕ требуются):

```bash
./scripts/build-images.sh                     # spark-custom:3.5.7 (+ jupyter)
SPARK_VERSION=3.5.8 ./scripts/build-images.sh
AIRFLOW=1 ./scripts/build-images.sh           # опционально airflow-spark
```

Публикация в GHCR — GitHub Action `.github/workflows/publish-images.yml`
(dispatch или тег `v*`); итоговые имена:

```
ghcr.io/fall-out-bug/spark-k8s-spark-custom:<ver>
ghcr.io/fall-out-bug/spark-k8s-jupyter-spark:<ver>
```

Для minikube-разработки образы можно грузить напрямую:
`minikube image load spark-custom:3.5.7`.

## Быстрый старт: чарт + MinIO + metastore

Готовый «озёрный минимум» — пресет `core-baseline`
(MinIO + PostgreSQL субчарта + Hive Metastore + History Server):

```bash
helm install my-spark charts/spark-3.5 \
  -f charts/spark-3.5/presets/core-baseline.yaml \
  --set global.s3.accessKey=...   \
  --set global.s3.secretKey=...   \
  --set spark-base.postgresql.auth.password=... \
  --set global.postgresql.host=my-spark-spark-base-postgresql
```

Правила кредов (constitution §IV): **дефолтных паролей нет ни в чартах, ни в
пресетах** — подача через `--set`, `-f secret-values.yaml` (из-под git) или
`existingSecret`. MinIO из пресета поднимается на
`http://minio-spark-35:9000` (имя переопределяется
`core.minio.fullnameOverride`), бакеты создаются автоматически, среди них
уже есть `spark-jobs`, `spark-logs`, `warehouse`.

s3a-конфигурация (`fs.s3a.endpoint/access.key/secret.key/path.style`) уже
прокинута во все нужные места рендера: Spark Connect, History Server,
Hive Metastore. Проверка сценария целиком:

```bash
helm template t charts/spark-3.5 -f charts/spark-3.5/presets/core-baseline.yaml \
  --set global.s3.accessKey=x --set global.s3.secretKey=x \
  --set spark-base.postgresql.auth.password=x >/tmp/r.yaml && grep -c s3a /tmp/r.yaml
```

## Тесты на k8s

Уровни проверки (от быстрого к тяжёлому):

```bash
# 1. Рендер/шаблоны без кластера (~30 сек; так работает PR-gate)
pytest -m "not e2e and not slow"

# 2. Одна реальная ячейка матрицы: deploy → smoke → e2e c записью/чтением в s3a
./scripts/run-matrix.sh --filter "id=SCENARIO-0036" --shared-infra deploy smoke e2e
#    S3 round-trip включается env: E2E_S3_ROUNDTRIP=1 (+S3_ACCESS_KEY/S3_SECRET_KEY)

# 3. Полный ночной уровень: 96 ячеек Spark 3.5.7/3.5.8/4.1.0/4.1.1 (k8s, no-gpu)
./scripts/run-matrix-96.sh --shared-infra
```

E2E-workload пишет агрегат как parquet в
`s3a://spark-jobs/e2e-roundtrip/<release>` и читает обратно с точным
побакетным сравнением — это настоящая проверка s3a, а не «MinIO рядом».
CI: `.github/workflows/ci-e2e.yml` гоняет ячейку №36 на push в dev и PR;
ночный P1/P2 (`ci-matrix-p1/p2.yml`) собирает сводку через
`scripts/aggregate-matrix-results.py`.

## Мониторинг

```bash
./scripts/tests/minikube/deploy-observability.sh   # Prometheus+Grafana+Loki в ns observability
./scripts/tests/minikube/verify-observability-recipes.sh
kubectl port-forward -n observability svc/observability-grafana 30030:30030
# Grafana: http://localhost:30030 (demo admin/admin)
```

Готовые панели: `spark-overview`, `performance-analysis`,
`airflow-cluster` (метрики DAG'ов идут от demo-metrics-exporter).
Пошаговые рецепты по ролям: `docs/observability/recipes/*-5min.md`.

## Известные ограничения (честно)

1. **Два опциональных MinIO-деплоя в spark-3.5**: per-release
   (`core.minio.*`, лёгкий emptyDir) и полный вариант внутри субчарта
   (`spark-base.minio.*`). По умолчанию оба выключены; включайте ровно один.
   Полная дедупликация запланирована отдельным change'ом.
2. SDK v2 2.54.4 — последний релиз на момент передачи; бамп =
   правка константы в четырёх `docker/spark-custom/Dockerfile.*`.
3. Доки по мониторингу (`docs/guides/monitoring/…`) описывают
   kube-prometheus-stack и не совпадают с демонстрационным стеком —
   ориентируйтесь на `docs/observability/INVENTORY.md`.
4. Коммит «96/96 passed» в `tests/results/` — исторический dry-run
   артефакт; реальное исполнение — шаги 2–3 выше.
