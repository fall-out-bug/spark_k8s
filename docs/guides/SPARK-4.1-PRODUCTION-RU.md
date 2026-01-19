# Производственное развертывание Spark 4.1.0

Гайд для DataOps/Platform Engineers: ресурсы, безопасность, HA, хранилище,
наблюдаемость и типичные проблемы.

## Обзор

Рекомендуемый базовый профиль:

- Spark Connect (3 реплики) с dynamic allocation
- Внешний S3 для event logs и данных
- Внешний PostgreSQL для Hive Metastore
- History Server включен
- Jupyter выключен (используйте JupyterHub отдельно)

## Ресурсные рекомендации

### Spark Connect

- **Replicas:** 3 (HA)
- **Requests:** 2 CPU / 4Gi
- **Limits:** 4 CPU / 8Gi

Executors (dynamic allocation):

- **Min/Max:** 2 / 50
- **Requests:** 2 CPU / 4Gi
- **Limits:** 4 CPU / 8Gi

### Hive Metastore

- **Requests:** 500m / 1Gi
- **Limits:** 2 CPU / 4Gi

### History Server

- **Requests:** 1 CPU / 2Gi
- **Limits:** 4 CPU / 8Gi
- Event logs: `s3a://prod-spark-logs/4.1/events`

## Безопасность (PSS Restricted)

Рекомендуемые настройки:

- `security.podSecurityStandards=true`
- Запуск без root (UID/GID 185)
- Drop всех Linux capabilities
- `allowPrivilegeEscalation=false`
- `seccompProfile: RuntimeDefault`

RBAC:

- Spark Connect должен создавать executor pods.
- Включите `rbac.create=true` и используйте отдельный ServiceAccount.

Network:

- Ограничьте доступ NetworkPolicy:
  - Spark Connect → Kubernetes API
  - Spark Connect → S3 endpoint
  - Spark Connect → Hive Metastore
  - History Server → S3 endpoint

## Высокая доступность

Spark Connect:

- 3 реплики, readiness/liveness probes включены.

Hive Metastore:

- Внешний PostgreSQL с HA (managed или primary/replica).

History Server:

- Stateless, логирование в S3.
- При необходимости разверните несколько реплик за Service.

## Хранилище

S3/MinIO:

- В проде используйте внешний S3.
- Настройте `global.s3.endpoint` и креды через Secrets.
- `pathStyleAccess` включайте только при необходимости.

Event logs:

- Разные префиксы по версиям:
  - `s3a://prod-spark-logs/3.5/events`
  - `s3a://prod-spark-logs/4.1/events`

## Наблюдаемость

Metrics:

- Spark Connect: метрики на 4040/15002 (scrape через PodMonitor).
- History Server: API на 18080.

Logging:

- Централизованный сбор логов (Fluent Bit / Vector).
- Логи driver/executor доступны через Kubernetes logging.

## Troubleshooting

Частые проблемы:

- **Executors не стартуют:** проверьте RBAC и ServiceAccount.
- **History Server пустой:** проверьте event log dir и S3 креды.
- **Ошибки Metastore:** проверьте PostgreSQL и имя БД.
- **Jupyter выключен:** ожидаемо для прод, используйте JupyterHub.

## Production Values Overlay

Стартовый пример:

```bash
helm upgrade --install spark-41 charts/spark-4.1 \
  -f docs/examples/values-spark-41-production.yaml
```

## Дополнительные гайды

- [Интеграция с Celeborn](CELEBORN-GUIDE.md)
- [Spark Operator](SPARK-OPERATOR-GUIDE.md)
