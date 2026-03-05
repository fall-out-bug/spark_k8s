# Требования: Матрица тестов 320 сценариев

## 1. Требование

**320 сценариев** — каждый проходит полный цикл:

```
deploy → smoke → e2e → load
```

- **deploy:** Helm install успешен, поды Ready
- **smoke:** 1K rows, count + filter → SMOKE_SUCCESS
- **e2e:** 10K rows, aggregations, joins → E2E_SUCCESS
- **load:** S3 parquet, 3 agg → LOAD_SUCCESS
- **history:** после load — приложение видно в History Server

## 2. Ожидаемый результат

- `./scripts/run-matrix.sh --filter "id=SCENARIO-XXXX" all` — PASS для любого SCENARIO-0001..SCENARIO-0320
- `./scripts/run-matrix-96.sh` — 96/96 PASS (gpu=false, platform=k8s)
- `./scripts/run-matrix-320.sh` — 320/320 PASS

## 3. Окружение

- K8s кластер (minikube 6 CPU / 48Gi или аналог)
- `--shared-infra`: MinIO, History Server, Hive Metastore, OTEL — общие для всех сценариев
- Образы `spark-custom:*` предзагружены (build-and-load-matrix-images.sh)

## 4. Что НЕ различается по требованиям

- k8s native vs standalone
- connect vs non-connect
- shared infra — один и тот же для всех 320

Все 320 — равноправные варианты деплоя. Пайплайн должен поддерживать каждый.

## 5. Текущее состояние (что сломано)

| Проблема | Сценарии | Причина |
|----------|----------|---------|
| deploy timeout | connect=false (160) | deploy.sh ждёт connect pod, его нет |
| smoke/e2e/load fail | connect=false (160) | скрипты ищут connect pod |
| image не инжектится | connect=false | run-matrix ставит только connect.image |
| spark-4.1 connect=false | 80 сценариев (4.1.x) | chart spark-4.1 без standalone — только connect |

Распределение: 160 connect=true, 160 connect=false. Среди connect=false: 80×3.5.x, 80×4.1.x.

## 6. Критерий приёмки

Исправления считаются готовыми, когда:

1. `run-matrix.sh --filter "id=SCENARIO-0041" all` (connect=false, 3.5.7) — PASS
2. `run-matrix.sh --filter "id=SCENARIO-0001" all` (connect=true, 3.5.7) — PASS
3. Оба типа (connect true/false) проходят deploy → smoke → e2e → load без ручных исключений
