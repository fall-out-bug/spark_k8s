# Мультиверсионный деплой Spark (3.5.7 + 4.1.0)

Гайд описывает запуск Spark 3.5.7 (LTS) и 4.1.0 (latest)
в одном Kubernetes кластере.

## Обзор

Сценарии:

- Плавная миграция на Spark 4.1.0
- Версионные различия фич
- Изоляция команд (DS на 4.1.0, легаси на 3.5.7)

## Стратегия изоляции

Компоненты, которые ДОЛЖНЫ быть изолированы:

| Компонент | Метод | Причина |
|-----------|-------|---------|
| Hive Metastore | Разные БД (`metastore_spark35`, `metastore_spark41`) | Несовместимость схем |
| History Server | Разные S3 префиксы (`/3.5/events`, `/4.1/events`) | Разный формат логов |
| Services | Разные release имена (`spark-35`, `spark-41`) | Без конфликтов |
| RBAC | Разные ServiceAccount | Изоляция прав |

Компоненты, которые МОЖНО шарить:

- PostgreSQL (разные базы)
- MinIO (разные бакеты/префиксы)
- Namespace (ok для dev/test; в проде лучше разнести)

## Деплой

### Вариант 1: Один namespace (Dev/Test)

```bash
helm install spark-35 charts/spark-3.5 \
  --namespace spark \
  --set spark-standalone.enabled=true \
  --set spark-standalone.hiveMetastore.enabled=true \
  --set spark-standalone.historyServer.enabled=true \
  --set spark-standalone.historyServer.logDirectory="s3a://spark-logs/3.5/events" \
  --wait

helm install spark-41 charts/spark-4.1 \
  --namespace spark \
  --set connect.enabled=true \
  --set hiveMetastore.enabled=true \
  --set hiveMetastore.database.name="metastore_spark41" \
  --set historyServer.enabled=true \
  --set historyServer.logDirectory="s3a://spark-logs/4.1/events" \
  --wait
```

### Вариант 2: Разные namespace (Production)

```bash
kubectl create namespace spark-35
kubectl create namespace spark-41

helm install spark-35 charts/spark-3.5 \
  --namespace spark-35 \
  --set spark-standalone.enabled=true \
  --wait

helm install spark-41 charts/spark-4.1 \
  --namespace spark-41 \
  --set connect.enabled=true \
  --wait
```

## Проверка

### 1) Изоляция сервисов

```bash
kubectl get svc -n spark | grep -E "(spark-35|spark-41)"
```

### 2) Изоляция metastore

```bash
kubectl get deploy -n spark -l app=hive-metastore -o jsonpath='{.items[*].spec.template.spec.containers[0].env}'
```

### 3) Изоляция History Server

```bash
kubectl logs -n spark -l app=spark-history-server | grep "s3a://spark-logs"
```

### 4) Coexistence test

```bash
./scripts/test-coexistence.sh spark
```

## Стратегия миграции (по этапам)

### Этап 1: Параллельный запуск

1. Деплоим 4.1.0 рядом с 3.5.7
2. Прод оставляем на 3.5.7
3. Запускаем smoke тесты для 4.1.0

### Этап 2: Пилотная миграция

1. Мигрируем 1-2 low-risk job
2. Сравниваем производительность (benchmark)
3. Мониторим стабильность

### Этап 3: Постепенный rollout

1. Мигрируем 20% джобов в неделю
2. Держим 3.5.7 для rollback
3. Мониторим через History Server

### Этап 4: Вывод 3.5.7

1. Мигрируем оставшиеся джобы
2. Запускаем финальный coexistence тест
3. Удаляем `spark-35`

## Частые проблемы

### Конфликт имен сервисов

**Симптом:** `helm install` падает с "service already exists".

**Решение:** разные release имена (`spark-35`, `spark-41`).

### Общая БД metastore

**Симптом:** ошибки схемы или пропавшие таблицы.

**Решение:** разные базы:

- 3.5.7: `metastore_spark35`
- 4.1.0: `metastore_spark41`

### History Server читает не те логи

**Симптом:** логи одной версии видны в другой.

**Решение:** разные S3 префиксы:

- 3.5.7: `s3a://spark-logs/3.5/events`
- 4.1.0: `s3a://spark-logs/4.1/events`

## Best Practices

1. В проде используйте разные namespace.
2. Фиксируйте версию Spark для каждого job.
3. Держите 3.5.7 для rollback до стабилизации 4.1.0.
4. Автомиграцию Hive Metastore не рекомендуем (out of scope).

## Пример values overlay

Используйте пример для shared namespace:

- `docs/examples/values-multi-version.yaml`

```bash
helm install spark-35 charts/spark-3.5 -f docs/examples/values-multi-version.yaml
helm install spark-41 charts/spark-4.1 -f docs/examples/values-multi-version.yaml
```

## Ссылки

- [Coexistence Test Script](../../scripts/test-coexistence.sh)
- [Spark 3.5.7 Production Guide](SPARK-STANDALONE-PRODUCTION.md)
- [Spark 4.1.0 Production Guide](SPARK-4.1-PRODUCTION.md)
