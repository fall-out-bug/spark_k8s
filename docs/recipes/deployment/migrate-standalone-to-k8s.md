# Migrate from Standalone to K8s Backend

**Source:** E2E matrix

## Overview

Мигрировать Spark с Standalone backend на K8s backend для динамического масштабирования executors.

## Prerequisites

- Текущий деплой: Spark Connect + Standalone
- Целевой деплой: Spark Connect + K8s backend

## Migration Steps

### Шаг 1: Backup текущей конфигурации

```bash
# Сохранить текущие values
helm get values spark-prod -n prod > prod-backup-$(date +%Y%m%d).yaml

# Проверить текущий backend mode
kubectl get cm -n prod spark-connect-configmap -o yaml | grep backendMode
```

### Шаг 2: Подготовить новую конфигурацию

Используйте `values-scenario-jupyter-connect-k8s.yaml` как шаблон:

```bash
cp charts/spark-4.1/values-scenario-jupyter-connect-k8s.yaml \
   charts/spark-4.1/values-prod-k8s.yaml
```

### Шаг 3: Выключить Standalone (опционально)

```bash
# Если Standalone больше не нужен другим командам
helm uninstall spark-standalone-master -n prod
helm uninstall spark-standalone-worker -n prod

# Или масштабировать до 0
kubectl scale statefulset -n prod spark-standalone-worker --replicas=0
```

### Шаг 4: Переключить на K8s backend

```bash
helm upgrade spark-prod charts/spark-4.1 -n prod \
  -f charts/spark-4.1/values-prod-k8s.yaml \
  --set connect.backendMode=k8s \
  --set connect.dynamicAllocation.enabled=true \
  --set connect.dynamicAllocation.minExecutors=2 \
  --set connect.dynamicAllocation.maxExecutors=50 \
  --set connect.initialExecutors=5 \
  --reuse-values
```

### Шаг 5: Настроить executor ресурсы для K8s

```bash
helm upgrade spark-prod charts/spark-4.1 -n prod \
  --set connect.executor.cores=2 \
  --set connect.executor.coresLimit=4 \
  --set connect.executor.memory=4Gi \
  --set connect.executor.memoryLimit=6Gi \
  --set connect.executor.instances=5 \
  --reuse-values
```

### Шаг 6: Валидация

```bash
# 1. Проверить что Connect запустился
kubectl wait --for=condition=ready pod -n prod -l app=spark-connect --timeout=300s

# 2. Проверить backend mode
kubectl exec -n prod deploy/spark-prod-spark-41-connect -- \
  printenv | grep BACKEND_MODE

# 3. Запустить тестовый job
kubectl exec -n prod deploy/jupyter -- \
  python3 -c "
from pyspark.sql import SparkSession
from pyspark.conf import SparkConf

conf = SparkConf()
conf.set('spark.executor.instances', '3')
conf.set('spark.dynamicAllocation.enabled', 'false')

spark = SparkSession.builder \
    .remote('sc://spark-prod-spark-41-connect:15002') \
    .config(conf=conf) \
    .getOrCreate()

print(f'Executors: {spark.sparkContext._jsc.sc().getExecutorIdsStatus().keys()}')
df = spark.range(100000).count()
print(f'Count: {df}')
spark.stop()
"

# 4. Проверить что executor pods создаются
kubectl get pods -n prod -l spark-role=executor
```

## Rollback (если что-то пошло не так)

```bash
# Откатиться на Standalone
helm rollback spark-prod -n prod

# Или переключить обратно
helm upgrade spark-prod charts/spark-4.1 -n prod \
  --set connect.backendMode=standalone \
  --set connect.standalone.masterService=spark-standalone-master \
  --set connect.standalone.masterPort=7077 \
  --reuse-values

# Восстановить Standalone если нужно
helm install spark-standalone charts/spark-3.5/charts/spark-standalone -n prod \
  -f prod-backup-YYYYMMDD.yaml
```

## Differences: Standalone vs K8s

| Параметр | Standalone | K8s |
|----------|-----------|-----|
| Executor pods | Fixed (workers) | Dynamic |
| Масштабирование | Manual (add workers) | Automatic |
| Resource quota | Pre-allocated | On-demand |
| Startup time | Быстро | Медленнее (pod provisioning) |
| Изоляция | Shared | Per-job |

## Best Practices

1. **Начните с консервативных настроек**
   ```yaml
   dynamicAllocation:
     enabled: true
     minExecutors: 2
     maxExecutors: 10  # постепенно увеличьте до 50
   ```

2. **Мониторинг**
   ```bash
   # Следите за количеством executors
   kubectl get pods -n prod -l spark-role=executor -w

   # Проверьте использование ресурсов
   kubectl top pods -n prod -l spark-role=executor
   ```

3. **Resource quotas**
   ```yaml
   # Установите квоты чтобы избежать oversubscription
   apiVersion: v1
   kind: ResourceQuota
   metadata:
     name: spark-executor-quota
   spec:
     hard:
       requests.cpu: "100"
       requests.memory: 400Gi
       limits.cpu: "200"
       limits.memory: 800Gi
   ```

## References

- Usage Guide: `docs/guides/ru/spark-k8s-constructor.md`
- E2E Report: `docs/testing/F06-e2e-matrix-report.md`
- Spark K8s: https://spark.apache.org/docs/latest/running-on-kubernetes.html
